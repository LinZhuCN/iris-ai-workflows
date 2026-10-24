#!/usr/bin/env python3
"""Default: free checks. --run explicitly authorizes six frozen cases, at most12 Chat attempts, no retries."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time

from business_privacy import require
import staged_risk_smoke as smoke

DIRECTORY = Path(__file__).resolve().parent / "data/evaluations"


def command(packet, authorization, runtime_version="staged-risk-v1"):
    reviewer = smoke.runtime_class(runtime_version)
    def literal(value):
        return json.dumps(value, ensure_ascii=True, separators=(",", ":")).replace('"', '""')

    return "\n".join([
        f'Set packet={{}}.%FromJSON("{literal(packet)}")',
        f'Set consent={{}}.%FromJSON("{literal(authorization)}")',
        f'Try {{ Set report=##class({reviewer}).Run(packet,consent) '
        f'Write "{smoke.MARKER}",$ZConvert(report.%ToJSON(),"O","UTF8"),! '
        f'}} Catch ex {{ Write "{smoke.MARKER}",{{"error":(ex.DisplayString())}}.%ToJSON(),! }}',
        "Halt", "",
    ])


def verify_report(report, packet, authorization, runtime_version="staged-risk-v1"):
    require(runtime_version in smoke.RUNTIMES or runtime_version == "staged-risk-v4",
            "Unknown staged report runtime")
    require("error" not in report or "id" in report, "IRIS refused the evaluation request")
    require(report["version"] == runtime_version, "Unexpected report runtime version")
    require(report["authorization"] == authorization and report["packet"] == packet,
            "Runtime report identity/input mismatch")
    require(report["state"] in {"completed", "failed", "interrupted"}, "Run did not reach a terminal state")
    require(report["reserved_model_requests"] <= 2 and len(report["phases"]) <= 2,
            "Two-phase budget exceeded")
    require([p["phase"] for p in report["phases"]] ==
            ["locate", "judge"][:len(report["phases"])], "Unexpected phase order")
    for phase in report["phases"]:
        require("fixture" not in phase and bool(phase["agent_session"]),
                "Actual SDK sessions required, never fixtures")
    require(report["execution"] == "evaluation_only", "Business execution is not authorized")
    if report["phases"]:
        require(report["phases"][0]["input"] == smoke.locate_input(packet),
                "Locator saw scope labels, case identity or oracle")


def summarize(journal, dataset=None):
    suite, expectations, freeze = smoke.load() if dataset is None else dataset
    runtime = journal["authorization"].get("runtime_version", "staged-risk-v1")
    if dataset is None:
        freeze = smoke.runtime_freeze(freeze, runtime)
    require(runtime == freeze.get("runtime_version", "staged-risk-v1"), "Runtime profile mismatch")
    records = smoke.source_records(freeze)
    require(journal["authorization"]["contract_hash"] == freeze["contract_hash"] and
            journal["authorization"]["suite_fingerprint"] == freeze["suite_fingerprint"],
            "Journal is not from this frozen contract/input")
    size = len(suite["cases"])
    require(len(journal["cases"]) == size, "Complete suite journal required")
    totals = {key: 0 for key in (
        "total_interactions", "total_prompt_tokens", "total_completion_tokens",
        "total_reasoning_tokens", "total_cache_read_tokens", "total_llm_duration_ms",
        "total_tool_calls")}
    counts = {"total": size, "runtime_completed": 0, "runtime_failed": 0, "valid_locator_topics": 0,
              "locator_fact_coverage": 0, "main_status_matches_author": 0,
              "main_fact_coverage": 0, "unresolved_matches_author": 0,
              "recommendation_matches_author": 0, "all_four_judgment_checks": 0,
              "reserved_model_requests": 0, "materialized_citations_verified": 0}
    sessions = []
    for entry, case, expected in zip(journal["cases"], suite["cases"], expectations["cases"]):
        require(entry["case_id"] == case["id"] == expected["id"], "Journal case identity/order changed")
        report = entry["report"]
        verify_report(report, case["packet"], entry["authorization"], runtime)
        checks = smoke.report_checks(report, expected)
        require(checks == entry["checks"], "Saved grading changed")
        counts["runtime_completed"] += report["state"] == "completed"
        counts["runtime_failed"] += report["state"] != "completed"
        counts["reserved_model_requests"] += report["reserved_model_requests"]
        locator, judgment = checks["localization"], checks["judgment"]
        counts["valid_locator_topics"] += bool(locator and locator["topic_found"])
        counts["locator_fact_coverage"] += bool(locator and locator["fact_coverage"])
        if judgment:
            for destination, source in (
                ("main_status_matches_author", "status_matches_author"),
                ("main_fact_coverage", "fact_coverage"),
                ("unresolved_matches_author", "unresolved_matches_author"),
                ("recommendation_matches_author", "recommendation_matches_author"),
            ):
                counts[destination] += judgment[source]
            counts["all_four_judgment_checks"] += all(judgment[key] for key in (
                "status_matches_author", "fact_coverage", "unresolved_matches_author",
                "recommendation_matches_author"))
        require(report["source"]["config_hash"] == freeze["source"]["config_hash"],
                "Runtime source changed")
        for phase in report["phases"]:
            stats = phase["sdk_stats"]
            require(stats["total_interactions"] == 1 and stats["total_tool_calls"] == 0,
                    "Tool-free one-interaction phase required")
            sessions.append(phase["agent_session"])
            for key in totals:
                totals[key] += stats[key]
        packages = {p["question_id"]: p for p in report.get("packages", [])}
        for package in packages.values():
            for evidence in package["evidence"]:
                smoke.verify_source(evidence, records)
        if judgment:
            for issue in report["result"]["issues"]:
                evidence = {e["id"]: e for e in packages[issue["question_id"]]["evidence"]}
                for citation in issue["citations"]:
                    hit = evidence[citation["evidence_id"]]
                    span = next(p for p in hit["passages"] if p["id"] == citation["passage_id"])
                    require(citation["quote"] == span["text"] ==
                            hit["text"][citation["start"]:citation["end"]] and
                            citation["start"] == span["start"] and citation["end"] == span["end"],
                            "Materialized citation differs from released canonical source")
                    counts["materialized_citations_verified"] += 1
    require(len(set(sessions)) == len(sessions) and totals["total_interactions"] <= (2 * size) and
            counts["reserved_model_requests"] <= (2 * size), "Session uniqueness or batch budget exceeded")
    return {"counts": counts, "sdk_totals": totals, "sessions": sessions,
            "provider_tokens": totals["total_prompt_tokens"] + totals["total_completion_tokens"],
            "independent_semantic_review": "pending",
            "legal_accuracy": "not_measured",
            "business_execution": "not_performed",
            "usage_note": "Reasoning is included in completion, cached tokens in prompt; do not add again"}


def run(suite, expectations, freeze, request_key, prepared, continue_unattempted=False):
    runtime = freeze.get("runtime_version", "staged-risk-v1")
    smoke.runtime_class(runtime)
    require(bool(re.fullmatch(r"[A-Za-z0-9-]{1,80}", request_key)),
            "An explicit bounded immutable request key is required")
    authorization = {
        "request_key": request_key, "suite_fingerprint": freeze["suite_fingerprint"],
        "expectations_fingerprint": freeze["expectations_fingerprint"],
        "contract_hash": freeze["contract_hash"], "source": freeze["source"],
        "source_agent_id": freeze["source_agent_id"], "acknowledge_cost": True,
        "maximum_model_requests": 2 * len(suite["cases"]), "automatic_retries": 0,
    }
    if runtime != "staged-risk-v1":
        authorization["runtime_version"] = runtime
    path = DIRECTORY / (request_key + "-staged.json")
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    if continue_unattempted:
        require(path.exists(), "A prior interrupted journal is required")
        journal = json.loads(path.read_text())
        require(journal["authorization"] == authorization and journal["state"] == "interrupted",
                "Only this exact interrupted authorization can continue unattempted cases")
        require(len(journal["cases"]) < len(suite["cases"]) and all("report" in c for c in journal["cases"]),
                "Uncertain attempted requests require read-only recovery, never replay")
        for entry, case, expected in zip(journal["cases"], suite["cases"], expectations["cases"]):
            require(entry["case_id"] == case["id"], "Prior case order changed")
            verify_report(entry["report"], case["packet"], entry["authorization"], runtime)
            entry["checks"] = smoke.report_checks(entry["report"], expected)
            entry["state"] = entry["report"]["state"]
        journal.setdefault("continuations", []).append(
            {"time": time.time(), "prior_error": journal.get("error"),
             "unattempted_only": True, "prior_case_count": len(journal["cases"])})
        journal["state"] = "running"
    else:
        require(not path.exists(), "Journal already exists. Read/recover it; never automatically rerun a batch")
        journal = {"authorization": authorization, "state": "running", "started": time.time(),
                   "cases": [], "human_review_required": True, "hipaa_risk_validation": "not_completed"}
        with path.open("x") as stream:
            json.dump(journal, stream, ensure_ascii=True, indent=2)
            stream.write("\n")
    start = len(journal["cases"])
    try:
        for case, expected, baseline in zip(suite["cases"][start:], expectations["cases"][start:],
                                            prepared["cases"][start:]):
            require(case["id"] == expected["id"] == baseline["case_id"], "Case order changed")
            consent = {
                "request_key": request_key + "-" + case["id"],
                "agent_id": freeze["source_agent_id"], "source_revision": freeze["source"]["revision"],
                "config_hash": freeze["source"]["config_hash"], "input_hash": baseline["input_hash"],
                "contract_hash": freeze["contract_hash"], "acknowledge_cost": True,
                "max_model_requests": 2,
            }
            entry = {"case_id": case["id"], "authorization": consent, "state": "attempting"}
            journal["cases"].append(entry)
            path.write_text(json.dumps(journal, ensure_ascii=True, indent=2) + "\n")
            result = subprocess.run(
                ["docker", "exec", "-i", "iris-triage-real-iris-1", "iris", "session", "IRIS", "-U", "TRIAGE"],
                input=command(case["packet"], consent, runtime), text=True, capture_output=True,
                check=True, timeout=600,
            )
            rows = [json.loads(line.split(smoke.MARKER, 1)[1])
                    for line in result.stdout.splitlines() if smoke.MARKER in line]
            require(len(rows) == 1, "Missing/ambiguous response; do not retry; inspect protected runtime state")
            entry["report"] = rows[0]
            path.write_text(json.dumps(journal, ensure_ascii=True, indent=2) + "\n")
            verify_report(entry["report"], case["packet"], consent, runtime)
            entry["checks"] = smoke.report_checks(entry["report"], expected)
            entry["state"] = entry["report"]["state"]
            path.write_text(json.dumps(journal, ensure_ascii=True, indent=2) + "\n")
            print(case["id"], entry["state"], "reserved",
                  entry["report"]["reserved_model_requests"], flush=True)
        journal["state"] = "completed"
        journal["summary"] = {
            "total": len(suite["cases"]),
            "runtime_completed": sum(c["state"] == "completed" for c in journal["cases"]),
            "reserved_model_requests": sum(c["report"]["reserved_model_requests"]
                                           for c in journal["cases"]),
        }
    except (ValueError, KeyError, subprocess.SubprocessError, OSError) as error:
        journal["state"] = "interrupted"
        journal["error"] = str(error)
        raise
    finally:
        journal["finished"] = time.time()
        path.write_text(json.dumps(journal, ensure_ascii=True, indent=2) + "\n")
    print(json.dumps(journal["summary"]), flush=True)
    print("Immutable runtime reports and local journal retained:", path, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--request-key")
    parser.add_argument("--runtime-version", choices=tuple(smoke.RUNTIMES), default="staged-risk-v1")
    parser.add_argument("--continue-unattempted", action="store_true",
                        help="Continue only cases absent from an exact interrupted journal; never replay attempts")
    args = parser.parse_args()
    if args.run and not args.request_key:
        parser.error("--run requires a new explicit --request-key")
    if args.continue_unattempted and not args.run:
        parser.error("--continue-unattempted requires --run and an existing journal")
    suite, expectations, freeze = smoke.load()
    freeze = smoke.runtime_freeze(freeze, args.runtime_version)
    smoke.source_records(freeze)
    if not args.run:
        print("PASS: frozen six-case source/contract specifications; no provider calls")
        return
    # All six inputs and source pins are checked before any model request.
    prepared = smoke.prepare(suite, freeze)
    baseline = json.loads(smoke.prepared_path(args.runtime_version).read_text())
    require(prepared == baseline, "Prepared inputs changed; no model call permitted")
    run(suite, expectations, freeze, args.request_key, prepared, args.continue_unattempted)


if __name__ == "__main__":
    main()
