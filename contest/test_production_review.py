import unittest
from unittest.mock import patch

import production_review_test as review


class ProductionReviewCLITests(unittest.TestCase):
    def test_default_inactive(self):
        with patch.object(review, "execute") as run, patch.object(review, "api") as http:
            review.main([])
            run.assert_not_called()
            http.assert_not_called()

    def test_compile_does_not_fund_or_send(self):
        with patch.object(review, "execute") as run, patch.object(review, "api") as http:
            review.main(["--install"])
            namespace, code = run.call_args.args
            self.assertEqual(namespace, "TRIAGE")
            self.assertIn("ProductionReviewService.cls", code)
            for forbidden in (").Authorize(", ").Run(", ").Pump(", "StartProduction", "ProcessInput"):
                self.assertNotIn(forbidden, code)
            http.assert_not_called()

    def test_no_repeated_paid_acceptance(self):
        with patch.object(review, "SAVED") as saved, patch.object(review, "api") as http:
            saved.exists.return_value = True
            with self.assertRaisesRegex(ValueError, "immutable"):
                review.acceptance(review.BASE)
            http.assert_not_called()

    def test_remote_rejected(self):
        with patch.object(review, "execute") as run, patch.object(review, "api") as http:
            with self.assertRaises(ValueError):
                review.main(["--authorize-acceptance", "--base", "https://example.invalid"])
            run.assert_not_called()
            http.assert_not_called()

    def test_plan_preserves_validated_base(self):
        with patch.object(review, "production", return_value="production-unit"), patch.object(review, "api", return_value={}) as http:
            review.main(["--plan"])
            http.assert_called_once_with(review.BASE, "/productions/production-unit/review-plan")

    def test_review_pages_exact_and_read_only(self):
        with patch.object(review, "api", side_effect=[
            {"production_id": "production-unit", "items": [{"header_id": 2}], "next_before": 2},
            {"production_id": "production-unit", "items": [{"header_id": 1}], "next_before": 0},
        ]) as http:
            _, items = review.reviews(review.BASE, "production-unit")
            self.assertEqual([i["header_id"] for i in items], [2, 1])
            self.assertEqual(len(http.call_args_list), 2)
            self.assertTrue(all(len(call.args) == 2 for call in http.call_args_list))

    def test_page_cursor_loop_fails(self):
        page = {"production_id": "production-unit", "items": [], "next_before": 2}
        with patch.object(review, "api", return_value=page):
            with self.assertRaisesRegex(ValueError, "cursor loop"):
                review.reviews(review.BASE, "production-unit")

    def test_nonempty_cursor_must_not_be_a_string(self):
        page = {"production_id": "production-unit", "items": [], "next_before": "2"}
        with patch.object(review, "api", return_value=page):
            with self.assertRaisesRegex(ValueError, "JSON integer"):
                review.reviews(review.BASE, "production-unit")


if __name__ == "__main__":
    unittest.main()
