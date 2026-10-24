#!/usr/bin/env python3
"""P2 live HTTP acceptance; uses only the dedicated synthetic DEMO Production."""
from concurrent.futures import ThreadPoolExecutor
import json
import subprocess
import time
import uuid

from platform_test import request

BASE = "http://127.0.0.1:5173/api/monitor"
ADMIN = "ContestKnowledgeAdmin"


def call(path, body=None, account=ADMIN, expected=200):
    code, result = request(BASE, path, account=account, body=body)
    assert code == expected, (path, code, result)
    return result


def wait_for(predicate, timeout=45):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        state = call("/v1/pipelines")
        if predicate(state):
            return state
        time.sleep(1)
    raise AssertionError("P2 condition timed out: " + json.dumps(state))


def demo_terminal(command):
    result = subprocess.run(
        ["docker", "exec", "-i", "iris-triage-real-iris-1", "iris", "session", "IRIS", "-U", "DEMO"],
        input=command + '\nHalt\n', capture_output=True, text=True, timeout=30, check=True,
    )
    assert "ACCEPTANCE_OK" in result.stdout, result.stdout + result.stderr
    return result.stdout


def change_interval(value=None):
    literal = json.dumps(value) if value is not None else '""'
    output = demo_terminal(
        'Set production=##class(Ens.Config.Production).%OpenId("Demo.Production")\n'
        'For i=1:1:production.Items.Count() { Set item=production.Items.GetAt(i) If item.Name="ObservationDispatcher" { Set setting=item.Settings.GetAt(1) Write "OLD_INTERVAL=",setting.Value,! '
        f'If {literal}\'="" Set setting.Value={literal} '
        '} }\n'
        'Set sc=production.%Save()\n'
        'If sc Write "ACCEPTANCE_OK",!\n'
    )
    return output.split("OLD_INTERVAL=", 1)[1].splitlines()[0]


