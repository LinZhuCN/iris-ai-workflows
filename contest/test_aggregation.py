import unittest
from unittest.mock import patch

import aggregation_test
import aggregation_setup


class AggregationCLITests(unittest.TestCase):
    def test_default_is_free_and_inactive(self):
        with patch("aggregation_test.subprocess.run") as run:
            aggregation_test.main([])
        run.assert_not_called()

    def test_command_is_bounded_and_explicit(self):
        for value in ('bad" Do evil', "../bad", "", "a" * 65):
            with self.assertRaises(ValueError):
                aggregation_test.command(value)
        command = aggregation_test.command("unit-batch")
        self.assertIn('service.ProcessInput', command)
        self.assertNotIn(".Chat(", command)
        self.assertNotIn("StartProduction", command)

    def test_failed_run_is_not_delivery(self):
        with self.assertRaises(ValueError):
            aggregation_test.validate({"error": "reconciliation required"})

    def test_setup_requires_explicit_apply(self):
        with patch("aggregation_setup.subprocess.run") as run, patch("aggregation_setup.aggregation_prepare.main") as prepare:
            aggregation_setup.main([])
        run.assert_not_called()
        prepare.assert_not_called()
