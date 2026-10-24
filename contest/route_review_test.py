#!/usr/bin/env python3
"""Install/observe automatic route monitoring. Only --authorize-four-requests enables two pinned model reviews."""
import argparse
import json
from pathlib import Path

from business_privacy import require
from route_evidence_test import receipt_pin
from route_ui_test import admin_request
from platform_test import request
from staged_risk_acceptance import save_immutable
from staged_risk_evaluation_test import verify_report
from staged_risk_smoke import source_records, verify_source
from utilization_test import MARKER, execute
from utilization_test import run_command, validate as validate_utilization

ROOT = Path(__file__).resolve().parent
TARGETS = (("aggregation", "aggregation-internal-demo"), ("utilization", "utilization-quality-demo"))
ACCEPTANCE = "p6-v4-20261016"
NEW_BATCH = "utilization-20261016-acceptance-v4"


def literal(value):
    return json.dumps(value, ensure_ascii=True, separators=(",", ":")).replace('"', '""')


def configure(authorize):
    freeze = json.loads((ROOT / "fixtures/staged-risk-freeze-v1.json").read_text())
    source = freeze["source"]
    config = {"agent_id": freeze["source_agent_id"], "source_revision": source["revision"],
              "config_hash": source["config_hash"]}
    grants = [{"kind": kind, "batch": batch, "receipt_hash": receipt_pin(
        ROOT / "data/evaluations" / f"{batch}-{kind}.json", kind, batch)} for kind, batch in TARGETS]
    return (
        f'Set config={{}}.%FromJSON("{literal(config)}"), grants=[].%FromJSON("{literal(grants)}") '
        'Do config.%Set("contract_hash",##class(Contest.RiskReviewV4).ContractHash()) '
        f'Do ##class(Contest.RouteReview).Configure(config,grants,{int(authorize)}) '
        f'Write "{MARKER}",{{"configured":true,"authorized_model_requests":{4 if authorize else 0}}}.%ToJSON(),!'
    )


def snapshot():
    value = execute("TRIAGE",
                    'Set result=##class(Contest.RouteReview).List(), details=[], reports=[] '
                    'For i=0:1:result.items.%Size()-1 { '
                    'Set item=##class(Contest.RouteReview).Detail(result.items.%Get(i).id) '
                    'Do details.%Push(item) '
                    'If item.%IsDefined("report_id") Do reports.%Push(##class(Contest.RiskReviewV3).Status(item.%Get("report_id"))) } '
                    f'Write "{MARKER}",$ZConvert({{"monitor":(result),"details":(details),"reports":(reports)}}.%ToJSON(),"O","UTF8"),!',
                    label="Route monitoring read")
    require(not value["monitor"]["next_cursor"], "Snapshot needs pagination; do not silently truncate")
    return value


def verify(value):
    require(value["monitor"]["enabled"] == 1 and value["monitor"]["heartbeat"] > 0 and
            not value["monitor"]["error"], "Automatic observer must be responsive")
    targets = {kind + "-" + batch for kind, batch in TARGETS}
    items = {item["id"]: item for item in value["details"]}
    require(targets <= items.keys(), "Both original routes must be automatically observed")
    total = 0
    completed = 0
    sessions = []
    for key in targets:
        item = items[key]
        require(item["state"] in ("completed", "failed", "interrupted") and item["origin"] == "automatic_after_send" and
                item["pin_basis"] == "independent_original_receipt", "Real automatically terminal review required")
        require(item["execution"] == "not_executed", "No business execution allowed")
        require(item["actual_model_requests"] <= 2 and item["reserved_model_requests"] == 2, "Per-batch budget exceeded")
        report = next(r for r in value["reports"] if r["id"] == item["report_id"])
        verify_report(report, item["evidence"]["packet"], report["authorization"], "staged-risk-v4")
        require(report["packet"] == item["evidence"]["packet"] and
                report["version"] == "staged-risk-v4" and report["source"]["model"] == "deepseek-flash",
                "Model input/runtime mismatch")
        if item["state"] == "completed":
            completed += 1
            require(report["result"] == item["result"] and
                    item["result"]["summary"]["execution"] == "not_executed" and
                    item["result"]["summary"]["recommended_action"] == "manual_review", "Accepted after-send result mismatch")
        else:
            require("result" not in item and "result" not in report and
                    item["event"]["category"] == "technical_failure", "Technical failure cannot become a privacy verdict")
        for phase in report["phases"]:
            require(phase["sdk_stats"]["total_interactions"] <= 1 and
                    (phase["state"] != "returned" or phase["sdk_stats"]["total_interactions"] == 1),
                    "At most one interaction per phase; failed provider calls can have no reported counters")
            sessions.append(phase["agent_session"])
        total += item["actual_model_requests"]
    require(total <= 4 and len(set(sessions)) == len(sessions), "Global four-request cap or session uniqueness failed")
    require(all(item["reserved_model_requests"] == 0 for key, item in items.items()
                if key not in targets and "authorization_id" not in item),
            "Unfunded history must not consume model budget")
    return {"terminal_reviews": 2, "completed": completed, "technical_failures": 2 - completed,
            "reserved_requests": total}


