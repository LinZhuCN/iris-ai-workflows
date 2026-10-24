#!/usr/bin/env python3
"""Install optional review-context contracts or read-check their API; no inference or business delivery."""
import argparse
import json

from business_privacy import require
from declaration_review_test import BASE
from platform_test import request
from route_ui_test import admin_request, local_base
from utilization_test import MARKER, execute


def check(base):
    local_base(base)
    status, productions = request(base, "/productions")
    require(status == 200, "Reader must be able to list managed Productions")
    require(request(base, "/production-flows/flow-" + "0" * 64, account=None)[0] == 401,
            "Anonymous flow access must be denied")
    path = "/production-flows/save"
    require(request(base, path, body={})[0] == 403, "Readers cannot save flow configuration")
    require(admin_request(base, path, {}, header=False)[0] == 403, "Flow changes require CSRF header")
    for raw in (b"null", b"[]", b'"scalar"', b"{"):
        require(admin_request(base, path, raw=raw)[0] == 400, "Object JSON required")
    require(admin_request(base, path, raw=b" " * 32769)[0] == 413, "Flow body must be bounded")
    require(admin_request(base, path, {})[0] == 409, "Invalid flow contracts fail explicitly")
    require(admin_request(base, path, {"invalid": "x" * 5000})[0] == 409,
            "Larger flow bodies must reach contract validation, not the old 4096-byte cap")
    inspected = 0
    for production in productions["items"]:
        list_path = "/productions/" + production["id"] + "/flows"
        status, before = request(base, list_path)
        require(status == 200 and before["production_id"] == production["id"] and
                before["can_manage"] is False and before["model_calls"] == 0, "Reader-scoped flow list required")
        require(before["record_kind"] == "optional_review_context" and
                before["discovered_flows"] is False and before["monitoring_prerequisite"] is False,
                "Optional contexts cannot masquerade as discovered flows or required enrollment")
        after, cursors = "", set()
        while True:
            status, page = request(base, list_path + "?after=" + after)
            require(status == 200 and len(page["items"]) <= 25, "Bounded flow list required")
            for flow in page["items"]:
                require(flow["production_id"] == production["id"] and
                        flow["binding"]["namespace"] == production["namespace"] and
                        flow["binding"]["production"] == production["production"], "Cross-Production flow leak")
                status, detail = request(base, f"/production-flows/{flow['id']}?revision={flow['revision']}")
                require(status == 200 and detail == flow, "Exact persisted flow version must match its list entry")
                require(flow["coverage"]["state"] == "optional_context_only" and
                        flow["monitoring_prerequisite"] is False and
                        flow["coverage"]["automatic_review"] is False and flow["model_calls"] == 0,
                        "Optional context cannot restrict collection, claim runtime evidence or grant inference")
                require(request(base, "/production-flows/" + flow["id"] + "?revision=1.5")[0] == 409,
                        "Fractional revision must fail")
                inspected += 1
            after = page["next_after"]
            if not after:
                break
            require(after not in cursors, "Flow cursor loop")
            cursors.add(after)
        require(request(base, list_path + "?after=../bad")[0] == 409, "Malformed flow cursor rejected")
        require(request(base, list_path)[1] == before, "Read checks cannot mutate flow versions")
    print(json.dumps({"status": "passed", "managed_productions": len(productions["items"]),
                      "inspected_flows": inspected, "scope": "M1 contract/API only; not runtime risk acceptance",
                      "new_model_calls": 0, "new_business_sends": 0}))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--install", action="store_true")
    group.add_argument("--check", action="store_true")
    parser.add_argument("--base", default=BASE)
    args = parser.parse_args(argv)
    local_base(args.base)
    if args.install:
        code = ('For path="/contest/src/ProductionFlow.cls","/contest/src/FlowEvidence.cls",'
                '"/contest/src/KnowledgeAPI.cls","/contest/dev/ProductionFlowTests.cls" { '
                'Set sc=$SYSTEM.OBJ.Load(path,"ck") '
                'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } ')
        execute("TRIAGE", code + f'Write "{MARKER}",{{"compiled":true}}.%ToJSON(),!')
        print("Compiled M1 contracts/API only. No flow configured, collector started, approval or model call.")
    elif args.check:
        check(args.base)
    else:
        print("Inactive. --install compiles contracts; --check reads existing flow records and API boundaries.")


if __name__ == "__main__":
    main()