def main():
    call("/v1/instances", account=None, expected=401)
    health = call("/connector/health", account="ContestConnectorReader")
    assert health["namespaces"] == ["DEMO"] and not health["arbitrary_instrumentation"]
    call("/connector/deploy", {}, account="ContestConnectorReader", expected=403)
    call("/v1/instances", account="ContestDemoSource", expected=401)
    call("/v1/instances/local-demo/discover", {}, account="ContestViewer", expected=403)
    call("/v1/instances/local-demo/discover", {"namespace": "USER"}, expected=400)
    for body in ([], None, {"scenario": "shell"}, {"scenario": "treatment", "payload": "forbidden"}):
        if body is not None:
            call("/v1/demo/messages", body, expected=400)
    snapshot = call("/v1/instances/local-demo/discover", {})
    assert snapshot["namespace"] == "DEMO" and snapshot["production"] == "Demo.Production"
    assert snapshot["running"] and len(snapshot["nodes"]) == 8
    assert len(snapshot["config_hash"]) == 64
    plan = call("/v1/deployments/plan", {"snapshot_id": snapshot["id"]})
    path = "/v1/deployments/" + plan["id"]
    call(path + "/apply", {"digest": plan["digest"]}, expected=409)
    call(path + "/approve", {"digest": "wrong"}, expected=409)
    call(path + "/approve", {"digest": plan["digest"]})
    applied = call(path + "/apply", {"digest": plan["digest"]})
    assert applied["state"] == "verifying", applied
    state = wait_for(lambda s: s["deployment"]["state"] == "active" and s["transport"]["pending"] == 0)
    assert state["deployment"]["loaded"]["digest"] == plan["digest"]
    # Re-applying the same deployment cannot replay the probe.
    probe = call(path + "/apply", {"digest": plan["digest"]})
    assert probe["probe"] == state["deployment"]["probe"]
    messages = []
    for scenario in ("treatment", "analytics", "failure"):
        message = call("/v1/demo/messages", {"scenario": scenario})
        assert message["outcome"] == ("failed" if scenario == "failure" else "delivered")
        assert message["observation_id"] and message["session_id"]
        assert len(message["observation_id"]) == 69, "Stable SHA-256 observation identity must survive BP response persistence"
        messages.append(message)
    ids = {m["observation_id"] for m in messages}
    state = wait_for(lambda s: ids <= {o["observation_id"] for o in s["observations"]} and not s["transport"]["pending"])
    observation = next(o for o in state["observations"] if o["observation_id"] == messages[0]["observation_id"])
    before = state["received"]
    # 20 real concurrent submissions of a new observation produce one inbox / receipt.
    duplicate_body = {**observation, "observation_id": "demo-" + str(uuid.uuid4())}
    reordered_body = dict(reversed(list(duplicate_body.items())))
    with ThreadPoolExecutor(max_workers=5) as pool:
        receipts = list(pool.map(lambda i: call("/inbox/observations", duplicate_body if i % 2 else reordered_body, account="ContestDemoSource"), range(20)))
    assert sum(not r["duplicate"] for r in receipts) == 1
    state = wait_for(lambda s: s["received"] == before + 1)
    assert sum(o["observation_id"] == duplicate_body["observation_id"] for o in state["observations"]) == 1
    call("/inbox/observations", {**duplicate_body, "outcome": "failed"}, account="ContestDemoSource", expected=409)
    call("/inbox/observations", {**duplicate_body, "namespace": "USER"}, account="ContestDemoSource", expected=400)
    call("/inbox/observations", duplicate_body, account=ADMIN, expected=401)
    print("PASS: identity / namespace boundaries, actual topology, digest approval, target acknowledgment, probe, three routes, 20-way duplicate suppression and conflict")
    # Receiver returns actual HTTP 503. Business processing does not wait for it.
    dispatcher_stopped = False
    try:
        call("/v1/demo/transport", {"paused": True})
        started = time.monotonic()
        message = call("/v1/demo/messages", {"scenario": "analytics"})
        elapsed = time.monotonic() - started
        assert elapsed < 5, elapsed
        assert message["outcome"] == "delivered"
        state = wait_for(lambda s: s["transport"]["retrying"] >= 1)
        assert message["observation_id"] not in {o["observation_id"] for o in state["observations"]}
        dispatcher_stopped = True
        demo_terminal(
            'Set sc=##class(Ens.Director).EnableConfigItem("ObservationDispatcher",0)\n'
            'If sc Write "ACCEPTANCE_OK",!\n'
        )
        assert call("/v1/pipelines")["transport"]["pending"] >= 1
    finally:
        call("/v1/demo/transport", {"paused": False})
        if dispatcher_stopped:
            demo_terminal(
                'Set sc=##class(Ens.Director).EnableConfigItem("ObservationDispatcher",1)\n'
                'If sc Write "ACCEPTANCE_OK",!\n'
            )
    state = wait_for(lambda s: not s["transport"]["pending"] and message["observation_id"] in {o["observation_id"] for o in s["observations"]})
    assert state["transport"]["dropped"] == 0
    print(f"PASS: actual HTTP 503 outage, business completed in {elapsed:.3f}s, persistent outbox retry and eventual receipt")
    # A saved target configuration change invalidates approval, even without a restart.
    snapshot = call("/v1/instances/local-demo/discover", {})
    plan = call("/v1/deployments/plan", {"snapshot_id": snapshot["id"]})
    original = change_interval()
    try:
        change_interval("2.25" if original != "2.25" else "2.5")
        call("/v1/deployments/" + plan["id"] + "/approve", {"digest": plan["digest"]}, expected=409)
        assert call("/v1/pipelines")["deployment"]["state"] == "stale"
    finally:
        change_interval(original)
    # Two approved plans on one observer baseline cannot overwrite each other.
    snapshot = call("/v1/instances/local-demo/discover", {})
    first = call("/v1/deployments/plan", {"snapshot_id": snapshot["id"]})
    second = call("/v1/deployments/plan", {"snapshot_id": snapshot["id"]})
    for candidate in (first, second):
        call("/v1/deployments/" + candidate["id"] + "/approve", {"digest": candidate["digest"]})
    call("/v1/deployments/" + first["id"] + "/apply", {"digest": first["digest"]})
    call("/v1/deployments/" + second["id"] + "/apply", {"digest": second["digest"]}, expected=409)
    call("/v1/deployments/plan", {"snapshot_id": snapshot["id"]}, expected=409)
    snapshot = call("/v1/instances/local-demo/discover", {})
    plan = call("/v1/deployments/plan", {"snapshot_id": snapshot["id"]})
    call("/v1/deployments/" + plan["id"] + "/approve", {"digest": plan["digest"]})
    call("/v1/deployments/" + plan["id"] + "/apply", {"digest": plan["digest"]})
    state = wait_for(lambda s: s["deployment"]["state"] == "active" and not s["transport"]["pending"])
    print("PASS: target drift and competing observer revisions rejected, dispatcher recovery, exact config restored, fresh approved deployment verified")
    print(f"READY: {state['received']} received observations, pending=0, receiver restored")


if __name__ == "__main__":
    main()
