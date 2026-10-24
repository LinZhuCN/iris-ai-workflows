import unittest
from unittest.mock import patch

import declaration_execution_test as execution


class DeclarationExecutionCLITests(unittest.TestCase):
    def test_default_never_changes_runtime(self):
        with patch.object(execution, "execute") as run:
            execution.main([])
            run.assert_not_called()

    def test_compile_and_host_reload_are_separate(self):
        with patch.object(execution, "execute") as run:
            execution.main(["--install"])
            self.assertEqual(run.call_count, 2)
            self.assertNotIn("TempStopConfigItem", repr(run.call_args_list))
            self.assertNotIn("Start(", repr(run.call_args_list))

    def test_explicit_local_reload_never_restarts_production_or_sends(self):
        with patch.object(execution, "execute") as run:
            execution.main(["--reload-hosts"])
            namespace, code = run.call_args.args
            self.assertEqual(namespace, "UTILIZATION")
            self.assertIn('TempStopConfigItem', code)
            self.assertIn('ProductionNeedsUpdate', code)
            self.assertIn('"UtilizationProcess","AnalysisReceiver"', code)
            for forbidden in ("RestartProduction", "StartProduction", "ProcessInput", "DeclarationExecution).Start"):
                self.assertNotIn(forbidden, code)

    def test_check_requires_identity_before_work(self):
        with patch.object(execution, "execute") as run:
            with self.assertRaises(SystemExit):
                execution.main(["--check"])
            run.assert_not_called()

    def test_remote_base_cannot_trigger_install(self):
        with patch.object(execution, "execute") as run:
            with self.assertRaises(ValueError):
                execution.main(["--install", "--base", "https://example.invalid"])
            run.assert_not_called()

    def test_failed_delivery_never_counts_as_acceptance(self):
        history = {"record_id": "record-unit", "model_calls": 0, "next_cursor": "", "items": []}
        with patch.object(execution, "request", return_value=(403, {})), \
                patch.object(execution, "admin_request", side_effect=[(200, {"digest": "unit"}), (200, history)]):
            with self.assertRaisesRegex(ValueError, "No real"):
                execution.check(execution.BASE, "record-unit")


if __name__ == "__main__":
    unittest.main()
