#!/usr/bin/env python3
"""Three prospective demo cases: --run sends three local messages and funds <=6 requests; --check is read-only."""
import argparse
import json
import time
from pathlib import Path

from business_privacy import fingerprint, require
from declaration_review_test import BASE
from hipaa_conditions_test import grade, load as legal_sources
from production_acceptance_test import captured, send
from production_evidence_test import api, pages
from production_review_test import reviews
from route_ui_test import local_base

ROOT = Path(__file__).resolve().parent
SUITE = ROOT / "fixtures/production-premises-v1.json"
SAVED = ROOT / "data/production-premises-20261020.json"
FOLLOWUP = ROOT / "data/production-premises-20261020-treatment-mapping.json"


def load(followup=False):
    suite = json.loads(SUITE.read_text())
    require(suite["schema"] == 1 and suite["suite"] == "production-premises-v1" and
            [c["id"] for c in suite["cases"]] == ["treatment", "marketing", "unknown"], "Fixed three-case suite required")
    if followup:
        suite["suite"] = "production-premises-v1-treatment-mapping-followup"
        suite["cases"] = suite["cases"][:1]
        suite["cases"][0]["premises"].update(
            recipient_mapping="M5Source and ProcessB are internal hospital transport components. ReceiverB represents the named synthetic external treating clinic in this simulation; ProcessB is not a separate business recipient. The original forward through these technical hosts is the disclosure described by this approval.",
            data_scope="All patient_id, full birthDate and status fields in this session refer to the same referred synthetic patient and treatment episode described above. No extra patient or unrelated activity is included.")
    return suite


def persist(saved, path):
    path.write_text(json.dumps(saved, indent=2) + "\n")


def await_review(base, pid, auth):
    deadline = time.monotonic() + 420
    while time.monotonic() < deadline:
        page, items = reviews(base, pid)
        require(not page["error"] and not page["worker_error"], "Background reviewer error; inspect retained evidence")
        funded = [r for r in items if r.get("authorization_id") == auth and r.get("reserved_model_requests")]
        require(len(funded) <= 1, "Session approval funded more than one body")
        if funded and funded[0]["state"] not in ("pending", "running"):
            return funded[0]
        time.sleep(2)
    raise ValueError("Review timeout; no automatic retry, refund or resend")


def run(base, followup=False):
    path = FOLLOWUP if followup else SAVED
    require(not path.exists(), "Acceptance is immutable; use --check, never repeat sends or paid requests")
    suite = load(followup)
    if followup:
        first = json.loads((ROOT / "data/production-premises-20261020.json").read_text())
        require(first["state"] == "finished" and len(first["runs"]) == 3 and
                all(r["state"] == "completed" for r in first["runs"]), "Retain completed original attempt before explicit follow-up")
    discovery = api(base, "/productions/discover")
    source = next(p for p in discovery["items"] if p["namespace"] == "M5OBSERVATION")
    pid = source["id"]
    plan = api(base, f"/productions/{pid}/review-plan")
    agents = [a for a in plan["eligible_agents"] if a["model"] == "deepseek-flash" and a["status"] == "published"]
    require(len(agents) == 1, "One pinned published reviewer required")
    page, _ = reviews(base, pid)
    require(not any(g["enabled"] and g["definition"]["expires_at"] > plan["now"] for g in page["authorizations"]),
            "Existing active grant must be resolved explicitly before synthetic sends")
    saved = {"suite_hash": fingerprint(suite), "suite": suite, "production_id": pid,
             "baseline": {p["id"]: p["config_hash"] for p in discovery["items"]},
             "agent": agents[0], "contract_hash": plan["contract_hash"], "runs": [], "state": "running"}
    with path.open("x") as output:
        json.dump(saved, output, indent=2)
    for case in suite["cases"]:
        row = {"case_id": case["id"], "batch": "m5-premise-" + case["id"] + "-" + str(time.time_ns()),
               "state": "send_requested"}
        saved["runs"].append(row)
        persist(saved, path)
        row.update(send("B", row["batch"]))
        require(row["outcome"] == "delivered", "Actual local delivery failed; never resend")
        row["state"] = "delivered"
        persist(saved, path)
        observations = captured(base, pid, row["message"])
        session = str(observations[0]["header"]["session_id"])
        require(all(str(o["header"]["session_id"]) == session for o in observations), "One exact source session required")
        plan = api(base, f"/productions/{pid}/review-plan")
        require(plan["contract_hash"] == saved["contract_hash"], "Reviewer changed before funding")
        a = saved["agent"]
        definition = {"authorization_id": "m5-premises-" + case["id"] + ("-mapping" if followup else "") + "-20261020",
                      "production_id": pid, "config_hash": source["config_hash"],
                      "agent_id": a["id"], "source_revision": a["revision"], "agent_config_hash": a["config_hash"],
                      "contract_hash": saved["contract_hash"], "every_n": 1, "max_reviews": 1, "max_model_requests": 2,
                      "expires_at": int(plan["now"]) + 600, "include_existing": True,
                      "acknowledge_cost": True, "acknowledge_synthetic_data_export": True,
                      "demo_premises": {"session_id": session, **case["premises"]}}
        row.update(definition=definition, session=session, state="authorization_requested")
        persist(saved, path)
        try:
            row["grant"] = api(base, "/productions/authorize-review", definition)
            persist(saved, path)
            item = await_review(base, pid, definition["authorization_id"])
            row.update(header=str(item["header_id"]), state=item["state"],
                       detail=api(base, f"/productions/{pid}/reviews/{item['header_id']}"))
            persist(saved, path)
        finally:
            row["revoked"] = api(base, "/productions/revoke-review",
                                 {"production_id": pid, "authorization_id": definition["authorization_id"]})
            persist(saved, path)
        print(case["id"], row["state"], flush=True)
        require(row["state"] == "completed", "Technical failure retained; no automatic replacement run")
    saved["state"] = "finished"
    persist(saved, path)
    check(base, followup)


