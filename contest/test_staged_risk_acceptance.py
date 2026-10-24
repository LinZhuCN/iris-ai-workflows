import copy
import unittest
from unittest.mock import patch

import staged_risk_acceptance as acceptance
import staged_risk_smoke as smoke
from business_privacy import fingerprint


class StagedRiskAcceptanceTests(unittest.TestCase):
    def test_new_suite_is_prospective_not_claimed_independent(self):
        suite, expected, rubric, freeze = acceptance.load()
        self.assertEqual(len(suite["cases"]), 8)
        self.assertEqual(suite["classification"],
                         "assistant_authored_prospective_not_independent_held_out")
        self.assertEqual(freeze["runtime_version"], "staged-risk-v3")
        self.assertEqual(freeze["maximum_proposed_model_requests"], 16)
        self.assertFalse(freeze["model_execution_authorized"])
        self.assertEqual(len(rubric["dimensions"]), 6)
        self.assertEqual(len(expected["cases"]), 8)

    def test_every_input_or_rubric_mutation_breaks_freeze(self):
        loaded = acceptance.load()
        for index, path in ((0, "suite"), (1, "expectations"), (2, "rubric")):
            changed = copy.deepcopy(loaded)
            changed[index]["extra"] = "modified"
            with self.assertRaisesRegex(ValueError, "fingerprint"):
                acceptance.verify(*changed)
        self.assertEqual(len({c["id"] for c in loaded[0]["cases"]}), 8)

    def test_frozen_runtime_source_changes_are_detected(self):
        with patch.object(acceptance, "file_sha256", return_value="changed"):
            with self.assertRaisesRegex(ValueError, "Runtime source"):
                acceptance.load()

    def test_locator_never_receives_oracle_or_rubric(self):
        suite, _, _, _ = acceptance.load()
        old, _, _ = smoke.load()
        old_packets = {fingerprint(c["packet"]) for c in old["cases"]}
        for case in suite["cases"]:
            view = smoke.locate_input(case["packet"])
            self.assertEqual(set(view), {"synthetic", "stage", "facts"})
            self.assertNotIn(case["id"], smoke.canonical(view))
            self.assertNotIn(fingerprint(case["packet"]), old_packets)
            self.assertNotIn("human_checks", smoke.canonical(view))

    def test_pending_worksheet_is_not_human_acceptance(self):
        suite, _, rubric, freeze = acceptance.load()
        review = acceptance.review_template(suite, rubric, freeze)
        result = acceptance.review_status(review, suite, rubric, freeze)
        self.assertEqual(result["state"], "pending")
        self.assertFalse(result["independent_validation_established"])
        self.assertFalse(result["business_deployment_authorized"])
        self.assertEqual(result["pending_dimensions"], 48)

    def test_no_outputs_means_no_automatic_or_human_pass(self):
        suite, _, rubric, freeze = acceptance.load()
        review = acceptance.review_template(suite, rubric, freeze)
        review["reviewer"] = "claimed reviewer"
        for case in review["cases"]:
            for judgment in case["dimensions"].values():
                judgment.update(verdict="pass", rationale="Plausible.", output_excerpt="Invented.")
        with self.assertRaisesRegex(ValueError, "Actual reports"):
            acceptance.review_status(review, suite, rubric, freeze)

    def test_review_mutations_and_missing_cases_are_rejected(self):
        suite, _, rubric, freeze = acceptance.load()
        for variant in ("fingerprint", "case", "dimension", "verdict"):
            review = acceptance.review_template(suite, rubric, freeze)
            if variant == "fingerprint":
                review["rubric_fingerprint"] = "changed"
            elif variant == "case":
                review["cases"].pop()
            elif variant == "dimension":
                review["cases"][0]["dimensions"].pop("data_minimization")
            else:
                review["cases"][0]["dimensions"]["data_minimization"]["verdict"] = "automatic_pass"
            with self.assertRaises(ValueError):
                acceptance.review_status(review, suite, rubric, freeze)

    def test_technical_failure_never_passes_even_with_human_marks(self):
        suite, _, rubric, freeze = acceptance.load()
        reports = self.failed_reports(suite, freeze)
        review = acceptance.review_template(suite, rubric, freeze, reports)
        review["reviewer"] = "self-attested reviewer"
        for case in review["cases"]:
            for judgment in case["dimensions"].values():
                judgment.update(verdict="pass", rationale="Reviewed example.", output_excerpt="failed")
        result = acceptance.review_status(review, suite, rubric, freeze, reports)
        self.assertEqual(result["state"], "blocked_technical_failure")
        self.assertFalse(result["independent_validation_established"])
        self.assertFalse(result["business_deployment_authorized"])

    def test_report_bound_excerpts_and_runtime_are_required(self):
        suite, _, rubric, freeze = acceptance.load()
        reports = self.failed_reports(suite, freeze)
        review = acceptance.review_template(suite, rubric, freeze, reports)
        review["reviewer"] = "self-attested reviewer"
        mark = review["cases"][0]["dimensions"]["scope_and_applicability"]
        mark.update(verdict="fail", rationale="Examined.", output_excerpt="Fabricated quotation.")
        with self.assertRaisesRegex(ValueError, "excerpt"):
            acceptance.review_status(review, suite, rubric, freeze, reports)
        reports[0]["version"] = "staged-risk-v2"
        with self.assertRaises(ValueError):
            acceptance.review_template(suite, rubric, freeze, reports)

    def test_input_facts_cannot_be_used_as_output_evidence(self):
        suite, _, rubric, freeze = acceptance.load()
        reports = self.failed_reports(suite, freeze)
        review = acceptance.review_template(suite, rubric, freeze, reports)
        review["reviewer"] = "self-attested reviewer"
        review["cases"][0]["dimensions"]["explanation_completeness"].update(
            verdict="pass", rationale="This only appears in the input.",
            output_excerpt=suite["cases"][0]["packet"]["facts"][0]["text"])
        with self.assertRaisesRegex(ValueError, "excerpt"):
            acceptance.review_status(review, suite, rubric, freeze, reports)

    def test_edited_worksheet_is_never_overwritten(self):
        with patch.object(acceptance.Path, "exists", return_value=True), \
                patch.object(acceptance, "read_json", return_value={"edited": True}), \
                patch.object(acceptance.Path, "open") as opened:
            with self.assertRaisesRegex(ValueError, "Immutable"):
                acceptance.save_immutable(acceptance.DIRECTORY / "unit.json", {"edited": False})
            opened.assert_not_called()

    def failed_reports(self, suite, freeze):
        return [{"id": case["id"], "version": "staged-risk-v3", "state": "failed",
                 "packet": case["packet"], "authorization": {"contract_hash": freeze["contract_hash"]},
                 "source": dict(freeze["source"], id=freeze["source_agent_id"]),
                 "phases": [], "reserved_model_requests": 0, "execution": "evaluation_only"}
                for case in suite["cases"]]


if __name__ == "__main__":
    unittest.main()
