#!/usr/bin/env python3
"""Explicit local M2 setup, synthetic sends or read-only saved-evidence acceptance. No model calls."""
import argparse
import json
import re
import time
from pathlib import Path

from business_privacy import require
from declaration_review_test import BASE
from route_ui_test import admin_request, local_base
from platform_test import request
from utilization_test import MARKER, execute

SAVED = Path(__file__).resolve().parent / "data/production-evidence-acceptance.json"


def api(base, path, body=None):
    status, value = admin_request(base, path, body)
    require(status == 200, f"M2 API {path}: HTTP {status}: {value}")
    return value


def pages(base, production, session=""):
    items, before, seen = [], 0, set()
    while True:
        page = api(base, f"/productions/{production}/evidence?before={before}&session={session}")
        require(page["production_id"] == production and page["model_calls"] == 0, "Evidence identity/accounting mismatch")
        items.extend(page["items"])
        before = page["next_before"]
        if not before:
            return items
        require(before not in seen, "Evidence cursor loop")
        seen.add(before)


def send(route, payload, format="json-object"):
    batch = "m2-" + str(time.time_ns())
    # Values are generated synthetic fixtures, never arbitrary user code.
    literal = json.dumps(payload).replace('"', '""')
    code = (f'Set request=##class(Contest.StructuredRequest).%New(), request.BatchId="{batch}",'
            f'request.Route="{route}", request.Format="{format}", request.PayloadJson="{literal}" '
            'Set sc=##class(Ens.Director).CreateBusinessService("StructuredSource",.service) '
            'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
            'Set sc=service.ProcessInput(request,.reply) '
            'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
            f'Write "{MARKER}",{{"batch":(request.BatchId),"message":(request.%Id()),"outcome":(reply.Outcome)}}.%ToJSON(),!')
    return execute("OBSERVATION", code, label="M2 synthetic send")


def wait_for(base, production, message, expected):
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        matches = [r for r in pages(base, production)
                   if str(r["header"]["body_id"]) == str(message)
                   and r["header"]["body_class"] == "Contest.StructuredRequest"]
        if matches and all(r["capture"]["state"] == expected for r in matches):
            return matches
        time.sleep(1)
    raise ValueError(f"Automatic observer did not capture message {message} as {expected}")


def acceptance(base):
    require(not SAVED.exists(), "Acceptance is immutable; use --check, never silently repeat business sends")
    production = next(p for p in api(base, "/productions/discover")["items"] if p["namespace"] == "OBSERVATION")
    enrolled = api(base, "/productions/enroll", {
        "namespace": production["namespace"], "production": production["production"],
        "config_hash": production["config_hash"], "acknowledge_monitoring": True,
    })
    pid = enrolled["id"]
    require(not api(base, f"/productions/{pid}/flows")["items"], "No manual flow/context registration for acceptance")
    first = send("A", {"patient_id": "SYNTHETIC-M2-A", "encounter": {"status": "finished"}})
    wait_for(base, pid, first["message"], "not_authorized")
    api(base, "/productions/authorize-inspection", {
        "production_id": pid, "config_hash": production["config_hash"],
        "acknowledge_local_synthetic_inspection": True,
    })
    second = send("A", {"patient_id": "SYNTHETIC-M2-A", "email": "synthetic@example.invalid"})
    wait_for(base, pid, second["message"], "captured")
    third = send("B", {"resourceType": "Bundle", "entry": [
        {"resource": {"resourceType": "Patient", "id": "SYNTHETIC-M2-B", "birthDate": "2001-02-03"}}]}, "fhir-r4")
    wait_for(base, pid, third["message"], "captured")
    before = api(base, f"/productions/{pid}/paths")["items"]
    require(not any(p["target"] == "ReceiverC" for p in before), "New path C must not already be observed")
    fourth = send("C", {"resourceType": "Bundle", "entry": []}, "fhir-r4")
    wait_for(base, pid, fourth["message"], "evidence_failed")
    fifth = send("C", {"patient_id": "SYNTHETIC-M2-C", "unknown_key": "PRIVATE-SYNTHETIC-VALUE"})
    wait_for(base, pid, fifth["message"], "captured")
    value = {"production_id": pid, "runs": [first, second, third, fourth, fifth],
             "expected": ["not_authorized", "captured", "captured", "evidence_failed", "captured"],
             "new_model_calls": 0}
    SAVED.write_text(json.dumps(value, indent=2) + "\n")
    check(base)


