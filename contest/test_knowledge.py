import copy
from contextlib import redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("knowledge", Path(__file__).with_name("knowledge.py"))
knowledge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(knowledge)


class KnowledgeTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        capture = redirect_stdout(io.StringIO())
        capture.__enter__()
        self.addCleanup(capture.__exit__, None, None, None)
        self.root = Path(self.directory.name)
        self.demo = self.root / "demo"
        self.full = self.root / "hipaa-documents/prepared/full"
        self.local = self.root / "local"
        self.patchers = [
            patch.object(knowledge, "ROOT", self.root),
            patch.object(knowledge, "DEMO", self.demo),
            patch.object(knowledge, "ARCHIVE", self.root / "hipaa-documents"),
            patch.object(knowledge, "LOCAL", self.local),
            patch.object(knowledge, "REQUIRED_URLS", {"https://www.hhs.gov/test"}),
        ]
        for patcher in self.patchers:
            patcher.start()
            self.addCleanup(patcher.stop)
        self.record = knowledge.document(
            "https://www.hhs.gov/test", "Test", "Synthetic source text",
            "official_guidance", "f" * 64, "test paragraph", source_version="test",
            retrieval_scope="normative",
        )

    def corpus(self, profile, records=None):
        path = self.demo if profile == "demo" else self.full
        path.mkdir(parents=True, exist_ok=True)
        records = records if records is not None else [self.record]
        data = b"".join((json.dumps(r, sort_keys=True) + "\n").encode() for r in records)
        manifest = {
            "schema_version": knowledge.SCHEMA, "profile": profile,
            "corpus_id": knowledge.digest(data), "documents": len(records),
            "text_bytes": sum(len(r["text"].encode()) for r in records),
            "file_bytes": len(data), "knowledge_file": "documents.jsonl",
            "retrieval_scopes": dict(knowledge.Counter(r["retrieval_scope"] for r in records)),
            "default_retrieval_scopes": ["normative", "technical", "orientation", "organization_policy"],
            "excluded_by_default": ["historical", "unreviewed"],
        }
        (path / "documents.jsonl").write_bytes(data)
        (path / "manifest.json").write_text(json.dumps(manifest))
        return path

    def test_article_excludes_navigation_and_script(self):
        parser = knowledge.Article()
        parser.feed("<main>nav<article><h1>Rule</h1><script>evil()</script>"
                    "<p>Keep exception.</p></article>footer</main>")
        text = knowledge.normalize("".join(parser.text))
        self.assertEqual(text, "Rule\nKeep exception.")

    def test_table_cells_do_not_merge(self):
        parser = knowledge.Article()
        parser.feed("<article><table><tr><td>Field</td><td>Purpose</td></tr></table></article>")
        self.assertEqual(knowledge.normalize("".join(parser.text)), "Field\nPurpose")

    def test_demo_excludes_proposals_and_controversial_topics(self):
        for suffix in ("security/guidance/proposed-rule/index.html",
                       "privacy/guidance/hipaa-online-tracking/index.html",
                       "privacy/guidance/reproductive-health/index.html"):
            self.assertFalse(knowledge.demo_html(
                "https://www.hhs.gov/hipaa/for-professionals/" + suffix, "Title"))

    def test_valid_corpus(self):
        self.assertEqual(knowledge.verify(self.corpus("demo"), "demo")["documents"], 1)

    def test_archive_documents_have_explicit_snapshot_version(self):
        record = knowledge.document(
            "https://www.hhs.gov/test", "Title", "text", "archived_text",
            "a" * 64, "complete text",
        )
        self.assertIn("publication date not verified", record["source_version"])

    def test_tampering_is_not_a_success(self):
        path = self.corpus("demo")
        (path / "documents.jsonl").write_text("{}\n")
        with self.assertRaisesRegex(ValueError, "checksum"):
            knowledge.verify(path)

    def test_renamed_full_profile_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "profile mismatch"):
            knowledge.verify(self.corpus("full"), "demo")

    def test_missing_full_does_not_fall_back_to_demo(self):
        self.corpus("demo")
        with self.assertRaises(FileNotFoundError):
            knowledge.select("full")
        self.assertFalse((self.local / "selection.json").exists())

    def test_switches_have_distinct_index_keys(self):
        self.corpus("demo")
        self.corpus("full")
        full = knowledge.select("full")
        demo = knowledge.select("demo")
        self.assertNotEqual(full["index_key"], demo["index_key"])
        self.assertEqual(knowledge.selected()["profile"], "demo")
        self.assertEqual(demo["index_status"], "not_imported")

    def test_release_check_refuses_full_selection(self):
        self.corpus("demo")
        self.corpus("full")
        knowledge.select("full")
        with patch("sys.argv", ["knowledge.py", "release-check"]):
            with self.assertRaisesRegex(ValueError, "explicit demo"):
                knowledge.main()

    def test_release_check_accepts_verified_demo(self):
        self.corpus("demo")
        knowledge.select("demo")
        with patch("sys.argv", ["knowledge.py", "release-check"]):
            knowledge.main()

    def test_selected_digest_is_pinned(self):
        self.corpus("demo")
        knowledge.select("demo")
        modified = copy.deepcopy(self.record)
        modified["text"] += " changed"
        modified["content_sha256"] = knowledge.digest(modified["text"].encode())
        self.corpus("demo", [modified])
        with self.assertRaisesRegex(ValueError, "changed"):
            knowledge.selected()

    def test_empty_provenance_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["source_locator"] = ""
        with self.assertRaisesRegex(ValueError, "provenance"):
            knowledge.verify(self.corpus("demo", [record]))

    def test_duplicate_content_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["id"] = "other"
        with self.assertRaisesRegex(ValueError, "Duplicate document content"):
            knowledge.verify(self.corpus("demo", [self.record, record]))

    def test_quality_validation_does_not_force_padding(self):
        path = self.corpus("demo")
        self.assertEqual(knowledge.verify(path)["documents"], 1)

    def test_historical_evidence_cannot_be_normative(self):
        record = copy.deepcopy(self.record)
        record["kind"] = "historical_final_rule"
        with self.assertRaisesRegex(ValueError, "Invalid retrieval scope"):
            knowledge.verify(self.corpus("demo", [record]))

    def test_unsafe_default_scope_policy_is_rejected(self):
        path = self.corpus("demo")
        manifest_path = path / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["default_retrieval_scopes"].append("unreviewed")
        manifest_path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, "Unsafe retrieval scope policy"):
            knowledge.verify(path)

    def test_default_export_filters_historical_evidence(self):
        historical = copy.deepcopy(self.record)
        historical.update(id="history", kind="historical_final_rule", retrieval_scope="historical")
        self.corpus("demo", [self.record, historical])
        output = self.root / "export.jsonl"
        with patch("sys.argv", ["knowledge.py", "export", "--output", str(output)]):
            knowledge.main()
        rows = [json.loads(line) for line in output.read_text().splitlines()]
        self.assertEqual([r["id"] for r in rows], [self.record["id"]])

    def test_explicit_historical_export(self):
        historical = copy.deepcopy(self.record)
        historical.update(id="history", kind="historical_final_rule", retrieval_scope="historical")
        self.corpus("demo", [self.record, historical])
        output = self.root / "historical.jsonl"
        with patch("sys.argv", ["knowledge.py", "export", "--scope", "historical",
                                "--output", str(output)]):
            knowledge.main()
        self.assertEqual(json.loads(output.read_text())["id"], "history")

    def test_default_export_excludes_unreviewed_records(self):
        record = copy.deepcopy(self.record)
        record.update(id="case", kind="unreviewed_archived_page", retrieval_scope="unreviewed")
        self.corpus("demo", [self.record, record])
        output = self.root / "default.jsonl"
        with patch("sys.argv", ["knowledge.py", "export", "--output", str(output)]):
            knowledge.main()
        self.assertEqual(len(output.read_text().splitlines()), 1)

    def test_export_refuses_to_overwrite_an_existing_file(self):
        self.corpus("demo")
        output = self.root / "existing.jsonl"
        output.write_text("preserve existing contents")
        with patch("sys.argv", ["knowledge.py", "export", "--output", str(output)]):
            with self.assertRaises(FileExistsError):
                knowledge.main()
        self.assertEqual(output.read_text(), "preserve existing contents")


