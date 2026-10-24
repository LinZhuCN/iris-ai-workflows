import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import production_deidentification_test as demo


class PrimaryDemoTests(unittest.TestCase):
    def test_neutral_context_and_premises_identical_only_payload_differs(self):
        suite = demo.load()
        bad, clean = suite["cases"]
        self.assertEqual(demo.payload(suite, bad)["export_context"], demo.payload(suite, clean)["export_context"])
        self.assertEqual(bad["oracle"]["assessment"], "risk_identified")
        self.assertEqual(clean["oracle"]["assessment"], "no_signal_on_checked_issues")
        self.assertNotIn("oracle", demo.payload(suite, bad))
        self.assertNotIn("risk", str(suite["premises"]).lower())
        self.assertNotIn("name", clean["payload"])
        self.assertNotIn("mrn", clean["payload"])
        self.assertEqual(clean["payload"]["birthDate"], "2001")

    def test_default_is_inactive(self):
        with patch.object(demo, "run") as run, patch.object(demo, "api") as api:
            demo.main([])
        run.assert_not_called()
        api.assert_not_called()

    def test_read_only_check_does_not_run(self):
        with patch.object(demo, "check") as check, patch.object(demo, "run") as run:
            demo.main(["--check"])
        check.assert_called_once_with(demo.BASE)
        run.assert_not_called()

    def test_immutable_attempt_blocks_replay_before_any_network_or_send(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "attempt.json"
            path.write_text('{"state":"send_requested"}')
            with patch.object(demo, "SAVED", path), patch.object(demo, "api") as api, patch.object(demo, "send") as send:
                with self.assertRaisesRegex(ValueError, "immutable"):
                    demo.run(demo.BASE)
            api.assert_not_called()
            send.assert_not_called()

    def test_remote_endpoint_rejected(self):
        with patch.object(demo, "run") as run:
            with self.assertRaises(ValueError):
                demo.main(["--run", "--base", "https://example.invalid"])
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
