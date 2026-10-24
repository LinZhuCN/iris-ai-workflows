import unittest
import json

from multi_runtime import transform, inspect_payload, policy_mismatches


class DistributionMappingTests(unittest.TestCase):
    def setUp(self):
        self.patient = {
            "resourceType": "Patient", "id": "multi-p1",
            "identifier": [{"value": "SYNTHETIC-MRN-001"}],
            "name": [{"family": "Synthetic", "given": ["Alex"]}],
            "birthDate": "1980-04-12",
        }

    def test_three_distinct_wire_formats_and_date_precision(self):
        sql = transform("quality", "test-quality", self.patient, "identifier-leak")
        rest = transform("research", "test-research", self.patient, "identifier-leak")
        hl7 = transform("clinic", "test-clinic", self.patient, "identifier-leak")
        self.assertEqual(inspect_payload("quality", sql)["fields"], ["patient_id", "birthYear", "status"])
        self.assertIs(type(json.loads(sql)["birthYear"]), int)
        self.assertIn("name", inspect_payload("research", rest)["fields"])
        self.assertIn("birthDate", inspect_payload("clinic", hl7)["fields"])
        self.assertTrue(hl7.startswith("MSH|^~\\&|"))
        self.assertEqual(hl7.split("\r")[0].split("|")[9], "test-clinic")
        self.assertNotIn("SYNTHETIC-MRN", str(inspect_payload("clinic", hl7)))

    def test_corrected_research_variant_is_not_full_compliance_claim(self):
        wire = transform("research", "test-control", self.patient, "corrected")
        facts = inspect_payload("research", wire)
        self.assertNotIn("name", facts["fields"])
        self.assertNotIn("mrn", facts["fields"])
        self.assertEqual(facts["declaration"]["method"], "safe_harbor")
        self.assertFalse(facts["full_date"])

    def test_policy_is_separate_from_law(self):
        policy = {"allowed_fields": ["birthYear", "status"],
                  "prohibited_fields": ["name", "mrn", "birthDate"]}
        facts = inspect_payload("research", transform("research", "test-research", self.patient, "identifier-leak"))
        self.assertEqual(set(policy_mismatches(facts, policy)), {"name", "mrn", "birthDate"})
        self.assertNotIn("assessment", facts)

    def test_unknown_branch_and_malformed_hl7_rejected(self):
        with self.assertRaises(ValueError):
            transform("unknown", "test-x", self.patient, "identifier-leak")
        with self.assertRaises(ValueError):
            inspect_payload("clinic", "MSH|invalid")
        with self.assertRaises(ValueError):
            inspect_payload("research", '{"birthDate":"1980-13-40"}')
        with self.assertRaises(ValueError):
            transform("research", "../escape", self.patient, "identifier-leak")


if __name__ == "__main__":
    unittest.main()
