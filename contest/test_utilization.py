import copy
import unittest
from unittest.mock import patch

import utilization_test


class UtilizationCLITests(unittest.TestCase):
    def test_default_is_inactive(self):
        with patch("utilization_test.subprocess.run") as run:
            utilization_test.main([])
        run.assert_not_called()

    def test_bounded_batch_command(self):
        for value in ('bad" Do evil', "", "../bad", "a" * 65):
            with self.assertRaises(ValueError):
                utilization_test.run_command(value)
        code = utilization_test.run_command("unit-batch")
        self.assertIn("service.ProcessInput", code)
        self.assertNotIn("Approve(", code)
        self.assertNotIn(".Chat(", code)

    def test_explicit_approval_pins_required(self):
        with patch("utilization_test.subprocess.run") as run:
            with self.assertRaises(SystemExit):
                utilization_test.main(["--approve"])
            with self.assertRaises(ValueError):
                utilization_test.main(["--approve", "--record-id", 'bad"', "--digest", "a" * 64])
        run.assert_not_called()

    def test_receipt_rejects_unexpected_scope(self):
        receipt = {
            "synthetic": True, "outcome": "delivered", "model_calls": 0,
            "transport": "same-instance-BO-to-SQL", "receiver_readback_match": True,
            "inspection": {
                "resource_counts": {"Patient": 2, "Encounter": 2, "Condition": 0, "MedicationRequest": 0},
                "field_paths": ["Patient.id", "Patient.birthDate", "Encounter.id", "Encounter.status",
                                "Encounter.class.system", "Encounter.class.code", "Encounter.subject.reference"],
            },
            "deidentification": "not_established", "legal_authorization": "not_established",
            "source_pins": [{"resource": resource, "version": "1", "hash": "a" * 64}
                            for resource in ("Patient/agg-p1", "Patient/agg-p2",
                                             "Encounter/agg-e1", "Encounter/agg-e2")],
            "message_id": "1", "session_id": 1, "receiver_message_id": "2",
            **{key: "a" * 64 for key in ("source_hash", "output_hash", "config_hash",
                                       "scope_hash", "receipt_hash")},
        }
        utilization_test.validate(receipt)
        for variant in ("fields", "count", "pins", "legal", "raw"):
            with self.subTest(variant=variant):
                changed = copy.deepcopy(receipt)
                if variant == "fields":
                    changed["inspection"]["field_paths"].append("Patient.name.family")
                elif variant == "count":
                    changed["inspection"]["resource_counts"]["Patient"] = 3
                elif variant == "pins":
                    changed["source_pins"].pop()
                elif variant == "legal":
                    changed["legal_authorization"] = "approved"
                else:
                    changed["payload"] = {}
                with self.assertRaises(ValueError):
                    utilization_test.validate(changed)
