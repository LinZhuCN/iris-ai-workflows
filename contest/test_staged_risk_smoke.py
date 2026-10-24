import copy
import json
import unittest
from unittest.mock import patch

import staged_risk_smoke as smoke
import staged_risk_evaluation_test as evaluation


class StagedRiskSmokeTests(unittest.TestCase):
    def test_v4_report_support_does_not_invent_a_frozen_smoke_profile(self):
        suite, _, freeze = smoke.load()
        packet = suite["cases"][0]["packet"]
        report = {"version": "staged-risk-v4", "authorization": {}, "packet": packet,
                  "state": "failed", "phases": [], "reserved_model_requests": 0, "execution": "evaluation_only"}
        evaluation.verify_report(report, packet, {}, "staged-risk-v4")
        with self.assertRaises(ValueError):
            evaluation.command(packet, {}, "staged-risk-v4")
        with self.assertRaises(ValueError):
            smoke.runtime_freeze(freeze, "staged-risk-v4")

    def test_frozen_six_cases_and_independent_expectations(self):
        suite, expectations, freeze = smoke.load()
        self.assertEqual(len(suite["cases"]), 6)
        self.assertEqual(freeze["maximum_proposed_model_requests"], 12)
        self.assertEqual({c["id"] for c in expectations["cases"]},
                         {c["id"] for c in suite["cases"]})

    def test_locator_input_excludes_scope_and_expected_labels(self):
        suite, _, _ = smoke.load()
        for case in suite["cases"]:
            view = smoke.locate_input(case["packet"])
            self.assertEqual(set(view), {"synthetic", "stage", "facts"})
            self.assertNotIn("required_questions", view)
            self.assertNotIn("status", view)
            self.assertNotIn(case["id"], smoke.canonical(view))

    def test_raw_localization_is_not_rescued_by_mandatory_merge(self):
        _, expectations, _ = smoke.load()
        expected = expectations["cases"][0]
        self.assertFalse(smoke.localization_checks({"questions": []}, expected)["topic_found"])
        wrong = {"questions": [{"topic": expected["topic"], "fact_ids": ["f2"],
                                "question": "A plausible but irrelevant question."}]}
        self.assertTrue(smoke.localization_checks(wrong, expected)["topic_found"])
        self.assertFalse(smoke.localization_checks(wrong, expected)["fact_coverage"])
        correct = copy.deepcopy(wrong)
        correct["questions"][0]["fact_ids"] = ["f1"]
        self.assertTrue(smoke.localization_checks(correct, expected)["fact_coverage"])

    def test_snapshot_hash_and_text_both_required(self):
        suite, _, freeze = smoke.load()
        records = smoke.source_records(freeze)
        record = records["45 CFR 164.514"]
        entry = {"metadata": record, "text": record["text"],
                 "source_hash_verified": True, "section_text_complete": True}
        smoke.verify_source(entry, records)
        changed = copy.deepcopy(entry)
        changed["text"] += " changed"
        with self.assertRaises(ValueError):
            smoke.verify_source(changed, records)
        changed = copy.deepcopy(entry)
        changed["source_hash_verified"] = False
        with self.assertRaises(ValueError):
            smoke.verify_source(changed, records)
        self.assertTrue(suite["cases"])

    def test_suite_mutation_breaks_freeze(self):
        suite, expected, freeze = smoke.load()
        suite["cases"][0]["packet"]["facts"][0]["text"] += " changed"
        with self.assertRaises(ValueError):
            smoke.verify_freeze(suite, expected, freeze)

    def test_author_checks_do_not_claim_human_acceptance(self):
        _, expected, _ = smoke.load()
        self.assertEqual(expected["review_status"],
                         "author_draft_requires_independent_human_review")
        self.assertTrue(all(c["human_checks"] for c in expected["cases"]))

    def test_technical_failure_is_not_a_negative_judgment(self):
        _, expectations, _ = smoke.load()
        expected = expectations["cases"][0]
        checks = smoke.report_checks({"state": "failed", "plan": {"questions": []}}, expected)
        self.assertIsNone(checks["judgment"])
        self.assertFalse(checks["localization"]["topic_found"])
        with self.assertRaises(ValueError):
            smoke.report_checks({"state": "failed", "result": {}}, expected)

    def test_malformed_raw_locator_remains_a_failure_not_a_grader_crash(self):
        _, expectations, _ = smoke.load()
        expected = expectations["cases"][4]
        for plan in ([], [{"topic": "deidentification", "fact_ids": ["f1"]}],
                     {"questions": None}, {"questions": [3]}):
            checks = smoke.report_checks({"state": "failed", "plan": plan}, expected)
            self.assertFalse(checks["localization"]["shape_valid"])
            self.assertFalse(checks["localization"]["topic_found"])
            self.assertIsNone(checks["judgment"])

    def test_accepted_judgment_does_not_erase_localization_miss(self):
        _, expectations, _ = smoke.load()
        expected = expectations["cases"][0]
        report = {"state": "completed", "plan": {"questions": []},
                  "questions": [{"id": "q1", "topic": "recipient_purpose"}],
                  "result": {"issues": [{"question_id": "q1", "status": "risk_signal",
                                         "fact_ids": ["f1"]}],
                             "summary": {"unresolved": True,
                                         "recommended_action": "manual_review"}}}
        checks = smoke.report_checks(report, expected)
        self.assertFalse(checks["localization"]["topic_found"])
        self.assertTrue(checks["judgment"]["status_matches_author"])
        self.assertEqual(checks["independent_semantic_review"], "pending")

    def test_execution_command_contains_only_packet_and_exact_consent(self):
        suite, _, _ = smoke.load()
        packet, consent = suite["cases"][0]["packet"], {"request_key": "unit-only"}
        code = evaluation.command(packet, consent)
        self.assertIn("##class(Contest.RiskReview).Run(packet,consent)", code)
        self.assertNotIn("risk_signal", code)
        self.assertNotIn("smoke-01", code)
        self.assertNotIn("human_checks", code)
        self.assertNotIn("Retry", code)
        self.assertIn(json.dumps(consent, separators=(",", ":")).replace('"', '""'), code)

    def test_report_checks_enforce_actual_sessions_order_and_budget(self):
        suite, _, _ = smoke.load()
        packet = suite["cases"][0]["packet"]
        consent = {"request_key": "unit-only"}
        report = {"authorization": consent, "packet": packet, "state": "failed",
                  "version": "staged-risk-v1",
                  "reserved_model_requests": 1, "execution": "evaluation_only",
                  "phases": [{"phase": "locate", "agent_session": 1,
                              "input": smoke.locate_input(packet)}]}
        evaluation.verify_report(report, packet, consent)
        for field, value in (("reserved_model_requests", 3), ("execution", "execute"),
                             ("version", "staged-risk-v2")):
            bad = copy.deepcopy(report)
            bad[field] = value
            with self.assertRaises(ValueError):
                evaluation.verify_report(bad, packet, consent)
        for field, value in (("fixture", True), ("phase", "judge"), ("agent_session", "")):
            bad = copy.deepcopy(report)
            bad["phases"][0][field] = value
            with self.assertRaises(ValueError):
                evaluation.verify_report(bad, packet, consent)

    def test_runtime_opt_in_preserves_v1_freeze_and_separates_preparation(self):
        _, _, freeze = smoke.load()
        original = copy.deepcopy(freeze)
        v1, v2 = smoke.runtime_freeze(freeze, "staged-risk-v1"), smoke.runtime_freeze(freeze, "staged-risk-v2")
        self.assertEqual(freeze, original)
        self.assertEqual(v1, freeze)
        self.assertNotEqual(v1["contract_hash"], v2["contract_hash"])
        for field in ("source", "source_agent_id", "suite_fingerprint", "expectations_fingerprint"):
            self.assertEqual(v1[field], v2[field])
        self.assertNotEqual(smoke.prepared_path("staged-risk-v1"),
                            smoke.prepared_path("staged-risk-v2"))
        self.assertFalse(v2["model_execution_authorized"])

    def test_runtime_selection_never_accepts_arbitrary_class_source(self):
        for invalid in ("Contest.Other", 'x") Write "bad', "staged-risk-v4"):
            with self.assertRaises(ValueError):
                evaluation.command({}, {}, invalid)
        self.assertIn("##class(Contest.RiskReviewV2).Run(packet,consent)",
                      evaluation.command({}, {}, "staged-risk-v2"))
        _, _, freeze = smoke.load()
        with patch.object(smoke.Path, "read_text", return_value=json.dumps({
                "schema_version": 1, "runtime_version": "staged-risk-v2",
                "base_contract_hash": "changed"})):
            with self.assertRaises((ValueError, KeyError)):
                smoke.runtime_freeze(freeze, "staged-risk-v2")

    def test_judge_only_profile_is_independent_and_defaults_stay_v1(self):
        _, _, freeze = smoke.load()
        v2 = smoke.runtime_freeze(freeze, "staged-risk-v2")
        v3 = smoke.runtime_freeze(freeze, "staged-risk-v3")
        self.assertEqual(v3["runtime_version"], "staged-risk-v3")
        self.assertNotIn(v3["contract_hash"], {freeze["contract_hash"], v2["contract_hash"]})
        for key in freeze:
            if key != "contract_hash":
                self.assertEqual(v3[key], freeze[key])
        self.assertEqual(len({smoke.prepared_path(v) for v in smoke.RUNTIMES}), 3)
        self.assertIn("##class(Contest.RiskReviewV3).Run(packet,consent)",
                      evaluation.command({}, {}, "staged-risk-v3"))
        self.assertIn("##class(Contest.RiskReview).Run(packet,consent)",
                      evaluation.command({}, {}))
        profile = json.loads((smoke.FIXTURES / "staged-risk-profile-v3.json").read_text())
        self.assertEqual(profile["base_contract_hash"], v2["contract_hash"])
        self.assertEqual(profile["change"], "judge_prompt_only")

    def test_existing_journal_is_never_automatically_rerun(self):
        suite, expected, freeze = smoke.load()
        with patch.object(evaluation.Path, "exists", return_value=True), \
                patch.object(evaluation.subprocess, "run") as process:
            with self.assertRaises(ValueError):
                evaluation.run(suite, expected, freeze, "unit-existing", {"cases": []})
            process.assert_not_called()

    def test_unconfirmed_prior_attempt_prevents_continuation(self):
        suite, expected, freeze = smoke.load()
        with patch.object(evaluation.Path, "exists", return_value=False), \
                patch.object(evaluation.subprocess, "run") as process:
            with self.assertRaises(ValueError):
                evaluation.run(suite, expected, freeze, "unit-absent", {"cases": []}, True)
            process.assert_not_called()


if __name__ == "__main__":
    unittest.main()
