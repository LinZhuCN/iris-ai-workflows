#!/usr/bin/env python3
"""Non-billing real DEMO rule activation and approved rollback acceptance."""
import argparse
import copy
import time
import uuid

from platform_test import request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="http://127.0.0.1:5173/api/monitor/v1")
    args = parser.parse_args()
    base, actor = args.base, "ContestKnowledgeAdmin"

    def call(path, body=None, expected=200):
        code, value = request(base, path, account=actor, body=body)
        assert code == expected, (path, code, value)
        return value

    def approve_apply(plan):
        call("/rules/approve", {"id": plan["id"], "digest": plan["digest"]})
        return call("/rules/apply", {"id": plan["id"], "digest": plan["digest"]})

    def verified(plan_id):
        deadline = time.monotonic() + 30
        while True:
            state = call("/rules")
            plan = next(p for p in state["plans"] if p["id"] == plan_id)
            if plan["state"] == "effect_verified":
                return plan
            assert time.monotonic() < deadline, ("Real effect receipts missing", plan)
            time.sleep(1)

    connector = base.removesuffix("/v1") + "/connector"

    def target(path, body, expected=200, account="ContestConnectorManager"):
        code, result = request(connector, path, account=account, body=body)
        assert code == expected, (path, code, result)
        return result

    assert request(base, "/rules", account=None)[0] == 401
    assert request(base, "/rules/create", body={})[0] == 403
    assert request(base, "/rules/create", account=actor, body={}, header=False)[0] == 403
    for raw in (b"null", b"[]", b"3", b'"text"'):
        assert request(base, "/rules/create", account=actor, raw=raw)[0] == 400
    state = call("/rules")
    assert state["target"]["bundle"]["enabled"] is False, "Acceptance requires the initial non-enforcing DEMO"
    jobs_before = call("/agents")["jobs"]
    baseline = call("/demo/messages", {"scenario": "analytics"})
    assert baseline["outcome"] == "delivered"
    evidence = call("/demo/messages", {"scenario": "failure"})
    deadline = time.monotonic() + 30
    while True:
        events = call("/events")["events"]
        event = next((e for e in events if e["observation_id"] == evidence["observation_id"]), None)
        if event:
            break
        assert time.monotonic() < deadline, "Synthetic event evidence was not received"
        time.sleep(1)
    event = call("/events/action", {"id": event["id"], "revision": event["revision"], "action": "opinion",
                                   "text": "Synthetic acceptance opinion: require manual review for analytics with direct identifiers. This technical failure is not a privacy finding."})
    create = {"event_id": event["id"], "opinion_id": event["opinions"][-1]["id"], "bundle": state["template"]}
    bad = copy.deepcopy(create)
    bad["bundle"]["endpoint"] = "http://not-allowed.invalid"
    call("/rules/create", bad, expected=409)
    bad = copy.deepcopy(create)
    bad["opinion_id"] = "missing"
    call("/rules/create", bad, expected=409)
    draft = call("/rules/create", create)
    assert draft["origin"] == "manual_template_not_ai"
    call("/rules/plan", {"id": draft["id"], "revision": draft["revision"]}, expected=409)
    tested = call("/rules/test", {"id": draft["id"], "revision": draft["revision"]})
    assert tested["report"]["passed"] is True and len(tested["report"]["cases"]) == 5
    call("/rules/plan", {"id": draft["id"], "revision": draft["revision"]}, expected=409)
    plan = call("/rules/plan", {"id": tested["id"], "revision": tested["revision"]})
    competing = call("/rules/plan", {"id": tested["id"], "revision": tested["revision"]})
    preparation = {"deployment_id": "rule-plan-" + uuid.uuid4().hex, "bundle_hash": plan["bundle_hash"],
                   "source_hash": plan["source_hash"], "expected_revision": plan["expected_revision"], "bundle": plan["bundle"]}
    target("/rules/prepare", preparation, expected=403, account="ContestConnectorReader")
    target("/rules/prepare", {**preparation, "bundle_hash": "0" * 64}, expected=409)
    prepared = target("/rules/prepare", preparation)
    assert prepared["state"] == "prepared"
    assert target("/rules/prepare", preparation) == prepared
    target("/rules/prepare", {**preparation, "expected_revision": preparation["expected_revision"] + 1}, expected=409)
    assert call("/rules")["target"]["revision"] == state["target"]["revision"], "Preparation must never activate"
    for digest in ("wrong", plan["digest"]):
        call("/rules/apply", {"id": plan["id"], "digest": digest}, expected=409)
    assert next(p for p in call("/rules")["plans"] if p["id"] == plan["id"])["state"] == "planned"
    activated = False
    try:
        loaded = approve_apply(plan)
        activated = True
        assert loaded["state"] == "loaded"
        assert [p["outcome"] for p in loaded["probes"]] == ["held_for_review", "delivered"]
        proven = verified(plan["id"])
        target("/rules/prepare", {**preparation, "deployment_id": "rule-plan-" + uuid.uuid4().hex}, expected=409)
        target("/rules/activate", {"deployment_id": preparation["deployment_id"], "bundle_hash": preparation["bundle_hash"]}, expected=409)
        call("/rules/approve", {"id": competing["id"], "digest": competing["digest"]}, expected=409)
        repeated = call("/rules/apply", {"id": plan["id"], "digest": plan["digest"]})
        assert repeated["probes"] == proven["probes"], "Same deployment must not replay business messages"
        assert repeated["loaded"]["revision"] == proven["loaded"]["revision"]
        events = call("/events")["events"]
        assert any(e["category"] == "rule_hold" and e["observation_id"] == loaded["probes"][0]["observation_id"] for e in events)
        rollback = call("/rules/rollback", {"id": plan["id"]})
        assert rollback["state"] == "planned" and rollback["bundle"]["enabled"] is False
        call("/rules/apply", {"id": rollback["id"], "digest": rollback["digest"]}, expected=409)
        restored = approve_apply(rollback)
        assert all(p["outcome"] == "delivered" for p in restored["probes"])
        verified(rollback["id"])
        activated = False
        final = call("/rules")
        assert final["target"]["bundle"]["enabled"] is False
        assert final["target"]["revision"] == state["target"]["revision"] + 2
        assert len(call("/agents")["jobs"]) == len(jobs_before)
        print("PASS: five golden cases, exact approval, source revision guard, held/delivered real probes, idempotent apply, rule event and approved rollback; zero model calls")
        print(f"Evidence: active plan {plan['id']}; rollback {rollback['id']}; final revision {final['target']['revision']}")
    finally:
        target = call("/rules")["target"]
        if activated or (target["deployment_id"] == plan["id"] and target["bundle"]["enabled"]):
            rollback = call("/rules/rollback", {"id": plan["id"]})
            approve_apply(rollback)
            verified(rollback["id"])
            print("Restored prior non-enforcing DEMO policy after acceptance failure.")


if __name__ == "__main__":
    main()
