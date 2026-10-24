#!/usr/bin/env python3
"""M5: explicit isolated setup and four local synthetic intakes, then bounded paid review."""
import argparse
import json
import re
import time
from pathlib import Path

from business_privacy import require
from declaration_review_test import BASE
from production_evidence_test import api, pages
from production_review_test import reviews
from route_ui_test import local_base
from utilization_test import MARKER, execute

SAVED = Path(__file__).resolve().parent / "data/production-m5-acceptance.json"
AUTHORIZATION = "m5-intake-20261020"
EXPECTED = {"A": "no_signal_on_checked_issues", "B": "risk_identified",
            "C": "information_required", "D": "no_signal_on_checked_issues"}


def save(value):
    SAVED.write_text(json.dumps(value, indent=2) + "\n")


def setup():
    load = ('Set sc=$System.OBJ.Load("/contest/dev/M5Provision.cls","ck") '
            'If $System.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } ')
    execute("%SYS", load + 'Do ##class(Contest.M5Provision).Foundation() '
            f'Write "{MARKER}",{{"foundation":true}}.%ToJSON(),!')
    execute("M5OBSERVATION", load + 'Do ##class(Contest.M5Provision).Install() '
            f'Write "{MARKER}",{{"installed":true}}.%ToJSON(),!')


