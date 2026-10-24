#!/usr/bin/env python3
"""Primary demo: --run sends two synthetic exports and funds <=4 requests; --check only reads."""
import argparse
import json
import time
from pathlib import Path

from business_privacy import fingerprint, require
from declaration_review_test import BASE
from hipaa_conditions_test import grade, load as legal_sources
from production_acceptance_test import captured
from production_evidence_test import api
from production_premises_test import await_review
from production_review_test import reviews
from route_ui_test import local_base
from utilization_test import MARKER, execute

ROOT = Path(__file__).resolve().parent
SUITE = ROOT / "fixtures/production-deidentification-v1.json"
SAVED = ROOT / "data/production-deidentification-20261021.json"


def load():
    suite = json.loads(SUITE.read_text())
    require(suite["suite"] == "production-deidentification-v1" and suite["schema"] == 1,
            "Fixed primary demo suite required")
    require([c["id"] for c in suite["cases"]] == ["identifier-leak", "minimized-control"],
            "One leak and one control required")
    return suite


def payload(suite, case):
    return {"export_context": suite["export_context"], **case["payload"]}


def persist(saved):
    SAVED.write_text(json.dumps(saved, indent=2) + "\n")


def send(body, batch):
    require(batch.startswith("m5-deid-") and len(batch) <= 64 and batch.replace("-", "").isalnum(),
            "Bounded synthetic batch required")
    literal = json.dumps(body).replace('"', '""')
    return execute("M5OBSERVATION", (
        f'Set request=##class(Contest.M5.Request).%New(), request.BatchId="{batch}", request.Route="B", '
        f'request.Format="json-object", request.PayloadJson="{literal}" '
        'Set sc=##class(Ens.Director).CreateBusinessService("M5Source",.service) '
        'If $System.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        'Set sc=service.ProcessInput(request,.reply) '
        'If $System.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        f'Write "{MARKER}",{{"batch":(request.BatchId),"message":(request.%Id()),"outcome":(reply.Outcome)}}.%ToJSON(),!'))


def run(base):
    require(not SAVED.exists(), "Demo attempt is immutable; use --check, never repeat sends or paid requests")
    suite = load()
    discovery = api(base, "/productions/discover")
    source = next(p for p in discovery["items"] if p["namespace"] == "M5OBSERVATION")
    pid = source["id"]
    plan = api(base, f"/productions/{pid}/review-plan")
    agents = [a for a in plan["eligible_agents"] if a["model"] == "deepseek-flash" and a["status"] == "published"]
    require(len(agents) == 1, "One pinned published reviewer required")
    page, _ = reviews(base, pid)
    require(not any(g["enabled"] and g["definition"]["expires_at"] > plan["now"] for g in page["authorizations"]),
            "Resolve existing active grants before synthetic sends")
    saved = {"suite": suite, "suite_hash": fingerprint(suite), "production_id": pid,
             "baseline": {p["id"]: p["config_hash"] for p in discovery["items"]},
             "agent": agents[0], "contract_hash": plan["contract_hash"], "runs": [], "state": "running"}
    with SAVED.open("x") as output:
        json.dump(saved, output, indent=2)
    for case in suite["cases"]:
        row = {"case_id": case["id"], "batch": "m5-deid-" + str(time.time_ns()), "state": "send_requested"}
        saved["runs"].append(row)
        persist(saved)
        row.update(send(payload(suite, case), row["batch"]))
        require(row["outcome"] == "delivered", "Local delivery failed; no resend")
        row["state"] = "delivered"
        persist(saved)
        observations = captured(base, pid, row["message"])
        require(all(o["capture"]["facts"]["export_context"] == suite["export_context"] for o in observations),
                "Both actual request edges must retain the same export declaration")
        session = str(observations[0]["header"]["session_id"])
        require(all(str(o["header"]["session_id"]) == session for o in observations), "Exact session required")
        plan = api(base, f"/productions/{pid}/review-plan")
        require(plan["contract_hash"] == saved["contract_hash"], "Reviewer changed before funding")
        agent = saved["agent"]
        definition = {"authorization_id": "deid-" + case["id"] + "-20261021",
                      "production_id": pid, "config_hash": source["config_hash"],
                      "agent_id": agent["id"], "source_revision": agent["revision"],
                      "agent_config_hash": agent["config_hash"], "contract_hash": saved["contract_hash"],
                      "every_n": 1, "max_reviews": 1, "max_model_requests": 2,
                      "expires_at": int(plan["now"]) + 600, "include_existing": True,
                      "acknowledge_cost": True, "acknowledge_synthetic_data_export": True,
                      "demo_premises": {"session_id": session, **suite["premises"]}}
        row.update(definition=definition, session=session, state="authorization_requested")
        persist(saved)
        try:
            row["grant"] = api(base, "/productions/authorize-review", definition)
            persist(saved)
            item = await_review(base, pid, definition["authorization_id"])
            row.update(header=str(item["header_id"]), state=item["state"],
                       detail=api(base, f"/productions/{pid}/reviews/{item['header_id']}"))
            persist(saved)
        finally:
            row["revoked"] = api(base, "/productions/revoke-review",
                                 {"production_id": pid, "authorization_id": definition["authorization_id"]})
            persist(saved)
        print(case["id"], row["state"], flush=True)
        require(row["state"] == "completed", "Technical failure retained; no automatic replacement run")
    saved["state"] = "finished"
    persist(saved)
    return check(base)


def check(base):
    suite, saved = load(), json.loads(SAVED.read_text())
    require(saved["suite"] == suite and saved["suite_hash"] == fingerprint(suite), "Prospective inputs/oracle changed")
    require(saved["state"] == "finished" and len(saved["runs"]) == 2, "Both original attempts required")
    _, sources = legal_sources()
    pid = saved["production_id"]
    page, _ = reviews(base, pid)
    require(not page["error"] and not page["worker_error"], "Reviewer health failure")
    outcomes, tokens = [], 0
    for case, row in zip(suite["cases"], saved["runs"]):
        require(row["case_id"] == case["id"], "Case identity mismatch")
        detail = api(base, f"/productions/{pid}/reviews/{row['header']}")
        require(detail == row["detail"], "Persistent report differs from saved original")
        review, report, evidence = detail["review"], detail["report"], detail["evidence"]
        grant = next(g for g in page["authorizations"] if g["authorization_id"] == row["definition"]["authorization_id"])
        require(not grant["enabled"] and grant["used_reviews"] == 1 and grant["definition"] == row["definition"],
                "Exact spent and revoked grant required")
        require(grant["definition"]["demo_premises"] == {"session_id": row["session"], **suite["premises"]},
                "Identical answer-free business premises required")
        require(str(evidence["header"]["session_id"]) == row["session"] and
                str(evidence["header"]["body_id"]) == str(row["message"]) and
                str(evidence["header"]["header_id"]) == row["header"], "Actual sent message binding required")
        require(review["observation_hash"] == evidence["record_hash"] and review["packet"] == report["packet"] and
                review["result"] == report["result"], "Observation/model/result binding mismatch")
        inspection = evidence["capture"]["facts"]
        require(inspection["export_context"] == suite["export_context"] and inspection["unknown_fields"] == 0,
                "Expected bounded actual export context")
        require(inspection["identifier_present"] == (case["id"] == "identifier-leak") and
                inspection["dates"]["full_date"] == (case["id"] == "identifier-leak"),
                "Actual field/date contrast required")
        facts = {f["id"]: f for f in report["packet"]["facts"]}
        require(json.loads(facts["observed_fields"]["text"]) == inspection and
                json.loads(facts["observed_export_context"]["text"])["declaration"] == suite["export_context"] and
                facts["observed_export_context"]["origin"] == "persisted_message_export_declaration",
                "Model must compare actual message context and observed output")
        require(report["source"]["id"] == saved["agent"]["id"] and
                report["source"]["revision"] == saved["agent"]["revision"] and
                report["source"]["config_hash"] == saved["agent"]["config_hash"] and
                report["authorization"]["contract_hash"] == saved["contract_hash"], "Frozen reviewer required")
        require(report["reserved_model_requests"] == review["reserved_model_requests"] == 2 and
                [p["phase"] for p in report["phases"]] == ["locate", "judge"], "Two real phases required")
        for phase in report["phases"]:
            require(phase["agent_session"] and phase["sdk_stats"]["total_interactions"] == 1 and
                    phase["sdk_stats"]["total_tool_calls"] == 0 and type(phase["usage"]["total_tokens"]) is int and
                    phase["usage"]["total_tokens"] > 0, "Actual AI Hub session and usage required")
            require(phase["input"]["facts"] == (report["packet"] if phase["phase"] == "judge" else report["packet"]["facts"]),
                    "Preserved model input differs from bound packet")
            tokens += phase["usage"]["total_tokens"]
        graded = grade({"topic": "deidentification", "oracle": case["oracle"]}, report, sources)
        graded["checks"]["aggregate"] = report["result"]["assessment"] == case["oracle"]["assessment"]
        graded["accepted"] = all(graded["checks"].values())
        outcomes.append({"case": case["id"], "header": row["header"], "session": row["session"], **graded})
    discovery = api(base, "/productions/discover")
    require({p["id"]: p["config_hash"] for p in discovery["items"]} == saved["baseline"], "Production configuration changed")
    summary = {"status": "passed" if all(o["accepted"] for o in outcomes) else "failed", "cases": outcomes,
               "requests": 4, "reported_tokens": tokens, "all_grants_revoked": True,
               "new_model_calls": 0, "new_business_sends": 0}
    print(json.dumps(summary, indent=2))
    require(summary["status"] == "passed", "First results retained; no oracle change or automatic retries")
    return summary


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--run", action="store_true")
    action.add_argument("--check", action="store_true")
    parser.add_argument("--base", default=BASE)
    args = parser.parse_args(argv)
    local_base(args.base)
    if args.run:
        run(args.base)
    elif args.check:
        check(args.base)
    else:
        print("Inactive. --run sends TWO synthetic messages and funds at most FOUR real model requests; --check reads only.")


if __name__ == "__main__":
    main()
