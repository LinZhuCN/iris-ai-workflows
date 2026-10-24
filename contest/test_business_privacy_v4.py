import copy
import unittest

import business_privacy as b
import test_business_privacy_v3 as v3_tests


class BusinessPrivacyV4Tests(unittest.TestCase):
    def fixture(self):
        case, evidence, proposal = v3_tests.BusinessPrivacyV3Tests().fixture()
        for hit in evidence:
            hit["metadata"] = {k: v for k, v in b.load()[1][hit["record_id"]].items() if k != "text"}
        section = "45 CFR 164.506"
        components = [
            {"tool": "SearchBusinessEvidence", "query": "Treatment", "parent_tool": "GatherBusinessEvidence",
             "response": {"availability": "available", "evidence": evidence}},
            {"tool": "LookupBusinessClause", "section": section, "anchor": "",
             "parent_tool": "GatherBusinessEvidence", "response": {
                 "availability": "unavailable", "evidence": [], "section": section, "anchor": "",
                 "error": "Explicit development unavailable fixture"}},
        ]
        response = b.business_bundle_response(components)
        packet = b.context(case)
        item = {"case_id": case["case_id"], "packet": packet, "state": "completed",
                "model_input": {"runId": "development-v4", "facts": packet},
                "agent_session": "development-not-a-model-run", "proposal": proposal,
                "result": b.resolve_business_v3(proposal, packet, evidence), "evidence": evidence,
                "tools": [{"tool": "ReadBusinessFacts", "origin": "server_prefill"}, *components, {
                    "tool": "GatherBusinessEvidence", "runId": "development-v4", "query": "Treatment",
                    "section": section, "anchor": "", "secondSection": "", "secondAnchor": "",
                    "response": response, "model_response": b.business_model_view(response)}]}
        return case, item

    def test_bundle_preserves_errors_evidence_and_does_not_duplicate_model_text(self):
        case, item = self.fixture()
        before = copy.deepcopy(item)
        grade = b.grade_runtime_case(case, item, b.load()[1], "hipaa-business-runtime-v4")
        self.assertTrue(grade["structural_pass"], grade["errors"])
        self.assertEqual(item, before)
        view = item["tools"][-1]["model_response"]
        self.assertIn("error", view["steps"][1])
        self.assertNotIn("evidence", view["steps"][0])
        self.assertEqual(grade["coverage_version"], "claim-and-condition-v1")

    def test_v4_requires_actual_bundle_and_exact_initial_facts(self):
        case, original = self.fixture()
        for mutation in ("missing_bundle", "missing_clause", "changed_view", "changed_input", "extra_bundle",
                         "changed_component", "wrong_parent", "failed", "reordered", "changed_plan"):
            item = copy.deepcopy(original)
            if mutation == "missing_bundle":
                item["tools"].pop()
            elif mutation == "missing_clause":
                del item["tools"][2]
            elif mutation == "changed_view":
                item["tools"][-1]["model_response"]["steps"][1]["error"] = "Silent clean fallback"
            elif mutation == "changed_input":
                item["model_input"]["facts"]["facts"][0]["text"] = "Changed bound facts"
            elif mutation == "extra_bundle":
                item["tools"].append(copy.deepcopy(item["tools"][-1]))
            elif mutation == "changed_component":
                item["tools"][1]["response"]["evidence"][0]["text"] = "Changed canonical text"
            elif mutation == "wrong_parent":
                item["tools"][1]["parent_tool"] = "AnotherTool"
            elif mutation == "reordered":
                item["tools"][0], item["tools"][1] = item["tools"][1], item["tools"][0]
            elif mutation == "changed_plan":
                item["tools"][-1]["section"] = "45 CFR 164.402"
            else:
                item["state"] = "failed"
            with self.subTest(mutation=mutation):
                result = b.grade_runtime_case(case, item, b.load()[1], "hipaa-business-runtime-v4")
                self.assertFalse(result["structural_pass"])
                self.assertFalse(result["action_policy"]["conforms"])

    def test_two_distinct_sections_and_plan_bounds(self):
        case, item = self.fixture()
        second = {"tool": "LookupBusinessClause", "section": "45 CFR 164.502", "anchor": "",
                  "parent_tool": "GatherBusinessEvidence", "response": {
                      "availability": "unavailable", "evidence": [], "section": "45 CFR 164.502", "anchor": "",
                      "error": "Explicit development unavailable fixture"}}
        item["tools"].insert(-1, second)
        bundle = item["tools"][-1]
        bundle["secondSection"] = "45 CFR 164.502"
        bundle["response"] = b.business_bundle_response(item["tools"][1:-1])
        bundle["model_response"] = b.business_model_view(bundle["response"])
        self.assertTrue(b.grade_runtime_case(case, item, b.load()[1], "hipaa-business-runtime-v4")["structural_pass"])
        for change in ({"query": "x" * 601}, {"secondSection": bundle["section"]},
                       {"secondSection": ""}, {"secondAnchor": "x" * 161}, {"section": "arbitrary SQL"}):
            altered = copy.deepcopy(item)
            altered["tools"][-1].update(change)
            with self.subTest(change=change):
                self.assertFalse(b.grade_runtime_case(case, altered, b.load()[1],
                                                     "hipaa-business-runtime-v4")["structural_pass"])

    def test_no_evidence_control_preserves_unavailability(self):
        _, item = self.fixture()
        case = next(c for c in b.load()[0]["cases"] if c["case_id"] == "business-11")
        packet = b.context(case)
        item.update(case_id=case["case_id"], packet=packet, evidence=[])
        item["model_input"]["facts"] = packet
        item["proposal"] = {"assessment": "insufficient_evidence", "recommended_action": "manual_review",
                            "reason": "Development outage control.", "findings": [], "claims": [],
                            "missing_information": ["Normative evidence unavailable"]}
        item["result"] = b.resolve_business_v3(item["proposal"], packet, [])
        item["tools"][1]["response"] = {"availability": "unavailable", "evidence": [],
                                         "error": "Explicit synthetic outage control"}
        bundle = item["tools"][-1]
        bundle["response"] = b.business_bundle_response(item["tools"][1:-1])
        bundle["model_response"] = b.business_model_view(bundle["response"])
        checked = b.grade_runtime_case(case, item, b.load()[1], "hipaa-business-runtime-v4")
        self.assertTrue(checked["structural_pass"], checked["errors"])
        self.assertTrue(checked["oracle_alignment"])

    def test_declared_bounded_failure_can_coexist_with_unknown_legal_basis(self):
        # Contract fixture only: neither factual entailment nor model quality is tested here.
        case, item = self.fixture()
        proposal = item["proposal"]
        failure = proposal["findings"][0]
        failure.update(condition="Observed routing/control condition", condition_status="not_met",
                       explanation="A narrowly declared affirmative failure, not a verdict about every permission.")
        unknown = copy.deepcopy(failure)
        unknown.update(condition="Separate disclosure basis", condition_status="unknown", affirmative_fact_ids=[],
                       exceptions={"status": "unresolved", "explanation": "The legal basis needs human verification."})
        proposal["findings"].append(unknown)
        proposal.update(assessment="risk", recommended_action="manual_review",
                        missing_information=["Disclosure basis and later obligations"])
        resolved = b.resolve_business_v3(proposal, b.context(case), item["evidence"])
        self.assertEqual([f["condition_status"] for f in resolved["findings"]], ["not_met", "unknown"])
        self.assertEqual(resolved["assessment"], "risk")
