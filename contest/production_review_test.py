#!/usr/bin/env python3
"""Compile M3, inspect plans or explicitly fund three saved synthetic observations."""
import argparse
import json
import time
from pathlib import Path

from business_privacy import require
from declaration_review_test import BASE
from platform_test import request
from production_evidence_test import SAVED as EVIDENCE_SAVED, api, pages
from route_ui_test import admin_request, local_base
from utilization_test import MARKER, execute

SAVED = Path(__file__).resolve().parent / "data/production-review-acceptance.json"
AUTHORIZATION = "m3-initial-20261020"


def production():
    return json.loads(EVIDENCE_SAVED.read_text())["production_id"]


def reviews(base, pid):
    items, before, seen = [], 0, set()
    while True:
        page = api(base, f"/productions/{pid}/reviews?before={before}")
        require(page["production_id"] == pid, "Cross-Production review response")
        items.extend(page["items"])
        before = page["next_before"]
        require(type(before) is int and before >= 0, "Review cursor must be a nonnegative JSON integer")
        if not before:
            return page, items
        require(before not in seen, "Review cursor loop")
        seen.add(before)


def acceptance(base):
    require(not SAVED.exists(), "Acceptance is immutable; use --check, never repeat paid requests")
    pid = production()
    require(not api(base, f"/productions/{pid}/flows")["items"], "Acceptance must not register manual contexts")
    records = pages(base, pid)
    bodies = {(str(r["header"]["session_id"]), r["header"]["body_class"], str(r["header"]["body_id"]))
              for r in records if r["capture"]["state"] == "captured"}
    require(len(bodies) == 3, "Exactly three retained M2 session/body samples required; no business sends")
    plan = api(base, f"/productions/{pid}/review-plan")
    sources = [a for a in plan["eligible_agents"] if a["model"] == "deepseek-flash" and a["status"] == "published"]
    require(len(sources) == 1, "One exact published deepseek-flash reviewer required")
    source = sources[0]
    body = {
        "authorization_id": AUTHORIZATION, "production_id": pid, "config_hash": plan["config_hash"],
        "agent_id": source["id"], "source_revision": source["revision"], "agent_config_hash": source["config_hash"],
        "contract_hash": plan["contract_hash"], "every_n": 1, "max_reviews": 3, "max_model_requests": 6,
        "expires_at": int(plan["now"]) + 1800, "include_existing": True,
        "acknowledge_cost": True, "acknowledge_synthetic_data_export": True,
    }
    saved = {"production_id": pid, "authorization_id": AUTHORIZATION, "definition": body,
             "expected_reviews": 3, "max_model_requests": 6, "state": "authorization_requested"}
    with SAVED.open("x") as output:
        json.dump(saved, output, indent=2)
        output.write("\n")
    # Always attempt revocation, including a lost authorization response.
    try:
        api(base, "/productions/authorize-review", body)
        deadline = time.monotonic() + 600
        while time.monotonic() < deadline:
            _, items = reviews(base, pid)
            funded = [r for r in items if r.get("authorization_id") == AUTHORIZATION
                      and r.get("reserved_model_requests", 0)]
            if len(funded) == 3 and all(r["state"] not in ("pending", "running") for r in funded):
                break
            time.sleep(2)
        else:
            raise ValueError("M3 worker did not finish within 600 seconds; no retry, inspect durable reviews")
    finally:
        api(base, "/productions/revoke-review", {"production_id": pid, "authorization_id": AUTHORIZATION})
    check(base)


