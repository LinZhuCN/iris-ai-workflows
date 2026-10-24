import copy
import unittest
from unittest.mock import patch

import declaration_acceptance_test as acceptance


def report_fixture():
    return {
        "authorization": {"acknowledge_cost": True, "max_model_requests": 2},
        "phases": [
            {"agent_session": "1", "sdk_stats": {"total_interactions": 1, "total_tool_calls": 0,
                                               "total_prompt_tokens": 10, "total_completion_tokens": 3}},
            {"agent_session": "2", "sdk_stats": {"total_interactions": 1, "total_tool_calls": 0,
                                               "total_prompt_tokens": 20, "total_completion_tokens": 4}},
        ],
        "packages": [{"question_id": "q1", "evidence": [{"id": "section", "source_hash_verified": True, "text": "A rule."}]}],
    }


class DeclarationAcceptanceTests(unittest.TestCase):
    def test_default_is_inactive(self):
        with patch.object(acceptance, "admin_request") as http:
            acceptance.main([])
            http.assert_not_called()

    def test_remote_base_rejected_before_credentials(self):
        with patch.object(acceptance, "admin_request") as http:
            with self.assertRaises(ValueError):
                acceptance.main(["--check", "--base", "https://example.invalid"])
            http.assert_not_called()

    def test_get_is_read_only_and_errors_are_not_success(self):
        with patch.object(acceptance, "admin_request", return_value=(200, {"real": True})) as http:
            self.assertEqual(acceptance.get(acceptance.BASE, "/record"), {"real": True})
            http.assert_called_once_with(acceptance.BASE, "/record")
        with patch.object(acceptance, "admin_request", return_value=(409, {"error": "changed"})):
            with self.assertRaises(ValueError):
                acceptance.get(acceptance.BASE, "/record")

    def test_pagination_accounts_for_all_versions(self):
        with patch.object(acceptance, "get", side_effect=[
            {"declaration_id": "unit", "items": [{"id": "v2"}], "has_older": True, "older_before_revision": 2},
            {"declaration_id": "unit", "items": [{"id": "v1"}], "has_older": False, "older_before_revision": 0},
        ]) as get:
            self.assertEqual(len(acceptance.history(acceptance.BASE, "unit")), 2)
            self.assertTrue(get.call_args.args[1].endswith("?before=2"))

    def test_pagination_loop_and_duplicate_versions_rejected(self):
        page = {"declaration_id": "unit", "items": [{"id": "v1"}], "has_older": True, "older_before_revision": 1}
        with patch.object(acceptance, "get", return_value=page):
            with self.assertRaisesRegex(ValueError, "cursor"):
                acceptance.history(acceptance.BASE, "unit")
        page.update(has_older=False, items=[{"id": "v1"}, {"id": "v1"}])
        with patch.object(acceptance, "get", return_value=page):
            with self.assertRaisesRegex(ValueError, "duplicate"):
                acceptance.history(acceptance.BASE, "unit")

    def test_usage_counts_real_sdk_tokens_including_failed_phases(self):
        value = report_fixture()
        value["phases"][1]["state"] = "failed"
        self.assertEqual(acceptance.usage(value), {
            "requests": 2, "prompt_tokens": 30, "completion_tokens": 7, "sessions": ["1", "2"],
        })

    def test_missing_usage_duplicate_sessions_tools_and_unfunded_calls_rejected(self):
        for variant in ("missing", "duplicate", "tool", "grant", "extra"):
            value = report_fixture()
            if variant == "missing":
                del value["phases"][1]["sdk_stats"]
            elif variant == "duplicate":
                value["phases"][1]["agent_session"] = "1"
            elif variant == "tool":
                value["phases"][1]["sdk_stats"]["total_tool_calls"] = 1
            elif variant == "grant":
                value["authorization"]["acknowledge_cost"] = False
            else:
                value["phases"].append(copy.deepcopy(value["phases"][0]))
            with self.subTest(variant=variant), self.assertRaises(ValueError):
                acceptance.usage(value)

    def test_canonical_citation_offsets_and_full_source_hash_required(self):
        result = {"issues": [{"question_id": "q1", "citations": [
            {"evidence_id": "section", "start": 2, "end": 6, "quote": "rule"},
        ]}]}
        self.assertEqual(acceptance.citations(report_fixture(), result), 1)
        result["issues"][0]["citations"][0]["end"] = 7
        with self.assertRaises(ValueError):
            acceptance.citations(report_fixture(), result)
        result["issues"][0]["citations"][0]["end"] = 6
        value = report_fixture()
        value["packages"][0]["evidence"][0]["source_hash_verified"] = False
        with self.assertRaises(ValueError):
            acceptance.citations(value, result)

    def test_empty_citations_cannot_count_as_model_acceptance(self):
        with self.assertRaises(ValueError):
            acceptance.citations(report_fixture(), {"issues": []})

    def test_unfunded_review_must_not_contain_a_finding(self):
        record = {"review": {"task": {"reserved_requests": 0, "attempted_requests": 0, "assessment": None, "result": None}}}
        self.assertIsNone(acceptance.proposal(acceptance.BASE, record))
        record["review"]["task"]["assessment"] = "no_risk_identified"
        with self.assertRaises(ValueError):
            acceptance.proposal(acceptance.BASE, record)

    def test_incomplete_browser_chain_never_passes(self):
        with self.assertRaises(ValueError):
            acceptance.walkthrough({acceptance.QUALITY: [], acceptance.MARKETING: []})


if __name__ == "__main__":
    unittest.main()
