#!/usr/bin/env python3
"""Generate a local-only Web Gateway service password (never print it)."""
from pathlib import Path
import secrets

directory = Path(__file__).parent / "data"
directory.mkdir(exist_ok=True)
path = directory / "gateway-password"
if not path.exists():
    with path.open("x") as stream:
        stream.write(secrets.token_hex(32) + "\n")
    path.chmod(0o600)
print("Local Gateway credential file is ready.")
