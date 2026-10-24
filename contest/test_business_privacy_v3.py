import copy
import json
import unittest

import business_privacy as b
import test_business_privacy_v2 as v2_tests


class BusinessPrivacyV3Tests(unittest.TestCase):
    def fixture(self):
        old = v2_tests.BusinessPrivacyV2Tests()
        old.setUpClass()
        case, evidence, base = old.fixture()
        finding = base["findings"][0]
        finding.pop("evidence_status")
        finding.update(applicability="applicable", applicability_fact_ids=finding["fact_ids"][:],
                       condition_status="met", affirmative_fact_ids=finding["fact_ids"][:],
                       exceptions={"status": "resolved", "explanation": "The described treatment exception was considered."})
        base["claims"] = []
        return case, evidence, base

    def test_claim_warning_does_not_become_condition_failure(self):
        case, evidence, proposal = self.fixture()
        f = proposal["findings"][0]
        proposal["claims"] = [{"fact_ids": f["fact_ids"][:], "status": "contradicted",
                               "explanation": "A claim conflicts with the dated evidence, not proof of missing controls.",
                               "citations": copy.deepcopy(f["citations"])}]
        f.update(condition_status="unknown", affirmative_fact_ids=[])
        proposal.update(assessment="insufficient_evidence", recommended_action="manual_review",
                        missing_information=["Whether the applicable arrangement actually exists and is valid"])
        result = b.resolve_business_v3(proposal, b.context(case), evidence)
        self.assertEqual(result["claims"][0]["status"], "contradicted")
        self.assertEqual(result["assessment"], "insufficient_evidence")
        proposal["assessment"] = "risk"
        with self.assertRaises(ValueError):
            b.resolve_business_v3(proposal, b.context(case), evidence)

    def test_document_counterfactuals_and_actions(self):
        # Developer-authored development pairs, not model judgments or a held-out/legal evaluation.
        for state, assessment in [("unknown", "insufficient_evidence"), ("not_met", "risk"), ("met", "no_finding")]:
            for stage in ["before_send", "after_send"]:
                case, evidence, p = self.fixture()
                packet = b.context(case)
                packet["stage"] = stage
                packet["facts"] = [{"id": "document", "text": {
                    "unknown": "The agreement has not been supplied; existence is not checked.",
                    "not_met": "An authorized reviewer confirmed no required agreement exists, and no alternative applies.",
                    "met": "An authorized reviewer verified the required agreement and applicable conditions.",
                }[state]}]
                f = p["findings"][0]
                f.update(fact_ids=["document"], applicability_fact_ids=["document"],
                         affirmative_fact_ids=[] if state == "unknown" else ["document"], condition_status=state)
                p.update(assessment=assessment, recommended_action="continue_under_existing_controls" if state == "met"
                         else "hold_for_review" if stage == "before_send" else "manual_review",
                         missing_information=["Agreement verification"] if state == "unknown" else [])
                with self.subTest(state=state, stage=stage):
                    result = b.resolve_business_v3(p, packet, evidence)
                    self.assertEqual(result["assessment"], assessment)
                    if stage == "after_send":
                        p["recommended_action"] = "hold_for_review"
                        with self.assertRaises(ValueError):
                            b.resolve_business_v3(p, packet, evidence)

    def test_incomplete_chain_and_exceptions_cannot_support_clean_or_risk(self):
        case, evidence, p = self.fixture()
        for change in [
            {"affirmative_fact_ids": []}, {"applicability_fact_ids": []},
            {"affirmative_fact_ids": ["invented"]},
            {"exceptions": {"status": "unresolved", "explanation": "An alternate basis is unverified."}},
            {"applicability": "unknown"}, {"condition_status": "not_met"},
            {"extra": "silently remove me"},
        ]:
            changed = copy.deepcopy(p)
            changed["findings"][0].update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                b.resolve_business_v3(changed, b.context(case), evidence)
        p["findings"][0].update(applicability="unknown", condition_status="unknown", affirmative_fact_ids=[],
                               applicability_fact_ids=[])
        p.update(assessment="insufficient_evidence", recommended_action="manual_review",
                 missing_information=["Applicability and alternative basis"])
        b.resolve_business_v3(p, b.context(case), evidence)

    def test_projection_is_compact_lossless_for_selected_passages_and_nonmutating(self):
        _, evidence, _ = self.fixture()
        for h in evidence:
            h["metadata"] = {"source_locator": "45 CFR 164.506", "source_url": "https://example.invalid/source",
                             "kind": "regulation_snapshot", "source_version": "dated",
                             "legal_status": "snapshot_not_independently_verified", "content_sha256": "audit-only"}
        raw = {"availability": "available", "evidence": evidence, "truncated": True}
        original = copy.deepcopy(raw)
        compact = b.business_model_view(raw)
        self.assertEqual(raw, original)
        self.assertLess(len(json.dumps(compact)), len(json.dumps(raw)))
        for canonical, model in zip(evidence, compact["evidence"]):
            self.assertNotIn("text", model)
            self.assertNotIn("metadata", model)
            self.assertEqual([(p["id"], p["text"]) for p in canonical["passages"]],
                             [(p["id"], p["text"]) for p in model["passages"]])
            self.assertTrue(model["partial_context"])
        self.assertTrue(compact["truncated"])

    def test_no_evidence_and_unverified_claims_are_not_clean(self):
        case, evidence, p = self.fixture()
        p.update(assessment="insufficient_evidence", recommended_action="manual_review",
                 findings=[], missing_information=["Normative source"])
        self.assertEqual(b.resolve_business_v3(p, b.context(case), []), p)
        p["claims"] = [{"fact_ids": ["purpose"], "status": "unverified",
                        "explanation": "No evidence", "citations": []}]
        with self.assertRaises(ValueError):
            b.resolve_business_v3(p, b.context(case), [])

    def test_semantic_truth_still_requires_review(self):
        case, evidence, p = self.fixture()
        # The validator checks a declared chain, not whether a fact truly entails the legal conclusion.
        p["findings"][0]["condition_status"] = "not_met"
        p.update(assessment="risk", recommended_action="manual_review")
        result = b.resolve_business_v3(p, b.context(case), evidence)
        self.assertEqual(result["assessment"], "risk")

    def test_runtime_projection_provenance_and_action_policy_are_separate(self):
        case, evidence, proposal = self.fixture()
        proposal.update(assessment="insufficient_evidence", recommended_action="hold_for_review",
                        missing_information=["Agreement verification"])
        proposal["findings"][0].update(condition_status="unknown", affirmative_fact_ids=[])
        for hit in evidence:
            hit["metadata"] = {k: v for k, v in b.load()[1][hit["record_id"]].items() if k != "text"}
        response = {"availability": "available", "evidence": evidence}
        item = {"case_id": case["case_id"], "packet": b.context(case), "state": "completed",
                "agent_session": "development-fixture-not-a-model-run", "proposal": proposal,
                "result": b.resolve_business_v3(proposal, b.context(case), evidence), "evidence": evidence,
                "tools": [{"tool": "ReadBusinessFacts"}, {"tool": "LookupBusinessClause", "response": response,
                                                       "model_response": b.business_model_view(response)}]}
        result = b.grade_runtime_case(case, item, b.load()[1], "hipaa-business-runtime-v3")
        self.assertTrue(result["structural_pass"])
        self.assertFalse(result["oracle_alignment"], "Do not change historical exact expectations")
        self.assertTrue(result["action_policy"]["conforms"], "A stage-permitted hold is a separate policy result")
        self.assertEqual(result["action_policy"]["version"], "stage-conservative-v1")
        altered = copy.deepcopy(item)
        altered["evidence"][0]["metadata"]["title"] = "Changed canonical audit metadata"
        self.assertFalse(b.grade_runtime_case(case, altered, b.load()[1], "hipaa-business-runtime-v3")["checks"]["runtime_provenance"])
        altered = copy.deepcopy(item)
        altered["state"] = "failed"
        self.assertFalse(b.grade_runtime_case(case, altered, b.load()[1], "hipaa-business-runtime-v3")["action_policy"]["conforms"])
        item["tools"][1]["model_response"]["evidence"][0]["passages"][0]["text"] = "Not what the source returned"
        result = b.grade_runtime_case(case, item, b.load()[1], "hipaa-business-runtime-v3")
        self.assertFalse(result["structural_pass"])
        self.assertFalse(result["action_policy"]["conforms"])

    def test_unverified_claim_and_inapplicable_condition_have_explicit_states(self):
        case, evidence, proposal = self.fixture()
        f = proposal["findings"][0]
        proposal["claims"] = [{"fact_ids": f["fact_ids"][:], "status": "unverified",
                               "explanation": "The operator claim is not established.",
                               "citations": copy.deepcopy(f["citations"])}]
        proposal.update(assessment="insufficient_evidence", recommended_action="manual_review",
                        missing_information=["Claim verification"])
        self.assertEqual(b.resolve_business_v3(proposal, b.context(case), evidence)["assessment"], "insufficient_evidence")
        proposal["claims"] = []
        proposal.update(assessment="no_finding", missing_information=[])
        f.update(applicability="not_applicable", condition_status="not_applicable", affirmative_fact_ids=[])
        self.assertEqual(b.resolve_business_v3(proposal, b.context(case), evidence)["findings"][0]["condition_status"],
                         "not_applicable")

    def test_runtime_grade_accepts_separate_ten_condition_and_claim_limits(self):
        case, evidence, proposal = self.fixture()
        proposal["findings"] *= 10
        finding = proposal["findings"][0]
        proposal["claims"] = [{"fact_ids": finding["fact_ids"][:], "status": "supported",
                               "explanation": "Development source check.", "citations": copy.deepcopy(finding["citations"])}
                              for _ in range(10)]
        for hit in evidence:
            hit["metadata"] = {k: v for k, v in b.load()[1][hit["record_id"]].items() if k != "text"}
        response = {"availability": "available", "evidence": evidence}
        item = {"case_id": case["case_id"], "packet": b.context(case), "state": "completed",
                "agent_session": "development-not-model", "proposal": proposal,
                "result": b.resolve_business_v3(proposal, b.context(case), evidence), "evidence": evidence,
                "tools": [{"tool": "ReadBusinessFacts"}, {"tool": "LookupBusinessClause", "response": response,
                                                       "model_response": b.business_model_view(response)}]}
        self.assertTrue(b.grade_runtime_case(case, item, b.load()[1], "hipaa-business-runtime-v3")["structural_pass"])
