#!/usr/bin/env python3
"""Create only the ignored, local synthetic FHIR service credential."""
import os
from pathlib import Path
import secrets


def main():
    path = Path(__file__).resolve().parent / "data/platform/AggregationFHIR.password"
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w") as stream:
            stream.write(secrets.token_urlsafe(36) + "\n")
    if path.is_symlink() or not path.is_file() or path.stat().st_mode & 0o077:
        raise RuntimeError("FHIR credential must be a private regular file")
    print("Local FHIR credential ready; no model call or environment provisioning.")


if __name__ == "__main__":
    main()
