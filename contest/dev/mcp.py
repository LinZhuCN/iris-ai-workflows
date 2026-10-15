#!/usr/bin/env python3
"""Launch workspace-local Agentic Dev with an ignored development credential."""
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
binary = root / "contest/data/agentic-dev/iris-agentic-dev"
password = root / "contest/data/agentic-dev/password"
if not (root / ".iris-agentic-dev.toml").is_file():
    raise SystemExit("Missing workspace configuration; refusing automatic instance discovery")
if not binary.is_file() or not os.access(binary, os.X_OK):
    raise SystemExit("Install the official iris-agentic-dev binary: see contest/dev/README.md")
if not password.is_file():
    raise SystemExit("Provision the local development account: see contest/dev/README.md")
secret = password.read_text().strip()
if not secret:
    raise SystemExit("Development credential file is empty")
environment = os.environ.copy()
for name in list(environment):
    if name.startswith("IRIS_"):
        del environment[name]
environment["IRIS_PASSWORD"] = secret
environment["OBJECTSCRIPT_WORKSPACE"] = str(root)
os.chdir(root)
os.execve(binary, [str(binary), *sys.argv[1:]], environment)