def check(base, followup=False, require_pass=True):
    saved, suite = json.loads((FOLLOWUP if followup else SAVED).read_text()), load(followup)
    require(saved["suite_hash"] == fingerprint(suite) and saved["suite"] == suite, "Frozen oracle/premises changed")
    require(len(saved["runs"]) == len(suite["cases"]) and saved["state"] == "finished", "All original attempts required")
    _, records = legal_sources()
    pid = saved["production_id"]
    page, items = reviews(base, pid)
    require(not page["error"] and not page["worker_error"], "Review worker health failure")
    result, usage = [], {"requests": 0, "tokens": 0, "citations": 0}
    for case, row in zip(suite["cases"], saved["runs"]):
        require(row["case_id"] == case["id"], "Case order mismatch")
        definition = row["definition"]
        require(definition["demo_premises"] == {"session_id": row["session"], **case["premises"]},
                "User premises changed after prospective freeze")
        grant = next(g for g in page["authorizations"] if g["authorization_id"] == definition["authorization_id"])
        require(not grant["enabled"] and grant["used_reviews"] == 1 and grant["definition"] == definition,
                "Exact spent/revoked session grant required")
        detail = api(base, f"/productions/{pid}/reviews/{row['header']}")
        require(detail == row["detail"], "Persistent detail differs from saved first result")
        review, report, evidence = detail["review"], detail["report"], detail["evidence"]
        require(str(evidence["header"]["session_id"]) == row["session"] and
                review["observation_hash"] == evidence["record_hash"] and review["packet"] == report["packet"] and
                review["result"] == report["result"], "Message/packet/result mismatch")
        approval = review["demo_approval"]
        require(approval["premises"] == definition["demo_premises"] and approval["actor"] == grant["actor"] and
                approval["confirmed_at"] == grant["authorized_at"] and
                approval["authorization_id"] == definition["authorization_id"] and
                approval["provenance"] == "user_confirmed_demo_premises_not_independently_verified",
                "User approval provenance mismatch")
        require("business_evidence" not in review, "Demo input must not fabricate SQL-readback business evidence")
        require(report["source"]["id"] == saved["agent"]["id"] and report["source"]["revision"] == saved["agent"]["revision"] and
                report["source"]["config_hash"] == saved["agent"]["config_hash"] and
                report["authorization"]["contract_hash"] == saved["contract_hash"], "Agent/reviewer freeze mismatch")
        require(report["reserved_model_requests"] == review["reserved_model_requests"] == 2 and
                [p["phase"] for p in report["phases"]] == ["locate", "judge"], "Two actual funded phases required")
        for phase in report["phases"]:
            require(phase["agent_session"] and phase["sdk_stats"]["total_interactions"] == 1 and
                    phase["sdk_stats"]["total_tool_calls"] == 0, "Actual tool-free AI Hub session required")
            require(phase["input"]["facts"] == report["packet"] if phase["phase"] == "judge"
                    else phase["input"]["facts"] == report["packet"]["facts"], "Model premises differ from approval")
            tokens = phase["usage"]["total_tokens"]
            require(type(tokens) is int and tokens > 0, "Explicit actual token usage required")
            usage["tokens"] += tokens
        funded = [i for i in items if i.get("authorization_id") == definition["authorization_id"] and i.get("reserved_model_requests")]
        require(len(funded) == 1 and funded[0]["id"] == review["id"], "No cross-session funding or duplicate review")
        observations = pages(base, pid, row["session"])
        request_edges = [o for o in observations if str(o["header"]["body_id"]) == str(row["message"]) and
                         o["header"]["body_class"] == "Contest.M5.Request"]
        require(len(request_edges) == 2 and all(o["capture"]["state"] == "captured" for o in request_edges),
                "Both actual BS/BP/BO request edges must be captured")
        graded = grade({"topic": "recipient_purpose", "oracle": case["oracle"]}, report, records)
        graded["checks"]["aggregate"] = report["result"]["assessment"] == case["oracle"]["assessment"]
        graded["accepted"] = graded["accepted"] and graded["checks"]["aggregate"]
        result.append({"case": case["id"], "header": row["header"], "session": row["session"],
                       "report_id": report["id"], **graded})
        usage["requests"] += report["reserved_model_requests"]
        usage["citations"] += graded["citations"]
    current = {p["id"]: p["config_hash"] for p in api(base, "/productions/discover")["items"]}
    require(all(current.get(pid) == digest for pid, digest in saved["baseline"].items()), "Production configuration changed")
    summary = {"status": "passed" if all(r["accepted"] for r in result) else "failed", "cases": result, "usage": usage,
               "business_sends_in_saved_run": len(saved["runs"]), "new_model_calls": 0, "new_business_sends": 0,
               "all_grants_revoked": True, "automatic_retries": 0,
               "scope": "User-approved demo premises and actual Production events; not real-world certification"}
    print(json.dumps(summary, indent=2))
    if require_pass:
        require(summary["status"] == "passed", "Prospective demo acceptance failed; preserve first results")
    return summary


