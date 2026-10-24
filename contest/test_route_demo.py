import unittest
from unittest.mock import patch

import route_demo


class RouteDemoTests(unittest.TestCase):
    def test_default_does_not_install_reset_or_call_models(self):
        with patch.object(route_demo, "execute") as execute, patch.object(route_demo, "install") as install:
            route_demo.main([])
        execute.assert_not_called()
        install.assert_not_called()

    def test_reset_and_cost_consent_are_separate(self):
        with patch.object(route_demo, "reset") as reset, patch.object(route_demo, "execute") as execute:
            route_demo.main(["--reset-demo"])
        reset.assert_called_once_with()
        execute.assert_not_called()
        with patch.object(route_demo, "configure", return_value="exact-pins") as configure, patch.object(route_demo, "execute") as execute:
            route_demo.main(["--authorize-four-requests"])
        configure.assert_called_once_with(True)
        self.assertEqual(execute.call_args.args, ("TRIAGE", "exact-pins"))

    def test_technical_failure_cannot_be_presented_as_completed_demo(self):
        with patch.object(route_demo, "snapshot", return_value={}), patch.object(
                route_demo, "verify", return_value={"completed": 1}):
            with self.assertRaises(ValueError):
                route_demo.check()

    def test_failed_output_retest_requires_its_own_explicit_flag(self):
        with patch.object(route_demo, "execute") as execute, patch.object(route_demo, "reset") as reset:
            route_demo.main(["--replace-failed-utilization-two-requests"])
        code = execute.call_args.args[1]
        self.assertIn("ReplaceFailedUtilization()", code)
        self.assertNotIn("ProcessInput", code)
        self.assertNotIn("Configure(", code)
        reset.assert_not_called()
