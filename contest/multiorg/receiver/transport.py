"""Owned, loopback-only protocol clients. Importable from embedded IRIS Python."""
import base64
import hashlib
import json
import pathlib
import re
import socket
import subprocess
import time
import urllib.error
import urllib.request

CONFIG = pathlib.Path("/dur/multiorg-receiver/credentials.json")
ROOT = pathlib.Path(__file__).resolve().parent
JAR = "/usr/irissys/dev/java/lib/1.8/intersystems-jdbc-3.11.0.jar"
REST_BASE = "http://gateway:80/csp/multiresearch/receipts"
NAMESPACES = {"sql": "DEMOQUALITY", "rest": "DEMORESEARCH", "hl7": "DEMOCLINIC"}
BRANCH_ALIASES = {"quality": "sql", "research": "rest", "clinic": "hl7"}
PROTOCOLS = {"sql": "JDBC/TCP", "rest": "HTTP/JSON", "hl7": "HL7v2/MLLP"}


def validate_id(value):
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9-]{1,64}", value):
        raise ValueError("delivery_id must be 1..64 ASCII alphanumeric or hyphen characters")
    return value


def digest(payload):
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def validate_payload(branch, delivery_id, payload):
    validate_id(delivery_id)
    if branch not in NAMESPACES:
        raise ValueError("unknown recipient branch")
    if not isinstance(payload, str) or len(payload.encode("utf-8")) > 16000:
        raise ValueError("payload must be UTF-8 text of at most 16000 bytes")
    if branch in ("sql", "rest"):
        value = json.loads(payload)
        if not isinstance(value, dict):
            raise ValueError("JSON object required")
        if branch == "sql":
            if set(value) != {"patient_id", "birthYear", "status"}:
                raise ValueError("SQL payload requires exactly patient_id, birthYear, status")
            if (not isinstance(value["patient_id"], str) or not 1 <= len(value["patient_id"]) <= 64
                    or type(value["birthYear"]) is not int or not 1800 <= value["birthYear"] <= 2100
                    or not isinstance(value["status"], str) or not 1 <= len(value["status"]) <= 64):
                raise ValueError("invalid quality column values")
        return value
    segments = payload.split("\r")
    fields = segments[0].split("|")
    if (len(fields) < 12 or fields[0] != "MSH" or fields[1] != "^~\\&"
            or fields[9] != delivery_id or not payload.endswith("\r")
            or "\n" in payload or "\x0b" in payload or "\x1c" in payload
            or not any(s.startswith("PID|") for s in segments)):
        raise ValueError("HL7 requires MSH-10 delivery_id, PID, CR segments and no framing bytes")
    pids = [s.split("|") for s in segments if s.startswith("PID|")]
    if (len(pids) != 1 or len(pids[0]) < 8 or not pids[0][3]
            or not pids[0][5] or not re.fullmatch(r"[0-9]{8}", pids[0][7])):
        raise ValueError("HL7 PID requires one patient MRN, name and YYYYMMDD DOB")
    return payload


def _receipt(branch, delivery_id, payload):
    return {"delivery_id": delivery_id, "payload_hash": digest(payload),
            "payload": payload, "stored_payload": payload, "namespace": NAMESPACES[branch],
            "protocol": PROTOCOLS[branch], "readback_match": True}


def _sql(mode, delivery_id, payload=""):
    values = validate_payload("sql", delivery_id, payload) if mode == "send" else {}
    fields = [mode, delivery_id, payload, digest(payload), values.get("patient_id", ""),
              str(values.get("birthYear", "")), values.get("status", "")]
    data = "\n".join(base64.b64encode(v.encode()).decode() for v in fields) + "\n"
    result = subprocess.run(
        ["java", "--class-path", JAR, str(ROOT / "QualityClient.java")],
        input=data, text=True, capture_output=True, timeout=25, check=False)
    if result.returncode:
        raise RuntimeError("quality JDBC delivery/read failed (no implicit retry)")
    lines = result.stdout.strip().splitlines()
    if lines == ["MISSING"]:
        return {"delivery_id": delivery_id, "found": False, "namespace": NAMESPACES["sql"]}
    if len(lines) != 5:
        raise RuntimeError("invalid JDBC receipt")
    stored = base64.b64decode(lines[0], validate=True).decode()
    receipt = _receipt("sql", delivery_id, stored)
    receipt["duplicate"] = lines[1] == "DUPLICATE"
    receipt["columns"] = {"patient_id": base64.b64decode(lines[2], validate=True).decode(),
                          "birthYear": int(base64.b64decode(lines[3], validate=True).decode()),
                          "status": base64.b64decode(lines[4], validate=True).decode()}
    if json.loads(stored) != receipt["columns"]:
        raise RuntimeError("quality stored columns and raw receipt disagree")
    receipt["column_inventory"] = ["patient_id", "birthYear", "status"]
    return receipt


