#!/usr/bin/env python3
"""D6 read-only acceptance of persisted real declaration, delivery and monitoring evidence."""
import argparse
import json
from urllib.parse import quote

from business_privacy import require
from declaration_review_test import BASE
from route_ui_test import admin_request, local_base

QUALITY = "demo-d3-browser-quality"
MARKETING = "demo-d3-browser-marketing"
BASELINE = ("demo-declaration-quality", "demo-declaration-marketing", "demo-declaration-incomplete")
BATCH = "declaration-quality-d4-002"


def get(base, path):
    code, value = admin_request(base, path)
    require(code == 200, f"Acceptance GET {path} failed with HTTP {code}")
    return value


def pages(base, path, cursor_field, query):
    values, seen = [], set()
    current = path
    while True:
        page = get(base, current)
        values.extend(page["items"])
        cursor = page[cursor_field]
        if not cursor:
            return values
        require(cursor not in seen, "Repeated pagination cursor")
        seen.add(cursor)
        current = path + "?" + query + "=" + quote(str(cursor), safe="")


def history(base, key):
    values, before, seen = [], "", set()
    while True:
        suffix = "?before=" + quote(str(before), safe="") if before else ""
        value = get(base, "/declarations/" + quote(key, safe="") + "/history" + suffix)
        require(value["declaration_id"] == key, "History belongs to another declaration")
        values.extend(value["items"])
        if not value["has_older"]:
            break
        before = value["older_before_revision"]
        require(before and before not in seen, "Invalid history cursor")
        seen.add(before)
    require(values and len({v["id"] for v in values}) == len(values), "Missing or duplicate immutable history")
    return values


def usage(report):
    require(report["authorization"]["acknowledge_cost"] is True and
            report["authorization"]["max_model_requests"] == 2, "Real explicit two-request report authorization required")
    sessions, prompt, completion, interactions = [], 0, 0, 0
    require(report["phases"], "Missing real Agent phases")
    for phase in report["phases"]:
        require(phase["agent_session"] and "sdk_stats" in phase, "SDK session/usage must be recorded, not defaulted")
        stats = phase["sdk_stats"]
        require(stats["total_interactions"] == 1 and stats["total_tool_calls"] == 0, "Unexpected hidden requests or tools")
        for field in ("total_prompt_tokens", "total_completion_tokens"):
            require(isinstance(stats[field], int) and stats[field] >= 0, "Invalid measured token count")
        sessions.append(str(phase["agent_session"]))
        interactions += stats["total_interactions"]
        prompt += stats["total_prompt_tokens"]
        completion += stats["total_completion_tokens"]
    require(len(set(sessions)) == len(sessions) and interactions <= 2, "Duplicated session or exceeded allowance")
    return {"requests": interactions, "prompt_tokens": prompt, "completion_tokens": completion, "sessions": sessions}


def citations(report, result):
    packages = {p["question_id"]: p for p in report["packages"]}
    count = 0
    for issue in result["issues"]:
        hits = {h["id"]: h for h in packages[issue["question_id"]]["evidence"]}
        for citation in issue["citations"]:
            hit = hits[citation["evidence_id"]]
            require(hit["source_hash_verified"] is True and
                    0 <= citation["start"] < citation["end"] <= len(hit["text"]) and
                    hit["text"][citation["start"]:citation["end"]] == citation["quote"],
                    "Citation does not match the exact verified source")
            count += 1
    require(count > 0, "Accepted real result requires materialized citations")
    return count


