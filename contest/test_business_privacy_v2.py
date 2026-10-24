import copy
import unittest

import business_privacy as benchmark


class BusinessPrivacyV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.suite, cls.records = benchmark.load()

    def fixture(self):
        case = self.suite["cases"][0]
        evidence, citations = [], []
        for i, authority in enumerate(case["oracle"]["authorities"]):
            record = next(r for r in self.records.values()
                          if r["source_locator"] == authority["section"] and r["kind"] == "regulation_snapshot")
            hit = {"id": f"evidence-{i}", "record_id": record["id"], "text": authority["anchor"]}
            hit["passages"] = benchmark.source_passages(hit["text"])
            evidence.append(hit)
            citations.append({"evidence_id": hit["id"], "passage_id": "p0"})
        proposal = {
            "assessment": "no_finding", "recommended_action": "continue_under_existing_controls",
            "reason": "Only the supplied treatment disclosure issue is assessed.",
            "findings": [{"fact_ids": case["oracle"]["critical_fact_ids"],
                          "condition": "Treatment permission and the relevant minimum-necessary exception.",
                          "evidence_status": "supported_no_finding",
                          "explanation": "Apply the provider treatment facts and the exception, not blanket compliance.",
                          "citations": citations}],
            "missing_information": [],
        }
        return case, evidence, proposal

    def test_selected_passages_materialize_without_mutating_model_output(self):
        case, evidence, proposal = self.fixture()
        original = copy.deepcopy(proposal)
        result = benchmark.resolve_business_v2(proposal, benchmark.context(case), evidence)
        self.assertEqual(proposal, original)
        quote = result["findings"][0]["citations"][0]
        self.assertEqual(quote["quote"], evidence[0]["passages"][0]["text"])
        self.assertEqual(quote["start"], 0)
        for key, value in (("quote", "model authored"), ("end", 100), ("extra", None)):
            changed = copy.deepcopy(proposal)
            changed["findings"][0]["citations"][0][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                benchmark.resolve_business_v2(changed, benchmark.context(case), evidence)

    def test_unknown_and_tampered_passages_rejected(self):
        case, evidence, proposal = self.fixture()
        changed = copy.deepcopy(proposal)
        changed["findings"][0]["citations"][0]["passage_id"] = "p999"
        with self.assertRaises(ValueError):
            benchmark.resolve_business_v2(changed, benchmark.context(case), evidence)
        evidence[0]["passages"][0]["text"] = "An invented source."
        with self.assertRaises(ValueError):
            benchmark.resolve_business_v2(proposal, benchmark.context(case), evidence)

    def test_missing_proof_risk_and_action_are_separate(self):
        case, evidence, proposal = self.fixture()
        finding = proposal["findings"][0]
        finding["evidence_status"] = "unresolved"
        proposal.update(assessment="risk", recommended_action="hold_for_review",
                        missing_information=["Verification of the claimed disclosure basis"])
        with self.assertRaises(ValueError):
            benchmark.resolve_business_v2(proposal, benchmark.context(case), evidence)
        proposal["assessment"] = "insufficient_evidence"
        result = benchmark.resolve_business_v2(proposal, benchmark.context(case), evidence)
        self.assertEqual(result["recommended_action"], "hold_for_review")
        proposal["assessment"] = "no_finding"
        with self.assertRaises(ValueError):
            benchmark.resolve_business_v2(proposal, benchmark.context(case), evidence)
        finding["evidence_status"] = "supported_risk"
        proposal["assessment"] = "risk"
        benchmark.resolve_business_v2(proposal, benchmark.context(case), evidence)
        with self.assertRaises(ValueError):
            benchmark.resolve_business_v2(proposal, {**benchmark.context(case), "stage": "after_send"}, evidence)

    def test_outage_has_no_invented_findings(self):
        case = next(c for c in self.suite["cases"] if c["id"] == "retrieval-failure")
        proposal = {"assessment": "insufficient_evidence", "recommended_action": "manual_review",
                    "reason": "No normative evidence available.", "findings": [],
                    "missing_information": ["Applicable normative evidence"]}
        self.assertEqual(benchmark.resolve_business_v2(proposal, benchmark.context(case), []), proposal)
        proposal["assessment"] = "no_finding"
        with self.assertRaises(ValueError):
            benchmark.resolve_business_v2(proposal, benchmark.context(case), [])

    def test_passages_are_bounded_contiguous_and_use_utf16_offsets(self):
        source = "A" * 799 + "\U0001f600" + "B" * 820 + "\n" + "C" * 19
        passages = benchmark.source_passages(source)
        self.assertEqual("".join(p["text"] for p in passages), source)
        self.assertEqual(passages[0]["end"], 799, "Never split a surrogate pair")
        self.assertEqual(passages[-1]["end"], len(source.encode("utf-16-le")) // 2)
        self.assertTrue(all(16 <= len(p["text"].encode("utf-16-le")) // 2 <= 815 for p in passages))
        self.assertEqual(benchmark.source_passages("No newline in this source text.")[0]["start"], 0)

    def test_v2_grader_requires_actual_clause_trace_and_untampered_resolution(self):
        case, evidence, proposal = self.fixture()
        result = benchmark.resolve_business_v2(proposal, benchmark.context(case), evidence)
        item = {"case_id": case["case_id"], "packet": benchmark.context(case), "state": "completed",
                "agent_session": "free-fixture-not-a-real-evaluation", "evidence": evidence,
                "proposal": proposal, "result": result, "tools": [
                    {"tool": "ReadBusinessFacts"},
                    {"tool": "LookupBusinessClause", "section": "45 CFR 164.506", "anchor": "",
                     "response": {"availability": "available", "evidence": evidence}},
                ]}
        grade = benchmark.grade_runtime_case(case, item, self.records, "hipaa-business-runtime-v2")
        self.assertTrue(grade["oracle_alignment"])
        self.assertTrue(grade["human_review_required"])
        self.assertEqual(grade["hipaa_risk_validation"], "not_completed")
        item["result"]["findings"][0]["citations"][0]["quote"] = "Tampered after resolution"
        self.assertFalse(benchmark.grade_runtime_case(case, item, self.records,
                                                    "hipaa-business-runtime-v2")["structural_pass"])

    def test_declared_status_does_not_prove_entailment_and_historical_is_not_normative(self):
        case, evidence, proposal = self.fixture()
        proposal["assessment"] = "risk"
        proposal["recommended_action"] = "manual_review"
        proposal["findings"][0]["evidence_status"] = "supported_risk"
        resolved = benchmark.resolve_business_v2(proposal, benchmark.context(case), evidence)
        self.assertEqual(resolved["assessment"], "risk",
                         "A schema guard cannot decide whether the model's claimed support is legally correct")
        historical = next(r for r in self.records.values() if r["retrieval_scope"] == "historical")
        evidence[0].update(record_id=historical["id"], text=historical["text"][:500])
        evidence[0]["passages"] = benchmark.source_passages(evidence[0]["text"])
        item = {"case_id": case["case_id"], "packet": benchmark.context(case), "state": "completed",
                "agent_session": "free-fixture", "proposal": proposal, "evidence": evidence, "tools": [],
                "result": benchmark.resolve_business_v2(proposal, benchmark.context(case), evidence)}
        result = benchmark.grade_runtime_case(case, item, self.records, "hipaa-business-runtime-v2")
        self.assertFalse(result["structural_pass"], "Materialized text does not make historical evidence normative")
