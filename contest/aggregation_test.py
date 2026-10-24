#!/usr/bin/env python3
"""Explicit local synthetic SQL-to-FHIR run and independent HTTP readback; no model."""
import argparse
import base64
import json
from pathlib import Path
import re
import subprocess
from urllib.request import Request, urlopen

from business_privacy import require
from staged_risk_acceptance import DIRECTORY, save_immutable

MARKER = "@@AGGREGATION@@"
BASE = "http://127.0.0.1:52779/csp/healthshare/fhirdemo/fhir/r4"


def command(batch):
    require(isinstance(batch, str) and re.fullmatch(r"[A-Za-z0-9-]{1,64}", batch),
            "Bounded batch ID required")
    return (
        'Try { Set ref={}.%FromJSON(^ContestAggregation("approvalRef")), '
        'request=##class(Contest.Aggregation.Request).%New(), '
        f'request.BatchId="{batch}", request.ApprovalId=ref.id, request.ScopeHash=ref.digest '
        'Set sc=##class(Ens.Director).CreateBusinessService("SQLSource",.service) '
        'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        'Set sc=service.ProcessInput(request,.reply) '
        'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        'Set stored={}.%FromJSON(^ContestAggregation("batch",request.BatchId)) '
        'If stored.receipt.%ToJSON()\'=reply.Receipt { Do ##class(Demo.Protocol).Fail("Receipt readback mismatch") } '
        f'Write "{MARKER}",reply.Receipt,! '
        f'}} Catch ex {{ Write "{MARKER}",{{"error":(ex.DisplayString())}}.%ToJSON(),! }}\nHalt\n')


def validate(receipt):
    require("error" not in receipt, "IRIS aggregation failed; inspect protected batch and event log")
    require(receipt["outcome"] == "delivered" and receipt["synthetic"] is True and
            receipt["model_calls"] == 0, "Actual synthetic delivery required")
    require(receipt["inspection"]["resource_counts"] ==
            dict.fromkeys(("Patient", "Encounter", "Condition", "MedicationRequest"), 2),
            "Four resource types, two each required")
    require(receipt["inspection"]["scope_match"] is True and
            receipt["inspection"]["complete_hipaa_check"] is False, "Scope match is not legal acceptance")
    require(len(receipt["readbacks"]) == 8 and
            len({r["resource"] for r in receipt["readbacks"]}) == 8, "Eight distinct readbacks required")
    for row in receipt["readbacks"]:
        require(re.fullmatch(r"(Patient|Encounter|Condition|MedicationRequest)/agg-[A-Za-z0-9-]+",
                             row["resource"]) is not None and
                row["mapped_values_match"] is True, "Unexpected readback identity")
    for key in ("source_hash", "output_hash", "wire_hash", "config_hash", "scope_hash", "receipt_hash"):
        require(re.fullmatch(r"[a-f0-9]{64}", receipt[key]) is not None, "Missing evidence digest")
    require(bool(receipt["message_id"]) and bool(receipt["session_id"]) and
            bool(receipt["send_message_id"]), "Real message linkage required")
    require(not {"source", "bundle", "readback_resources"} & receipt.keys(),
            "Raw business data must stay local")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--batch-id")
    args = parser.parse_args(argv)
    if not args.run:
        print("No run. Use --run --batch-id ID for local synthetic delivery; no model calls.")
        return
    if not args.batch_id:
        parser.error("--run requires --batch-id")
    result = subprocess.run(
        ["docker", "exec", "-i", "iris-triage-real-iris-1", "iris", "session", "IRIS", "-U", "PIPELINE"],
        input=command(args.batch_id), text=True, capture_output=True, check=True, timeout=240)
    rows = [json.loads(line.split(MARKER, 1)[1]) for line in result.stdout.splitlines() if MARKER in line]
    require(len(rows) == 1, "Exactly one IRIS receipt required")
    receipt = rows[0]
    validate(receipt)
    password = (Path(__file__).resolve().parent / "data/platform/AggregationFHIR.password").read_text().strip()
    authorization = "Basic " + base64.b64encode(("ContestAggregationFHIR:" + password).encode()).decode()
    for row in receipt["readbacks"]:
        request = Request(BASE + "/" + row["resource"],
                          headers={"Accept": "application/fhir+json", "Authorization": authorization})
        with urlopen(request, timeout=20) as response:
            actual = json.load(response)
        require(actual["resourceType"] + "/" + actual["id"] == row["resource"] and
                actual["meta"]["versionId"] == row["version"], "Stored delivery version no longer current")
    save_immutable(DIRECTORY / (args.batch_id + "-aggregation.json"),
                   {"receipt": receipt, "http_readbacks_verified": 8, "model_calls": 0})
    print("PASS SQL -> BS/BP/BO -> FHIR transaction -> eight readbacks; persisted receipt matched.")
    print("batch", receipt["batch_id"], "approval", receipt["approval_id"],
          "session", receipt["session_id"])


if __name__ == "__main__":
    main()
