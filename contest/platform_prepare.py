#!/usr/bin/env python3
"""Prepare the local-only Knowledge API without changing a Production."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess

import knowledge

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--container", default="iris-triage-real-iris-1")
    args = parser.parse_args()
    directory = ROOT / "data/platform"
    directory.mkdir(parents=True, exist_ok=True)
    directory.chmod(0o700)
    for account in ("ContestViewer", "ContestKnowledgeAdmin"):
        path = directory / f"{account}.password"
        if not path.exists():
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "w") as stream:
                stream.write(secrets.token_hex(32) + "\n")
    manifest = knowledge.verify(knowledge.DEMO, "demo")
    records = [json.loads(line) for line in (knowledge.DEMO / manifest["knowledge_file"]).read_text(encoding="utf-8").splitlines()]
    records = [record for record in records if record["retrieval_scope"] in manifest["default_retrieval_scopes"]]
    if len(records) != 715:
        raise ValueError("Expected the validated 715-record default export")
    data = "".join(json.dumps(record, ensure_ascii=False) + "\n" for record in records).encode("utf-8")
    destination = ROOT / "data/knowledge/platform-default.jsonl"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    (directory / "corpus.sha256").write_text(hashlib.sha256(data).hexdigest() + "\n")
    command = (
        'Set $Namespace="TRIAGE"\n'
        'For file="LocalKnowledge","KnowledgeService","ExistingVectorStore","KnowledgeAPI" { Set sc=$SYSTEM.OBJ.Load("/contest/src/"_file_".cls","ck") If $SYSTEM.Status.IsError(sc) { Do $SYSTEM.Status.DisplayError(sc) Halt } }\n'
        'Set $Namespace="%SYS"\n'
        'Set sc=$SYSTEM.OBJ.Load("/contest/dev/PlatformProvision.cls","ck")\n'
        'If sc Do ##class(User.ContestPlatformProvision).Run()\nHalt\n'
    )
    result = subprocess.run(
        ["docker", "exec", "-i", args.container, "iris", "session", "IRIS", "-U", "%SYS"],
        input=command, capture_output=True, text=True, timeout=60, check=True,
    )
    if "PLATFORM_READY" not in result.stdout:
        raise RuntimeError(result.stdout + result.stderr)
    print("Knowledge API provisioned. Credentials are in ignored contest/data/platform; not printed.")


if __name__ == "__main__":
    main()
