#!/usr/bin/env python3
"""Free API checks by default; --run explicitly permits one read-only twelve-case batch (max48 requests)."""
import argparse
import json
from pathlib import Path
import time

import business_privacy as benchmark
from platform_test import request

DIRECTORY = Path(__file__).resolve().parent / "data/evaluations"
INPUT_FILE = DIRECTORY / "business-context-v1.json"
ORACLE_FILE = DIRECTORY / "business-oracle-v1.json"


def prepare():
    suite, records = benchmark.load()
    raw, digest = benchmark.runtime_inputs(suite)
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    oracle = json.dumps({"manifest_hash": benchmark.fingerprint(suite), "cases": [
        {"case_id": c["case_id"], "required_sections": c["required_sections"], "oracle": c["oracle"]}
        for c in suite["cases"]]}, sort_keys=True, ensure_ascii=True, separators=(",", ":"))
    for path, content in ((INPUT_FILE, raw), (ORACLE_FILE, oracle)):
        if path.exists():
            if path.read_text() != content:
                raise RuntimeError("Prepared business inputs/oracle changed. Preserve the previous version before replacing.")
        else:
            with path.open("x") as stream:
                stream.write(content)
    return suite, records, digest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="http://127.0.0.1:5173/api/monitor/v1")
    parser.add_argument("--prepare", action="store_true", help="Prepare answer-free local inputs; no HTTP or model request")
    parser.add_argument("--run", action="store_true", help="Explicit cost authorization for twelve cases at most48 requests, no retries")
    parser.add_argument("--agent-id", help="Exact pinned source Agent identity, never auto-selected")
    parser.add_argument("--request-key", help="Approved immutable request key, never auto-generated")
    parser.add_argument("--runtime-version", choices=("hipaa-business-runtime-v1", "hipaa-business-runtime-v2", "hipaa-business-runtime-v3", "hipaa-business-runtime-v4"),
                        default="hipaa-business-runtime-v1", help="Explicit reviewer version; selecting a version does not authorize a model call")
    args = parser.parse_args()
    if args.prepare and args.run:
        parser.error("--prepare and --run are mutually exclusive")
    if args.run and (not args.agent_id or not args.request_key):
        parser.error("--run requires an explicitly approved --agent-id and --request-key")
    suite, records, digest = prepare()
    if args.prepare:
        print("Prepared answer-free inputs:", digest, "; no network or model requests")
        return

    def get(path):
        code, value = request(args.base, path, account="ContestKnowledgeAdmin")
        if code != 200:
            raise RuntimeError((path, code, value))
        return value

    path = "/business-evaluations"
    assert request(args.base, path, account=None)[0] == 401
    assert request(args.base, path, body={})[0] == 403
    assert request(args.base, path, account="ContestKnowledgeAdmin", body={}, header=False)[0] == 403
    for raw in (b"null", b"[]", b"3", b'"text"'):
        assert request(args.base, path, account="ContestKnowledgeAdmin", raw=raw)[0] == 400
    for body in ({}, {"agent_id": "unused", "input_hash": digest, "request_key": "unused",
                      "acknowledge_cost": True, "max_model_requests": 52}):
        assert request(args.base, path, account="ContestKnowledgeAdmin", body=body)[0] == 400
    versioned = {"agent_id": "unused", "input_hash": "0" * 64, "request_key": "invalid-v2-input-guard",
                 "acknowledge_cost": True, "max_model_requests": 48, "runtime_version": "hipaa-business-runtime-v2"}
    assert request(args.base, path, account="ContestKnowledgeAdmin", body=versioned)[0] == 409
    assert request(args.base, path, account="ContestKnowledgeAdmin",
                   body={**versioned, "runtime_version": "hipaa-business-runtime-v3",
                         "request_key": "invalid-v3-input-guard"})[0] == 409
    assert request(args.base, path, account="ContestKnowledgeAdmin",
                   body={**versioned, "runtime_version": "hipaa-business-runtime-v4",
                         "request_key": "invalid-v4-input-guard"})[0] == 409
    assert request(args.base, path, account="ContestKnowledgeAdmin",
                   body={**versioned, "runtime_version": "arbitrary"})[0] == 400
    assert request(args.base, path, account="ContestKnowledgeAdmin", body={
        "agent_id": "unused", "input_hash": "0" * 64, "request_key": "invalid-input-guard",
        "acknowledge_cost": True, "max_model_requests": 48})[0] == 409
    before = get(path)
    assert before["automatic_model_budget"] == 0 and before["execution"] == "evaluation_only"
    if not args.run:
        print("PASS: answer-free preparation, authentication, consent, JSON/CSRF and48-request cap; no model calls")
        return
    if not args.request_key or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-" for c in args.request_key):
        raise ValueError("Request key must contain only letters, digits and hyphens")
    journal_file = DIRECTORY / (args.request_key + "-business.json")
    body = {"agent_id": args.agent_id, "input_hash": digest, "request_key": args.request_key,
            "acknowledge_cost": True, "max_model_requests": 48}
    if args.runtime_version != "hipaa-business-runtime-v1":
        body["runtime_version"] = args.runtime_version
    journal = json.loads(journal_file.read_text()) if journal_file.exists() else {"authorization": body}
    if journal["authorization"] != body:
        raise RuntimeError("Do not change the authorized identity or inputs under an existing key")
    journal_file.write_text(json.dumps(journal, indent=2) + "\n")
    code, report = request(args.base, path, account="ContestKnowledgeAdmin", body=body)
    if code != 202:
        raise RuntimeError((code, report))
    journal["evaluation_id"] = report["id"]
    journal_file.write_text(json.dumps(journal, indent=2) + "\n")
    # Only GET polling follows; re-running the script returns this same server-keyed report.
    deadline = time.monotonic() + 900
    last_progress = None
    while report["state"] in ("queued", "running"):
        progress = (report["state"], len(report["cases"]))
        if progress != last_progress:
            print(f"Business evaluation {report['id']}: {progress[0]}, {progress[1]}/12 processed; no automatic retries", flush=True)
            last_progress = progress
        if time.monotonic() >= deadline:
            raise RuntimeError("Worker status uncertain; reconcile the same request key, never launch a replacement")
        time.sleep(2)
        report = next(r for r in get(path)["reports"] if r["id"] == journal["evaluation_id"])
    report.pop("diagnostics", None)  # Preserve runtime evidence separately from derived machine checks.
    assert report["inputs"]["manifest_hash"] == benchmark.fingerprint(suite) and report["input_hash"] == digest
    assert report["reserved_model_requests"] <= 48
    cases = {c["case_id"]: c for c in suite["cases"]}
    assert report["prompt_version"] == args.runtime_version
    grades = [benchmark.grade_runtime_case(cases[item["case_id"]], item, records, args.runtime_version)
              for item in report["cases"]]
    journal.update(report=report, checks=grades, human_review_required=True, hipaa_risk_validation="not_completed")
    journal_file.write_text(json.dumps(journal, indent=2) + "\n")
    print("Valid output contracts:", report.get("summary", {}).get("valid_contracts", 0),
          "; author-oracle alignment:", sum(g["oracle_alignment"] for g in grades), "/12; not a legal accuracy score", flush=True)
    for item, checked in zip(report["cases"], grades):
        print(item["case_id"], item["state"], "oracle_alignment=" + str(checked["oracle_alignment"]),
              "session=" + str(item.get("agent_session", "")), checked["errors"], flush=True)
    print("Saved exact runtime evidence:", journal_file)
    print("Human entailment/applicability review required; no business action, publication or overall HIPAA pass.")
    if report["state"] != "completed" or len(grades) != 12 or not all(g["oracle_alignment"] for g in grades):
        raise SystemExit("STRUCTURE/ORACLE CHECKS NOT PASSED: original failures retained; no retries")


if __name__ == "__main__":
    main()
