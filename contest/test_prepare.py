import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import prepare


class PrepareCredentialTests(unittest.TestCase):
    def test_default_preserves_existing_gateway_and_skips_admin(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "data").mkdir()
            gateway = root / "data/gateway-password"
            gateway.write_text("existing-test-value\n")
            with patch("prepare.__file__", str(root / "prepare.py")), patch("prepare.getpass.getpass") as prompt:
                prepare.main([])
            prompt.assert_not_called()
            self.assertEqual(gateway.read_text(), "existing-test-value\n")
            self.assertFalse((root / "data/portal-admin-password").exists())

    def test_admin_is_opt_in_private_and_requires_confirmation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch("prepare.__file__", str(root / "prepare.py")):
                with patch("prepare.getpass.getpass", side_effect=["unit-test-value", "mismatch"]):
                    with self.assertRaises(SystemExit):
                        prepare.main(["--portal-admin"])
                path = root / "data/portal-admin-password"
                self.assertFalse(path.exists())
                with patch("prepare.getpass.getpass", side_effect=["unit-test-value"] * 2):
                    prepare.main(["--portal-admin"])
                self.assertEqual(path.read_text(), "unit-test-value\n")
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
