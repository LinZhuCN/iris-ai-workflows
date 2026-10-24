#!/usr/bin/env python3
"""Local synthetic FHIR utilization setup, registration, explicit approval and delivery."""
import argparse
import json
import re
import subprocess

from business_privacy import require
from staged_risk_acceptance import DIRECTORY, save_immutable

MARKER = "@@UTILIZATION@@"


def execute(namespace, action, *, label="Utilization"):
    code = (
        'Try { ' + action + ' '
        f'}} Catch ex {{ Write "{MARKER}",{{"error":(ex.DisplayString())}}.%ToJSON(),! }}\nHalt\n')
    result = subprocess.run(
        ["docker", "exec", "-i", "iris-triage-real-iris-1", "iris", "session", "IRIS", "-U", namespace],
        input=code, text=True, capture_output=True, check=True, timeout=240)
    rows = [json.loads(line.split(MARKER, 1)[1]) for line in result.stdout.splitlines() if MARKER in line]
    require(len(rows) == 1 and "error" not in rows[0],
            label + " failed: " + repr(rows))
    return rows[0]


def load():
    return ('Set sc=$SYSTEM.OBJ.Load("/contest/dev/UtilizationProvision.cls","ck") '
            'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } ')


def run_command(batch):
    require(isinstance(batch, str) and re.fullmatch(r"[A-Za-z0-9-]{1,64}", batch),
            "Bounded batch identity required")
    return (
        'Set ref={}.%FromJSON(^ContestUtilization("registration")), '
        'request=##class(Contest.Aggregation.Request).%New(), '
        f'request.BatchId="{batch}", request.ApprovalId=ref.id, request.ScopeHash=ref.digest '
        'Set sc=##class(Ens.Director).CreateBusinessService("FHIRSource",.service) '
        'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        'Set sc=service.ProcessInput(request,.reply) '
        'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        'Set receipt={}.%FromJSON(reply.Receipt), '
        'read=##class(Contest.Utilization.Runtime).ReadReceiver(request.BatchId) '
        'If read.%Get("output_hash")\'=receipt.%Get("output_hash") { Do ##class(Demo.Protocol).Fail("SQL readback differs") } '
        f'Write "{MARKER}",receipt.%ToJSON(),!')


def validate(receipt):
    require(receipt["synthetic"] is True and receipt["outcome"] == "delivered" and
            receipt["model_calls"] == 0 and receipt["transport"] == "same-instance-BO-to-SQL",
            "Actual local synthetic delivery required")
    require(receipt["receiver_readback_match"] is True and
            receipt["inspection"]["resource_counts"] ==
            {"Patient": 2, "Encounter": 2, "Condition": 0, "MedicationRequest": 0},
            "Expected four-resource utilization scope")
    require(set(receipt["inspection"]["field_paths"]) ==
            {"Patient.id", "Patient.birthDate", "Encounter.id", "Encounter.status",
             "Encounter.class.system", "Encounter.class.code", "Encounter.subject.reference"},
            "Unexpected actual output fields")
    require(receipt["deidentification"] == "not_established" and
            receipt["legal_authorization"] == "not_established", "No legal/de-identification pass")
    for key in ("source_hash", "output_hash", "config_hash", "scope_hash", "receipt_hash"):
        require(re.fullmatch(r"[a-f0-9]{64}", receipt[key]) is not None, "Digest missing")
    require(len(receipt["source_pins"]) == 4 and
            len({row["resource"] for row in receipt["source_pins"]}) == 4 and
            all(row["version"] and re.fullmatch(r"[a-f0-9]{64}", row["hash"])
                for row in receipt["source_pins"]), "Versioned source evidence required")
    require(bool(receipt["message_id"]) and bool(receipt["session_id"]) and
            bool(receipt["receiver_message_id"]), "Actual message linkage required")
    require(not {"source", "bundle", "payload"} & receipt.keys(), "Raw output is not a minimized receipt")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--setup", action="store_true")
    group.add_argument("--register", action="store_true")
    group.add_argument("--approve", action="store_true")
    group.add_argument("--run", action="store_true")
    parser.add_argument("--record-id")
    parser.add_argument("--digest")
    parser.add_argument("--batch-id")
    args = parser.parse_args(argv)
    if args.setup:
        execute("%SYS", load() + 'Do ##class(User.ContestUtilizationProvision).Foundation() '
                f'Write "{MARKER}",{{"foundation":true}}.%ToJSON(),!')
        execute("UTILIZATION", load() + 'Do ##class(User.ContestUtilizationProvision).Pipeline() '
                f'Write "{MARKER}",{{"installed":true}}.%ToJSON(),!')
        print("Installed only; no registration, approval, delivery or model call.")
    elif args.register:
        ref = execute("UTILIZATION", load() + 'Set ref=##class(User.ContestUtilizationProvision).Register() '
                      f'Write "{MARKER}",ref.%ToJSON(),!')
        print(json.dumps(ref))
        print("Registration is not approval. Review the full dossier in TRIAGE before --approve.")
    elif args.approve:
        if not (args.record_id and args.digest):
            parser.error("--approve requires --record-id and --digest after dossier review")
        require(re.fullmatch(r"route-[A-Za-z0-9-]{1,80}", args.record_id) and
                re.fullmatch(r"[a-f0-9]{64}", args.digest), "Bounded exact approval identity required")
        execute("UTILIZATION", load() +
                f'Do ##class(User.ContestUtilizationProvision).Approve("{args.record_id}","{args.digest}") '
                f'Write "{MARKER}",{{"approved":true}}.%ToJSON(),!')
        print("Explicit synthetic approval recorded; no delivery.")
    elif args.run:
        if not args.batch_id:
            parser.error("--run requires --batch-id")
        receipt = execute("UTILIZATION", run_command(args.batch_id))
        validate(receipt)
        save_immutable(DIRECTORY / (args.batch_id + "-utilization.json"), receipt)
        print("PASS FHIR -> bounded projection -> BO -> SQL persistence/readback.", receipt["batch_id"])
    else:
        print("No changes or model call. Choose --setup, --register, --approve or --run explicitly.")


if __name__ == "__main__":
    main()
