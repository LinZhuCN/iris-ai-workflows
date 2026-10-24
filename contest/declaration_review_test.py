#!/usr/bin/env python3
"""D2 declaration review: explicit initial consent and read-only checks including all funded revision history."""
import argparse
import json
import time

from business_privacy import require
from platform_test import request
from route_ui_test import admin_request, local_base
from utilization_test import MARKER, execute

TARGETS = ("demo-declaration-quality", "demo-declaration-marketing", "demo-declaration-incomplete")
BASE = "http://127.0.0.1:5173/api/monitor/v1"


def records(base):
    status, result = admin_request(base, "/declarations")
    require(status == 200, "Declaration list failed")
    values = {item["declaration_id"]: item for item in result["items"]}
    require(all(key in values for key in TARGETS), "Three explicit acceptance declarations are required")
    return {key: values[key] for key in TARGETS}


def review_three(base):
    local_base(base)
    selected = records(base)
    # Explicit applicant premises are fixed before any Agent call, not repaired after a verdict.
    marketing = selected[TARGETS[1]]
    if marketing["review"]["task"] is None:
        proposal = json.loads(json.dumps(marketing["proposal"]))
        proposal["arrangements"] = {
            "status": "not_relied_upon",
            "details": "No individual authorization is proposed for this identifiable-data marketing disclosure. "
                       "No exception to the marketing authorization requirement or alternative permission is relied upon.",
        }
        if proposal != marketing["proposal"]:
            status, marketing = admin_request(base, "/declarations", {
                "declaration_id": marketing["declaration_id"], "expected_revision": marketing["revision"],
                "expected_digest": marketing["digest"], "proposal": proposal,
            })
            require(status == 200, "Prepare explicit marketing applicant premises failed")
            selected[TARGETS[1]] = marketing
    plans = []
    for key, record in selected.items():
        status, submitted = admin_request(base, "/declarations/submit", {
            "record_id": record["id"], "digest": record["digest"],
        })
        require(status == 200, "Submission failed for " + key)
        require(submitted["review"]["task"]["state"] == "blocked_budget",
                "Acceptance never refills or retries a previously funded task")
        status, plan = admin_request(base, "/declarations/" + record["id"] + "/review-plan")
        require(status == 200 and plan["consent"]["max_model_requests"] == 2,
                "Pinned two-request plan required for " + key)
        plan["consent"]["acknowledge_cost"] = True
        plans.append((key, plan["consent"]))
    for key, consent in plans:
        status, queued = admin_request(base, "/declarations/review", consent)
        require(status == 200, "Queue failed for " + key + ": " + repr(queued))
        print(json.dumps({"declaration": key, "task": queued["review"]["task"]["id"],
                          "state": queued["review"]["task"]["state"], "max_requests": 2}), flush=True)
    print("Authorized at most six requests total. No automatic retry or business delivery.", flush=True)


def acceptance_history(base, selected):
    revisions = []
    for key, current in selected.items():
        status, history = admin_request(base, "/declarations/" + key + "/history")
        require(status == 200 and not history["has_older"],
                "Complete bounded acceptance history required; never omit older funded attempts")
        require(any(record["id"] == current["id"] for record in history["items"]),
                "Acceptance history must include the current revision")
        for record in history["items"]:
            task = record["review"]["task"]
            if record["id"] == current["id"] or (task and task["reserved_requests"]):
                revisions.append((key, record))
    return revisions


def check(base, wait_seconds=0):
    deadline = time.monotonic() + wait_seconds
    while True:
        selected = records(base)
        states = [r["review"]["task"]["state"] if r["review"]["task"] else "not_submitted"
                  for r in selected.values()]
        if all(state in ("completed", "failed") for state in states) or time.monotonic() >= deadline:
            break
        time.sleep(3)
    total_reserved = total_attempts = total_interactions = prompt_tokens = completion_tokens = citations = 0
    output, previous_output = [], []
    for key, record in acceptance_history(base, selected):
        task = record["review"]["task"]
        require(task and task["state"] in ("completed", "failed"), "Review not terminal: " + key)
        require(task["reserved_requests"] == task["runtime"]["authorization"]["max_model_requests"] == 2,
                "Each separately funded task must retain its exact two-request allowance")
        total_reserved += task["reserved_requests"]
        total_attempts += task["attempted_requests"]
        status, report = admin_request(base, "/declarations/" + record["id"] + "/review-report")
        require(status == 200 and report["version"] == "declaration-review-v1", "Actual declaration report required")
        require(report["authorization"]["input_hash"] == task["runtime"]["authorization"]["input_hash"],
                "Report must match the funded proposal")
        require(report["reserved_model_requests"] == task["attempted_requests"], "Attempt count mismatch")
        require(task["runtime"]["session_id"] and task["runtime"]["message_id"], "Real Interoperability linkage required")
        for phase in report["phases"]:
            stats = phase.get("sdk_stats", {})
            total_interactions += stats.get("total_interactions", 0)
            prompt_tokens += stats.get("total_prompt_tokens", 0)
            completion_tokens += stats.get("total_completion_tokens", 0)
        item = {"declaration": key, "revision": record["revision"], "state": task["state"],
                "assessment": task["assessment"], "attempts": task["attempted_requests"],
                "session": task["runtime"]["session_id"], "report": report["id"],
                "agent_sessions": [phase["agent_session"] for phase in report["phases"]],
                "contract_hash": report["authorization"]["contract_hash"]}
        if task["state"] == "completed":
            result = task["result"]
            require(result == report["result"] and result["assessment"] == task["assessment"], "Bound result mismatch")
            packages = {p["question_id"]: p for p in report["packages"]}
            for issue in result["issues"]:
                hits = {hit["id"]: hit for hit in packages[issue["question_id"]]["evidence"]}
                for citation in issue["citations"]:
                    hit = hits[citation["evidence_id"]]
                    require(hit["text"][citation["start"]:citation["end"]] == citation["quote"],
                            "Materialized citation must match exact source offsets")
                    require(hit["source_hash_verified"] is True, "Complete source hash must be verified")
                    citations += 1
            item["missing_information"] = result["missing_information"]
            item["explanations"] = [issue["explanation"] for issue in result["issues"]]
        else:
            require(task["assessment"] is None and task["result"] is None, "Failure must not contain a verdict")
            item["error"] = task["runtime"]["error"]
        (output if record["id"] == selected[key]["id"] else previous_output).append(item)
    require(total_attempts == total_interactions <= total_reserved,
            "Historical attempts/SDK usage must agree within the sum of all explicit per-task allowances")
    print(json.dumps({"reviews": output, "previous_reviews": previous_output,
                      "reserved_requests": total_reserved, "attempted_requests": total_attempts,
                      "sdk_interactions": total_interactions, "prompt_tokens": prompt_tokens,
                      "completion_tokens": completion_tokens, "materialized_citations": citations},
                     ensure_ascii=False, indent=2))
    require(all(item["state"] == "completed" for item in output), "At least one real Agent review failed")
    expected = ("no_risk_identified", "risk_identified", "information_required")
    require(tuple(item["assessment"] for item in output) == expected,
            "Actual assessment differs from the frozen three-case expectation; do not relabel or retry automatically")