def check(base):
    saved = json.loads(SAVED.read_text())
    pid = saved["production_id"]
    records = pages(base, pid)
    require(len({r["id"] for r in records}) == len(records), "No duplicate evidence records")
    require(len(saved["runs"]) == len(saved["expected"]) == 5, "Exactly five saved acceptance batches required")
    for run, expected in zip(saved["runs"], saved["expected"]):
        require(re.fullmatch(r"m2-[0-9]{1,25}", run["batch"]) is not None, "Bounded saved fixture batch ID required")
        matches = [r for r in records if r["header"]["body_class"] == "Contest.StructuredRequest"
                   and str(r["header"]["body_id"]) == str(run["message"])]
        require(len(matches) == 2 and all(r["capture"]["state"] == expected for r in matches),
                "Both real BS/BP and BP/BO request edges must have the expected capture disposition")
        for r in matches:
            require(r["outcome"] == "attempted" and r["delivery_evidence"] == "message_header_only",
                    "Successful send must not be upgraded to independent receiver evidence")
            session = str(r["header"]["session_id"])
            grouped = pages(base, pid, session)
            require(grouped and all(str(v["header"]["session_id"]) == session for v in grouped),
                    "Session correlation must be exact and Production scoped")
    paths = api(base, f"/productions/{pid}/paths")["items"]
    for route in ("A", "B", "C"):
        require(any(e["source"] == "StructuredSource" and e["target"] == "Process" + route for e in paths),
                "Source path missing: " + route)
        require(any(e["source"] == "Process" + route and e["target"] == "Receiver" + route for e in paths),
                "Receiver path missing: " + route)
    require(any(r["capture"]["state"] == "unsupported" for r in records), "Unsupported replies remain visible")
    require("PRIVATE-SYNTHETIC-VALUE" not in json.dumps(records) and
            "synthetic@example.invalid" not in json.dumps(records), "Raw values leaked into evidence")
    require(not api(base, f"/productions/{pid}/flows")["items"], "Monitoring never manufactures manual flow records")
    batches = ",".join("'" + run["batch"] + "'" for run in saved["runs"])
    readback = execute("OBSERVATION", (
        f'Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM SQLUser.StructuredReceipt WHERE BatchID IN ({batches})") '
        'If rs.%SQLCODE<0 { Throw ##class(%Exception.General).%New("Readback query failed") } '
        f'Set next=rs.%Next() Write "{MARKER}",{{"rows":(rs.%Get("N"))}}.%ToJSON(),!'))
    require(readback["rows"] == 5, "All five real business deliveries must remain in SQL")
    for path in ("/productions/authorize-inspection", "/productions/revoke-inspection"):
        require(request(base, path, body={})[0] == 403, "Readers cannot grant or revoke payload inspection")
        require(admin_request(base, path, {}, header=False)[0] == 403, "CSRF required for payload-access changes")
    for suffix in ("/evidence?before=1.5", "/evidence?session=../bad", "/paths?after=../bad"):
        require(admin_request(base, "/productions/" + pid + suffix)[0] == 409, "Bounded evidence/session/path cursor required")
    require(request(base, f"/productions/{pid}/evidence", account=None)[0] == 401, "Anonymous evidence access rejected")
    all_items = api(base, "/productions")["items"]
    require(all(not p["error"] and p["current"]["running"] for p in all_items), "Observer/business health failure")
    for p in all_items:
        if p["id"] != pid:
            require(all(r["production_id"] != pid for r in pages(base, p["id"])), "Cross-Production evidence leak")
    print(json.dumps({"status": "passed", "production_id": pid, "observations": len(records),
                      "observed_edges": len(paths), "capture_counts": api(base, f"/productions/{pid}/evidence")["capture_counts"],
                      "manual_flow_records": 0, "new_model_calls": 0, "mode": "read_saved_runtime_evidence"}, indent=2))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--install", action="store_true")
    group.add_argument("--setup", action="store_true")
    group.add_argument("--run-acceptance", action="store_true")
    group.add_argument("--check", action="store_true")
    parser.add_argument("--base", default=BASE)
    args = parser.parse_args(argv)
    local_base(args.base)
    if args.install:
        code = ('For path="/contest/src/ProductionEvidence.cls","/contest/src/ProductionMonitor.cls",'
                '"/contest/src/KnowledgeAPI.cls","/contest/dev/ProductionEvidenceTests.cls" { '
                'Set sc=$SYSTEM.OBJ.Load(path,"ck") '
                'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } ')
        execute("TRIAGE", code + f'Write "{MARKER}",{{"compiled":true}}.%ToJSON(),!')
    elif args.setup:
        load = ('Set sc=$SYSTEM.OBJ.Load("/contest/dev/StructuredProvision.cls","ck") '
                'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } ')
        execute("%SYS", load + f'Do ##class(Contest.StructuredProvision).Foundation() Write "{MARKER}",{{"installed":true}}.%ToJSON(),!')
        execute("OBSERVATION", load + f'Do ##class(Contest.StructuredProvision).Install() Write "{MARKER}",{{"installed":true}}.%ToJSON(),!')
    elif args.run_acceptance:
        acceptance(args.base)
    elif args.check:
        check(args.base)
    else:
        print("Inactive. --install compiles; --setup creates the isolated runtime; --run-acceptance explicitly sends five synthetic batches; --check reads saved evidence.")


if __name__ == "__main__":
    main()