class ReleasePackageTests(unittest.TestCase):
    def test_release_demo_inputs_are_valid_without_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(knowledge, "ARCHIVE", Path(directory) / "missing-archive"):
                result = knowledge.verify(knowledge.DEMO, "demo")
                output = Path(directory) / "default.jsonl"
                with patch("sys.argv", ["knowledge.py", "export", "--output", str(output)]):
                    with redirect_stdout(io.StringIO()):
                        knowledge.main()
                rows = [json.loads(line) for line in output.read_text().splitlines()]
                self.assertTrue(rows)
                self.assertEqual(len(rows), sum(result["retrieval_scopes"][scope]
                                                for scope in knowledge.DEFAULT_SCOPES))
                self.assertTrue(all(r["retrieval_scope"] in knowledge.DEFAULT_SCOPES
                                    for r in rows))
        self.assertGreater(result["text_bytes"], 20_000_000)
        self.assertLess(result["text_bytes"], 30_000_000)

    def test_background_sources_are_not_default_retrieval(self):
        records = [json.loads(line) for line in
                   (knowledge.DEMO / "documents.jsonl").read_text().splitlines()]
        for record in records:
            if record["kind"] == "historical_final_rule":
                self.assertEqual(record["retrieval_scope"], "historical")
            if record["kind"] == "unreviewed_archived_page":
                self.assertEqual(record["retrieval_scope"], "unreviewed")
        self.assertEqual({r["source_url"] for r in records if r["kind"] == "technical_guidance"
                          and "nist.gov" in r["source_url"]}, {
            s["url"] for s in json.loads(
                (knowledge.DEMO / "supplemental-sources.json").read_text())["sources"]
        })

    def test_source_coverage_for_evaluation_cases(self):
        records = [json.loads(line) for line in
                   (knowledge.DEMO / "documents.jsonl").read_text().splitlines()]
        available = {r["source_locator"] for r in records}
        cases = json.loads((knowledge.DEMO / "evaluation-cases.json").read_text())["cases"]
        for case in cases:
            with self.subTest(case=case["id"]):
                self.assertTrue(set(case["required_sections"]).issubset(available))

    def test_raw_archive_and_local_profile_are_git_ignored(self):
        for path in ("hipaa-documents/sources/example.pdf",
                     "hipaa-documents/prepared/full/documents.jsonl",
                     "contest/data/knowledge/selection.json"):
            result = subprocess.run(
                ["git", "check-ignore", "-q", path], cwd=knowledge.ROOT, check=False,
            )
            self.assertEqual(result.returncode, 0, path)


if __name__ == "__main__":
    unittest.main()
