import unittest
from unittest.mock import patch

import route_ui_test


class RouteUICLITests(unittest.TestCase):
    def test_default_is_inactive(self):
        with patch("route_ui_test.execute") as execute, patch("route_ui_test.check") as check:
            route_ui_test.main([])
        execute.assert_not_called()
        check.assert_not_called()

    def test_install_does_not_change_security_or_production(self):
        with patch("route_ui_test.execute", return_value={"installed": True}) as execute:
            route_ui_test.main(["--install"])
        namespace, code = execute.call_args.args
        self.assertEqual(namespace, "TRIAGE")
        self.assertIn("RouteUI.cls", code)
        self.assertIn("KnowledgeAPI.cls", code)
        for forbidden in ("Foundation()", "Security.Users", "Security.Roles", "StartProduction", "ProcessInput", ".Chat("):
            self.assertNotIn(forbidden, code)

    def test_admin_credentials_are_never_read_for_remote_requests(self):
        with patch("route_ui_test.Path.read_text") as read:
            for base in ("https://example.com/api", "http://example.com/api", "http://user@localhost/api"):
                with self.assertRaises(ValueError):
                    route_ui_test.admin_request(base, "/governance")
        read.assert_not_called()
