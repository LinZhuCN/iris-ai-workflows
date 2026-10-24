import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import staged_risk_acceptance as acceptance
import staged_risk_challenge as challenge
import staged_risk_evaluation_test as evaluation


class StagedRiskChallengeTests(unittest.TestCase):
    def test_run_reserves_correct_suite_budget_without_retries(self):
        suite, expected, _, freeze = acceptance.load()
        prepared = {"cases": [{"case_id": c["id"], "input_hash": "test"}
                              for c in suite["cases"]]}
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(evaluation, "DIRECTORY", Path(directory)), \
                patch.object(evaluation.subprocess, "run", side_effect=OSError("test interrupted")) as call:
            with self.assertRaises(OSError):
                evaluation.run(suite, expected, freeze, "unit-eight-only", prepared)
            journal = acceptance.read_json(Path(directory) / "unit-eight-only-staged.json")
        self.assertEqual(journal["authorization"]["maximum_model_requests"], 16)
        self.assertEqual(journal["authorization"]["automatic_retries"], 0)
        self.assertEqual(len(journal["cases"]), 1)
        self.assertEqual(journal["cases"][0]["state"], "attempting")
        self.assertEqual(call.call_count, 1)

    def test_default_path_never_executes_model(self):
        with patch.object(challenge.evaluation, "run") as run, \
                patch.object(challenge, "verify_completed_journal") as verify:
            challenge.main([])
            run.assert_not_called()
            verify.assert_not_called()

    def test_paid_requires_explicit_key_and_prepared_match(self):
        with self.assertRaises(SystemExit):
            challenge.main(["--run"])
        with patch.object(challenge.smoke, "prepare", return_value={"changed": True}), \
                patch.object(challenge.evaluation, "run") as run:
            with self.assertRaises(ValueError):
                challenge.main(["--run", "--request-key", "unit-mismatch"])
            run.assert_not_called()

    def test_six_case_journal_cannot_be_presented_as_challenge(self):
        with self.assertRaises(ValueError):
            challenge.verify_completed_journal({"authorization": {"contract_hash": "wrong"},
                                                "cases": []})


if __name__ == "__main__":
    unittest.main()
