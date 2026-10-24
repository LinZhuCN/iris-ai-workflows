#!/usr/bin/env python3
"""Verify local HIPAA indexing in an isolated IRIS container with no network."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time
import uuid

import embedding
import knowledge

ROOT = Path(__file__).resolve().parents[1]
IMAGE = "docker.iscinternal.com/docker-intersystems/intersystems/irishealth:2026.3.0AI.154.0"


def docker(*args, **kwargs):
    return subprocess.run(["docker", *args], check=True, capture_output=True,
                          text=True, **kwargs).stdout


def verify_output(output):
    passed = re.findall(r"^\s+(Test\w+) passed\s*$", output, re.MULTILINE)
    if (output.count("All PASSED") != 2 or len(passed) != 8
            or "FAILED" in output or "OFFLINE_EMBEDDING_COMPLETED" not in output
            or "OFFLINE_HIPAA_DOCUMENTS=715" not in output):
        raise RuntimeError("Offline framework/index verification failed:\n" + output)
    return passed


def run(license_path, cache, image):
    if not license_path.is_file():
        raise ValueError("A valid local IRIS license file is required")
    repository = cache / ("models--" + embedding.MODEL.replace("/", "--"))
    for name in embedding.FILES:
        embedding.verify_file(repository / "snapshots" / embedding.REVISION / name, name)
    if (repository / "refs/main").read_text().strip() != embedding.REVISION:
        raise ValueError("Local model cache revision mismatch")
    manifest = knowledge.verify(knowledge.DEMO, "demo")
    records = [json.loads(line) for line in
               (knowledge.DEMO / manifest["knowledge_file"]).read_text().splitlines()]
    records = [r for r in records if r["retrieval_scope"] in manifest["default_retrieval_scopes"]]
    name = "iris-embedding-proof-" + uuid.uuid4().hex[:8]
    data = ROOT / "contest/data"
    data.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="offline-embedding-", dir=data) as directory:
        source = Path(directory) / "hipaa.jsonl"
        source.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in records),
                          encoding="utf-8")
        mounts = [
            (license_path.resolve(), "/usr/irissys/mgr/iris.key"),
            (cache.resolve(), "/dur/models/fastembed"),
            (ROOT / "contest/src", "/sources"),
            (ROOT / "contest/dev", "/tests"),
            (ROOT / "contest/OfflineEmbedding.cls", "/offline/OfflineEmbedding.cls"),
            (source.resolve(), "/hipaa.jsonl"),
        ]
        args = ["run", "--rm", "-d", "--name", name, "--network", "none",
                "-e", "FASTEMBED_CACHE_DIR=/dur/models/fastembed"]
        for host, container in mounts:
            args.extend(["--mount", f"type=bind,source={host},target={container},readonly"])
        docker(*args, image)
        try:
            deadline = time.monotonic() + 90
            while True:
                ready = subprocess.run(
                    ["docker", "exec", "-i", name, "iris", "session", "IRIS", "-U", "%SYS"],
                    input='Write "OFFLINE_IRIS_READY",!\nHalt\n', capture_output=True, text=True,
                    timeout=10)
                if ready.returncode == 0 and "OFFLINE_IRIS_READY" in ready.stdout:
                    break
                if time.monotonic() >= deadline:
                    raise RuntimeError("Isolated IRIS did not become responsive")
                time.sleep(1)
            network = docker("inspect", "--format", "{{.HostConfig.NetworkMode}}", name).strip()
            if network != "none":
                raise RuntimeError("Offline proof requires Docker network=none")
            output = docker("exec", "-i", name, "iris", "session", "IRIS", "-U", "%SYS",
                            input='Set sc=$System.OBJ.Load("/offline/OfflineEmbedding.cls","ck")\n'
                                  'Do ##class(User.OfflineEmbedding).Run()\nHalt\n',
                            timeout=300)
            passed = verify_output(output)
            proof = {
                "network": network, "image": image, "model": embedding.MODEL,
                "revision": embedding.REVISION, "dimensions": 384,
                "corpus_id": manifest["corpus_id"], "documents": len(records),
                "chunks": 1785, "passed_tests": passed, "failed_tests": 0,
            }
            (data / "embedding-offline-proof.json").write_text(json.dumps(proof, indent=2) + "\n")
            print(json.dumps(proof, indent=2))
        finally:
            docker("stop", name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--license", type=Path, required=True)
    parser.add_argument("--cache", type=Path, default=embedding.DEFAULT_CACHE)
    parser.add_argument("--image", default=IMAGE)
    args = parser.parse_args()
    run(args.license, args.cache, args.image)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit("Offline embedding check failed: " + str(error))
