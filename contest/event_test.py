#!/usr/bin/env python3
"""Non-billing event acceptance against only the local synthetic DEMO."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import time

from platform_test import request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="http://127.0.0.1:5173/api/monitor/v1")
    args = parser.parse_args()
    base, builder = args.base, "ContestKnowledgeAdmin"
    assert request(base, "/events", account=None)[0] == 401
    assert request(base, "/events/action", body={})[0] == 403
    assert request(base, "/events/investigate", account=builder, body={})[0] == 400
    code, before = request(base, "/agents", account=builder)
    assert code == 200
    code, message = request(base, "/demo/messages", account=builder, body={"scenario": "failure"})
    assert code == 200
    deadline = time.monotonic() + 25
    while True:
        code, state = request(base, "/events", account=builder)
        assert code == 200
        found = [e for e in state["events"] if e["observation_id"] == message["observation_id"]]
        if found:
            event = found[0]
            break
        assert time.monotonic() < deadline, "Real observation was not consumed into an event"
        time.sleep(1)
    code, detail = request(base, f"/events/{event['id']}", account=builder)
    assert code == 200 and detail["observation"]["schema"] == 2
    assert detail["observation"]["facts"]["synthetic"]
    body = {"id": event["id"], "revision": event["revision"], "action": "in_review",
            "text": "Synthetic acceptance: begin human review."}
    with ThreadPoolExecutor(max_workers=5) as pool:
        results = list(pool.map(lambda _: request(base, "/events/action", account=builder, body=body), range(5)))
    assert sum(code == 200 for code, _ in results) == 1
    assert sum(code == 409 for code, _ in results) == 4
    event = next(value for code, value in results if code == 200)
    for target in ("resolved", "open"):
        code, event = request(base, "/events/action", account=builder, body={
            "id": event["id"], "revision": event["revision"], "action": target,
            "text": "Synthetic acceptance lifecycle transition; no business replay.",
        })
        assert code == 200
    coverage = next((e for e in state["events"] if e["category"] == "coverage_gap"), None)
    if coverage:
        opinion = "Hold synthetic analytics exports with direct identifiers for manual review."
        if not any(o["text"] == opinion for o in coverage["opinions"]):
            code, saved = request(base, "/events/action", account=builder, body={
                "id": coverage["id"], "revision": coverage["revision"], "action": "opinion", "text": opinion,
            })
            assert code == 200 and saved["opinions"][-1]["summary_state"] == "not_requested"
    code, after = request(base, "/agents", account=builder)
    assert code == 200 and len(after["jobs"]) == len(before["jobs"])
    code, final = request(base, "/events", account=builder)
    assert code == 200 and final["automatic_model_budget"] == 0
    assert all(r["state"] == "blocked_budget" for r in final["reviews"] if r["origin"] == "source_sample")
    print("PASS: real schema-2 observation/event, five concurrent revisions, human lifecycle, local opinion and zero automatic inference")


if __name__ == "__main__":
    main()
