#!/usr/bin/env python3
"""Prepare a pinned, verified local FastEmbed cache; never call inference APIs."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MODEL = "Qdrant/all-MiniLM-L6-v2-onnx"
REVISION = "d13954661f83248295ba75c1ed411eef3b7b936e"
MODEL_SHA256 = "bbd7b466f6d58e646fdc2bd5fd67b2f5e93c0b687011bd4548c420f7bd46f0c5"
FILES = {
    "model.onnx": (90387630, None),
    "config.json": (650, "56c8c186de9040d4fea8daac2ca110f9d412bf04"),
    "special_tokens_map.json": (695, "9bbecc17cabbcbd3112c14d6982b51403b264bfa"),
    "tokenizer.json": (711649, "4eade387f6f3ade6a663a25642ed27843081a772"),
    "tokenizer_config.json": (1412, "954add25cc0792a2226b11d8ed5c9c39578084f0"),
    "vocab.txt": (231508, "fb140275c155a9c7c5a3b3e0e77a9e839594a938"),
    "README.md": (945, "be1f8e1e86bd36cff35ffa4f3dcd09ba91c041df"),
}
DEFAULT_CACHE = ROOT / "contest/data/models/fastembed"


def verify_file(path, name):
    size, blob = FILES[name]
    if path.stat().st_size != size:
        raise ValueError(f"Model file size mismatch: {name}")
    sha256 = hashlib.sha256()
    sha1 = hashlib.sha1(b"blob " + str(size).encode() + b"\0")
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            sha256.update(block)
            sha1.update(block)
    checksum = sha256.hexdigest()
    if name == "model.onnx":
        if checksum != MODEL_SHA256:
            raise ValueError("ONNX model SHA-256 mismatch")
    elif sha1.hexdigest() != blob:
        raise ValueError(f"Pinned repository blob mismatch: {name}")
    return {"file": name, "bytes": size, "sha256": checksum}


def prepare(cache, endpoint, download_directory=None):
    repository = cache / ("models--" + MODEL.replace("/", "--"))
    snapshot = repository / "snapshots" / REVISION
    snapshot.mkdir(parents=True, exist_ok=True)
    files = []
    for name in FILES:
        path = snapshot / name
        if not path.is_file():
            temporary = path.with_suffix(path.suffix + ".download")
            try:
                existing = download_directory / name if download_directory else None
                if existing and existing.is_file():
                    shutil.copyfile(existing, temporary)
                else:
                    subprocess.run([
                        "curl", "--fail", "--location", "--retry", "2",
                        "--connect-timeout", "15", "--max-time", "300",
                        "--output", str(temporary),
                        f"{endpoint.rstrip('/')}/{MODEL}/resolve/{REVISION}/{name}",
                    ], check=True)
                verify_file(temporary, name)
                temporary.replace(path)
            finally:
                temporary.unlink(missing_ok=True)
        files.append(verify_file(path, name))
    (repository / "refs").mkdir(exist_ok=True)
    (repository / "refs/main").write_text(REVISION)
    manifest = {
        "model": MODEL, "revision": REVISION, "dimensions": 384,
        "license": "Apache-2.0",
        "official_source": f"https://huggingface.co/{MODEL}/tree/{REVISION}",
        "configured_download_endpoint": endpoint, "files": files,
    }
    (cache / "model-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    parser.add_argument("--endpoint", choices=("https://huggingface.co", "https://hf-mirror.com"),
                        default="https://huggingface.co")
    parser.add_argument("--download-directory", type=Path)
    args = parser.parse_args()
    prepare(args.cache, args.endpoint, args.download_directory)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        raise SystemExit("Local embedding preparation failed: " + str(error))
