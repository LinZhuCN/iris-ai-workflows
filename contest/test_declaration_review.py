import contextlib
import io
import json
import unittest
from unittest.mock import patch

import declaration_review_test as review


class DeclarationReviewCLITests(unittest.TestCase):
    def test_default_is_inactive(self):
        with patch.object(review, "execute") as execute, patch.object(review, "review_three") as paid:
            review.main([])
            execute.assert_not_called()
            paid.assert_not_called()

    def test_paid_and_deployment_are_separate(self):
        with patch.object(review, "execute") as execute, patch.object(review, "review_three") as paid:
            review.main(["--authorize-six-requests"])
            paid.assert_called_once_with(review.BASE)
            execute.assert_not_called()

    def test_install_does_not_activate(self):
        with patch.object(review, "execute") as execute, patch.object(review, "review_three") as paid:
            review.main(["--install"])
            self.assertNotIn(".Activate()", execute.call_args.args[1])
            paid.assert_not_called()

    def test_remote_base_rejected_before_work(self):
        with patch.object(review, "execute") as execute:
            with self.assertRaises(ValueError):
                review.main(["--install", "--base", "https://example.invalid"])
            execute.assert_not_called()

    def test_consumed_target_cannot_reauthorize(self):
        record = {"id": "declaration-unit", "digest": "pinned", "review": {"task": {}}}
        with patch.object(review, "records", return_value={key: record for key in review.TARGETS}), \
                patch.object(review, "admin_request", return_value=(200, {"review": {"task": {"state": "failed"}}})) as http:
            with self.assertRaisesRegex(ValueError, "never refills"):
                review.review_three(review.BASE)
            self.assertTrue(all(call.args[1] != "/declarations/review" for call in http.call_args_list))

    def test_history_keeps_failed_attempts_and_skips_unfunded_drafts(self):
        current = {"id": "quality-v2", "review": {"task": {"reserved_requests": 2}}}
        failed = {"id": "quality-v1", "review": {"task": {"reserved_requests": 2, "state": "failed"}}}
        draft = {"id": "quality-draft", "review": {"task": None}}
        history = {"items": [current, failed, draft], "has_older": False}
        with patch.object(review, "admin_request", return_value=(200, history)):
            self.assertEqual(review.acceptance_history(review.BASE, {"quality": current}),
                             [("quality", current), ("quality", failed)])

    def test_history_cannot_silently_omit_older_attempts(self):
        current = {"id": "quality-v2", "review": {"task": None}}
        with patch.object(review, "admin_request",
                          return_value=(200, {"items": [current], "has_older": True})):
            with self.assertRaisesRegex(ValueError, "history"):
                review.acceptance_history(review.BASE, {"quality": current})

    def test_history_requires_current_revision(self):
        current = {"id": "quality-v2", "review": {"task": None}}
        with patch.object(review, "admin_request",
                          return_value=(200, {"items": [], "has_older": False})):
            with self.assertRaisesRegex(ValueError, "current revision"):
                review.acceptance_history(review.BASE, {"quality": current})

    def test_check_counts_original_failure_without_requiring_it_to_pass(self):
        selected, revisions, reports = {}, [], {}
        for index, key in enumerate(review.TARGETS):
            result = {"assessment": ("no_risk_identified", "risk_identified", "information_required")[index],
                      "issues": [], "missing_information": []}
            task = {
                "state": "completed", "reserved_requests": 2, "attempted_requests": 2,
                "assessment": result["assessment"], "result": result,
                "runtime": {"authorization": {"input_hash": key, "max_model_requests": 2},
                            "session_id": index + 1, "message_id": index + 1},
            }
            record = {"id": key, "revision": 2, "review": {"task": task}}
            selected[key] = record
            revisions.append((key, record))
            reports["/declarations/" + key + "/review-report"] = {
                "id": key, "version": "declaration-review-v1", "reserved_model_requests": 2,
                "authorization": {"input_hash": key, "contract_hash": "contract"},
                "phases": [{"agent_session": str(index), "sdk_stats": {"total_interactions": 2}}],
                "result": result, "packages": [],
            }
        failed = {
            "id": "original-failed-quality", "revision": 1,
            "review": {"task": {
                "state": "failed", "reserved_requests": 2, "attempted_requests": 2,
                "assessment": None, "result": None,
                "runtime": {"authorization": {"input_hash": "original", "max_model_requests": 2}, "session_id": 9,
                            "message_id": 9, "error": "Original failure retained"},
            }},
        }
        revisions.append((review.TARGETS[0], failed))
        reports["/declarations/original-failed-quality/review-report"] = {
            "id": "original-report", "version": "declaration-review-v1", "reserved_model_requests": 2,
            "authorization": {"input_hash": "original", "contract_hash": "old-contract"},
            "phases": [{"agent_session": "original", "sdk_stats": {"total_interactions": 2}}],
        }
        with patch.object(review, "records", return_value=selected), \
                patch.object(review, "acceptance_history", return_value=revisions), \
                patch.object(review, "admin_request", side_effect=lambda base, path: (200, reports[path])), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            review.check(review.BASE)
        result = json.loads(output.getvalue())
        self.assertEqual(result["attempted_requests"], 8)
        self.assertEqual(result["reserved_requests"], 8)
        self.assertEqual(result["sdk_interactions"], 8)
        self.assertEqual(len(result["reviews"]), 3)
        self.assertEqual(result["previous_reviews"][0]["state"], "failed")


if __name__ == "__main__":
    unittest.main()
