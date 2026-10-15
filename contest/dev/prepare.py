#!/usr/bin/env python3
"""Provision credentials only on the explicitly selected contest container."""
import os
from pathlib import Path
import secrets
import subprocess

directory = Path(__file__).resolve().parents[1] / "data/agentic-dev"
directory.mkdir(parents=True, exist_ok=True)
path = directory / "password"
if not path.exists():
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as stream:
        stream.write(secrets.token_hex(32) + "\n")
container = os.environ.get("TRIAGE_DEV_CONTAINER", "iris-triage-real-iris-1")
result = subprocess.run(
    ["docker", "exec", "-i", container, "iris", "session", "IRIS", "-U", "%SYS"],
    input='Set sc=$SYSTEM.OBJ.Load("/contest/dev/Provision.cls","ck")\n'
          'If sc Do ##class(User.ContestDevProvision).Run()\nHalt\n',
    text=True, capture_output=True, timeout=60, check=True,
)
if "DEV_ACCOUNT_READY" not in result.stdout:
    raise SystemExit(result.stdout + result.stderr)
print("Dedicated development account provisioned; password stays in ignored local storage.")
