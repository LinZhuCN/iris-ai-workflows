import unittest
from unittest.mock import patch

import production_evidence_test as evidence


class ProductionEvidenceCLITests(unittest.TestCase):
    def test_default_is_inactive(self):
        with patch.object(evidence, "execute") as run, patch.object(evidence, "admin_request") as http:
            evidence.main([])
            run.assert_not_called()
            http.assert_not_called()

    def test_install_is_compile_only(self):
        with patch.object(evidence, "execute") as run:
            evidence.main(["--install"])
            namespace, code = run.call_args.args
            self.assertEqual(namespace, "TRIAGE")
            self.assertIn("/contest/src/ProductionEvidence.cls", code)
            for forbidden in (").Authorize(", ").Capture(", ").Pump(", "StartProduction", "ProcessInput"):
                self.assertNotIn(forbidden, code)

    def test_remote_base_rejected_before_operations(self):
        with patch.object(evidence, "execute") as run:
            with self.assertRaises(ValueError):
                evidence.main(["--setup", "--base", "https://example.invalid"])
            run.assert_not_called()

    def test_http_failure_is_not_success(self):
        with patch.object(evidence, "admin_request", return_value=(409, {"message": "failed"})):
            with self.assertRaisesRegex(ValueError, "HTTP 409"):
                evidence.api(evidence.BASE, "/productions")

    def test_saved_acceptance_cannot_repeat_business_sends(self):
        with patch.object(evidence, "SAVED") as saved, patch.object(evidence, "send") as send:
            saved.exists.return_value = True
            with self.assertRaisesRegex(ValueError, "immutable"):
                evidence.acceptance(evidence.BASE)
            send.assert_not_called()


if __name__ == "__main__":
    unittest.main()