def check_complete(base):
    first = check(base, require_pass=False)
    followup = check(base, followup=True)
    original = {c["case"]: c for c in first["cases"]}
    require(original["marketing"]["accepted"] and original["unknown"]["accepted"], "Original risk/unknown case failed")
    require(not original["treatment"]["accepted"] and followup["cases"][0]["accepted"],
            "Preserve the original incomplete treatment input and separately validated repair")
    usage = {k: first["usage"][k] + followup["usage"][k] for k in ("requests", "tokens", "citations")}
    summary = {"status": "passed_after_explicit_input_mapping_repair", "first_pass": "2/3",
               "followup": "1/1 unchanged treatment oracle, two added business-mapping inputs",
               "usage_including_failed_first_case": usage, "business_sends_in_saved_runs": 4,
               "all_grants_revoked": True, "new_model_calls": 0, "new_business_sends": 0}
    print(json.dumps(summary, indent=2))
    return summary


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--run", action="store_true")
    group.add_argument("--check", action="store_true")
    group.add_argument("--check-complete", action="store_true",
                       help="Read original cases and separately approved repair; does not relabel first-pass failure")
    parser.add_argument("--treatment-mapping-followup", action="store_true",
                        help="Requires explicit additional approval: one new treatment send / two requests; original journal retained")
    parser.add_argument("--base", default=BASE)
    args = parser.parse_args(argv)
    local_base(args.base)
    require(not (args.check_complete and args.treatment_mapping_followup), "Complete check includes both journals")
    if args.run:
        run(args.base, args.treatment_mapping_followup)
    elif args.check:
        check(args.base, args.treatment_mapping_followup)
    elif args.check_complete:
        check_complete(args.base)
    else:
        print("Inactive. --run needs explicit approval for three synthetic sends and six model requests; --check only reads.")


if __name__ == "__main__":
    main()
