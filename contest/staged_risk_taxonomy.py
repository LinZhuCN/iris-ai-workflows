#!/usr/bin/env python3
"""Describe a non-adopted status proposal; optionally bind disputes to saved reports. Never Chat or rescore."""
import argparse
import json
from pathlib import Path

from business_privacy import fingerprint, require
import staged_risk_acceptance as acceptance
import staged_risk_challenge as challenge


def validate(proposal):
    _, expected, _, freeze = acceptance.load()
    require(proposal["proposal"] == "staged-risk-taxonomy-draft-v1" and
            proposal["adoption"] == "not_adopted" and
            proposal["review_status"] == "assistant_proposal_requires_external_review",
            "Only the non-adopted assistant proposal is supported")
    require(proposal["runtime_version"] == "staged-risk-v3" and
            proposal["contract_hash"] == freeze["contract_hash"], "Frozen runtime mismatch")
    require([d["case_id"] for d in proposal["disputes"]] ==
            ["challenge-02", "challenge-04", "challenge-07"], "Dispute coverage changed")
    by_id = {case["id"]: case for case in expected["cases"]}
    for dispute in proposal["disputes"]:
        require(dispute["review_decision"] == "pending" and
                dispute["draft_expected_status"] == by_id[dispute["case_id"]]["status"],
                "Do not approve or rewrite a historical expected status in this proposal")
        require(all(isinstance(dispute[key], str) and dispute[key].strip() for key in
                    ("proposal_reason", "current_contract_alternative", "external_question",
                     "minimal_pair")), "Dispute rationale/counterexample missing")


def load():
    proposal = acceptance.read_json(acceptance.FIXTURES / "staged-risk-taxonomy-draft-v1.json")
    validate(proposal)
    return proposal


def describe(proposal):
    validate(proposal)
    return {"proposal": proposal["proposal"], "adoption": proposal["adoption"],
            "pending_decisions": len(proposal["disputes"]),
            "changes_runtime": False, "independent_review_completed": False,
            "model_calls": 0, "legal_accuracy": "not_measured"}


def audit(journal, proposal):
    validate(proposal)
    require(isinstance(journal, dict) and "authorization" in journal and
            "cases" in journal and "analysis" in journal, "Actual complete challenge journal required")
    analysis = challenge.verify_completed_journal(journal)
    require(analysis == journal["analysis"], "Historical grading changed; do not rescore")
    by_id = {entry["case_id"]: entry for entry in journal["cases"]}
    expected = {case["id"]: case for case in acceptance.load()[1]["cases"]}
    disputes = []
    for dispute in proposal["disputes"]:
        entry = by_id[dispute["case_id"]]
        report = entry["report"]
        topic = expected[dispute["case_id"]]["topic"]
        question = next(q for q in report["questions"] if q["topic"] == topic)
        issue = next(i for i in report["result"]["issues"] if i["question_id"] == question["id"])
        require(issue["status"] == dispute["observed_status"], "Observed dispute status changed")
        disputes.append({
            "case_id": dispute["case_id"], "report_id": report["id"],
            "report_fingerprint": fingerprint(report),
            "historical_checks": entry["checks"],
            "observed_main_issue": issue,
            "observed_questions": report["questions"],
            "observed_missing_information": report["result"]["missing_information"],
            "observed_summary": report["result"]["summary"],
            "review_proposal": dispute,
        })
    return dict(describe(proposal), proposal_fingerprint=fingerprint(proposal),
                journal_fingerprint=fingerprint(journal), historical_analysis=analysis,
                disputes=disputes,
                warning="Read-only local audit; not fresh IRIS authentication, legal review or a new score")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--journal", type=Path, help="Read the completed exploratory eight-case journal")
    parser.add_argument("--output", type=Path, help="Save an immutable audit, never overwrite edits")
    args = parser.parse_args()
    if args.output and not args.journal:
        parser.error("--output requires --journal")
    proposal = load()
    result = (audit(acceptance.read_json(args.journal), proposal)
              if args.journal else describe(proposal))
    if args.output:
        acceptance.save_immutable(args.output, result)
    print(json.dumps(describe(proposal), indent=2))
    if args.journal:
        print("Historical four-check matches:", result["historical_analysis"]["counts"]["all_four_judgment_checks"])
        print("Three disagreements bound to saved output; decisions remain pending, no regrading.")


if __name__ == "__main__":
    main()
