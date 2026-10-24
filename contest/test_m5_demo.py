import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import m5_demo as demo


class FixedM5DemoTests(unittest.TestCase):
    def test_an_existing_journal_blocks_new_paid_attempt_before_network(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "saved.json"
            path.write_text('{"state":"passed"}')
            with patch.object(demo, "SAVED", path), patch.object(demo, "api") as api:
                with self.assertRaisesRegex(ValueError, "never overwrite"):
                    demo.run(demo.BASE)
                api.assert_not_called()

    def test_resume_without_journal_is_not_a_new_attempt(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(demo, "SAVED", Path(directory) / "missing.json"), patch.object(demo, "api") as api:
                with self.assertRaises(ValueError):
                    demo.run(demo.BASE, resume=True)
                api.assert_not_called()

    def test_completed_attempt_cannot_be_resumed_for_more_requests(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "saved.json"
            path.write_text(json.dumps({"state": "passed", "sent": {}}))
            with patch.object(demo, "SAVED", path), patch.object(demo, "api", return_value={}) as api:
                with self.assertRaisesRegex(ValueError, "no resend"):
                    demo.run(demo.BASE, resume=True)
                self.assertEqual(api.call_count, 1)
                self.assertEqual(api.call_args.args[1], "/m5-demo")

    def test_reset_is_exactly_scoped_and_checks_other_objects(self):
        status = {"production_id": "fixed", "config_hash": "current"}
        clean = {"enrolled": False, "inspection_enabled": False, "profiles": [], "runs": []}
        with patch.object(demo, "api", side_effect=[status, clean]) as api, \
                patch.object(demo, "other_state", return_value={"unchanged": True}) as other:
            self.assertEqual(demo.reset(demo.BASE), clean)
            self.assertEqual(api.call_args.args, (demo.BASE, "/m5-demo/reset", {
                "confirmation": "RESET M5 DEMO", "config_hash": "current",
            }))
            self.assertEqual(other.call_count, 2)

    def test_reset_reports_unrelated_changes_instead_of_success(self):
        status = {"production_id": "fixed", "config_hash": "current"}
        clean = {"enrolled": False, "inspection_enabled": False, "profiles": [], "runs": []}
        with patch.object(demo, "api", side_effect=[status, clean]), \
                patch.object(demo, "other_state", side_effect=[{"old": True}, {"changed": True}]):
            with self.assertRaisesRegex(ValueError, "unchanged"):
                demo.reset(demo.BASE)

    def test_check_command_does_not_execute_or_reset(self):
        with patch.object(demo, "check") as check, patch.object(demo, "run") as run, patch.object(demo, "reset") as reset:
            demo.main(["--check"])
            check.assert_called_once_with(demo.BASE)
            run.assert_not_called()
            reset.assert_not_called()

    def test_remote_target_is_rejected_before_action(self):
        with patch.object(demo, "run") as run:
            with self.assertRaises(ValueError):
                demo.main(["--run", "--base", "https://example.invalid"])
            run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
