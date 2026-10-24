import copy
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import hipaa_conditions_test as h


class HIPAAConditionsTests(unittest.TestCase):
    def report(self):
        suite, records = h.load()
        case = suite["cases"][0]
        hits, citations = [], []
        for index, authority in enumerate(case["oracle"]["authorities"]):
            record = records[authority["section"]]
            start = record["text"].lower().index(authority["anchor"].lower())
            end = start + len(authority["anchor"])
            passage = {"id": "p" + str(index), "start": start, "end": end, "text": record["text"][start:end]}
            identifier = "e" + str(index)
            hits.append({"id": identifier, "metadata": record, "text": record["text"], "passages": [passage],
                         "source_hash_verified": True, "section_text_complete": True})
            citations.append({"evidence_id": identifier, "passage_id": passage["id"],
                              "start": start, "end": end, "quote": passage["text"]})
        oracle = case["oracle"]
        report = {"state": "completed", "questions": [{"id": "q1", "topic": case["topic"]}],
                  "packages": [{"question_id": "q1", "evidence": hits}],
                  "result": {"missing_information": [], "issues": [{"question_id": "q1",
                    "status": oracle["status"], "applicability": oracle["applicability"][0],
                    "condition_status": oracle["condition_status"][0], "fact_ids": oracle["critical_fact_ids"],
                    "citations": citations, "explanation": "Synthetic scorer fixture, not a model result."}]}}
        return case, report, records

    def journal(self):
        case, report, records = self.report()
        suite = {"suite": "scorer-unit-only", "cases": [case]}
        agent = {"id": "unit-agent", "revision": 1, "config_hash": "unit-config"}
        consent = {"input_hash": "unit-input", "contract_hash": "unit-contract",
                   "agent_id": agent["id"], "source_revision": agent["revision"],
                   "config_hash": agent["config_hash"], "max_model_requests": 2, "acknowledge_cost": True}
        p = h.packet(case)
        report.update(id="unit-report", packet=p, authorization=copy.deepcopy(consent),
                      version="hipaa-conditions-v1", execution="evaluation_only", source=agent,
                      reserved_model_requests=2, phases=[
                          {"phase": phase, "input": {k: p[k] for k in ("synthetic", "stage", "facts")} if phase == "locate"
                           else {"facts": p}, "agent_session": "unit-" + phase, "usage": {"total_tokens": 10},
                           "sdk_stats": {"total_interactions": 1, "total_tool_calls": 0}}
                          for phase in ("locate", "judge")])
        frozen = {"suite_hash": h.fingerprint(suite), "packet_hash": h.fingerprint([p]), "agent": copy.deepcopy(agent),
                  "cases": [{"case_id": case["id"], "input_hash": consent["input_hash"],
                             "contract_hash": consent["contract_hash"]}], "maximum_model_requests": 16}
        return suite, {"freeze": frozen, "cases": [{"case_id": case["id"], "consent": consent, "report": report}]}, records

    def test_prospective_cases_cover_permissions_exceptions_and_real_unknowns(self):
        suite, _ = h.load()
        statuses = [c["oracle"]["status"] for c in suite["cases"]]
        self.assertEqual(statuses.count("risk_signal"), 3)
        self.assertEqual(statuses.count("no_signal_on_checked_issue"), 4)
        self.assertEqual(statuses.count("unresolved"), 1)

    def test_projection_does_not_export_oracle_labels_clauses_or_case_ids(self):
        suite, _ = h.load()
        for case in suite["cases"]:
            p = h.packet(case)
            self.assertEqual(set(p), {"synthetic", "stage", "facts", "required_questions"})
            self.assertNotIn(case["id"], h.literal(p))
            self.assertNotIn("oracle", h.literal(p))
            self.assertNotIn("approved_scenario", h.literal(p))
            changed = copy.deepcopy(case)
            changed["oracle"] = {"status": "invented", "authorities": []}
            self.assertEqual(h.packet(changed), p)

    def test_free_default_cannot_call_model_or_business_runtime(self):
        with patch.object(h, "execute") as execute, patch.object(h, "api") as api:
            h.main([])
        execute.assert_not_called()
        api.assert_not_called()

    def test_existing_journal_cannot_be_replayed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "unit-hipaa.json"
            path.write_text("{}")
            with patch.object(h, "DIRECTORY", Path(directory)), patch.object(h, "prepare") as prepare:
                with self.assertRaisesRegex(ValueError, "already exists"):
                    h.run({}, h.BASE, "unit")
            prepare.assert_not_called()

    def test_invalid_run_key_fails_before_any_runtime_call(self):
        with patch.object(h, "prepare") as prepare:
            with self.assertRaises(ValueError):
                h.run({}, h.BASE, '../invalid"')
        prepare.assert_not_called()

    def test_technical_failure_never_counts_as_a_correct_judgment(self):
        suite, _ = h.load()
        row = h.grade(suite["cases"][0], {"state": "failed"}, {})
        self.assertFalse(row["accepted"])
        self.assertTrue(row["technical_failure"])
        self.assertIsNone(row["actual"])

    def test_correct_label_alone_cannot_pass_without_decisive_clause(self):
        case, report, records = self.report()
        self.assertTrue(h.grade(case, report, records)["accepted"])
        report["result"]["issues"][0]["citations"].pop()
        row = h.grade(case, report, records)
        self.assertTrue(row["checks"]["status"])
        self.assertFalse(row["checks"]["decisive_clauses"])
        self.assertFalse(row["accepted"])

    def test_exact_quote_must_be_bound_to_verified_complete_source(self):
        for field, value in [("source_hash_verified", False), ("section_text_complete", False)]:
            case, report, records = self.report()
            report["packages"][0]["evidence"][0][field] = value
            with self.assertRaisesRegex(ValueError, "Citation differs"):
                h.grade(case, report, records)
        case, report, records = self.report()
        report["result"]["issues"][0]["citations"][0]["start"] += 1
        with self.assertRaisesRegex(ValueError, "Citation differs"):
            h.grade(case, report, records)

    def test_missing_premise_or_new_unresolved_issue_cannot_pass_on_label(self):
        for mutation in ("premise", "gap", "additional_issue"):
            case, report, records = self.report()
            if mutation == "premise":
                report["result"]["issues"][0]["fact_ids"] = []
            elif mutation == "gap":
                report["result"]["missing_information"] = ["A material fact is missing"]
            else:
                extra = copy.deepcopy(report["result"]["issues"][0])
                extra["status"] = "unresolved"
                report["result"]["issues"].append(extra)
            self.assertFalse(h.grade(case, report, records)["accepted"])

    def test_changed_oracle_projection_or_prepared_case_rejected_before_grading(self):
        suite, records = h.load()
        frozen = {"suite_hash": h.fingerprint(suite),
                  "packet_hash": h.fingerprint([h.packet(c) for c in suite["cases"]]),
                  "cases": [{"case_id": c["id"]} for c in suite["cases"]]}
        for field, value in [("suite_hash", "changed"), ("packet_hash", "changed"), ("cases", [])]:
            modified = copy.deepcopy(frozen)
            modified[field] = value
            with self.assertRaisesRegex(ValueError, "Frozen|Prepared"):
                h.summarize(suite, {"freeze": modified, "cases": []}, records)

    def test_consent_and_source_must_match_freeze_even_when_label_is_correct(self):
        suite, journal, records = self.journal()
        self.assertTrue(h.summarize(suite, journal, records)["all_checks_passed"])
        for field in ("input_hash", "contract_hash", "config_hash", "source_revision"):
            changed = copy.deepcopy(journal)
            changed["cases"][0]["consent"][field] = "changed"
            with self.assertRaisesRegex(ValueError, "Consent differs"):
                h.summarize(suite, changed, records)
        changed = copy.deepcopy(journal)
        changed["cases"][0]["report"]["source"]["config_hash"] = "changed"
        with self.assertRaisesRegex(ValueError, "source revision"):
            h.summarize(suite, changed, records)

    def test_missing_usage_or_funded_phase_is_not_success_shaped_accounting(self):
        suite, journal, records = self.journal()
        changed = copy.deepcopy(journal)
        changed["cases"][0]["report"]["phases"][0]["usage"] = {}
        with self.assertRaisesRegex(ValueError, "token accounting"):
            h.summarize(suite, changed, records)
        changed = copy.deepcopy(journal)
        changed["cases"][0]["report"]["phases"].pop()
        with self.assertRaisesRegex(ValueError, "both actual funded phases"):
            h.summarize(suite, changed, records)

    def test_oracle_in_locator_input_is_rejected(self):
        suite, journal, records = self.journal()
        journal["cases"][0]["report"]["phases"][0]["input"]["oracle"] = suite["cases"][0]["oracle"]
        with self.assertRaisesRegex(ValueError, "Locator received labels"):
            h.summarize(suite, journal, records)

    def test_remote_endpoint_rejected(self):
        with patch.object(h, "load") as load:
            with self.assertRaises(ValueError):
                h.main(["--prepare", "--base", "https://example.invalid"])
        load.assert_not_called()


if __name__ == "__main__":
    unittest.main()
