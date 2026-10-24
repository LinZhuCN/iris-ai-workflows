import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import route_evidence_test as evidence


class RouteEvidenceCLITests(unittest.TestCase):
    def test_default_is_inactive_and_pins_are_required(self):
        with patch("route_evidence_test.execute") as execute:
            evidence.main([])
            with self.assertRaises(SystemExit):
                evidence.main(["--read", "--route", "utilization", "--batch-id", "unit"])
        execute.assert_not_called()

    def test_command_is_read_only_and_bounded(self):
        command = evidence.read_command("utilization", "unit", "a" * 64)
        self.assertIn("Contest.RouteEvidence).Read(", command)
        for forbidden in ("ProcessInput", "Approve(", ".Chat(", "StartProduction"):
            self.assertNotIn(forbidden, command)
        for kind, batch, pin in (("USER", "unit", "a" * 64),
                                 ("utilization", 'bad" Do evil', "a" * 64),
                                 ("aggregation", "unit", "bad")):
            with self.assertRaises(ValueError):
                evidence.read_command(kind, batch, pin)

    def test_original_receipt_binds_route_and_batch(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "original.json"
            receipt = {"synthetic": True, "outcome": "delivered", "batch_id": "unit",
                       "receiver_message_id": "2", "receipt_hash": "a" * 64}
            path.write_text(json.dumps(receipt))
            self.assertEqual(evidence.receipt_pin(path, "utilization", "unit"), "a" * 64)
            for kind, batch in (("aggregation", "unit"), ("utilization", "different")):
                with self.assertRaises(ValueError):
                    evidence.receipt_pin(path, kind, batch)
            path.write_text(json.dumps({"receipt": {**receipt, "send_message_id": "3"}}))
            self.assertEqual(evidence.receipt_pin(path, "aggregation", "unit"), "a" * 64)
            del receipt["receipt_hash"]
            path.write_text(json.dumps(receipt))
            with self.assertRaises(ValueError):
                evidence.receipt_pin(path, "utilization", "unit")

    def test_install_does_not_provision_or_send(self):
        with patch("route_evidence_test.execute", return_value={"installed": True}) as execute:
            evidence.main(["--install"])
        namespace, code = execute.call_args.args
        self.assertEqual(namespace, "TRIAGE")
        self.assertIn("/contest/src/RouteEvidence.cls", code)
        for forbidden in ("Foundation()", "Pipeline()", "StartProduction", "Approve(", "ProcessInput", ".Chat("):
            self.assertNotIn(forbidden, code)

    def test_fact_projection_preserves_claims_and_missing_evidence(self):
        labels = (("declared_purpose", "claim", "unverified"),
                  ("declared_context", "claim", "unverified"),
                  ("approved_scope", "observation", "verified"),
                  ("observed_output", "observation", "verified"),
                  ("delivery_evidence", "observation", "verified"),
                  ("evidence_limits", "missing_information", "unknown"))
        pin = "a" * 64
        sample = {
            "current_admission": {"state": "expired"},
            "evidence": {
                "schema": 1, "adapter": "route-evidence-v1", "synthetic": True, "route_kind": "utilization",
                "batch_id": "unit", "execution": "not_executed", "model_calls": 0,
                "evidence_hash": pin,
                "provenance": {key: pin for key in ("source_hash", "output_hash", "config_hash",
                                                    "scope_hash", "receipt_hash")},
                "packet": {"synthetic": True, "stage": "after_send",
                           "facts": [{"id": name, "kind": kind, "verification": verification}
                                     for name, kind, verification in labels]},
                "fact_evidence": [{"fact_id": name, "batch_id": "unit", "route_kind": "utilization",
                                   "receipt_hash": pin} for name, _, _ in labels],
                "approved": {"legal_authorization": "not_established", "historical_scope_match": True},
                "observed": {"inspection": {"complete_hipaa_check": False}},
            },
        }
        self.assertIs(evidence.validate(sample, "utilization", "unit", pin), sample["evidence"])
        for variant in ("claim", "missing", "reference", "raw", "stage", "legal"):
            with self.subTest(variant=variant):
                changed = copy.deepcopy(sample)
                result = changed["evidence"]
                if variant == "claim":
                    result["packet"]["facts"][0]["verification"] = "verified"
                elif variant == "missing":
                    result["packet"]["facts"].pop()
                elif variant == "reference":
                    result["fact_evidence"][0]["receipt_hash"] = "b" * 64
                elif variant == "raw":
                    result["bundle"] = {}
                elif variant == "stage":
                    result["packet"]["stage"] = "before_send"
                else:
                    result["approved"]["legal_authorization"] = "approved"
                with self.assertRaises(ValueError):
                    evidence.validate(changed, "utilization", "unit", pin)