def proposal(base, record):
    task = record["review"]["task"]
    if task is None or task["reserved_requests"] == 0:
        require(task is None or (task["attempted_requests"] == 0 and task["assessment"] is None and task["result"] is None),
                "Unfunded review cannot have a finding or usage")
        return None
    require(task["record_id"] == record["id"] and task["declaration_digest"] == record["digest"] and
            task["revision"] == record["revision"] and task["reserved_requests"] == 2, "Review revision binding mismatch")
    grant = task["runtime"]["authorization"]
    require(grant["record_id"] == record["id"] and grant["digest"] == record["digest"] and
            grant["task_id"] == task["id"] and grant["acknowledge_cost"] is True and
            grant["max_model_requests"] == 2, "Exact task cost grant required")
    report = get(base, "/declarations/" + record["id"] + "/review-report")
    auth = report["authorization"]
    require(report["id"] == task["runtime"]["report_id"] and auth["request_key"] == "declaration-" + task["id"],
            "Wrong task report")
    for field in ("agent_id", "source_revision", "config_hash", "input_hash", "contract_hash"):
        require(auth[field] == grant[field], "Proposal report differs from its grant: " + field)
    measured = usage(report)
    require(task["attempted_requests"] == report["reserved_model_requests"] == measured["requests"] and
            task["runtime"]["message_id"] and task["runtime"]["session_id"], "Actual proposal requests/messages missing")
    require(task["state"] == report["state"] and task["state"] in ("completed", "failed"), "Nonterminal review is not acceptance")
    count = 0
    if task["state"] == "completed":
        require(task["result"] == report["result"] and task["assessment"] == task["result"]["assessment"],
                "Actual accepted result mismatch")
        count = citations(report, task["result"])
    else:
        require(task["result"] is None and task["assessment"] is None, "Technical failure must not be a business finding")
    decision = record["decision"]
    if decision is not None:
        require(decision["record_id"] == record["id"] and decision["digest"] == record["digest"] and
                decision["task_id"] == task["id"] and decision["task_hash"] == task["record_hash"],
                "Human decision belongs to another version or task")
    return {**measured, "report": report["id"], "record": record["id"], "declaration": record["declaration_id"],
            "revision": record["revision"], "state": task["state"], "assessment": task["assessment"], "citations": count}


def walkthrough(histories):
    quality = {r["revision"]: r for r in histories[QUALITY]}
    marketing = {r["revision"]: r for r in histories[MARKETING]}
    require(1 in quality and 2 in quality and 1 in marketing and 2 in marketing, "Real browser revision chain is incomplete")
    old, corrected = quality[1], quality[2]
    require(old["review"]["task"]["assessment"] == "information_required" and
            old["review"]["task"]["result"]["missing_information"] and old["decision"]["action"] == "returned",
            "Missing-input case must have actual material questions and human return")
    require(corrected["parent_digest"] == old["digest"] and corrected["review"]["task"]["id"] != old["review"]["task"]["id"] and
            corrected["review"]["task"]["assessment"] == "no_risk_identified" and corrected["decision"]["action"] == "approved",
            "Corrected proposal must have its own real review and human approval")
    require(marketing[1]["review"]["task"]["state"] == "failed" and marketing[1]["decision"]["action"] == "returned" and
            marketing[2]["review"]["task"]["assessment"] == "risk_identified" and marketing[2]["decision"]["action"] == "rejected",
            "Risk case or preserved technical failure is missing")
    require(corrected["id"] != old["id"] and corrected["proposal"] != old["proposal"], "Revision cannot be a relabelled old record")
    return corrected, marketing[2]