def send(route, batch):
    require(route in EXPECTED and re.fullmatch(r"m5-[A-Za-z0-9-]{1,60}", batch), "Bounded synthetic fixture required")
    payload = {"patient_id": "SYNTHETIC-M5-" + route,
               "birthDate": "2001-02-03" if route == "B" else "2001", "status": "finished"}
    literal = json.dumps(payload).replace('"', '""')
    return execute("M5OBSERVATION", (
        f'Set request=##class(Contest.M5.Request).%New(), request.BatchId="{batch}", request.Route="{route}", '
        f'request.Format="json-object", request.PayloadJson="{literal}" '
        'Set sc=##class(Ens.Director).CreateBusinessService("M5Source",.service) '
        'If $System.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        'Set sc=service.ProcessInput(request,.reply) '
        'If $System.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        f'Write "{MARKER}",{{"batch":(request.BatchId),"message":(request.%Id()),"outcome":(reply.Outcome)}}.%ToJSON(),!'))


def captured(base, pid, message):
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        rows = [r for r in pages(base, pid) if r["header"]["body_class"] == "Contest.M5.Request"
                and str(r["header"]["body_id"]) == str(message)]
        if len(rows) == 2 and all(r["capture"]["state"] == "captured" for r in rows):
            return rows
        time.sleep(1)
    raise ValueError("M5 observer did not capture both request edges; no resend")


def acceptance(base):
    require(not SAVED.exists(), "M5 acceptance is immutable; inspect saved state, never repeat paid requests or sends")
    found = api(base, "/productions/discover")
    item = next(p for p in found["items"] if p["namespace"] == "M5OBSERVATION")
    baseline = {p["id"]: p["config_hash"] for p in found["items"] if p["id"] != item["id"]}
    enrolled = api(base, "/productions/enroll", {"namespace": item["namespace"], "production": item["production"],
        "config_hash": item["config_hash"], "acknowledge_monitoring": True})
    pid = enrolled["id"]
    require(not api(base, f"/productions/{pid}/flows")["items"], "No per-flow contexts/enrollment")
    api(base, "/productions/authorize-inspection", {"production_id": pid, "config_hash": item["config_hash"],
        "acknowledge_local_synthetic_inspection": True})
    saved = {"production_id": pid, "baseline_other_productions": baseline, "runs": [],
             "authorization_id": AUTHORIZATION, "state": "sending", "definitions": []}
    with SAVED.open("x") as output:
        json.dump(saved, output, indent=2)
        output.write("\n")
    for route in EXPECTED:
        if route == "D":
            before = api(base, f"/productions/{pid}/paths")["items"]
            require(not any(e["target"] == "ReceiverD" for e in before), "D must not already be observed")
            saved["before_d_edges"] = before
        run = {"route": route, "batch": "m5-" + route + "-" + str(time.time_ns()), "state": "send_requested"}
        saved["runs"].append(run)
        save(saved)
        result = send(route, run["batch"])
        run.update(result, state="delivered")
        save(saved)
        captured(base, pid, run["message"])
    plan = api(base, f"/productions/{pid}/review-plan")
    agents = [a for a in plan["eligible_agents"] if a["model"] == "deepseek-flash" and a["status"] == "published"]
    require(len(agents) == 1, "One pinned published reviewer required")
    agent = agents[0]
    body = {"authorization_id": AUTHORIZATION, "production_id": pid, "config_hash": plan["config_hash"],
        "agent_id": agent["id"], "source_revision": agent["revision"], "agent_config_hash": agent["config_hash"],
        "contract_hash": plan["contract_hash"], "every_n": 1, "max_reviews": 4, "max_model_requests": 8,
        "expires_at": int(plan["now"]) + 1800, "include_existing": True,
        "acknowledge_cost": True, "acknowledge_synthetic_data_export": True}
    saved["definitions"].append(body)
    saved["state"] = "authorization_requested"
    save(saved)
    try:
        api(base, "/productions/authorize-review", body)
        deadline = time.monotonic() + 900
        while time.monotonic() < deadline:
            _, items = reviews(base, pid)
            funded = [r for r in items if r.get("authorization_id") == AUTHORIZATION and r.get("reserved_model_requests")]
            if len(funded) == 4 and all(r["state"] not in ("pending", "running") for r in funded):
                break
            time.sleep(2)
        else:
            raise ValueError("M5 reviews did not finish; no automatic retry")
    finally:
        api(base, "/productions/revoke-review", {"production_id": pid, "authorization_id": AUTHORIZATION})
    saved["state"] = "review_finished"
    save(saved)
    check(base)


def check(base):
    saved = json.loads(SAVED.read_text())
    pid = saved["production_id"]
    require(isinstance(pid, str) and re.fullmatch(r"production-[a-f0-9]{64}", pid), "Exact saved Production identity required")
    require(len(saved["runs"]) == 4 and all(r["state"] == "delivered" for r in saved["runs"]), "Four persisted sends required")
    observations = pages(base, pid)
    page, items = reviews(base, pid)
    require(not page["error"] and not page["worker_error"], "Reviewer health failure")
    grant = next(g for g in page["authorizations"] if g["authorization_id"] == saved["authorization_id"])
    require(not grant["enabled"] and grant["used_reviews"] == 4 and grant["definition"] == saved["definitions"][0],
            "Exact spent and revoked M5 grant required")
    totals = {"requests": 0, "tokens": 0, "citations": 0}
    assessments = {}
    for run in saved["runs"]:
        rows = [r for r in observations if r["header"]["body_class"] == "Contest.M5.Request"
                and str(r["header"]["body_id"]) == str(run["message"])]
        require(len(rows) == 2 and all(r["capture"]["state"] == "captured" for r in rows), "Both request edges captured")
        matches = [r for r in items if r.get("reserved_model_requests") and r["id"] in {o["id"] for o in rows}]
        require(len(matches) == 1, "Exactly one paid review per forwarded session/body")
        review = matches[0]
        require(review["state"] == "completed", "Technical failure is not a finding: " + review.get("error", review["state"]))
        detail = api(base, f"/productions/{pid}/reviews/{review['header_id']}")
        report = detail["report"]
        evidence = review["business_evidence"]
        require(review["observation_hash"] == detail["evidence"]["record_hash"] == evidence["observation_hash"],
                "Observation/business evidence binding mismatch")
        require(evidence["receipt"]["readback_match"] is True and evidence["receipt"]["batch_id"] == run["batch"] and
                evidence["receipt"]["receiver"] == "Receiver" + run["route"], "Actual receiver readback mismatch")
        header = str(review["header_id"])
        require(re.fullmatch(r"[0-9]{1,15}", header), "Bounded persisted header identity required")
        live = execute("TRIAGE", (
            f'Set observation=##class(Contest.ProductionEvidence).Read("{pid}",{header}), '
            'actual=##class(Contest.ProductionBusinessEvidence).Read(observation) '
            f'Write "{MARKER}",{{"evidence_hash":(actual.%Get("evidence_hash"))}}.%ToJSON(),!'))
        require(live["evidence_hash"] == evidence["evidence_hash"],
                "Live receiver/message readback differs from frozen model evidence")
        assessment = review["result"]["assessment"]
        require(assessment == EXPECTED[run["route"]], f"Unexpected {run['route']} scoped assessment: {assessment}")
        assessments[run["route"]] = {"header": review["header_id"], "assessment": assessment, "report": report["id"]}
        require(review["context_state"] == "no_optional_context", "No manual contexts")
        require(report["packet"] == review["packet"] and report["reserved_model_requests"] == 2 and len(report["phases"]) == 2,
                "Two-phase exact packet/report binding required")
        require("SYNTHETIC-M5-" not in json.dumps(review), "Raw synthetic identifiers must not be exported")
        totals["requests"] += report["reserved_model_requests"]
        for phase in report["phases"]:
            require(phase["agent_session"] and phase["state"] == "returned" and
                    phase["sdk_stats"]["total_interactions"] == 1 and phase["sdk_stats"]["total_tool_calls"] == 0,
                    "Actual one-interaction tool-free AI Hub session required")
            totals["tokens"] += phase["usage"].get("total_tokens", 0)
        for issue in review["result"]["issues"]:
            for citation in issue["citations"]:
                source = next(h for package in report["packages"] if package["question_id"] == issue["question_id"]
                              for h in package["evidence"] if h["id"] == citation["evidence_id"])
                passage = next(p for p in source["passages"] if p["id"] == citation["passage_id"])
                require(source["source_hash_verified"] is True and source["section_text_complete"] is True and
                        source["metadata"]["retrieval_scope"] == "normative" and
                        source["text"][citation["start"]:citation["end"]] == citation["quote"] == passage["text"],
                        "Question-specific complete normative citation mismatch")
                totals["citations"] += 1
    require(totals["requests"] == 8, "Four bounded reviews must consume eight requests")
    risk_feed = api(base, f"/productions/{pid}/risks")
    original_reports = {a["report"] for a in assessments.values()}
    original_observations = {r["id"] for r in items if r.get("report_id") in original_reports}
    categories = [r["category"] for r in risk_feed["items"]
                  if r["source"] == "production_observation" and r["id"] in original_observations]
    require(sorted(categories) == sorted(["no_deviation_on_checked_use", "risk_identified",
                                         "information_required", "no_deviation_on_checked_use"]),
            "Scoped results missing from Production risk feed")
    paths = api(base, f"/productions/{pid}/paths")["items"]
    for route in EXPECTED:
        require(any(e["source"] == "M5Source" and e["target"] == "Process" + route for e in paths) and
                any(e["source"] == "Process" + route and e["target"] == "Receiver" + route for e in paths),
                "Automatic path discovery missing " + route)
    require(not any(e["target"] == "ReceiverD" for e in saved["before_d_edges"]), "D was not a newly observed path")
    require(not api(base, f"/productions/{pid}/flows")["items"], "No manual flow contexts")
    discovered = {p["id"]: p for p in api(base, "/productions/discover")["items"]}
    for other, config in saved["baseline_other_productions"].items():
        require(other in discovered and discovered[other]["config_hash"] == config, "Other active Production changed")
        other_page, other_reviews = reviews(base, other) if discovered[other]["managed"] else ({}, [])
        require(not any(r.get("authorization_id") == saved["authorization_id"] for r in other_reviews),
                "Cross-Production review budget leak")
    print(json.dumps({"status": "passed", "production_id": pid, "assessments": assessments, "usage": totals,
        "observations": len(observations), "edges": len(paths), "manual_contexts": 0,
        "authorization_revoked": True, "mode": "read_saved_M5_evidence", "new_model_calls": 0}, indent=2))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--setup", action="store_true")
    group.add_argument("--run-acceptance", action="store_true")
    group.add_argument("--check", action="store_true")
    parser.add_argument("--base", default=BASE)
    args = parser.parse_args(argv)
    local_base(args.base)
    if args.setup:
        setup()
    elif args.run_acceptance:
        acceptance(args.base)
    elif args.check:
        check(args.base)
    else:
        print("Inactive. --setup creates/starts isolated M5 runtime; --run-acceptance sends four synthetic batches and funds eight requests; --check only reads.")


if __name__ == "__main__":
    main()