def check(base):
    saved = json.loads(SAVED.read_text())
    pid, auth = saved["production_id"], saved["authorization_id"]
    page, items = reviews(base, pid)
    require(not page["error"] and not page["worker_error"] and page["heartbeat"], "M3 worker health failure")
    grants = [g for g in page["authorizations"] if g["authorization_id"] == auth]
    require(len(grants) == 1, "Exact durable authorization required")
    grant = grants[0]
    require(not grant["enabled"], "Acceptance model authorization must be revoked")
    require(grant["definition"] == saved["definition"], "Authorized scope changed")
    funded = [r for r in items if r.get("authorization_id") == auth and r.get("reserved_model_requests", 0)]
    require(len(funded) == saved["expected_reviews"] == grant["used_reviews"] == 3, "Three exact funded samples required")
    requests, tokens, citations, edges = 0, 0, 0, set()
    for item in funded:
        require(item["state"] == "completed", "Failed/interrupted review is not a verdict: " + item["state"])
        detail = api(base, f"/productions/{pid}/reviews/{item['header_id']}")
        report, evidence = detail["report"], detail["evidence"]
        require(report["version"] == "production-review-v1" and report["state"] == "completed", "Wrong runtime/report")
        require(item["observation_hash"] == evidence["record_hash"], "Review not bound to exact observation")
        require(item["result"]["assessment"] == "information_required", "Unknown actual purpose/recipient cannot be all-clear")
        require(item["result"]["summary"]["unresolved"] and not item["result"]["summary"]["risk_detected"],
                "Missing context must not be invented into a HIPAA violation")
        require(item["result"]["missing_information"], "Concrete material questions required")
        require(item["context_state"] == "no_optional_context", "Manual context must not be a prerequisite")
        require(report["reserved_model_requests"] == 2 and len(report["phases"]) == 2, "Exactly two AI Hub phases")
        requests += report["reserved_model_requests"]
        edges.add((evidence["header"]["source"], evidence["header"]["target"]))
        for phase in report["phases"]:
            require(phase["agent_session"] and phase["state"] == "returned", "Persisted AI Hub session required")
            require(phase["sdk_stats"]["total_interactions"] == 1 and phase["sdk_stats"]["total_tool_calls"] == 0,
                    "Each phase must be a single tool-free AI Hub interaction")
            usage = phase.get("usage", {})
            tokens += usage.get("total_tokens", usage.get("input_tokens", 0) + usage.get("output_tokens", 0))
        for package in report["packages"]:
            for hit in package["evidence"]:
                require(hit["metadata"]["retrieval_scope"] == "normative", "Non-normative source")
        for issue in item["result"]["issues"]:
            for ref in issue["citations"]:
                source = next(hit for package in report["packages"] for hit in package["evidence"]
                              if hit["id"] == ref["evidence_id"])
                require(source["text"][ref["start"]:ref["end"]] == ref["quote"], "Citation span mismatch")
                citations += 1
    require(requests == saved["max_model_requests"] == 6 and len(edges) == 3, "Request budget or A/B/C coverage mismatch")
    require(any(r["state"] == "not_sampled_duplicate" for r in items), "Forwarded bodies must not cause double charging")
    risk_feed = api(base, f"/productions/{pid}/risks")
    linked = [r for r in risk_feed["items"] if r["source"] == "production_observation"]
    require(len(linked) == 3 and all(r["category"] == "information_required" for r in linked),
            "M3 outcomes missing from the existing Production risks feed")
    require(not api(base, f"/productions/{pid}/flows")["items"], "No manual flow registration")
    for endpoint in ("/productions/authorize-review", "/productions/revoke-review"):
        require(request(base, endpoint, body={})[0] == 403, "Reader cannot authorize model spending")
        require(admin_request(base, endpoint, {}, header=False)[0] == 403, "CSRF required")
    require(request(base, f"/productions/{pid}/reviews", account=None)[0] == 401, "Anonymous review access denied")
    require(admin_request(base, f"/productions/{pid}/reviews?before=1.5")[0] == 409, "Strict cursor")
    serialized = json.dumps(items)
    for raw in ("PRIVATE-SYNTHETIC-VALUE", "synthetic@example.invalid", "SYNTHETIC-M2-"):
        require(raw not in serialized, "Raw message value leaked to model facts")
    print(json.dumps({"status": "passed", "production_id": pid, "completed_reviews": 3,
                      "model_requests": requests, "reported_tokens": tokens, "verified_citations": citations,
                      "assessment": "information_required", "authorization_revoked": True,
                      "new_business_messages": 0, "manual_flow_records": 0}, indent=2))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--install", action="store_true")
    group.add_argument("--plan", action="store_true")
    group.add_argument("--authorize-acceptance", action="store_true",
                       help="Requires separate user approval: at most three reviews / six real requests")
    group.add_argument("--check", action="store_true")
    parser.add_argument("--base", default=BASE)
    args = parser.parse_args(argv)
    local_base(args.base)
    base = args.base
    if args.install:
        paths = ("RiskReview", "HIPAAReview", "ProductionBusinessEvidence", "ProductionReview", "ProductionReviewService", "ProductionEvidence",
                 "ProductionMonitor", "ProductionFlow", "KnowledgeAPI", "RouteReview")
        literals = ",".join('"/contest/src/' + name + '.cls"' for name in paths)
        execute("TRIAGE", 'For path=' + literals + ' { Set sc=$System.OBJ.Load(path,"ck") '
                'If $System.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } '
                'For path="/contest/dev/ProductionReviewTests.cls","/contest/dev/ProductionPremiseTests.cls","/contest/dev/ProductionMonitorTests.cls","/contest/dev/ProductionEvidenceTests.cls" { '
                'Set sc=$System.OBJ.Load(path,"ck") '
                'If $System.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } '
                f'Write "{MARKER}",{{"compiled":true}}.%ToJSON(),!', label="M3 compile-only installation")
        print("Compiled M3 only. No budget grant, business send or model call.")
    elif args.plan:
        print(json.dumps(api(base, f"/productions/{production()}/review-plan"), indent=2))
    elif args.authorize_acceptance:
        acceptance(base)
    elif args.check:
        check(base)
    else:
        print("Inactive. --install compiles, --plan reads; --authorize-acceptance explicitly funds six requests; --check reads.")


if __name__ == "__main__":
    main()
