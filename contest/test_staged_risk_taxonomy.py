import copy
import unittest
from unittest.mock import patch

import staged_risk_taxonomy as taxonomy
import staged_risk_acceptance as acceptance


class StagedRiskTaxonomyTests(unittest.TestCase):
    def test_proposal_is_not_a_new_runtime_or_legal_acceptance(self):
        proposal = taxonomy.load()
        self.assertEqual(proposal["adoption"], "not_adopted")
        self.assertEqual(len(proposal["disputes"]), 3)
        self.assertTrue(all(d["review_decision"] == "pending" for d in proposal["disputes"]))
        self.assertEqual(len(proposal["counterexamples"]), 6)

    def test_default_summary_does_not_manufacture_an_adjudication(self):
        result = taxonomy.describe(taxonomy.load())
        self.assertEqual(result["pending_decisions"], 3)
        self.assertFalse(result["changes_runtime"])
        self.assertFalse(result["independent_review_completed"])
        self.assertEqual(result["model_calls"], 0)

    def test_audit_requires_actual_full_challenge_journal(self):
        with self.assertRaises(ValueError):
            taxonomy.audit({}, taxonomy.load())

    def test_adopted_or_auto_approved_proposal_rejected(self):
        proposal = taxonomy.load()
        for key, value in (("adoption", "adopted"), ("review_status", "independently_approved")):
            changed = copy.deepcopy(proposal)
            changed[key] = value
            with self.assertRaises(ValueError):
                taxonomy.validate(changed)

    def test_pending_proposal_cannot_change_expected_scores(self):
        proposal = taxonomy.load()
        _, expected, _, freeze = acceptance.load()
        self.assertEqual(proposal["contract_hash"], freeze["contract_hash"])
        for dispute in proposal["disputes"]:
            case = next(c for c in expected["cases"] if c["id"] == dispute["case_id"])
            self.assertEqual(dispute["draft_expected_status"], case["status"])
        self.assertTrue(all(c["preferred_status"] in
                            {"risk_signal", "unresolved", "no_signal_on_checked_issue"}
                            for c in proposal["counterexamples"]))

    def test_audit_preserves_observed_labels_and_old_scores(self):
        proposal = taxonomy.load()
        _, expected, _, _ = acceptance.load()
        expected_by_id = {case["id"]: case for case in expected["cases"]}
        entries = []
        for dispute in proposal["disputes"]:
            case_id = dispute["case_id"]
            entries.append({
                "case_id": case_id, "checks": {"unchanged": case_id},
                "report": {
                    "id": case_id, "questions": [{"id": "q1", "topic": expected_by_id[case_id]["topic"]}],
                    "result": {"issues": [{"question_id": "q1", "status": dispute["observed_status"]}],
                               "missing_information": ["Material gap remains."],
                               "summary": {"unresolved": True}},
                },
            })
        analysis = {"counts": {"all_four_judgment_checks": 6}}
        journal = {"authorization": {}, "cases": entries, "analysis": analysis}
        original = copy.deepcopy(journal)
        with patch.object(taxonomy.challenge, "verify_completed_journal", return_value=analysis):
            result = taxonomy.audit(journal, proposal)
        self.assertEqual(journal, original)
        self.assertEqual(result["historical_analysis"], analysis)
        self.assertEqual([d["observed_main_issue"]["status"] for d in result["disputes"]],
                         ["risk_signal", "risk_signal", "unresolved"])
        self.assertTrue(all(d["review_proposal"]["review_decision"] == "pending"
                            for d in result["disputes"]))
        changed = copy.deepcopy(journal)
        changed["analysis"] = {"counts": {"all_four_judgment_checks": 8}}
        with patch.object(taxonomy.challenge, "verify_completed_journal", return_value=analysis):
            with self.assertRaisesRegex(ValueError, "Historical grading"):
                taxonomy.audit(changed, proposal)


if __name__ == "__main__":
    unittest.main()
