"""Real local acceptance; no AI/model calls and no existing recipient data deletion."""
import json
import base64
import subprocess
import urllib.error
import urllib.request
import uuid

import iris
import transport


def count(namespace):
    previous = iris.system.Process.NameSpace()
    try:
        iris.system.Process.SetNamespace(namespace)
        return int(list(iris.sql.exec("SELECT COUNT(*) FROM MultiOrg_Receiver.Receipt"))[0][0])
    finally:
        iris.system.Process.SetNamespace(previous)


def run(branches=("sql", "rest", "hl7")):
    origin = iris.system.Process.NameSpace()
    prefix = "m2-" + uuid.uuid4().hex
    bodies = {
        "sql": '{"patient_id":"SYN-M2-001","birthYear":1980,"status":"referred"}',
        "rest": '{"patient_id":"SYN-M2-001","name":"Synthetic Élodie","birthDate":"1980-01-02"}',
        "hl7": ("MSH|^~\\&|SOURCE|HOSPITAL|CLINIC|DEMOCLINIC|20261024120000||"
                f"ADT^A01|{prefix}-hl7|P|2.5\r"
                "PID|1||SYN-M2-001^^^DEMO^MR||SYNTHETIC^PATIENT||19800102\r")
    }
    baseline = {b: count(ns) for b, ns in transport.NAMESPACES.items()}
    checks = 0
    ready = transport.readiness()
    if not branches or any(branch not in transport.NAMESPACES for branch in branches):
        raise ValueError("unknown acceptance branch")
    if not all(item["ready"] for item in ready if item["name"] in branches):
        raise RuntimeError("RECEIVER-FAIL readiness: " + json.dumps(ready))
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    if "rest" in branches:
        try:
            with opener.open(transport.REST_BASE + "/readiness-check", timeout=5):
                raise AssertionError("REST permitted anonymous read")
        except urllib.error.HTTPError as exc:
            assert exc.code in (401, 403), "REST must require authentication"
            checks += 1
    if "sql" in branches:
        fields = ["permissions", prefix, "", "", "", "", ""]
        probe = subprocess.run(
            ["java", "--class-path", transport.JAR, str(transport.ROOT / "QualityClient.java")],
            input="\n".join(base64.b64encode(v.encode()).decode() for v in fields) + "\n",
            text=True, capture_output=True, timeout=25)
        assert probe.returncode == 0 and probe.stdout.strip() == "PERMISSIONS-OK", "SQL role must not update/delete"
        checks += 1
    for branch, payload in bodies.items():
        if branch not in branches:
            continue
        delivery_id = prefix + "-" + branch
        alias = {"sql": "quality", "rest": "research", "hl7": "clinic"}[branch]
        first = transport.send(alias, delivery_id, payload)
        assert first["readback_match"] and first["payload"] == payload, branch + " initial readback"
        checks += 1
        repeat = transport.send(branch, delivery_id, payload)
        assert repeat["readback_match"], branch + " duplicate readback"
        checks += 1
        stored = transport.read(alias, delivery_id)
        assert stored["payload_hash"] == transport.digest(payload), branch + " read digest"
        checks += 1
        changed = payload.replace("SYN-M2-001", "SYN-M2-002")
        try:
            transport.send(branch, delivery_id, changed)
        except (RuntimeError, ValueError):
            checks += 1
        else:
            raise AssertionError("different body accepted for same delivery ID")
        assert transport.read(branch, delivery_id)["payload"] == payload, branch + " rejection changed stored body"
        actual_count = count(transport.NAMESPACES[branch])
        assert actual_count == baseline[branch] + 1, branch + " count " + str((baseline[branch], actual_count))
        checks += 2
        assert iris.system.Process.NameSpace() == origin, branch + " namespace changed"
        checks += 1
    if "hl7" in branches:
        invalid_id = prefix + "-invalid"
        invalid = bodies["hl7"].replace(prefix + "-hl7", invalid_id).replace(
            "SYNTHETIC^PATIENT", "")
        try:
            transport._mllp(invalid_id, invalid)
        except ValueError:
            assert not transport.read("hl7", invalid_id).get("found"), "negative ACK inserted malformed PID"
            checks += 1
        else:
            raise AssertionError("clinic accepted malformed patient PID")
    try:
        transport.read("hl7", "../invalid")
    except ValueError:
        assert iris.system.Process.NameSpace() == origin
        checks += 1
    print("RECEIVER-ACCEPTANCE " + json.dumps({
        "checks": checks, "failures": 0, "delivery_prefix": prefix,
        "verified_branches": list(branches),
        "readiness": ready,
        "counts_before": baseline,
        "counts_after": {b: count(ns) for b, ns in transport.NAMESPACES.items()},
        "namespace_restored": iris.system.Process.NameSpace() == origin}))
