import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import production_acceptance_test as m5


class M5AcceptanceCLITests(unittest.TestCase):
    def test_default_is_inactive(self):
        with patch.object(m5, "execute") as execute, patch.object(m5, "api") as api:
            m5.main([])
        execute.assert_not_called()
        api.assert_not_called()

    def test_setup_does_not_enroll_authorize_or_send(self):
        with patch.object(m5, "execute", return_value={}) as execute, patch.object(m5, "api") as api:
            m5.main(["--setup"])
        self.assertEqual(execute.call_count, 2)
        self.assertEqual([c.args[0] for c in execute.call_args_list], ["%SYS", "M5OBSERVATION"])
        api.assert_not_called()

    def test_saved_acceptance_cannot_resend_or_refund(self):
        with tempfile.TemporaryDirectory() as directory:
            saved = Path(directory) / "saved.json"
            saved.write_text(json.dumps({"state": "authorization_requested"}))
            with patch.object(m5, "SAVED", saved), patch.object(m5, "api") as api, patch.object(m5, "send") as send:
                with self.assertRaisesRegex(ValueError, "immutable"):
                    m5.acceptance(m5.BASE)
            api.assert_not_called()
            send.assert_not_called()

    def test_fixture_inputs_are_bounded_literals(self):
        with patch.object(m5, "execute") as execute:
            for route, batch in [("X", "m5-safe"), ("A", 'm5-";WRITE')]:
                with self.assertRaises(ValueError):
                    m5.send(route, batch)
            execute.assert_not_called()
            m5.send("B", "m5-test-B")
            code = execute.call_args.args[1]
            self.assertIn('request.Route="B"', code)
            self.assertIn("2001-02-03", code)
            self.assertIn("M5Source", code)

    def test_check_has_no_delivery_or_inference_entrypoint(self):
        with patch.object(m5, "check") as check, patch.object(m5, "setup") as setup, patch.object(m5, "acceptance") as acceptance:
            m5.main(["--check"])
        check.assert_called_once_with(m5.BASE)
        setup.assert_not_called()
        acceptance.assert_not_called()


if __name__ == "__main__":
    unittest.main()
