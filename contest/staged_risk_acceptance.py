#!/usr/bin/env python3
"""Free prospective acceptance preparation/review checks. No Chat or business execution path."""
import argparse
import hashlib
import json
import re
from pathlib import Path

from business_privacy import fingerprint, require
import staged_risk_evaluation_test as evaluation
import staged_risk_smoke as smoke

ROOT = Path(__file__).resolve().parent
FIXTURES = ROOT / "fixtures"
DIRECTORY = ROOT / "data/evaluations"
DIMENSIONS = {"scope_and_applicability", "evidence_entailment", "fact_and_uncertainty",
              "explanation_completeness", "data_minimization", "bounded_outcome"}
RUNTIME_SOURCES = {"src/RiskReview.cls", "src/RiskReviewV2.cls",
                   "src/RiskReviewV3.cls", "src/RiskEvidence.cls"}


def file_sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path):
    return json.loads(path.read_text())


def load():
    suite = read_json(FIXTURES / "staged-risk-challenge-v1.json")
    expected = read_json(FIXTURES / "staged-risk-challenge-expectations-v1.json")
    rubric = read_json(FIXTURES / "staged-risk-semantic-rubric-v1.json")
    profile = read_json(FIXTURES / "staged-risk-challenge-freeze-v1.json")
    _, _, base = smoke.load()
    require(fingerprint(base) == profile["baseline_freeze_fingerprint"],
            "Baseline source freeze fingerprint changed")
    pinned = smoke.runtime_freeze(base, "staged-risk-v3")
    require(pinned["contract_hash"] == profile["contract_hash"], "V3 contract changed")
    freeze = dict(pinned, **profile)
    verify(suite, expected, rubric, freeze)
    return suite, expected, rubric, freeze


def verify(suite, expected, rubric, freeze):
    for value, key in ((suite, "suite_fingerprint"), (expected, "expectations_fingerprint"),
                       (rubric, "rubric_fingerprint")):
        require(fingerprint(value) == freeze[key], f"Acceptance {key} fingerprint changed")
    require(suite["suite"] == expected["suite"] == freeze["suite"] == "staged-risk-challenge-v1",
            "Challenge suite identity changed")
    require(suite["classification"] == "assistant_authored_prospective_not_independent_held_out" and
            expected["review_status"] == "assistant_draft_requires_independent_human_review",
            "Independent review limitations must remain explicit")
    require(freeze["runtime_version"] == suite["runtime_version"] == "staged-risk-v3" and
            freeze["model_execution_authorized"] is False and
            freeze["maximum_proposed_model_requests"] == 16, "No model execution authorized")
    require(set(freeze["runtime_source_sha256"]) == RUNTIME_SOURCES, "Runtime source pins missing")
    for path, digest in freeze["runtime_source_sha256"].items():
        require(file_sha256(ROOT / path) == digest, f"Runtime source changed: {path}")
    require({d["id"] for d in rubric["dimensions"]} == DIMENSIONS and
            len(rubric["dimensions"]) == len(DIMENSIONS), "Semantic dimensions changed")
    ids = [c["id"] for c in suite["cases"]]
    require(len(ids) == len(set(ids)) == 8 and ids == [c["id"] for c in expected["cases"]],
            "Eight unique ordered challenge cases required")
    for case, oracle in zip(suite["cases"], expected["cases"]):
        require(re.fullmatch(r"challenge-[0-9]{2}", case["id"]) is not None, "Invalid case ID")
        packet = case["packet"]
        require(set(case) == {"id", "packet"} and
                set(packet) == {"synthetic", "stage", "facts", "required_questions"} and
                packet["synthetic"] is True, "Synthetic answer-free packet required")
        require(len(packet["required_questions"]) == 1 and
                packet["required_questions"][0]["topic"] == oracle["topic"] and
                bool(oracle["human_checks"]), "Case scope/rubric missing")
    smoke.source_records(freeze)


def check_reports(reports, suite, freeze):
    require(isinstance(reports, list) and len(reports) == len(suite["cases"]),
            "Exactly eight ordered actual reports required")
    ids = set()
    for report, case in zip(reports, suite["cases"]):
        evaluation.verify_report(report, case["packet"], report["authorization"], "staged-risk-v3")
        require(report["authorization"]["contract_hash"] == freeze["contract_hash"],
                "Report contract changed")
        require(report["id"] not in ids, "Repeated report identity")
        ids.add(report["id"])
        require(report["source"]["id"] == freeze["source_agent_id"] and
                all(report["source"][key] == freeze["source"][key]
                    for key in ("revision", "config_hash", "index_version", "corpus")),
                "Report source changed")
        for phase in report["phases"]:
            require(phase["sdk_stats"]["total_interactions"] == 1 and
                    phase["sdk_stats"]["total_tool_calls"] == 0, "Tool-free one-interaction phase required")
        if report["state"] == "completed":
            require(len(report["phases"]) == report["reserved_model_requests"] == 2,
                    "Completed reports require both real phases")


