#!/usr/bin/env python3
"""Free local synthetic artifact collection. No model calls, external delivery or Production changes."""
import argparse
import json
import re
import subprocess

from business_privacy import require
import staged_risk_acceptance as acceptance

MARKER = "@@EXPORT-EVIDENCE@@"
TRANSFORMS = ("retain", "remove_direct", "year_only")


def command(key):
    require(isinstance(key, str) and re.fullmatch(r"[A-Za-z0-9-]{1,60}", key),
            "A bounded immutable collection key is required")
    lines = []
    for transform in TRANSFORMS:
        request_key = key + "-" + transform.replace("_", "-")
        config = json.dumps({"revision": 1, "recipient": "local-analytics-a",
                             "transform": transform}, separators=(",", ":")).replace('"', '""')
        lines.append(
            f'Try {{ Set config={{}}.%FromJSON("{config}"), value=##class(Contest.ExportEvidence).Collect("{request_key}",config), '
            'reloaded=##class(Contest.ExportEvidence).Read(value.id,value.%Get("config_hash"),value.%Get("output_hash")) '
            'If value.%ToJSON()\'=reloaded.%ToJSON() { Do ##class(Demo.Protocol).Fail("Evidence readback mismatch") } '
            f'Write "{MARKER}",$ZConvert(value.%ToJSON(),"O","UTF8"),! '
            f'}} Catch ex {{ Write "{MARKER}",{{"error":(ex.DisplayString())}}.%ToJSON(),! }}')
    return "\n".join(lines + ["Halt", ""])


def verify_receipts(receipts):
    require(isinstance(receipts, list) and len(receipts) == 3, "Three actual artifact receipts required")
    require(len({r["id"] for r in receipts}) == 3, "Independent artifact identities required")
    for receipt, transform in zip(receipts, TRANSFORMS):
        require("error" not in receipt, "IRIS evidence collection failed")
        require(not {"source", "output"} & set(receipt), "Raw artifact data must stay local")
        require(receipt["model_calls"] == 0 and receipt["execution"] == "not_executed",
                "No model or delivery permitted")
        require(receipt["collector"] == "local-synthetic-export-v1" and
                isinstance(receipt["actor"], str) and bool(receipt["actor"]) and
                isinstance(receipt["observed_at"], (int, float)) and receipt["observed_at"] > 0,
                "Collector, actor and observation time required")
        require(receipt["scope"] == {"synthetic": True, "namespace": "TRIAGE", "stage": "config_review",
                                    "delivery_state": "not_sent", "production_binding": "none"},
                "Independent local-only scope required")
        require(receipt["config"] == {"revision": 1, "recipient": "local-analytics-a", "transform": transform},
                "Unexpected artifact scope")
        for field in ("record_hash", "source_hash", "config_hash", "output_hash"):
            require(re.fullmatch(r"[0-9a-f]{64}", receipt[field]) is not None, "Invalid evidence digest")
        check = receipt["inspection"]
        require(check["checker"] == "allowed-output-columns-v1" and
                check["columns"] == ["name", "mrn", "email", "birth_date", "admission_date", "region"],
                "Checker/column scope differs")
        require(check["row_count"] == 2 and check["complete_hipaa_check"] is False,
                "Actual two-row bounded check, not legal acceptance")
        direct = 2 if transform == "retain" else 0
        dates = 0 if transform == "year_only" else 4
        require(check["identifier_counts"] == {"name": direct, "mrn": direct, "email": direct,
                                               "full_dates": dates}, "Actual output counts differ")
        require(check["checked_identifier_result"] == ("not_detected" if dates == 0 else "present"),
                "Inspection result differs")
        require(all(value == "not_collected" for value in receipt["business_basis"].values()) and
                set(receipt["business_basis"]) == {"authorization", "expert_determination", "release_approval"},
                "Unconnected business records must not become verified")
        facts = receipt["packet"]["facts"]
        require([f["verification"] for f in facts] == ["verified", "verified", "unknown"] and
                receipt["packet"]["stage"] == "config_review", "Observation/unknown distinction lost")
        require(len(receipt["fact_evidence"]) == len(facts), "Fact evidence links missing")
        for ref, fact in zip(receipt["fact_evidence"], facts):
            require(ref["fact_id"] == fact["id"] and ref["record_id"] == receipt["id"] and
                    all(ref[k] == receipt[k] for k in ("record_hash", "config_hash", "output_hash")),
                    "Fact reference scope differs")
        projection = json.dumps(receipt)
        require(all(value not in projection for value in
                    ("SYNTHETIC-NAME-", "SYNTHETIC-MRN-", "@example.invalid",
                     "2001-02-03", "2002-03-04", "2026-10-01", "2026-10-02")),
                "Raw synthetic values leaked into minimized context")
    require(len({r["source_hash"] for r in receipts}) == 1, "Control source differs")
    require(len({r["output_hash"] for r in receipts}) == 3, "Transforms did not change actual artifacts")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--collect", action="store_true", help="Generate/persist three synthetic local artifacts")
    parser.add_argument("--request-key")
    args = parser.parse_args(argv)
    if args.collect and not args.request_key:
        parser.error("--collect requires --request-key")
    if not args.collect:
        print("No collection or model call. Use --collect --request-key NEW-KEY for free synthetic evidence.")
        return
    code = command(args.request_key)
    result = subprocess.run(
        ["docker", "exec", "-i", "iris-triage-real-iris-1", "iris", "session", "IRIS", "-U", "TRIAGE"],
        input=code, text=True, capture_output=True, check=True, timeout=120)
    receipts = [json.loads(line.split(MARKER, 1)[1]) for line in result.stdout.splitlines() if MARKER in line]
    require(not any("error" in receipt for receipt in receipts), "Evidence collection rejected; inspect protected audit")
    verify_receipts(receipts)
    path = acceptance.DIRECTORY / (args.request_key + "-export-evidence.json")
    acceptance.save_immutable(path, {"model_calls": 0, "persistent_readback_equal": True, "receipts": receipts,
                                     "limitation": "Independent local synthetic collector; not actual Production export or legal verification"})
    for receipt in receipts:
        print(receipt["config"]["transform"], receipt["id"], receipt["inspection"]["identifier_counts"])
    print("PASS persisted artifacts/readback/scoped minimized context. Authorization/expert/approval remain uncollected.")


if __name__ == "__main__":
    main()
