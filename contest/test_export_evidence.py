import copy
import unittest
from unittest.mock import patch

import export_evidence_test as evidence


class ExportEvidenceCliTests(unittest.TestCase):
    def receipts(self):
        receipts = []
        for index, transform in enumerate(evidence.TRANSFORMS):
            direct = 2 if transform == "retain" else 0
            dates = 0 if transform == "year_only" else 4
            item = {
                "id": "artifact-" + str(index), "record_hash": str(index) * 64,
                "source_hash": "a" * 64, "config_hash": "b" * 64, "output_hash": str(index) * 64,
                "model_calls": 0, "execution": "not_executed",
                "collector": "local-synthetic-export-v1", "actor": "test-only", "observed_at": 1,
                "scope": {"synthetic": True, "namespace": "TRIAGE", "stage": "config_review",
                          "delivery_state": "not_sent", "production_binding": "none"},
                "config": {"revision": 1, "recipient": "local-analytics-a", "transform": transform},
                "inspection": {"row_count": 2, "complete_hipaa_check": False,
                               "checker": "allowed-output-columns-v1",
                               "columns": ["name", "mrn", "email", "birth_date", "admission_date", "region"],
                               "identifier_counts": {"name": direct, "mrn": direct, "email": direct,
                                                     "full_dates": dates},
                               "checked_identifier_result": "not_detected" if dates == 0 else "present"},
                "business_basis": {k: "not_collected" for k in
                                   ("authorization", "expert_determination", "release_approval")},
                "packet": {"stage": "config_review", "facts": [
                    {"id": "f1", "verification": "verified"}, {"id": "f2", "verification": "verified"},
                    {"id": "f3", "verification": "unknown"}]},
            }
            item["fact_evidence"] = [
                dict(fact_id=f["id"], record_id=item["id"],
                     **{k: item[k] for k in ("record_hash", "config_hash", "output_hash")})
                for f in item["packet"]["facts"]]
            receipts.append(item)
        return receipts

    def test_cli_default_is_free_no_collection(self):
        with patch.object(evidence.subprocess, "run") as run:
            evidence.main([])
            run.assert_not_called()

    def test_command_does_not_allow_arbitrary_input_or_calls(self):
        code = evidence.command("unit-only")
        self.assertIn("Contest.ExportEvidence).Collect", code)
        self.assertIn("Contest.ExportEvidence).Read", code)
        self.assertNotIn(".Chat", code)
        self.assertNotIn("Scenario", code)
        for key in ("bad_key", 'x") Write "injection', "", "a" * 61):
            with self.assertRaises(ValueError):
                evidence.command(key)

    def test_expected_shapes_and_counts_are_checked(self):
        evidence.verify_receipts(self.receipts())
        for mutation in ("counts", "approval", "reference", "raw", "legal", "scope"):
            values = copy.deepcopy(self.receipts())
            if mutation == "counts":
                values[1]["inspection"]["identifier_counts"]["mrn"] = 2
            if mutation == "approval":
                values[1]["business_basis"]["authorization"] = "verified"
            if mutation == "reference":
                values[1]["fact_evidence"][0]["output_hash"] = "stale"
            if mutation == "raw":
                values[1]["output"] = []
            if mutation == "legal":
                values[1]["inspection"]["complete_hipaa_check"] = True
            if mutation == "scope":
                values[1]["scope"]["production_binding"] = "DemoRouter"
            with self.assertRaises(ValueError):
                evidence.verify_receipts(values)


if __name__ == "__main__":
    unittest.main()
