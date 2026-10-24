import unittest
from unittest.mock import patch

import production_monitor_test as monitor


class ProductionMonitorCLITests(unittest.TestCase):
    def test_inactive_default(self):
        with patch.object(monitor, "execute") as run, patch.object(monitor, "admin_request") as http:
            monitor.main([])
            run.assert_not_called()
            http.assert_not_called()

    def test_install_compiles_without_enrolling_or_running_business(self):
        with patch.object(monitor, "execute") as run:
            monitor.main(["--install"])
            namespace, code = run.call_args.args
            self.assertEqual(namespace, "TRIAGE")
            for forbidden in (").Enroll(", ").Pump(", "StartProduction", "RestartProduction", "ProcessInput", "TempStopConfigItem"):
                self.assertNotIn(forbidden, code)

    def test_reject_remote_base(self):
        with patch.object(monitor, "execute") as run:
            with self.assertRaises(ValueError):
                monitor.main(["--install", "--base", "https://example.invalid"])
            run.assert_not_called()

    def test_one_managed_object_is_not_multiple_production_acceptance(self):
        with patch.object(monitor, "get", side_effect=[{"model_calls": 0}, {"items": [{}], "error": ""}]):
            with self.assertRaisesRegex(ValueError, "at least two"):
                monitor.check(monitor.BASE)

    def test_error_response_is_not_success(self):
        with patch.object(monitor, "admin_request", return_value=(409, {"message": "denied"})):
            with self.assertRaises(ValueError):
                monitor.get(monitor.BASE, "/productions")


if __name__ == "__main__":
    unittest.main()
