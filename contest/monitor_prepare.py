#!/usr/bin/env python3
"""Install the isolated synthetic P2 Production and owned platform inbox service."""
import os
from pathlib import Path
import secrets
import subprocess

ROOT = Path(__file__).resolve().parent


def main():
    directory = ROOT / "data/platform"
    directory.mkdir(parents=True, exist_ok=True)
    for account in ("ContestConnectorReader", "ContestConnectorManager", "ContestDemoSource"):
        path = directory / f"{account}.password"
        if not path.exists():
            fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
            with os.fdopen(fd, "w") as stream:
                stream.write(secrets.token_hex(32) + "\n")
    command = (
        'Set sc=$System.OBJ.Load("/contest/dev/MonitorProvision.cls","ck")\n'
        'If $System.Status.IsOK(sc) Do ##class(User.ContestMonitorProvision).Run()\nHalt\n'
    )
    result = subprocess.run(
        ["docker", "exec", "-i", "iris-triage-real-iris-1", "iris", "session", "IRIS", "-U", "%SYS"],
        input=command, capture_output=True, text=True, check=True, timeout=120,
    )
    if "MONITOR_READY" not in {line.strip() for line in result.stdout.splitlines()}:
        raise RuntimeError(result.stdout + result.stderr)
    print("MONITOR_READY: DEMO installed; owned TRIAGE inbox added without restarting its Production.")


if __name__ == "__main__":
    main()
