import copy
import json
from pathlib import Path
import unittest

import business_privacy as benchmark


class BusinessPrivacyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.suite, cls.records = benchmark.load()

    def treatment(self):
        case = self.suite["cases"][0]
        evidence = []
        citations = []
        for i, section in enumerate(case["required_sections"]):
            record = next(r for r in self.records.values() if r["source_locator"] == section
                          and r["kind"] == "regulation_snapshot")
            anchor = next(a["anchor"] for a in case["oracle"]["authorities"] if a["section"] == section)
            evidence.append({"id": f"evidence-{i}", "record_id": record["id"], "text": anchor})
            citations.append({"evidence_id": f"evidence-{i}", "quote": anchor})
        response = {
            "assessment": "no_finding", "recommended_action": "continue_under_existing_controls",
            "reason": "Only the described treatment disclosure is assessed; other controls still apply.",
            "findings": [{"fact_ids": case["oracle"]["critical_fact_ids"],
                          "explanation": "Treatment disclosure and minimum-necessary exception require context.",
                          "citations": citations}],
            "missing_information": [],
        }
        return case, evidence, response

    def test_manifest_has_ten_business_cases_and_two_controls(self):
        result = benchmark.verify(self.suite, self.records)
        self.assertEqual(result["business_cases"], 10)
        self.assertEqual(result["control_cases"], 2)
        self.assertEqual(result["status"], "prepared_not_evaluated")
        self.assertEqual(len({c["case_id"] for c in self.suite["cases"]}), 12)

    def test_model_context_never_contains_oracle_or_answer_flags(self):
        for case in self.suite["cases"]:
            context = benchmark.context(case)
            self.assertEqual(set(context), {"case_id", "stage", "synthetic", "facts"})
            self.assertEqual(context["case_id"], case["case_id"])
            self.assertNotIn("id", context)
            for fact in context["facts"]:
                self.assertEqual(set(fact), {"id", "text"})
            for forbidden in ("oracle", "expected", "required_sections", "direct_identifiers",
                              "deidentification_verified"):
                self.assertNotIn(forbidden, context)

    def test_runtime_bundle_and_report_cannot_supply_or_hide_answers(self):
        raw, digest = benchmark.runtime_inputs(self.suite)
        bundle = json.loads(raw)
        self.assertEqual(digest, benchmark.knowledge.digest(raw.encode()))
        self.assertEqual(len(bundle["cases"]), 12)
        self.assertNotIn("oracle", raw)
        self.assertNotIn("required_sections", raw)
        case, evidence, response = self.treatment()
        report = {"case_id": case["case_id"], "state": "failed", "result": response,
                  "evidence": evidence, "tools": [], "agent_session": "unit"}
        checked = benchmark.grade_runtime_case(case, report, self.records)
        self.assertFalse(checked["oracle_alignment"], "Failed runtime cases cannot be upgraded by a valid-looking result")
        report["state"] = "completed"
        self.assertFalse(benchmark.grade_runtime_case(case, report, self.records)["oracle_alignment"],
                         "Missing actual tool provenance must remain a failure")
        report.update(packet=benchmark.context(case), tools=[
            {"tool": "ReadBusinessFacts"},
            {"tool": "SearchBusinessEvidence", "query": "treatment disclosure exception",
             "response": {"availability": "available", "evidence": evidence}},
        ])
        self.assertTrue(benchmark.grade_runtime_case(case, report, self.records)["oracle_alignment"])
        report["packet"]["facts"][0]["text"] = "Mutated after evaluation"
        self.assertFalse(benchmark.grade_runtime_case(case, report, self.records)["oracle_alignment"])

    def test_authentic_quotes_and_right_label_are_not_semantic_acceptance(self):
        case, evidence, response = self.treatment()
        result = benchmark.grade(case, response, evidence, self.records)
        self.assertTrue(result["structural_pass"])
        self.assertTrue(result["oracle_alignment"])
        self.assertTrue(result["human_review_required"])
        self.assertEqual(result["hipaa_risk_validation"], "not_completed")
        self.assertTrue(result["review_rubric"]["must_explain"])

    def test_historical_wrong_section_and_fabricated_quote_fail(self):
        case, evidence, response = self.treatment()
        variants = []
        changed = copy.deepcopy(response)
        changed["findings"][0]["citations"][0]["quote"] = "HIPAA always prohibits identifiers."
        variants.append((changed, evidence))
        historical = next(r for r in self.records.values() if r["retrieval_scope"] == "historical")
        changed_evidence = copy.deepcopy(evidence)
        changed_evidence[0].update(record_id=historical["id"], text=historical["text"][:100])
        variants.append((response, changed_evidence))
        for answer, hits in variants:
            with self.subTest(answer=answer, hits=hits[0]["record_id"]):
                result = benchmark.grade(case, answer, hits, self.records)
                self.assertFalse(result["structural_pass"])
                self.assertFalse(result["oracle_alignment"])

    def test_wrong_label_missing_fact_and_section_cannot_pass(self):
        case, evidence, response = self.treatment()
        changed = copy.deepcopy(response)
        changed["assessment"] = "risk"
        self.assertFalse(benchmark.grade(case, changed, evidence, self.records)["oracle_alignment"])
        changed = copy.deepcopy(response)
        changed["findings"][0]["fact_ids"] = ["made-up"]
        self.assertFalse(benchmark.grade(case, changed, evidence, self.records)["structural_pass"])
        changed = copy.deepcopy(response)
        changed["findings"][0]["citations"] = changed["findings"][0]["citations"][:1]
        self.assertFalse(benchmark.grade(case, changed, evidence, self.records)["oracle_alignment"])

    def test_retrieval_failure_is_explicit_not_clean_or_fake_cited(self):
        case = next(c for c in self.suite["cases"] if c["id"] == "retrieval-failure")
        response = {"assessment": "insufficient_evidence", "recommended_action": "manual_review",
                    "reason": "Retrieval failed; no legal evidence can be validated.",
                    "findings": [], "missing_information": ["Applicable normative evidence"]}
        result = benchmark.grade(case, response, [], self.records)
        self.assertTrue(result["structural_pass"])
        self.assertTrue(result["oracle_alignment"])
        response["assessment"] = "no_finding"
        self.assertFalse(benchmark.grade(case, response, [], self.records)["oracle_alignment"])

    def test_bad_input_is_a_failure_not_a_default(self):
        case, evidence, response = self.treatment()
        for value in (None, [], {}, {**response, "action": "execute_sql"}):
            result = benchmark.grade(case, value, evidence, self.records)
            self.assertFalse(result["structural_pass"])
            self.assertTrue(result["errors"])
        response["assessment"] = "risk"
        self.assertFalse(benchmark.grade(case, response, evidence, self.records)["structural_pass"],
                         "Risk cannot authorize continuing under existing controls")
        with self.assertRaises(ValueError):
            benchmark.verify({**self.suite, "schema_version": 999}, self.records)
        changed = copy.deepcopy(self.suite)
        changed["cases"][0]["oracle"]["authorities"][0]["anchor"] = "not real regulation text"
        with self.assertRaises(ValueError):
            benchmark.verify(changed, self.records)

    def test_genuine_but_irrelevant_quote_still_needs_human_review(self):
        case, evidence, response = self.treatment()
        record = self.records[evidence[0]["record_id"]]
        irrelevant = "Uses or disclosures made to the individual"
        self.assertIn(irrelevant, record["text"])
        evidence[0]["text"] = irrelevant
        response["findings"][0]["citations"][0]["quote"] = irrelevant
        result = benchmark.grade(case, response, evidence, self.records)
        self.assertTrue(result["oracle_alignment"], "Structural section coverage is not semantic entailment")
        self.assertTrue(result["human_review_required"])
        self.assertEqual(result["hipaa_risk_validation"], "not_completed")


if __name__ == "__main__":
    unittest.main()