def _http(method, delivery_id, payload=None):
    config = json.loads(CONFIG.read_text())
    token = base64.b64encode(
        (config["research_user"] + ":" + config["research_password"]).encode()).decode()
    body = json.dumps({"delivery_id": delivery_id, "payload": payload},
                      ensure_ascii=False).encode() if method == "POST" else None
    url = REST_BASE
    if method == "GET":
        url += "/" + validate_id(delivery_id)
    req = urllib.request.Request(url, data=body, method=method,
                                 headers={"Authorization": "Basic " + token,
                                          "Content-Type": "application/json; charset=utf-8"})
    # Do not honor external proxy settings or follow redirects with credentials.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    try:
        with opener.open(req, timeout=8) as response:
            data = response.read(200000)
            receipt = json.loads(data)
            receipt["http_status"] = response.status
            return receipt
    except urllib.error.HTTPError as exc:
        raise RuntimeError("research receiver HTTP " + str(exc.code)) from None


def check_ack(ack, delivery_id):
    msa = [s.split("|") for s in ack.split("\r") if s.startswith("MSA|")]
    if len(msa) != 1 or len(msa[0]) < 3 or msa[0][2] != delivery_id or msa[0][1] != "AA":
        raise ValueError("HL7 ACK rejected or control ID does not match")
    return msa[0][1]


def _mllp(delivery_id, payload):
    with socket.create_connection(("127.0.0.1", 25751), timeout=5) as conn:
        conn.settimeout(5)
        conn.sendall(b"\x0b" + payload.encode() + b"\x1c\r")
        response = bytearray()
        deadline = time.monotonic() + 8
        while b"\x1c\r" not in response:
            if time.monotonic() > deadline or len(response) > 8192:
                raise TimeoutError("MLLP ACK deadline/size exceeded")
            block = conn.recv(4096)
            if not block:
                raise RuntimeError("MLLP closed before ACK")
            response.extend(block)
    if not response.startswith(b"\x0b") or not response.endswith(b"\x1c\r"):
        raise ValueError("invalid MLLP ACK frame")
    ack = response[1:-2].decode()
    check_ack(ack, delivery_id)
    deadline = time.monotonic() + 4
    while True:
        receipt = read("hl7", delivery_id)
        if receipt.get("found", True):
            receipt["ack"] = ack
            receipt["ack_code"] = "AA"
            receipt["ack_control_id"] = delivery_id
            return receipt
        if time.monotonic() >= deadline:
            raise TimeoutError("HL7 ACK received but durable readback not available")
        time.sleep(0.1)


def send(branch: str, delivery_id: str, payload: str) -> dict:
    branch = BRANCH_ALIASES.get(branch, branch)
    validate_payload(branch, delivery_id, payload)
    if branch == "sql":
        receipt = _sql("send", delivery_id, payload)
    elif branch == "rest":
        receipt = _http("POST", delivery_id, payload)
        reread = _http("GET", delivery_id)
        if reread.get("payload") != receipt.get("payload"):
            raise RuntimeError("REST POST and GET receipt disagree")
    else:
        receipt = _mllp(delivery_id, payload)
    receipt["readback_match"] = (receipt.get("delivery_id") == delivery_id
                                  and receipt.get("payload_hash") == digest(payload)
                                  and receipt.get("payload") == payload
                                  and receipt.get("namespace") == NAMESPACES[branch])
    if not receipt["readback_match"]:
        raise RuntimeError("durable receiver readback mismatch")
    return receipt


def read(branch: str, delivery_id: str) -> dict:
    branch = BRANCH_ALIASES.get(branch, branch)
    validate_id(delivery_id)
    if branch == "sql":
        return _sql("read", delivery_id)
    if branch == "rest":
        return _http("GET", delivery_id)
    if branch != "hl7":
        raise ValueError("unknown recipient branch")
    import iris
    previous = iris.system.Process.NameSpace()
    try:
        iris.system.Process.SetNamespace("DEMOCLINIC")
        return json.loads(iris.cls("MultiOrg.Receiver.API").Read(delivery_id, "hl7"))
    finally:
        iris.system.Process.SetNamespace(previous)


def readiness() -> list:
    results = []
    for branch in NAMESPACES:
        try:
            if branch == "hl7":
                with socket.create_connection(("127.0.0.1", 25751), timeout=2) as conn:
                    conn.settimeout(2)
                    conn.sendall(b"\x0bM2-RECEIVER-HEALTH\x1c\r")
                    if conn.recv(256) != b"\x0bM2-DEMOCLINIC-v1\x1c\r":
                        raise RuntimeError("clinic listener ownership mismatch")
            receipt = read(branch, "readiness-check")
            results.append({"name": branch, "ready": True, "detail": NAMESPACES[branch]})
        except Exception as exc:
            results.append({"name": branch, "ready": False,
                            "detail": (type(exc).__name__ + ": " + str(exc))[:240]})
    return results
