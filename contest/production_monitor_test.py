#!/usr/bin/env python3
"""Install or verify multi-Production read-only monitoring; no automatic enrollment, sends or model calls."""
import argparse
import json

from business_privacy import require
from declaration_review_test import BASE
from platform_test import request
from route_ui_test import admin_request, local_base
from utilization_test import execute, MARKER


def get(base, path):
    code, value = admin_request(base, path)
    require(code == 200, f"Production monitoring GET failed: {path}, HTTP {code}")
    return value


def check(base):
    discovered = get(base, "/productions/discover")
    require(discovered["model_calls"] == 0, "Discovery cannot infer")
    state = get(base, "/productions")
    require(not state["error"], "Production observer has an error")
    require(len(state["items"]) >= 2, "Enroll at least two actual active Productions from the page first")
    ids = {item["id"] for item in state["items"]}
    require(len(ids) == len(state["items"]), "Managed identities must be unique")
    output = []
    for record in state["items"]:
        require(record["last_scan"] > 0 and not record["error"], "Automatic Production scan must succeed")
        detail = get(base, "/productions/" + record["id"])
        require(detail["record"]["namespace"] == record["namespace"] and detail["record"]["production"] == record["production"],
                "Managed detail identity changed")
        require(detail["monitoring_scope"]["unit"] == "production" and
                detail["monitoring_scope"]["flow_registration_required"] is False and
                detail["monitoring_scope"]["component_scope"] == "all_current_components",
                "Production monitoring cannot require per-flow registration")
        events, before, cursors = [], 0, set()
        while True:
            page = get(base, f"/productions/{record['id']}/events?before={before}")
            require(page["production_id"] == record["id"] and
                    all(e["production_id"] == record["id"] for e in page["items"]), "Cross-Production event leak")
            events.extend(page["items"])
            before = page["next_before"]
            if not before:
                break
            require(before not in cursors, "Event pagination loop")
            cursors.add(before)
        require(len({e["source_key"] for e in events}) == len(events), "Duplicate captured events")
        require(any(e["category"] == "coverage_gap" for e in events), "General payload coverage must be explicit")
        risks, offset, cursors = [], 0, set()
        while True:
            page = get(base, f"/productions/{record['id']}/risks?before={offset}")
            require(page["production_id"] == record["id"] and page["general_payload_assessment"] is False and
                    page["model_calls"] == 0, "Linked review scope cannot claim general payload review")
            risks.extend(page["items"])
            offset = page["next_offset"]
            if not offset:
                break
            require(offset not in cursors, "Risk pagination loop")
            cursors.add(offset)
        for event in events:
            evidence = event["evidence"]
            require(not any(key in evidence for key in ("Text", "text", "body", "payload", "ErrorStatus", "Description")),
                    "Free-text bodies/logs must not enter generic collection")
        if record["namespace"] == "DEMO":
            require(any(e["category"] == "message_error" for e in events) and
                    any(e["category"] == "runtime_log" for e in events),
                    "New local DEMO failure must be observed in message and runtime-log metadata")
            require(any(r["category"] == "risk_identified" for r in risks), "Existing real scoped DEMO risk must be linked")
        if record["namespace"] == "UTILIZATION":
            require(all(e["category"] not in ("message_error", "runtime_log") or
                        e["evidence"].get("session_id") not in (513, 519) for e in events), "DEMO sessions cannot leak into UTILIZATION")
            require(any(r["source"] == "declaration_after_send" for r in risks), "Actual declaration comparison must be attached")
        output.append({"id": record["id"], "namespace": record["namespace"], "production": record["production"],
                       "events": len(events), "reviews": len(risks), "headers": record["header_count"],
                       "warning_logs": record["log_count"], "last_scan": record["last_scan"]})
    require(request(base, "/productions/discover")[0] == 403, "Readers cannot enumerate source namespaces")
    for path in ("/productions/enroll", "/productions/manage", "/productions/action"):
        require(request(base, path, body={})[0] == 403, "Reader mutation rejected")
        require(admin_request(base, path, {}, header=False)[0] == 403, "CSRF header required")
    require(admin_request(base, "/productions/enroll", raw=b"[]")[0] == 400, "Object JSON required")
    require(admin_request(base, "/productions/enroll", raw=b" " * 4097)[0] == 413, "Bounded enrollment body required")
    print(json.dumps({"status": "passed", "discovered": len(discovered["items"]),
                      "discovery_errors": discovered["errors"], "managed": output, "new_model_calls": 0,
                      "new_business_sends": 0}, indent=2))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--install", action="store_true")
    group.add_argument("--check", action="store_true")
    parser.add_argument("--base", default=BASE)
    args = parser.parse_args(argv)
    local_base(args.base)
    if args.install:
        code = ('For path="/contest/src/ProductionMonitor.cls","/contest/src/KnowledgeAPI.cls",'
                '"/contest/src/RouteReview.cls","/contest/dev/ProductionMonitorTests.cls" { '
                'Set sc=$SYSTEM.OBJ.Load(path,"ck") '
                'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } ')
        execute("TRIAGE", code + f'Write "{MARKER}",{{"compiled":true}}.%ToJSON(),!')
        print("Compiled registry/API/timer hook only. No enrollment, manual scan, Production change or inference.")
    elif args.check:
        check(args.base)
    else:
        print("Inactive. Discover/enroll from the workspace. --install compiles; --check reads existing evidence.")


if __name__ == "__main__":
    main()
