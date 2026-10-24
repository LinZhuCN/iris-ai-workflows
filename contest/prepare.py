#!/usr/bin/env python3
"""Prepare ignored local credentials; optionally configure the demo Portal administrator."""
import argparse
import getpass
from pathlib import Path
import secrets

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--portal-admin", action="store_true",
                        help="Prompt for a local superuser password; no expiry or first-login reset")
    args = parser.parse_args(argv)
    directory = Path(__file__).parent / "data"
    directory.mkdir(exist_ok=True)
    path = directory / "gateway-password"
    if not path.exists():
        with path.open("x") as stream:
            stream.write(secrets.token_hex(32) + "\n")
        path.chmod(0o600)
    if args.portal_admin:
        password = getpass.getpass("Local demo superuser password: ")
        confirmation = getpass.getpass("Confirm password: ")
        if not password or password != confirmation or "\n" in password or "\r" in password:
            parser.error("A nonempty matching single-line password is required")
        path = directory / "portal-admin-password"
        path.touch(mode=0o600, exist_ok=True)
        path.chmod(0o600)
        path.write_text(password + "\n")
        print("Local Portal credential saved. Startup will configure superuser; local demo use only.")
    print("Local Gateway credential file is ready.")


if __name__ == "__main__":
    main()