def acceptance_command():
    targets = [{"kind": kind, "batch": batch, "receipt_hash": receipt_pin(
        ROOT / "data/evaluations" / f"{batch}-{kind}.json", kind, batch)} for kind, batch in TARGETS]
    targets.append({"kind": "utilization", "batch": NEW_BATCH, "receipt_hash": ""})
    return (f'Set targets=[].%FromJSON("{literal(targets)}") '
            f'Do ##class(Contest.RouteReview).AuthorizeAcceptance("{ACCEPTANCE}",targets) '
            f'Write "{MARKER}",{{"authorization_id":"{ACCEPTANCE}","max_model_requests":6}}.%ToJSON(),!')


def verify_acceptance(value):
    items = {d["id"]: d for d in value["details"] if d.get("authorization_id") == ACCEPTANCE}
    expected = [f"{kind}-{batch}-{ACCEPTANCE}" for kind, batch in TARGETS] + ["utilization-" + NEW_BATCH]
    require(set(items) == set(expected), "Three exact acceptance targets required")
    sessions = []
    total = 0
    citations = 0
    freeze = json.loads((ROOT / "fixtures/staged-risk-freeze-v1.json").read_text())
    records = source_records(freeze)
    for key in expected:
        item = items[key]
        require(item["state"] == "completed", f"Acceptance task did not complete: {key} / {item['state']}")
        report = next(r for r in value["reports"] if r["id"] == item["report_id"])
        require(report["version"] == "staged-risk-v4" and report["packet"] == item["evidence"]["packet"] and
                report["state"] == "completed" and report["result"] == item["result"], "V4 report provenance mismatch")
        require(report["source"]["model"] == "deepseek-flash" and report["reserved_model_requests"] == 2 and
                item["actual_model_requests"] == 2, "Pinned model/two-phase cap required")
        require(report["source"]["id"] == freeze["source_agent_id"] and
                all(report["source"][field] == freeze["source"][field]
                    for field in ("revision", "config_hash", "index_version", "corpus")), "Original source Agent/index changed")
        consent = report["authorization"]
        require(consent["request_key"] == "route-" + key and consent["acknowledge_cost"] is True and
                consent["max_model_requests"] == 2 and consent["agent_id"] == report["source"]["id"] and
                consent["source_revision"] == report["source"]["revision"] and
                consent["config_hash"] == report["source"]["config_hash"], "Exact task/source consent required")
        require(item["result"]["summary"]["recommended_action"] == "manual_review" and
                item["execution"] == item["result"]["summary"]["execution"] == "not_executed",
                "Review cannot execute or hold a delivered task")
        require(len(report["phases"]) == 2 and [p["phase"] for p in report["phases"]] == ["locate", "judge"],
                "Two unique real phases required")
        for phase in report["phases"]:
            require(phase["sdk_stats"]["total_interactions"] == 1 and phase["sdk_stats"]["total_tool_calls"] == 0,
                    "Exactly one tool-free model interaction per phase")
            sessions.append(phase["agent_session"])
        packages = {p["question_id"]: p for p in report["packages"]}
        for package in packages.values():
            for hit in package["evidence"]:
                verify_source(hit, records)
        facts = {f["id"]: f for f in report["packet"]["facts"]}
        for issue in item["result"]["issues"]:
            require("applicability" in issue and "condition_status" in issue and
                    "affirmative_fact_ids" in issue and "exceptions" in issue, "Explicit condition chain required")
            if issue["status"] == "risk_signal":
                require(issue["applicability"] == "applicable" and issue["condition_status"] == "not_met" and
                        issue["exceptions"]["status"] == "resolved" and issue["affirmative_fact_ids"] and
                        all(facts[f]["kind"] == "observation" and facts[f]["verification"] == "verified"
                            for f in issue["affirmative_fact_ids"]), "Unknown/claim cannot establish a failed applicable condition")
            hits = {hit["id"]: hit for hit in packages[issue["question_id"]]["evidence"]}
            for citation in issue["citations"]:
                hit = hits[citation["evidence_id"]]
                passage = next(p for p in hit["passages"] if p["id"] == citation["passage_id"])
                require(citation["quote"] == passage["text"] ==
                        hit["text"][citation["start"]:citation["end"]] and
                        citation["start"] == passage["start"] and citation["end"] == passage["end"],
                        "Materialized citation differs from frozen canonical source")
                citations += 1
        total += report["reserved_model_requests"]
    require(total == 6 and len(set(sessions)) == 6, "Six-request global cap and session uniqueness required")
    fresh = items["utilization-" + NEW_BATCH]
    receipt = json.loads((ROOT / f"data/evaluations/{NEW_BATCH}-utilization.json").read_text())
    require(fresh["trigger"] == "new_completed_batch" and fresh["origin"] == "automatic_after_send" and
            fresh["evidence"]["provenance"]["receipt_hash"] == receipt["receipt_hash"] and
            fresh["created"] >= receipt["received_at"] and
            fresh["evidence"]["observed"]["message_id"] == receipt["message_id"],
            "New actual delivery must precede automatic capture with exact receipt/message linkage")
    return {"completed": 3, "model_requests": total, "new_delivery": NEW_BATCH,
            "materialized_citations_verified": citations, "independent_legal_review": "not_performed"}


