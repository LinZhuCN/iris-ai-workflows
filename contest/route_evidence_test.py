#!/usr/bin/env python3
"""Revalidate historical route evidence using an independently saved original receipt."""
import argparse
import json
import re
from pathlib import Path

from business_privacy import require
from staged_risk_acceptance import DIRECTORY, save_immutable
from utilization_test import MARKER, execute


def receipt_pin(path, kind, batch):
    require(kind in ("aggregation", "utilization"), "Known route kind required")
    require(isinstance(batch, str) and re.fullmatch(r"[A-Za-z0-9-]{1,64}", batch),
            "Bounded route batch required")
    saved = json.loads(Path(path).read_text())
    require(isinstance(saved, dict), "Original receipt object required")
    receipt = saved.get("receipt", saved)
    require(isinstance(receipt, dict) and receipt.get("batch_id") == batch and
            receipt.get("synthetic") is True and receipt.get("outcome") == "delivered",
            "Original delivered synthetic receipt for this batch required")
    marker = "send_message_id" if kind == "aggregation" else "receiver_message_id"
    require(bool(receipt.get(marker)), "Original receipt is for a different route")
    pin = receipt.get("receipt_hash")
    require(isinstance(pin, str) and re.fullmatch(r"[a-f0-9]{64}", pin),
            "Original receipt digest required; do not discover a replacement pin from current IRIS data")
    return pin


def read_command(kind, batch, pin):
    require(kind in ("aggregation", "utilization") and
            isinstance(batch, str) and re.fullmatch(r"[A-Za-z0-9-]{1,64}", batch) and
            isinstance(pin, str) and re.fullmatch(r"[a-f0-9]{64}", pin),
            "Bounded route, batch and original receipt pin required")
    return (f'Set value=##class(Contest.RouteEvidence).Read("{kind}","{batch}","{pin}") '
            f'Write "{MARKER}",value.%ToJSON(),!')


def validate(value, kind, batch, pin):
    require(isinstance(value, dict) and set(value) == {"evidence", "current_admission"},
            "Historical evidence and current admission must remain separate")
    evidence = value["evidence"]
    require(evidence["schema"] == 1 and evidence["adapter"] in ("route-evidence-v1", "route-evidence-v2") and evidence["synthetic"] is True and
            evidence["route_kind"] == kind and evidence["batch_id"] == batch and
            evidence["model_calls"] == 0 and evidence["execution"] == "not_executed",
            "Bounded synthetic evidence only")
    provenance = evidence["provenance"]
    require(provenance["receipt_hash"] == pin and
            all(isinstance(provenance[key], str) and re.fullmatch(r"[a-f0-9]{64}", provenance[key])
                for key in ("receipt_hash", "source_hash", "output_hash", "config_hash", "scope_hash")) and
            re.fullmatch(r"[a-f0-9]{64}", evidence["evidence_hash"]),
            "Pinned evidence provenance required")
    packet = evidence["packet"]
    require(packet["synthetic"] is True and packet["stage"] == "after_send",
            "This is historical after-send review, not an admission decision")
    expected = {
        "declared_purpose": ("claim", "unverified"),
        "declared_context": ("claim", "unverified"),
        "approved_scope": ("observation", "verified"),
        "observed_output": ("observation", "verified"),
        "delivery_evidence": ("observation", "verified"),
        "evidence_limits": ("missing_information", "unknown"),
    }
    if evidence["adapter"] == "route-evidence-v2":
        expected.update(organization_policy=("local_policy", "verified"),
                        approved_scenario=("observation", "verified"))
        scenario = evidence["approved"]["scenario"]
        require(scenario["synthetic"] is True and scenario["policy_id"] == "DEMO-INTERNAL-USE-1" and
                scenario["recipient_relationship"] == "same-covered-entity" and
                scenario["deidentification_required"] is False and
                scenario["individual_authorization_required"] is False, "Explicit approved synthetic internal-use scenario required")
    facts = packet["facts"]
    require(len(facts) == len(expected) and {fact["id"] for fact in facts} == set(expected) and
            all((fact["kind"], fact["verification"]) == expected[fact["id"]] for fact in facts),
            "Do not upgrade declarations or unknown legal evidence to verified facts")
    refs = evidence["fact_evidence"]
    require(len(refs) == len(expected) and {ref["fact_id"] for ref in refs} == set(expected) and
            all(ref["batch_id"] == batch and ref["route_kind"] == kind and ref["receipt_hash"] == pin
                for ref in refs), "Every fact must retain a source reference")
    require(evidence["approved"]["legal_authorization"] == "not_established" and
            evidence["approved"]["historical_scope_match"] is True and
            evidence["observed"]["inspection"]["complete_hipaa_check"] is False,
            "Synthetic approval and scoped inspection are not legal acceptance")
    require(not {"source", "bundle", "payload", "readback_resources", "source_pins"} & evidence.keys(),
            "Raw patient data must not be exported as evidence")
    return evidence


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--read", action="store_true")
    group.add_argument("--install", action="store_true",
                       help="Compile only the TRIAGE reader and its fixed class dependencies")
    parser.add_argument("--route", choices=("aggregation", "utilization"))
    parser.add_argument("--batch-id")
    parser.add_argument("--receipt-file", type=Path)
    args = parser.parse_args(argv)
    if args.install:
        execute("TRIAGE",
                'For path="/contest/demo/Protocol.cls","/contest/pipeline/Request.cls",'
                '"/contest/pipeline/SendRequest.cls","/contest/pipeline/Reply.cls",'
                '"/contest/pipeline/Data.cls","/contest/pipeline/Mapping.cls",'
                '"/contest/pipeline/Runtime.cls","/contest/utilization/Runtime.cls",'
                '"/contest/src/RouteScenario.cls","/contest/src/RouteGovernance.cls","/contest/src/RouteEvidence.cls" { '
                'Set sc=$SYSTEM.OBJ.Load(path,"ck") '
                'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } '
                f'Write "{MARKER}",{{"installed":true}}.%ToJSON(),!', label="Route evidence install")
        print("Compiled TRIAGE reader only; no environment provisioning, Production changes or model calls.")
        return
    if not args.read:
        print("No read or model call. Use --read with a route, batch and original --receipt-file.")
        return
    if not (args.route and args.batch_id and args.receipt_file):
        parser.error("--read requires --route, --batch-id and original --receipt-file")
    pin = receipt_pin(args.receipt_file, args.route, args.batch_id)
    value = execute("TRIAGE", read_command(args.route, args.batch_id, pin), label="Route evidence")
    evidence = validate(value, args.route, args.batch_id, pin)
    save_immutable(DIRECTORY / (args.batch_id + "-route-evidence-v1.json"), evidence)
    print("PASS revalidated historical evidence.", args.route, args.batch_id)
    print("Current admission (not a historical integrity conclusion):", value["current_admission"]["state"])
    print("No raw source/output export, delivery, approval or model call.")


if __name__ == "__main__":
    main()
