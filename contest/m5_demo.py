#!/usr/bin/env python3
"""Install, verify, or explicitly reset the fixed M5 onboarding demonstration."""
import argparse
import hashlib
import json
import time
import uuid
from pathlib import Path

from business_privacy import require
from declaration_review_test import BASE
from production_evidence_test import api
from route_ui_test import local_base
from utilization_test import MARKER, execute

ROOT = Path(__file__).resolve().parent
SAVED = ROOT / "data/m5-onboarding-acceptance.json"


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def save(value):
    SAVED.write_text(json.dumps(value, indent=2) + "\n")


def install():
    print(execute("TRIAGE", (
        'For name="M5Demo","ProductionReview","KnowledgeAPI" { '
        'Set sc=$SYSTEM.OBJ.Load("/contest/src/"_name_".cls","ck") '
        'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } '
        f'Write "{MARKER}",{{"control_plane":true}}.%ToJSON(),!')))
    print(execute("M5OBSERVATION", (
        'If $Get(^ContestM5Install("owner"))\'="iris-ai-workflows" { Do ##class(Demo.Protocol).Fail("M5 ownership mismatch") } '
        'Set sc=$SYSTEM.OBJ.Load("/contest/m5/DemoRuntime.cls","ck") '
        'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        f'Write "{MARKER}",{{"runtime":true,"sends":0,"model_calls":0}}.%ToJSON(),!')))


def other_state(base, pid):
    productions = api(base, "/productions")["items"]
    return {
        "productions": {
            p["id"]: {k: p[k] for k in ("namespace", "production", "enabled", "revision", "baseline")}
            for p in productions if p["id"] != pid
        },
        "organizations": api(base, "/organizations")["items"],
        "distribution_runs": api(base, "/distribution")["runs"],
    }


def reset(base):
    state = api(base, "/m5-demo")
    before = other_state(base, state["production_id"])
    result = api(base, "/m5-demo/reset", {
        "confirmation": "RESET M5 DEMO", "config_hash": state["config_hash"],
    })
    require(not result["enrolled"] and not result["inspection_enabled"] and
            result["profiles"] == [] and result["runs"] == [], "Clean logical demo start required")
    require(before == other_state(base, state["production_id"]),
            "Other Production definitions, shared profiles and distribution records must be unchanged")
    return result


def run(base, resume=False):
    require(resume == SAVED.exists(), "Use --resume for the retained attempt; never overwrite or resend")
    state = api(base, "/m5-demo")
    if resume:
        saved = json.loads(SAVED.read_text())
        require(saved["state"] in ("send_requested", "audit_requested") and "sent" in saved,
                "Only a retained delivered attempt may resume; no resend or new paid attempt")
        sent, command = saved["sent"], saved["command"]
        if saved["state"] == "audit_requested":
            require("consent" in saved, "Exact retained consent required")
    else:
        saved = {"state": "preparing", "production_id": state["production_id"],
                 "other_state_hash": digest(other_state(base, state["production_id"]))}
        with SAVED.open("x") as stream:
            json.dump(saved, stream, indent=2)
        state = reset(base)
        for profile in state["presets"]:
            api(base, "/m5-demo/profiles", {"profile": profile, "expected_revision": 0, "confirmed": True})
        api(base, "/productions/enroll", {
            "namespace": state["namespace"], "production": state["production"],
            "config_hash": state["config_hash"], "acknowledge_monitoring": True,
        })
        api(base, "/productions/authorize-inspection", {
            "production_id": state["production_id"], "config_hash": state["config_hash"],
            "acknowledge_local_synthetic_inspection": True,
        })
        command = {"run_id": "m5-demo-" + str(uuid.uuid4()), "config_hash": state["config_hash"], "confirmed": True}
        saved.update(state="send_requested", command=command)
        save(saved)
        sent = api(base, "/m5-demo/send", command)
        saved["sent"] = sent
        save(saved)
    require(sent["state"] == "delivered" and sent["receipt"]["readback_match"], "Actual SQL receiver readback required")
    duplicate = api(base, "/m5-demo/send", command)
    require(all(duplicate[k] == sent[k] for k in sent),
            "Duplicate run must preserve the original send fields, never replay")
    if not resume:
        research = dict(sent["profiles"]["research"]["profile"])
        research["purpose"] = "Edited after sending; must not rewrite the frozen message scenario."
        api(base, "/m5-demo/profiles", {"profile": research, "expected_revision": 1, "confirmed": True})
    deadline = time.monotonic() + 90
    while True:
        state = api(base, "/m5-demo")
        current = next(r for r in state["runs"] if r["id"] == sent["id"])
        require(current["profiles"] == sent["profiles"], "Profile edits must not rewrite frozen run")
        rows = api(base, f'/productions/{state["production_id"]}/evidence')["items"]
        captured = [r for r in rows if str(r["header"]["header_id"]) == sent["header_id"]]
        if captured and captured[0]["capture"]["state"] == "captured":
            break
        require(time.monotonic() < deadline, "Automatic observer failed; no automatic resend")
        time.sleep(2)
    plan = state["plan"]
    agents = [a for a in plan["eligible_agents"] if a["model"] == "deepseek-flash" and a["status"] == "published"]
    require(len(agents) == 1, "Exactly one expected published reviewer required")
    agent = agents[0]
    consent = saved.get("consent") or {
        "run_id": sent["id"], "authorization_id": str(uuid.uuid4()),
        "agent_id": agent["id"], "source_revision": agent["revision"],
        "agent_config_hash": agent["config_hash"], "contract_hash": plan["contract_hash"],
        "config_hash": state["config_hash"], "acknowledge_cost": True,
    }
    saved.update(state="audit_requested", consent=consent)
    save(saved)
    grant = api(base, "/m5-demo/audit", consent)
    require(grant["definition"]["max_reviews"] == 1 and grant["definition"]["max_model_requests"] == 2,
            "One review / two requests only")
    require(grant["definition"]["demo_premises"]["session_id"] == sent["session_id"],
            "No other session may spend this grant")
    saved["grant"] = grant
    save(saved)
    deadline = time.monotonic() + 900
    while True:
        state = api(base, "/m5-demo")
        current = next(r for r in state["runs"] if r["id"] == sent["id"])
        report = current.get("report")
        if report and report["state"] in ("completed", "failed", "interrupted"):
            saved.update(state=report["state"], completed=current, report_hash=digest(report))
            save(saved)
            break
        require(time.monotonic() < deadline, "Audit timed out; preserved attempt, no automatic paid retry")
        time.sleep(3)
    require(report["state"] == "completed", "Real model execution failed; inspect retained report, do not retry automatically")
    require(report["result"]["assessment"] == "risk_identified", "Expected scoped Safe Harbor contradiction")
    require(report["reserved_model_requests"] == 2 and len(report["phases"]) == 2,
            "Two real phases required")
    for phase in report["phases"]:
        require(phase["state"] == "returned" and phase["raw"] and phase["agent_session"],
                "Actual preserved model response and session required")
    facts = {f["id"]: f for f in report["packet"]["facts"]}
    require("org_research_profile" in facts and
            json.loads(facts["org_research_profile"]["text"]) == sent["profiles"]["research"]["profile"],
            "Model must consume the frozen profile, not current edited form")
    require("SYNTHETIC-DEMO-NAME" not in json.dumps(report["packet"]), "Raw patient values remain local")
    api(base, "/productions/revoke-review", {
        "production_id": state["production_id"], "authorization_id": consent["authorization_id"],
    })
    require(saved["other_state_hash"] == digest(other_state(base, state["production_id"])),
            "Unrelated state changed")
    saved["state"] = "passed"
    save(saved)
    print(json.dumps({"state": "passed", "run": sent["id"], "header": sent["header_id"],
                      "sessions": [p["agent_session"] for p in report["phases"]], "requests": 2}))


def check(base):
    saved = json.loads(SAVED.read_text())
    require(saved["state"] == "passed", "Acceptance not complete")
    report = saved["completed"]["report"]
    require(saved["report_hash"] == digest(report), "Saved acceptance integrity mismatch")
    report_id = report["id"]
    require(report_id.replace("-", "").isalnum(), "Bounded saved report ID required")
    actual = execute("TRIAGE", f'Set r=##class(Contest.RiskReview).Status("{report_id}") '
                     f'Write "{MARKER}",$ZConvert(r.%ToJSON(),"O","UTF8"),!')
    require(digest(actual) == saved["report_hash"], "Persistent report changed or missing after reset")
    require(saved["other_state_hash"] == digest(other_state(base, saved["production_id"])),
            "Unrelated baseline changed")
    print("Saved real M5 onboarding acceptance verified; no new sends or model calls.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--install", action="store_true")
    group.add_argument("--run", action="store_true", help="Archives/reset M5 logical state, one local send, at most two paid model requests")
    group.add_argument("--resume", action="store_true", help="Resume only the retained delivered attempt with its exact consent; no resend or replacement budget")
    group.add_argument("--check", action="store_true", help="Read-only saved acceptance validation, including after reset")
    group.add_argument("--reset", action="store_true", help="Archive only M5 demo logical state; preserve physical messages and model reports")
    parser.add_argument("--base", default=BASE)
    args = parser.parse_args(argv)
    local_base(args.base)
    if args.install:
        install()
    elif args.run or args.resume:
        run(args.base, resume=args.resume)
    elif args.check:
        check(args.base)
    else:
        reset(args.base)
        print("M5 demo reset to clean logical start. Original IRIS messages/SQL receipts/model reports archived or retained; other demos unchanged.")


if __name__ == "__main__":
    main()
