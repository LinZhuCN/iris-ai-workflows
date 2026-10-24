#!/usr/bin/env python3
"""Check evaluation contracts; --run explicitly permits a bounded paid batch."""
import argparse
import json
from pathlib import Path
import time

from platform_test import request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="http://127.0.0.1:5173/api/monitor/v1")
    parser.add_argument("--run", action="store_true", help="Permit one paid batch: 48 requests with --evaluation-only, otherwise 52 including investigation; no retries")
    parser.add_argument("--request-key", default="privacy-quality-20261016")
    parser.add_argument("--evaluation-only", action="store_true", help="Run only twelve cases (max 48 requests); no event investigation")
    parser.add_argument("--agent-id", help="Explicit published Agent or versioned v2 candidate; mandatory for evaluation-only")
    args = parser.parse_args()
    actor, base = "ContestKnowledgeAdmin", args.base

    def get(path):
        code, value = request(base, path, account=actor)
        assert code == 200, (path, code, value)
        return value

    def post(path, body):
        code, value = request(base, path, account=actor, body=body)
        assert code in (200, 202), (path, code, value)
        return value

    def wait(read, done, seconds=900):
        deadline = time.monotonic() + seconds
        while True:
            value = read()
            if done(value):
                return value
            assert time.monotonic() < deadline, "Timed out: request status is uncertain; do not resubmit the investigation"
            time.sleep(2)

    assert request(base, "/evaluations", account=None)[0] == 401
    assert request(base, "/evaluations", body={})[0] == 403
    assert request(base, "/evaluations", account=actor, body={}, header=False)[0] == 403
    for body in ({}, {"agent_id": "unused", "request_key": "unused", "acknowledge_cost": False, "max_model_requests": 48},
                 {"agent_id": "unused", "request_key": "unused", "acknowledge_cost": True, "max_model_requests": 52}):
        assert request(base, "/evaluations", account=actor, body=body)[0] == 400
    for raw in (b"null", b"[]", b"5", b'"text"'):
        assert request(base, "/evaluations", account=actor, raw=raw)[0] == 400
    before = get("/evaluations")
    assert before["automatic_model_budget"] == 0
    if args.evaluation_only and not args.agent_id:
        parser.error("--evaluation-only requires --agent-id")
    if not args.run:
        print("PASS: evaluation authentication, consent, 48-request budget, JSON/CSRF guards; no model calls")
        return
    if not args.request_key or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-" for c in args.request_key):
        raise ValueError("Request key must contain only letters, digits and hyphens")
    directory = Path(__file__).resolve().parent / "data/evaluations"
    directory.mkdir(parents=True, exist_ok=True)
    journal_file = directory / (args.request_key + ".json")
    journal = json.loads(journal_file.read_text()) if journal_file.exists() else {}

    def save():
        journal_file.write_text(json.dumps(journal, indent=2) + "\n")

    agents = get("/agents")
    config = next(a for a in agents["agents"] if a["id"] == args.agent_id) if args.agent_id else next(a for a in agents["agents"] if a["status"] == "published")
    assert config["model"] == "deepseek-flash" and config["max_iterations"] == 4
    if not args.evaluation_only:
        assert config["status"] == "published", "Investigation requires a published Agent"
    if journal and journal["config_hash"] != config["config_hash"]:
        raise RuntimeError("Published configuration changed; refusing a new run under an existing authorization key")
    mode = "evaluation_only" if args.evaluation_only else "investigation_and_evaluation"
    if journal and journal.get("mode", "investigation_and_evaluation") != mode:
        raise RuntimeError("Cannot change authorized scope under an existing request key")
    journal.update({"request_key": args.request_key, "mode": mode, "max_model_requests": 48 if args.evaluation_only else 52, "config_hash": config["config_hash"]})
    save()
    if not args.evaluation_only and "investigation" not in journal:
        if journal.get("investigation_submitted"):
            matches = [r for r in get("/events")["reviews"] if r.get("origin") == "manual_investigation"
                       and r.get("event_id") == journal["source_event"]["id"] and r.get("config_hash") == journal["config_hash"]]
            if len(matches) != 1:
                raise RuntimeError("Earlier investigation POST has unknown status. Reconcile /events before any new paid request.")
            journal["investigation"] = matches[0]
        else:
            candidates = get("/events")["events"]
            event = next((e for e in candidates if e["category"] == "coverage_gap"), None)
            if event is None:
                raise RuntimeError("A real analytics coverage event is required before paid investigation")
            observation = get("/events/" + event["id"])["observation"]
            assert observation["schema"] == 2 and observation["scenario"] == "analytics"
            journal["source_event"] = event
            journal["investigation_submitted"] = True
            save()
            journal["investigation"] = post("/events/investigate", {"id": event["id"], "revision": event["revision"],
                                                                   "agent_id": config["id"], "acknowledge_cost": True})
        save()
    review = None
    if not args.evaluation_only:
        investigation_id = journal["investigation"]["id"]
        review = wait(lambda: next(r for r in get("/events")["reviews"] if r["id"] == investigation_id),
                      lambda value: value["state"] not in ("queued", "running"))
        journal["investigation"] = review
        detail = get("/events/" + journal["source_event"]["id"])
        assert detail["event"] == journal["source_event"], "Investigation must not alter or close the source event"
        save()
        print("Investigation:", review["state"], investigation_id, flush=True)
    body = {"agent_id": config["id"], "request_key": args.request_key, "acknowledge_cost": True, "max_model_requests": 48}
    report = post("/evaluations", body)
    journal["evaluation_id"] = report["id"]
    save()
    repeated = post("/evaluations", body)
    assert repeated["id"] == report["id"], "Same request key must not spend a second budget"
    report_id = report["id"]
    report = wait(lambda: next(r for r in get("/evaluations")["reports"] if r["id"] == report_id),
                  lambda value: value["state"] not in ("queued", "running"))
    journal["evaluation"] = report
    save()
    assert report["reserved_model_requests"] <= 48
    assert get("/events")["automatic_model_budget"] == 0
    assert len(get("/agents")["jobs"]) == len(agents["jobs"]), "Evaluation must not rewrite publication test history"
    print("Evaluation:", report["state"], report_id, report.get("summary"), flush=True)
    for case in report["cases"]:
        result = case.get("result", {})
        print(case["scenario"], "expected=" + case["expected"], "actual=" + result.get("assessment", case["state"]),
              "passed=" + str(case["passed"]), "session=" + str(case.get("agent_session", "")))
    print("Saved exact provider evidence:", journal_file)
    if (review and review["state"] != "completed") or report["state"] != "completed" or not report["passed"]:
        raise SystemExit("QUALITY NOT PASSED: original failures retained; no automatic retry or success-shaped fallback.")
    print("PASS: twelve fixed synthetic cases" + ("; no investigation requested" if args.evaluation_only else " plus one real investigation; original event unchanged") + "; no automatic monitoring")


if __name__ == "__main__":
    main()
