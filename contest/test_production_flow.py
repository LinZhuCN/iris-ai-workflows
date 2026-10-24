import unittest
from unittest.mock import patch

import production_flow_test as flow


class ProductionFlowCLITests(unittest.TestCase):
    def test_inactive_default(self):
        with patch.object(flow, "execute") as run, patch.object(flow, "request") as http:
            flow.main([])
            run.assert_not_called()
            http.assert_not_called()

    def test_install_is_compile_only(self):
        with patch.object(flow, "execute") as run:
            flow.main(["--install"])
            namespace, code = run.call_args.args
            self.assertEqual(namespace, "TRIAGE")
            self.assertIn("/contest/src/ProductionFlow.cls", code)
            self.assertIn("/contest/src/FlowEvidence.cls", code)
            for forbidden in (").Save(", ").Enroll(", ").Pump(", "StartProduction",
                              "RestartProduction", "ProcessInput", "TempStopConfigItem"):
                self.assertNotIn(forbidden, code)

    def test_remote_base_is_rejected(self):
        with patch.object(flow, "execute") as run, patch.object(flow, "request") as http:
            with self.assertRaises(ValueError):
                flow.main(["--check", "--base", "https://example.invalid"])
            run.assert_not_called()
            http.assert_not_called()

    def test_check_refuses_failed_production_list(self):
        with patch.object(flow, "request", return_value=(403, {})):
            with self.assertRaisesRegex(ValueError, "Reader"):
                flow.check(flow.BASE)


if __name__ == "__main__":
    unittest.main()
