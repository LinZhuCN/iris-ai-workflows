"""Receiver-side durable storage; never imported by outbound send paths."""
import json
import socket
import time

import iris
from transport import _receipt, digest, validate_id, validate_payload, NAMESPACES


def _context(branch):
    if branch not in ("rest", "hl7") or iris.system.Process.NameSpace() != NAMESPACES[branch]:
        raise ValueError("receiver namespace mismatch")


def read(delivery_id, branch):
    validate_id(delivery_id)
    _context(branch)
    rows = list(iris.sql.exec(
        "SELECT RawPayload,PayloadHash FROM MultiOrg_Receiver.Receipt WHERE DeliveryId = ?",
        delivery_id))
    if not rows:
        return json.dumps({"delivery_id": delivery_id, "found": False,
                           "namespace": NAMESPACES[branch]})
    payload, stored_hash = rows[0]
    if digest(payload) != stored_hash:
        raise ValueError("stored digest mismatch")
    return json.dumps(dict(_receipt(branch, delivery_id, payload), found=True))


def store(delivery_id, payload, branch):
    validate_payload(branch, delivery_id, payload)
    _context(branch)
    existing = json.loads(read(delivery_id, branch))
    duplicate = existing.get("found", False)
    if not duplicate:
        try:
            iris.sql.exec(
                "INSERT INTO MultiOrg_Receiver.Receipt (DeliveryId,PayloadHash,RawPayload) VALUES (?,?,?)",
                delivery_id, digest(payload), payload)
        except Exception:
            # A concurrent insert must still satisfy exact-body idempotency.
            existing = json.loads(read(delivery_id, branch))
            if not existing.get("found"):
                raise
            duplicate = True
    receipt = json.loads(read(delivery_id, branch))
    if receipt["payload_hash"] != digest(payload) or receipt["payload"] != payload:
        raise ValueError("delivery ID body conflict")
    receipt["duplicate"] = duplicate
    return json.dumps(receipt)


def listen():
    _context("hl7")
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("127.0.0.1", 25751))
        server.listen(8)
        while True:
            connection, _ = server.accept()
            with connection:
                connection.settimeout(3)
                frame = bytearray()
                control = ""
                try:
                    deadline = time.monotonic() + 5
                    while not frame.endswith(b"\x1c\r"):
                        if time.monotonic() >= deadline or len(frame) > 16003:
                            raise ValueError("MLLP frame deadline/size")
                        block = connection.recv(4096)
                        if not block:
                            raise ValueError("incomplete MLLP frame")
                        frame.extend(block)
                    if not frame.startswith(b"\x0b"):
                        raise ValueError("MLLP start byte missing")
                    if frame == b"\x0bM2-RECEIVER-HEALTH\x1c\r":
                        connection.sendall(b"\x0bM2-DEMOCLINIC-v1\x1c\r")
                        continue
                    payload = frame[1:-2].decode("utf-8")
                    fields = payload.split("\r", 1)[0].split("|")
                    if len(fields) > 9:
                        control = validate_id(fields[9])
                    store(control, payload, "hl7")
                    code = "AA"
                except Exception:
                    code = "AE"
                # No ACK to a mere readiness connection; NACKs only echo validated IDs.
                if control:
                    ack = (f"MSH|^~\\&|DEMOCLINIC|CLINIC|DEMODISTRIBUTION|SOURCE|"
                           f"{time.strftime('%Y%m%d%H%M%S')}||ACK|ACK-{control}|P|2.5\r"
                           f"MSA|{code}|{control}\r")
                    try:
                        connection.sendall(b"\x0b" + ack.encode() + b"\x1c\r")
                    except OSError:
                        pass