def boundaries(base):
    require(request(base, "/declarations/review", body={})[0] == 403, "Readers cannot fund reviews")
    require(request(base, "/declarations/recover", body={})[0] == 403, "Readers cannot recover workers")
    selected = records(base)
    for record in selected.values():
        path = "/declarations/" + record["id"] + "/review-plan"
        require(request(base, path)[0] == 403, "Cost planning requires write capability")
        status, plan = admin_request(base, path)
        if status == 200:
            require(plan["model_calls"] == 0 and plan["consent"]["acknowledge_cost"] is False,
                    "Planning must not authorize inference")
            require(admin_request(base, "/declarations/review", plan["consent"])[0] == 409,
                    "Cost acknowledgment must not default true")
    print("PASS D2 read/write boundaries and non-authorizing plans. No model calls.")


def status(base):
    for key, record in records(base).items():
        task = record["review"]["task"]
        print(json.dumps({"declaration": key, "revision": record["revision"],
                          "state": None if task is None else task["state"],
                          "assessment": None if task is None else task["assessment"],
                          "reserved_requests": 0 if task is None else task["reserved_requests"],
                          "attempted_requests": 0 if task is None else task["attempted_requests"],
                          "report_id": None if task is None else task.get("runtime", {}).get("report_id")},
                         ensure_ascii=False))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--install", action="store_true")
    group.add_argument("--activate-hosts", action="store_true")
    group.add_argument("--authorize-six-requests", action="store_true")
    group.add_argument("--check", action="store_true")
    group.add_argument("--boundaries", action="store_true")
    group.add_argument("--status", action="store_true")
    parser.add_argument("--wait-seconds", type=int, default=0)
    parser.add_argument("--base", default=BASE)
    args = parser.parse_args(argv)
    local_base(args.base)
    if args.install:
        paths = ["/contest/src/" + name + ".cls" for name in (
            "RiskReview", "RiskEvidence", "DeclarationEvidence", "DeclarationReview", "DeclarationService", "DeclarationReviewRequest",
            "DeclarationReviewReply", "DeclarationQueue", "DeclarationReviewService", "DeclarationReviewProcess",
            "KnowledgeAPI")]
        paths += ["/contest/dev/DeclarationReviewTests.cls", "/contest/dev/DeclarationProvision.cls"]
        code = "For path=" + ",".join(json.dumps(path) for path in paths) + (
            ' { Set sc=$SYSTEM.OBJ.Load(path,"ck") '
            'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } ')
        execute("TRIAGE", code + f'Write "{MARKER}",{{"compiled":true}}.%ToJSON(),!', label="D2 compilation")
        print("Compiled D2 only; no hosts activated, no model calls.")
    elif args.activate_hosts:
        execute("TRIAGE", 'Do ##class(Contest.DeclarationProvision).Activate() ' +
                f'Write "{MARKER}",{{"activated":true}}.%ToJSON(),!', label="D2 host activation")
        print("Added two declaration review hosts using local Production update, not a Production restart.")
    elif args.authorize_six_requests:
        review_three(args.base)
    elif args.check:
        require(0 <= args.wait_seconds <= 1200, "Bounded wait required")
        check(args.base, args.wait_seconds)
    elif args.boundaries:
        boundaries(args.base)
    elif args.status:
        status(args.base)
    else:
        print("Inactive. Installation, host activation, paid authorization and read-only verification are separate.")


if __name__ == "__main__":
    main()