def check(base):
    local_base(base)
    histories = {key: history(base, key) for key in (*BASELINE, QUALITY, MARKETING)}
    expected = ("no_risk_identified", "risk_identified", "information_required")
    require(tuple(histories[key][0]["review"]["task"]["assessment"] for key in BASELINE) == expected,
            "Real three-case Agent results differ from the frozen normal/risk/missing expectation")
    corrected, rejected = walkthrough(histories)
    reports = [measured for rows in histories.values() for r in rows if (measured := proposal(base, r)) is not None]
    runs = pages(base, "/declarations/" + corrected["id"] + "/executions", "next_cursor", "before")
    selected = [r for r in runs if r["grant"]["batch_id"] == BATCH]
    require(len(selected) == 1 and selected[0]["state"] == "delivered", "Exactly one actual successful walkthrough batch required")
    run = get(base, "/declarations/executions/" + selected[0]["id"])
    require(run == selected[0] and run["grant"]["record"]["id"] == corrected["id"] and
            run["grant"]["record"]["digest"] == corrected["digest"], "Execution approval snapshot mismatch")
    consent, receipt = run["grant"]["consent"], run["receipt"]
    require(consent["acknowledge_delivery"] is True and consent["decision_hash"] == corrected["decision"]["record_hash"] and
            consent["task_hash"] == corrected["review"]["task"]["record_hash"] and
            receipt["scope_hash"] == run["grant_hash"] and receipt["approval_id"] == run["id"] and
            receipt["receiver_readback_match"] is True and run["model_calls"] == 0, "Actual delivery/readback grant missing")
    link = receipt["declaration_binding"]
    require(link["record_id"] == corrected["id"] and link["revision"] == 2 and
            link["decision_hash"] == consent["decision_hash"] and link["task_hash"] == consent["task_hash"],
            "Receipt is not bound to the corrected reviewed/approved revision")
    require(receipt["inspection"]["resource_counts"] == {"Patient": 2, "Encounter": 2, "Condition": 0, "MedicationRequest": 0} and
            set(receipt["inspection"]["field_paths"]) == set(corrected["proposal"]["data"]["fields"]),
            "Actual resource/field shape is not the declared recipe")
    failed = [r for r in runs if r["grant"]["batch_id"] == "declaration-quality-d4-001"]
    require(len(failed) == 1 and failed[0]["state"] == "reconciliation_required" and failed[0]["receipt"] is None,
            "Original uncertain delivery must remain unreplayed")
    monitor = get(base, "/declarations/monitor/" + run["id"])
    evidence, report = monitor["evidence"], monitor["report"]
    require(monitor["origin"] == "automatic_after_send" and monitor["state"] == "completed" and
            monitor["receipt_hash"] == receipt["receipt_hash"] and evidence["record_id"] == corrected["id"] and
            evidence["decision_hash"] == consent["decision_hash"] and evidence["task_hash"] == consent["task_hash"],
            "Automatic comparison is not linked to the exact historical approval")
    require(report["authorization"]["request_key"] == "monitor-" + run["id"] and
            monitor["report_id"] == report["id"] and monitor["result"] == report["result"], "Actual post-send report mismatch")
    require(monitor["observer_error"] == "" and monitor["error"] == "" and monitor["heartbeat"] > 0,
            "Observer has an unresolved runtime failure")
    measured = usage(report)
    require(measured["requests"] == monitor["attempted_requests"] == monitor["reserved_requests"] == 2,
            "Post-send allowance/attempt/SDK mismatch")
    require(monitor["result"]["summary"]["risk_detected"] is False and
            monitor["result"]["summary"]["unresolved"] is False and not monitor["result"]["missing_information"],
            "Actual walkthrough comparison differs from the expected matched use")
    event = monitor["event"]
    require(event["state"] == "resolved" and event["revision"] == 3 and
            [(a["before"], a["after"]) for a in event["actions"]] == [("open", "in_review"), ("in_review", "resolved")] and
            all(a["actor"] and a["text"] and a["time"] for a in event["actions"]), "Durable human monitoring review is incomplete")
    reports.append({**measured, "report": report["id"], "state": "completed", "citations": citations(report, monitor["result"]),
                    "execution": run["id"], "stage": "after_send"})
    sessions = [session for r in reports for session in r["sessions"]]
    require(len(sessions) == len(set(sessions)) and len({r["report"] for r in reports}) == len(reports),
            "A report or Agent session was double counted")
    for record in (histories[QUALITY][-1], rejected):
        code, _ = admin_request(base, "/declarations/" + record["id"] + "/execution-plan?batch_id=d6-denied-plan")
        require(code == 409, "Old or rejected declaration unexpectedly permits a delivery plan")
    return {
        "status": "passed", "mode": "read_only_saved_real_evidence", "new_model_requests": 0, "new_deliveries": 0,
        "walkthrough": {"corrected_record": corrected["id"], "rejected_marketing_record": rejected["id"],
                        "execution": run["id"], "batch": BATCH, "delivery_session": receipt["session_id"],
                        "monitor_report": report["id"], "event": event["state"]},
        "historical_usage": {"scope": "Five D2/D3 demo declarations, every funded revision, plus the linked D5 comparison",
                             "requests": sum(r["requests"] for r in reports),
                             "prompt_tokens": sum(r["prompt_tokens"] for r in reports),
                             "completion_tokens": sum(r["completion_tokens"] for r in reports),
                             "total_tokens": sum(r["prompt_tokens"] + r["completion_tokens"] for r in reports),
                             "failed_reports": sum(r["state"] == "failed" for r in reports),
                             "verified_citations": sum(r["citations"] for r in reports)},
        "reports": reports,
        "boundaries": "Synthetic bounded recipe and observed scope/delivery, not unobserved recipient conduct. Negative drift tests run separately without out-of-scope sends.",
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--base", default=BASE)
    args = parser.parse_args(argv)
    local_base(args.base)
    if args.check:
        print(json.dumps(check(args.base), ensure_ascii=False, indent=2))
    else:
        print("Inactive. --check verifies existing real evidence using GET only; never funds, sends, resets or replays.")


if __name__ == "__main__":
    main()
