import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import production_premises_test as p


class ProductionPremiseAcceptanceTests(unittest.TestCase):
    def test_default_has_no_side_effects(self):
        with patch.object(p, "run") as run, patch.object(p, "api") as api, patch.object(p, "send") as send:
            p.main([])
        run.assert_not_called()
        api.assert_not_called()
        send.assert_not_called()

    def test_existing_attempt_is_never_replayed(self):
        with tempfile.TemporaryDirectory() as directory:
            saved = Path(directory) / "existing.json"
            saved.write_text('{"state":"authorization_requested"}')
            with patch.object(p, "SAVED", saved), patch.object(p, "api") as api, patch.object(p, "send") as send:
                with self.assertRaisesRegex(ValueError, "immutable"):
                    p.run(p.BASE)
            api.assert_not_called()
            send.assert_not_called()

    def test_three_prospective_cases_are_distinct_and_answer_free(self):
        suite = p.load()
        self.assertEqual([c["oracle"]["assessment"] for c in suite["cases"]],
                         ["no_signal_on_checked_issues", "risk_identified", "information_required"])
        for case in suite["cases"]:
            self.assertNotIn("oracle", case["premises"])
            self.assertNotIn("session_id", case["premises"])
            self.assertTrue(case["premises"]["confirmed"])
        self.assertEqual(suite["cases"][1]["premises"]["authorization_status"], "absent")
        self.assertEqual(suite["cases"][2]["premises"]["authorization_status"], "unknown")

    def test_check_routes_only_to_readback(self):
        with patch.object(p, "check") as check, patch.object(p, "run") as run:
            p.main(["--check"])
        check.assert_called_once_with(p.BASE, False)
        run.assert_not_called()

    def test_remote_endpoint_rejected_before_sending(self):
        with patch.object(p, "run") as run:
            with self.assertRaises(ValueError):
                p.main(["--run", "--base", "https://example.invalid"])
        run.assert_not_called()

    def test_followup_does_not_change_original_case_expectation(self):
        original, followup = p.load(), p.load(True)
        self.assertEqual(followup["cases"][0]["oracle"], original["cases"][0]["oracle"])
        self.assertEqual(len(followup["cases"]), 1)
        for key, value in original["cases"][0]["premises"].items():
            self.assertEqual(followup["cases"][0]["premises"][key], value)
        self.assertIn("recipient_mapping", followup["cases"][0]["premises"])
        self.assertNotIn("recipient_mapping", original["cases"][0]["premises"])

    def test_complete_check_preserves_first_failure_and_counts_all_costs(self):
        usage = {"requests": 6, "tokens": 90, "citations": 11}
        first = {"cases": [{"case": "treatment", "accepted": False}, {"case": "marketing", "accepted": True},
                           {"case": "unknown", "accepted": True}], "usage": usage}
        followup = {"cases": [{"case": "treatment", "accepted": True}],
                    "usage": {"requests": 2, "tokens": 25, "citations": 4}}
        with patch.object(p, "check", side_effect=[first, followup]), patch.object(p, "send") as send:
            result = p.check_complete(p.BASE)
        self.assertEqual(result["first_pass"], "2/3")
        self.assertEqual(result["usage_including_failed_first_case"], {"requests": 8, "tokens": 115, "citations": 15})
        send.assert_not_called()
        first["cases"][1]["accepted"] = False
        with patch.object(p, "check", side_effect=[first, followup]):
            with self.assertRaisesRegex(ValueError, "Original risk/unknown"):
                p.check_complete(p.BASE)


if __name__ == "__main__":
    unittest.main()