def check():
    base = "http://127.0.0.1:5173/api/monitor/v1"
    require(request(base, "/route-reviews", account=None)[0] == 401, "Anonymous access must fail")
    status, value = request(base, "/route-reviews")
    require(status == 200 and value["enabled"] == 1 and value["heartbeat"] > 0, "Real automatic observer required")
    require(request(base, "/route-reviews", body={})[0] == 403, "Readers cannot record actions")
    require(admin_request(base, "/route-reviews", {}, header=False)[0] == 403, "CSRF header required")
    require(admin_request(base, "/route-reviews", {"id": "invalid", "revision": 1,
                                                 "action": "deliver", "text": "No execution"})[0] == 409,
            "No execution action permitted")
    for item in value["items"]:
        status, detail = request(base, "/route-reviews/" + item["id"])
        require(status == 200 and detail["execution"] == "not_executed", "Read-only review detail required")
    print("PASS real route-review HTTP auth/read/action/CSRF boundaries; no model or mutation.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--install", action="store_true")
    modes.add_argument("--observe", action="store_true")
    modes.add_argument("--authorize-four-requests", action="store_true")
    modes.add_argument("--status", action="store_true")
    modes.add_argument("--snapshot", action="store_true")
    modes.add_argument("--check", action="store_true")
    modes.add_argument("--authorize-acceptance-six", action="store_true")
    modes.add_argument("--deliver-new", action="store_true")
    modes.add_argument("--acceptance-snapshot", action="store_true")
    args = parser.parse_args(argv)
    if args.install:
        paths = ["/contest/src/RouteScenario.cls", "/contest/src/RouteGovernance.cls",
                 "/contest/src/RouteEvidence.cls", "/contest/src/RiskReviewV4.cls",
                 "/contest/src/RouteReview.cls", "/contest/src/KnowledgeAPI.cls", "/contest/src/MonitorInbox.cls"]
        action = 'For path=' + ",".join(json.dumps(p) for p in paths) + ' { Set sc=$SYSTEM.OBJ.Load(path,"ck") If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } '
        execute("TRIAGE", action + f'Write "{MARKER}",{{"installed":true}}.%ToJSON(),!', label="Route monitor installation")
        print("Compiled observer/API/timer hook. No Production restart or budget authorization.")
    elif args.observe or args.authorize_four_requests:
        value = execute("TRIAGE", configure(args.authorize_four_requests), label="Route monitoring configuration")
        print(json.dumps(value))
        print("The existing Production timer discovers batches and runs workers automatically; no browser or manual Pump call.")
    elif args.authorize_acceptance_six:
        print(json.dumps(execute("TRIAGE", acceptance_command(), label="Explicit six-request acceptance authorization")))
    elif args.deliver_new:
        execute("TRIAGE",
                f'If \'$Data(^ContestRouteReview("acceptance","{ACCEPTANCE}")) {{ Do ##class(Demo.Protocol).Fail("Explicit acceptance authorization required before new delivery") }} '
                f'Write "{MARKER}",{{"authorized":true}}.%ToJSON(),!', label="Delivery authorization check")
        receipt = execute("UTILIZATION", run_command(NEW_BATCH), label="New synthetic acceptance delivery")
        validate_utilization(receipt)
        save_immutable(ROOT / f"data/evaluations/{NEW_BATCH}-utilization.json", receipt)
        print(f"Delivered {NEW_BATCH} through existing BS/BP/BO and SQL receiver. Background observer performs capture/review, not this command.")
    elif args.acceptance_snapshot:
        value = snapshot()
        summary = verify_acceptance(value)
        path = ROOT / f"data/evaluations/route-monitor-{ACCEPTANCE}.json"
        if path.exists():
            previous = json.loads(path.read_text())
            require(previous["reports"] == value["reports"], "Frozen acceptance reports changed")
        else:
            save_immutable(path, value)
        print("PASS " + json.dumps(summary) + "; no legal accuracy claim.")
    elif args.check:
        check()
    elif args.status or args.snapshot:
        value = snapshot()
        if args.snapshot:
            path = ROOT / "data/evaluations/route-monitor-p6-20261016.json"
            summary = verify(value)
            if path.exists():
                previous = json.loads(path.read_text())
                current = {r["id"]: r for r in value["reports"]}
                require(all(current.get(r["id"]) == r for r in previous["reports"]), "Frozen original model reports changed")
            else:
                save_immutable(path, value)
            print(f"PASS automatic intake/budget/terminal provenance: {summary}; immutable journal: {path.name}")
            print("Technical failures are not successful AI assessments; snapshot verification never retries them.")
        else:
            print(json.dumps(value["monitor"], indent=2))
    else:
        print("Inactive. Choose --install, --observe (no new model consent), or explicitly --authorize-four-requests.")


if __name__ == "__main__":
    main()
