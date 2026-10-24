import unittest
from unittest.mock import patch

import route_review_test as runner


class RouteReviewCLITests(unittest.TestCase):
    def test_default_has_no_side_effects(self):
        with patch.object(runner, "execute") as execute:
            runner.main([])
        execute.assert_not_called()

    def test_install_does_not_enable_budget_or_restart(self):
        with patch.object(runner, "execute") as execute:
            runner.main(["--install"])
        command = execute.call_args.args[1]
        self.assertIn("MonitorInbox.cls", command)
        self.assertNotIn("Configure(", command)
        self.assertNotIn("StartProduction", command)

    def test_observe_does_not_authorize_inference(self):
        with patch.object(runner, "configure", return_value="observe-only") as configure, patch.object(
                runner, "execute", return_value={"configured": True}):
            runner.main(["--observe"])
        configure.assert_called_once_with(False)

    def test_model_budget_requires_distinct_explicit_flag(self):
        with patch.object(runner, "configure", return_value="authorized") as configure, patch.object(
                runner, "execute", return_value={"configured": True}):
            runner.main(["--authorize-four-requests"])
        configure.assert_called_once_with(True)

    def test_conflicting_modes_are_rejected(self):
        with patch.object(runner, "execute") as execute, self.assertRaises(SystemExit):
            runner.main(["--observe", "--authorize-four-requests"])
        execute.assert_not_called()

    def test_snapshot_rejects_a_synthetic_or_unfinished_result(self):
        with self.assertRaises(ValueError):
            runner.verify({"monitor": {"enabled": 1, "heartbeat": 1, "error": ""}, "details": [], "reports": []})

    def test_read_serializes_cited_unicode_as_utf8_without_invoking_review(self):
        with patch.object(runner, "execute", return_value={"monitor": {"next_cursor": ""}}) as execute:
            runner.snapshot()
        command = execute.call_args.args[1]
        self.assertIn('$ZConvert(', command)
        self.assertIn('"UTF8"', command)
        self.assertNotIn(".Run(", command)
        self.assertNotIn(".Pump(", command)

    def test_acceptance_requires_distinct_explicit_authorization(self):
        with patch.object(runner, "execute", return_value={"authorized": True}) as execute, patch.object(
                runner, "acceptance_command", return_value="explicit-six"):
            runner.main(["--authorize-acceptance-six"])
        self.assertEqual(execute.call_args.args[1], "explicit-six")

    def test_failed_delivery_authorization_cannot_send(self):
        with patch.object(runner, "execute", side_effect=ValueError("not authorized")) as execute, patch.object(
                runner, "run_command") as delivery:
            with self.assertRaises(ValueError):
                runner.main(["--deliver-new"])
        self.assertEqual(execute.call_count, 1)
        delivery.assert_not_called()

    def test_acceptance_verifier_rejects_missing_tasks(self):
        with self.assertRaises(ValueError):
            runner.verify_acceptance({"details": [], "reports": []})
