import unittest
from unittest.mock import patch

import declaration_monitor_test as monitor


class DeclarationMonitorCLITests(unittest.TestCase):
    def test_default_is_inactive(self):
        with patch.object(monitor, "execute") as run, patch.object(monitor, "admin_request") as http:
            monitor.main([])
            run.assert_not_called()
            http.assert_not_called()

    def test_install_never_funds_or_manually_scans(self):
        with patch.object(monitor, "execute") as run:
            monitor.main(["--install"])
            namespace, code = run.call_args.args
            self.assertEqual(namespace, "TRIAGE")
            for forbidden in (").Pump(", ").Scan(", ").Authorize(", "RestartProduction", "TempStopConfigItem", "ProcessInput"):
                self.assertNotIn(forbidden, code)

    def test_check_requires_exact_run(self):
        with patch.object(monitor, "execute") as run:
            with self.assertRaises(SystemExit):
                monitor.main(["--check"])
            run.assert_not_called()

    def test_remote_base_is_rejected(self):
        with patch.object(monitor, "execute") as run:
            with self.assertRaises(ValueError):
                monitor.main(["--install", "--base", "https://example.invalid"])
            run.assert_not_called()

    def test_failed_delivery_is_not_monitoring_acceptance(self):
        with patch.object(monitor, "admin_request", return_value=(200, {"state": "reconciliation_required"})):
            with self.assertRaisesRegex(ValueError, "Verified delivered"):
                monitor.check(monitor.BASE, "declaration-run-unit")


if __name__ == "__main__":
    unittest.main()
