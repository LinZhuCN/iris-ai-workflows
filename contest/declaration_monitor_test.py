#!/usr/bin/env python3
"""Install D5 or read and verify automatic monitoring; never sends or calls a model."""
import argparse
import json

from business_privacy import require
from declaration_review_test import BASE
from route_ui_test import admin_request, local_base
from platform_test import request
from utilization_test import MARKER, execute


def check(base, run_id):
    code, run = admin_request(base, "/declarations/executions/" + run_id)
    require(code == 200 and run["state"] == "delivered", "Verified delivered execution required")
    code, item = admin_request(base, "/declarations/monitor/" + run_id)
    require(code == 200 and item["origin"] == "automatic_after_send", "Independent observer capture required")
    evidence = item["evidence"]
    require(evidence["record_id"] == run["grant"]["record"]["id"] and
            evidence["decision_hash"] == run["grant"]["consent"]["decision_hash"] and
            evidence["task_hash"] == run["grant"]["consent"]["task_hash"] and
            evidence["receipt_hash"] == run["receipt"]["receipt_hash"], "Exact historical approved use required")
    require(item["state"] == "completed" and item["result"] is not None, "Real automatic AI comparison incomplete")
    report = item["report"]
    interactions = prompt = completion = citations = 0
    for phase in report["phases"]:
        usage = phase["sdk_stats"]
        interactions += usage["total_interactions"]
        prompt += usage["total_prompt_tokens"]
        completion += usage["total_completion_tokens"]
        require(usage["total_tool_calls"] == 0, "After-send reviewer must not expose tools")
    require(interactions == item["attempted_requests"] == item["reserved_requests"] == 2, "Exact two-phase SDK usage required")
    packages = {p["question_id"]: p for p in report["packages"]}
    for issue in item["result"]["issues"]:
        hits = {hit["id"]: hit for hit in packages[issue["question_id"]]["evidence"]}
        for citation in issue["citations"]:
            hit = hits[citation["evidence_id"]]
            require(hit["source_hash_verified"] and hit["text"][citation["start"]:citation["end"]] == citation["quote"],
                    "Exact source-backed observed-use citation required")
            citations += 1
    require(citations > 0, "Real cited result required")
    require(request(base, "/declarations/monitor/authorize", body={})[0] == 403, "Reader cannot authorize AI")
    require(request(base, "/declarations/monitor/action", body={})[0] == 403, "Reader cannot mutate event")
    require(request(base, f"/declarations/monitor/{run_id}/plan")[0] == 403, "Cost plan is writer-only")
    print(json.dumps({
        "run": run_id, "batch": evidence["batch_id"], "review": item["state"],
        "summary": item["result"]["summary"], "event": item["event"]["state"],
        "agent_sessions": [p["agent_session"] for p in report["phases"]],
        "requests": interactions, "prompt_tokens": prompt, "completion_tokens": completion,
        "total_tokens": prompt + completion, "verified_citations": citations,
        "receipt_hash": evidence["receipt_hash"],
    }, indent=2))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--install", action="store_true")
    group.add_argument("--check", action="store_true")
    parser.add_argument("--run-id")
    parser.add_argument("--base", default=BASE)
    args = parser.parse_args(argv)
    local_base(args.base)
    if args.check and not args.run_id:
        parser.error("--check requires --run-id")
    if args.install:
        code = ('For path="/contest/src/DeclarationMonitor.cls","/contest/src/DeclarationExecution.cls",'
                '"/contest/src/KnowledgeAPI.cls","/contest/src/RouteReview.cls","/contest/dev/DeclarationMonitorTests.cls" { '
                'Set sc=$SYSTEM.OBJ.Load(path,"ck") '
                'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } ')
        execute("TRIAGE", code + f'Write "{MARKER}",{{"compiled":true}}.%ToJSON(),!')
        print("Compiled observer and fresh-worker hook. Existing timer discovers batches. No manual scan, model grant, delivery or Production restart.")
    elif args.check:
        check(args.base, args.run_id)
    else:
        print("Inactive. --install only compiles; --check only reads. Fund exact receipts separately from the page.")


if __name__ == "__main__":
    main()
