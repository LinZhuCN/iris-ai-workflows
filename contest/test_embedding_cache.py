import contextlib
import hashlib
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import embedding
from offline_embedding import verify_output


class EmbeddingCacheTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.source = self.root / "download"
        self.source.mkdir()
        self.content = {"model.onnx": b"synthetic ONNX", "config.json": b"{}"}
        for name, data in self.content.items():
            (self.source / name).write_bytes(data)
        files = {
            name: (len(data), hashlib.sha1(b"blob " + str(len(data)).encode()
                                         + b"\0" + data).hexdigest())
            for name, data in self.content.items()
        }
        self.patch_files = patch.object(embedding, "FILES", files)
        self.patch_sha = patch.object(
            embedding, "MODEL_SHA256", hashlib.sha256(self.content["model.onnx"]).hexdigest())
        self.patch_files.start()
        self.patch_sha.start()
        self.addCleanup(self.patch_files.stop)
        self.addCleanup(self.patch_sha.stop)
        self.cache = self.root / "cache"

    def prepare(self):
        with contextlib.redirect_stdout(io.StringIO()):
            return embedding.prepare(self.cache, "https://hf-mirror.com", self.source)

    def snapshot(self):
        return (self.cache / ("models--" + embedding.MODEL.replace("/", "--"))
                / "snapshots" / embedding.REVISION)

    def test_verified_cache_reuses_files_without_network(self):
        with patch("embedding.subprocess.run") as download:
            manifest = self.prepare()
            self.prepare()
            download.assert_not_called()
        self.assertEqual(manifest["dimensions"], 384)
        self.assertEqual(manifest["revision"], embedding.REVISION)
        self.assertEqual((self.snapshot().parent.parent / "refs/main").read_text(),
                         embedding.REVISION)

    def test_rejects_size_mismatch(self):
        (self.source / "model.onnx").write_bytes(b"bad")
        with self.assertRaisesRegex(ValueError, "size mismatch"):
            self.prepare()
        self.assertFalse((self.cache / "model-manifest.json").exists())
        self.assertFalse(list(self.cache.rglob("*.download")))

    def test_rejects_model_checksum_mismatch(self):
        (self.source / "model.onnx").write_bytes(b"x" * len(self.content["model.onnx"]))
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            self.prepare()

    def test_rejects_configuration_checksum_mismatch(self):
        (self.source / "config.json").write_bytes(b"[]")
        with self.assertRaisesRegex(ValueError, "repository blob mismatch"):
            self.prepare()

    def test_existing_corruption_fails_without_redownload(self):
        self.prepare()
        (self.snapshot() / "config.json").write_bytes(b"[]")
        with patch("embedding.subprocess.run") as download:
            with self.assertRaisesRegex(ValueError, "repository blob mismatch"):
                self.prepare()
            download.assert_not_called()

    def test_failed_download_leaves_no_ready_manifest(self):
        (self.source / "model.onnx").unlink()
        with patch("embedding.subprocess.run",
                   side_effect=embedding.subprocess.CalledProcessError(22, "curl")):
            with self.assertRaises(embedding.subprocess.CalledProcessError):
                self.prepare()
        self.assertFalse((self.cache / "model-manifest.json").exists())
        self.assertFalse(list(self.cache.rglob("*.download")))

    def test_offline_proof_requires_all_framework_tests(self):
        output = "\n".join(
            [f" TestExample{i} passed" for i in range(8)]
            + ["All PASSED", "All PASSED", "OFFLINE_HIPAA_DOCUMENTS=715",
               "OFFLINE_EMBEDDING_COMPLETED"])
        self.assertEqual(len(verify_output(output)), 8)
        for invalid in (output.replace("All PASSED", "", 1),
                        output.replace("DOCUMENTS=715", "DOCUMENTS=195"),
                        output + "\nSome tests FAILED"):
            with self.assertRaisesRegex(RuntimeError, "verification failed"):
                verify_output(invalid)


if __name__ == "__main__":
    unittest.main()
