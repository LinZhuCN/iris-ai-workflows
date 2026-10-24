#!/usr/bin/env python3
"""Non-billing HTTP checks for the fixed local privacy Agent factory."""
import argparse

from platform_test import request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="http://127.0.0.1:5173/api/monitor/v1")
    args = parser.parse_args()
    base = args.base
    builder = "ContestKnowledgeAdmin"
    assert request(base, "/agents", account=None)[0] == 401
    code, reader = request(base, "/agents")
    assert code == 200 and not reader["can_write"]
    for action in ("generate", "test", "retest", "edit", "revise", "publish", "bind", "disable"):
        assert request(base, f"/agents/{action}", body={})[0] == 403
    for action in ("generate", "test", "retest"):
        for body in ({}, {"acknowledge_cost": False}, {"acknowledge_cost": "true"}):
            assert request(base, f"/agents/{action}", account=builder, body=body)[0] == 400
    assert request(base, "/agents/generate", account=builder, body={}, header=False)[0] == 403
    assert request(base, "/agents/edit", account=builder, raw=b"{")[0] == 400
    assert request(base, "/agents/revise", account=builder, body={}, header=False)[0] == 403
    for raw in (b"null", b"[]", b"3"):
        assert request(base, "/agents/revise", account=builder, raw=raw)[0] == 400
    for body in ({"id": "nonexistent", "revision": 1}, {"id": "", "revision": 1},
                 {"id": 12, "revision": 1}, {"id": "nonexistent", "revision": "1"}):
        assert request(base, "/agents/publish", account=builder, body=body)[0] == 409
    code, state = request(base, "/agents", account=builder)
    assert code == 200 and state["can_write"]
    for config in state["agents"]:
        assert config["template"] == "privacy_review" and config["max_iterations"] == 4
        assert config["executor_version"] == "privacy-v1"
        if config.get("prompt_version"):
            assert config["prompt_version"] == "privacy-review-v2" and len(config["prompt_hash"]) == 64
            if config["status"] == "draft":
                # Explicit cost consent cannot bypass the server's v2 legacy-test rejection.
                body = {"id": config["id"], "revision": config["revision"], "acknowledge_cost": True}
                assert request(base, "/agents/test", account=builder, body=body)[0] == 409
                assert request(base, "/agents/retest", account=builder, body={**body, "report_id": "unused"})[0] == 409
        if config["status"] == "published":
            body = {"id": config["id"], "revision": config["revision"],
                    "draft": {k: config[k] for k in ("name", "purpose", "retrieval_query")}}
            assert request(base, "/agents/edit", account=builder, body=body)[0] == 409
            assert request(base, "/agents/disable", account=builder,
                           body={"id": config["id"], "revision": config["revision"] - 1})[0] == 409
    for job in state["jobs"]:
        if job["kind"] != "test" or not job.get("passed"):
            continue
        assert job["state"] == "completed" and len(job["cases"]) == 3
        for case in job["cases"]:
            assert case["passed"] and case["result"]["assessment"] == case["expected"]
            assert {"ReadPrivacyFacts", "SearchPrivacyEvidence"} <= {t["tool"] for t in case["tools"]}
            assert set(case["result"]["citations"]) <= {e["id"] for e in case["evidence"]}
    print("PASS: authentication, roles, cost/CSRF gates, input guards, immutable published versions and retained real report provenance; no model calls")


if __name__ == "__main__":
    main()