def review_template(suite, rubric, freeze, reports=None):
    if reports is not None:
        check_reports(reports, suite, freeze)
    return {
        "schema_version": 1, "suite": suite["suite"],
        "suite_fingerprint": freeze["suite_fingerprint"],
        "rubric_fingerprint": freeze["rubric_fingerprint"],
        "contract_hash": freeze["contract_hash"],
        "reports_fingerprint": None if reports is None else fingerprint(reports),
        "reviewer": "", "independence_declaration": "not_established",
        "cases": [{"case_id": case["id"], "dimensions": {
            dimension["id"]: {"verdict": "pending", "rationale": "", "output_excerpt": ""}
            for dimension in rubric["dimensions"]}} for case in suite["cases"]],
    }


def report_strings(value):
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [text for item in value.values() for text in report_strings(item)]
    if isinstance(value, list):
        return [text for item in value for text in report_strings(item)]
    return []


def output_strings(report):
    return report_strings({key: report[key] for key in
                           ("plan", "judgment", "result", "error", "state") if key in report})


def review_status(review, suite, rubric, freeze, reports=None):
    template = review_template(suite, rubric, freeze, reports)
    require(set(review) == set(template), "Unexpected review fields")
    for key in ("schema_version", "suite", "suite_fingerprint", "rubric_fingerprint",
                "contract_hash", "reports_fingerprint"):
        require(review[key] == template[key], f"Review identity/fingerprint changed: {key}")
    require(isinstance(review["reviewer"], str) and
            isinstance(review["independence_declaration"], str), "Invalid reviewer declaration")
    require(isinstance(review["cases"], list) and len(review["cases"]) == len(suite["cases"]),
            "Review case coverage changed")
    pending, failed = 0, 0
    for index, (case, expected_case) in enumerate(zip(review["cases"], template["cases"])):
        require(set(case) == {"case_id", "dimensions"} and
                case["case_id"] == expected_case["case_id"] and
                set(case["dimensions"]) == DIMENSIONS, "Review cases/dimensions changed")
        for mark in case["dimensions"].values():
            require(set(mark) == {"verdict", "rationale", "output_excerpt"} and
                    mark["verdict"] in {"pending", "pass", "fail"}, "Invalid review verdict")
            require(all(isinstance(mark[key], str) for key in ("rationale", "output_excerpt")),
                    "Invalid review text")
            pending += mark["verdict"] == "pending"
            failed += mark["verdict"] == "fail"
            if mark["verdict"] != "pending":
                require(reports is not None, "Actual reports required before human verdicts")
                require(review["reviewer"].strip() and mark["rationale"].strip() and
                        mark["output_excerpt"].strip(), "Reviewer, rationale and output excerpt required")
                require(any(mark["output_excerpt"] in text for text in output_strings(reports[index])),
                        "Review excerpt not present in the bound report")
    technical_failure = reports is not None and any(r["state"] != "completed" for r in reports)
    state = ("blocked_technical_failure" if technical_failure else "failed" if failed else
             "pending" if pending or reports is None else "human_rubric_passed_self_attested")
    return {"state": state, "pending_dimensions": pending, "failed_dimensions": failed,
            "independent_validation_established": False, "business_deployment_authorized": False,
            "legal_accuracy": "not_measured",
            "note": "Identity/excerpt validation cannot verify human expertise, entailment or independence"}


def save_immutable(path, value):
    if path.exists():
        require(read_json(path) == value, "Immutable preparation/worksheet differs; use a new file")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x") as stream:
        json.dump(value, stream, ensure_ascii=True, indent=2)
        stream.write("\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare", action="store_true", help="Read pinned IRIS sources; never Chat")
    parser.add_argument("--reports", type=Path, help="Eight actual reports in case order; read-only")
    parser.add_argument("--review-template", type=Path, help="Write a pending worksheet; never overwrite edits")
    parser.add_argument("--review", type=Path, help="Check a worksheet against the exact bound reports")
    args = parser.parse_args()
    if args.review and not args.reports:
        parser.error("--review requires --reports; no hypothetical human acceptance")
    suite, _, rubric, freeze = load()
    reports = None if args.reports is None else read_json(args.reports)
    review = review_template(suite, rubric, freeze, reports)
    if args.prepare:
        prepared = smoke.prepare(suite, freeze)
        save_immutable(DIRECTORY / "staged-risk-challenge-v1-prepared.json", prepared)
        print("PASS: eight pinned IRIS packets/evidence inputs prepared; no Chat")
        print("Judgment input characters:", [c["judge_input_characters"] for c in prepared["cases"]])
    if args.review_template:
        save_immutable(args.review_template, review)
    result = review_status(read_json(args.review) if args.review else review, suite, rubric, freeze, reports)
    print(json.dumps(result, indent=2))
    print("Eight assistant-authored prospective cases, NOT independent held-out evidence.")
    print("No model execution, legal certification or business deployment authorized.")
    if result["state"] in {"failed", "blocked_technical_failure"}:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
