#!/usr/bin/env python3
"""Download a checksum-pinned official Agentic Dev release into ignored storage."""
import hashlib
import os
from pathlib import Path
import platform
import subprocess
import tempfile

version = "1.5.0"
assets = {
    ("Darwin", "arm64"): ("macos-arm64", "cfae461e715945bdc0d3f6462ec1795c88f31a161573cca2c5872cda08c050d9"),
    ("Darwin", "x86_64"): ("macos-x86_64", "b9f54111852bc969652b6ace2cbbbc90020e6c4646d9034c8d86ff70256aef59"),
    ("Linux", "aarch64"): ("linux-aarch64", "3698ebc2baccec1bf852a2ce7fcf3ac312fcefbcf2525df49a8839919ad068c1"),
    ("Linux", "x86_64"): ("linux-x86_64", "a9660b4bf0a74498c7dcd6a371b7c1900e4ad8be237cd8f9187a4f406a83dcee"),
}
key = (platform.system(), platform.machine())
if key not in assets:
    raise SystemExit("Supported hosts: macOS/Linux ARM64 or x86_64; use WSL on Windows")
asset, expected = assets[key]
directory = Path(__file__).resolve().parents[1] / "data/agentic-dev"
directory.mkdir(parents=True, exist_ok=True)
destination = directory / "iris-agentic-dev"

def checksum(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()

if destination.is_file() and checksum(destination) == expected:
    destination.chmod(0o755)
    print("Official Agentic Dev v" + version + " already installed; SHA-256 verified")
else:
    descriptor, temporary = tempfile.mkstemp(prefix="download-", dir=directory)
    os.close(descriptor)
    temporary = Path(temporary)
    try:
        url = ("https://github.com/intersystems-community/iris-agentic-dev/releases/download/"
               "v" + version + "/iris-agentic-dev-" + asset)
        subprocess.run(["curl", "--fail", "--location", "--retry", "3",
                        "--connect-timeout", "30", "--max-time", "600",
                        "--output", str(temporary), url], check=True)
        if checksum(temporary) != expected:
            raise SystemExit("Release SHA-256 mismatch; download was not installed")
        temporary.chmod(0o755)
        temporary.replace(destination)
        print("Installed official Agentic Dev v" + version + "; SHA-256 verified")
    finally:
        if temporary.exists():
            temporary.unlink()
