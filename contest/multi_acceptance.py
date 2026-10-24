#!/usr/bin/env python3
"""Explicit synthetic distribution acceptance; --check never sends or calls models."""
import argparse
import json
import time
from pathlib import Path

from business_privacy import require
from production_evidence_test import api

BASE = "http://127.0.0.1:52779/api/monitor/v1"
SAVED = Path(__file__).resolve().parent / "data/multi-organization-acceptance.json"


def wait_run(run_id, audit=False):
    deadline = time.monotonic() + (300 if audit else 180)
    while time.monotonic() < deadline:
        record = api(BASE, "/distribution/runs/" + run_id)
        state = record.get("audit_state") if audit else record["state"]
        terminal = ("completed", "completed_with_errors", "failed", "partial", "interrupted")
        if state in terminal:
            return record
        time.sleep(2)
    raise AssertionError("Worker did not finish within bounded wait; do not replay automatically")


def verify(record):
    require(record["state"] == "completed", "Three actual deliveries required: " + str(record.get("error", "")))
    require(len(record["source_pins"]) == 1 and record["source_pins"][0]["version"],
            "Versioned FHIR source pin missing")
    require({b["namespace"] for b in record["branches"]} ==
            {"DEMOQUALITY", "DEMORESEARCH", "DEMOCLINIC"}, "Three isolated recipient namespaces required")
    for branch in record["branches"]:
        require(branch["state"] == "acknowledged" and branch["receipt"]["readback_match"] is True,
                "Actual acknowledgement plus readback required")
        require(branch["payload_hash"] == branch["receipt"]["payload_hash"] == branch["facts"]["payload_hash"],
                "Wire/receiver/sidecar digest mismatch")
        require(branch["message_id"] and branch["session_id"] and branch["header_id"],
                "Actual IRIS message edge missing")
        require(len(branch["evidence_hash"]) == 64, "Frozen evidence digest missing")
        if branch["id"] == "quality":
            require(branch["fields"] == ["patient_id", "birthYear", "status"] and
                    branch["policy_mismatches"] == [], "SQL projection incorrect")
        if branch["id"] == "research":
            expected = {"name", "mrn", "birthDate"} if record["variant"] == "identifier-leak" else set()
            require(set(branch["policy_mismatches"]) == expected, "Research receiving-policy comparison differs")
        if branch["id"] == "clinic":
            require({"name", "mrn", "birthDate"} <= set(branch["fields"]), "HL7 PID evidence missing")


def run(new_attempt=False):
    require(not SAVED.exists() or new_attempt, "Prior acceptance retained; use --check or explicit --new-attempt")
    require(api(BASE, "/distribution")["ready"] is True, "All interfaces and profiles must be ready")
    api(BASE, "/distribution/seed", {"confirmed": True})
    saved = {"runs": [], "model_requests": 0, "prior_development_attempts": []}
    if SAVED.exists():
        prior = json.loads(SAVED.read_text())
        saved["prior_development_attempts"] = prior.get("prior_development_attempts", []) + [prior["runs"]]
    SAVED.write_text(json.dumps(saved, indent=2) + "\n")
    for variant in ("identifier-leak", "corrected"):
        run_id = "multi-" + str(time.time_ns())
        saved["runs"].append({"id": run_id, "variant": variant})
        SAVED.write_text(json.dumps(saved, indent=2) + "\n")
        api(BASE, "/distribution/run", {"run_id": run_id, "variant": variant, "confirmed": True})
        record = wait_run(run_id)
        verify(record)
        repeated = api(BASE, "/distribution/run", {"run_id": run_id, "variant": variant, "confirmed": True})
        require(repeated == record, "Duplicate submission must not resend or mutate completed run")
        print(variant + ": 3/3 actual protocol receipts and sidecar evidence verified", flush=True)
    return check()


def check():
    saved = json.loads(SAVED.read_text())
    for row in saved["runs"]:
        record = api(BASE, "/distribution/runs/" + row["id"])
        verify(record)
        if "audit_state" in record:
            require(record["audit_state"] == "completed", "Audit retained a failure: " + str(record.get("audit_error", "")))
            require(record["audit_interop"]["host"] == "AdvisoryAudit" and
                    record["audit_interop"]["session_id"], "AI runtime must be linked to its actual Business Process session")
            require(sum(b["audit"]["model_requests"] for b in record["branches"]) <= 6,
                    "Six-request run budget exceeded")
            for branch in record["branches"]:
                audit = branch["audit"]
                require(audit["state"] == "completed" and audit["model_requests"] <= 2,
                        "Validated real AI Hub result required")
                raw = audit["raw"]
                require(len(raw["phases"]) == 2 and
                        all(p["agent_session"] and p["state"] == "returned" and
                            p.get("usage", {}).get("total_tokens", 0) > 0 for p in raw["phases"]),
                        "Preserved actual AI Hub sessions required")
                require(sum(p["reserved_model_requests"] for p in raw["phases"]) ==
                        audit["model_requests"], "Phase/run request accounting mismatch")
                require(raw["interop"] == record["audit_interop"], "AI report / Business Process binding mismatch")
                require("SYNTHETIC-MRN-001" not in json.dumps(raw["packet"]),
                        "Raw identity must not enter model fact packet")
                if record["variant"] == "identifier-leak":
                    expected = "risk_identified" if branch["id"] == "research" else "no_signal_on_checked_issues"
                    require(audit["assessment"] == expected,
                            "Research contradiction/treatment-context acceptance contrast failed")
                for issue in raw["result"]["issues"]:
                    if issue["status"] != "unresolved":
                        require(issue["citations"] and all(
                            c["quote"] and c["end"] - c["start"] == len(c["quote"])
                            for c in issue["citations"]), "Validated exact source spans required")
    print("Read-only acceptance passed; no new sends or model calls.")
    return saved


def audit():
    saved = json.loads(SAVED.read_text())
    row = next(r for r in saved["runs"] if r["variant"] == "identifier-leak")
    record = api(BASE, "/distribution/runs/" + row["id"])
    require("audit_state" not in record, "Retain original model attempt; no automatic replacement")
    api(BASE, "/distribution/audit", {"run_id": row["id"], "acknowledge_cost": True,
                                    "acknowledge_synthetic": True})
    record = wait_run(row["id"], audit=True)
    print(json.dumps({"run": record["id"], "audit_state": record.get("audit_state"),
                      "error": record.get("audit_error"),
                      "branches": [{"id": b["id"], "audit": {k: v for k, v in b.get("audit", {}).items()
                                                          if k != "raw"}} for b in record["branches"]]}, indent=2))
    return check()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--run", action="store_true")
    group.add_argument("--new-attempt", action="store_true", help="New free synthetic run IDs; retain prior attempts")
    group.add_argument("--check", action="store_true")
    group.add_argument("--audit", action="store_true", help="At most three reviews/six real-provider requests")
    args = parser.parse_args()
    if args.run:
        run()
    elif args.new_attempt:
        run(new_attempt=True)
    elif args.audit:
        audit()
    else:
        check()
