import unittest
from unittest.mock import patch

import declaration_test


class DeclarationCLITests(unittest.TestCase):
    def test_default_is_inactive(self):
        with patch.object(declaration_test, "execute") as execute, \
                patch.object(declaration_test, "admin_request") as request:
            declaration_test.main([])
            execute.assert_not_called()
            request.assert_not_called()

    def test_example_requires_explicit_identity(self):
        with patch.object(declaration_test, "admin_request") as request:
            with self.assertRaises(SystemExit):
                declaration_test.main(["--create-example", "quality"])
            request.assert_not_called()

    def test_examples_are_distinct_proposals_without_assessments(self):
        internal = declaration_test.example("quality", now=5000000000)
        external = declaration_test.example("marketing", now=5000000000)
        incomplete = declaration_test.example("incomplete", now=5000000000)
        self.assertEqual(internal["validity"]["from"], 4999999990)
        self.assertEqual(external["recipient_id"], "external-marketing-demo")
        self.assertEqual(external["purpose"]["category"], "marketing")
        self.assertEqual(external["data"]["fields"], ["Patient.id", "Patient.name"])
        self.assertEqual(incomplete["recipient_id"], "unspecified-recipient")
        for proposal in (internal, external, incomplete):
            self.assertTrue(proposal["synthetic"])
            self.assertNotIn("assessment", proposal)
            self.assertNotIn("approved", proposal)

    def test_failed_creation_is_not_success(self):
        with patch.object(declaration_test, "admin_request", return_value=(409, {"message": "Conflict"})):
            with self.assertRaisesRegex(Exception, "Draft creation failed"):
                declaration_test.create_example("http://127.0.0.1", "quality", "new-proposal")

    def test_invalid_identity_never_sends(self):
        with patch.object(declaration_test, "admin_request") as request:
            with self.assertRaises(Exception):
                declaration_test.create_example("http://127.0.0.1", "quality", "../bad")
            request.assert_not_called()


if __name__ == "__main__":
    unittest.main()
