#!/usr/bin/env python3
"""Prospective eight-case exploration. Default free; --run requires a new key and cost authorization."""
import argparse
import json
import subprocess

from business_privacy import require
import staged_risk_acceptance as acceptance
import staged_risk_evaluation_test as evaluation
import staged_risk_smoke as smoke


def verify_completed_journal(journal):
    suite, expected, _, freeze = acceptance.load()
    authorization = journal["authorization"]
    require(authorization["contract_hash"] == freeze["contract_hash"] and
            authorization["suite_fingerprint"] == freeze["suite_fingerprint"] and
            authorization["expectations_fingerprint"] == freeze["expectations_fingerprint"] and
            authorization["source"] == freeze["source"] and
            authorization["source_agent_id"] == freeze["source_agent_id"] and
            authorization["runtime_version"] == "staged-risk-v3" and
            authorization["maximum_model_requests"] == 16 and
            authorization["automatic_retries"] == 0 and
            authorization["acknowledge_cost"] is True, "Challenge authorization mismatch")
    reports = [entry["report"] for entry in journal["cases"]]
    acceptance.check_reports(reports, suite, freeze)
    return evaluation.summarize(journal, (suite, expected, freeze))


def readback(reports):
    commands = []
    for report in reports:
        identifier = json.dumps({"id": report["id"]}, ensure_ascii=True).replace('"', '""')
        commands.append(f'Set object={{}}.%FromJSON("{identifier}"), id=object.id')
        commands.append(f'Write "{smoke.MARKER}",$ZConvert(##class(Contest.RiskReviewV3).Status(id).%ToJSON(),"O","UTF8"),!')
    result = subprocess.run(
        ["docker", "exec", "-i", "iris-triage-real-iris-1", "iris", "session", "IRIS", "-U", "TRIAGE"],
        input="\n".join(commands + ["Halt", ""]), text=True, capture_output=True,
        check=True, timeout=120)
    rows = [json.loads(line.split(smoke.MARKER, 1)[1]) for line in result.stdout.splitlines()
            if smoke.MARKER in line]
    require(rows == reports, "Persistent report readback differs; never rerun requests")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--request-key")
    args = parser.parse_args(argv)
    if args.run and not args.request_key:
        parser.error("--run requires a new explicit --request-key")
    suite, expected, rubric, freeze = acceptance.load()
    if not args.run:
        print("PASS: frozen eight-case specification; no Chat. Not independent/legal acceptance.")
        return
    prepared = smoke.prepare(suite, freeze)
    require(prepared == acceptance.read_json(acceptance.DIRECTORY / "staged-risk-challenge-v1-prepared.json"),
            "Prepared challenge inputs differ; no model call allowed")
    evaluation.run(suite, expected, freeze, args.request_key, prepared)
    path = evaluation.DIRECTORY / (args.request_key + "-staged.json")
    journal = acceptance.read_json(path)
    analysis = verify_completed_journal(journal)
    reports = [entry["report"] for entry in journal["cases"]]
    readback(reports)
    journal["analysis"] = analysis
    journal["persistent_reports_equal"] = True
    journal["classification"] = suite["classification"]
    journal["rubric_fingerprint"] = freeze["rubric_fingerprint"]
    path.write_text(json.dumps(journal, ensure_ascii=True, indent=2) + "\n")
    acceptance.save_immutable(evaluation.DIRECTORY / (args.request_key + "-reports.json"), reports)
    acceptance.save_immutable(evaluation.DIRECTORY / (args.request_key + "-review-pending.json"),
                              acceptance.review_template(suite, rubric, freeze, reports))
    print(json.dumps(analysis, indent=2))
    print("Exploratory result only; all 48 independent human verdicts remain pending.")


if __name__ == "__main__":
    main()
