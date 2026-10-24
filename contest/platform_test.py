#!/usr/bin/env python3
"""Exercise the local Knowledge API; --build explicitly adds a shadow rebuild."""
import argparse
import base64
import json
from pathlib import Path
import time
import urllib.error
import urllib.request

DIRECTORY = Path(__file__).resolve().parent / "data/platform"
QUESTION = "Remove medical record numbers and all elements of dates except year Safe Harbor de-identification identifiers"


def request(base, path, account="ContestViewer", body=None, header=True, raw=None):
    headers = {"Accept": "application/json"}
    if account:
        password = (DIRECTORY / f"{account}.password").read_text().strip()
        headers["Authorization"] = "Basic " + base64.b64encode(f"{account}:{password}".encode()).decode()
    if body is not None or raw is not None:
        headers["Content-Type"] = "application/json"
        if header:
            headers["X-Requested-With"] = "IRIS-Workflows"
    data = raw if raw is not None else json.dumps(body).encode() if body is not None else None
    try:
        response = urllib.request.urlopen(
            urllib.request.Request(base + path, headers=headers, data=data), timeout=120,
        )
    except urllib.error.HTTPError as error:
        response = error
    with response:
        text = response.read().decode()
        return response.code, json.loads(text) if "application/json" in response.headers.get("Content-Type", "") else text[:300]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="http://127.0.0.1:5173/api/monitor/v1")
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--failure", action="store_true", help="Temporarily change only the local prepared export to verify failure isolation")
    args = parser.parse_args()
    assert request(args.base, "/knowledge", account=None)[0] == 401
    code, before = request(args.base, "/knowledge")
    assert code == 200, (code, before)
    assert before["ready"] and before["chunks"] == 1785 and before["dimensions"] == 384
    assert not before["can_build"]
    assert request(args.base, "/knowledge/builds", body={})[0] == 403
    for raw in (b"null", b"12", b'"text"', b"[]"):
        code, result = request(args.base, "/knowledge/builds", account="ContestKnowledgeAdmin", raw=raw)
        assert code == 400, (raw, code, result)
    assert request(args.base, "/knowledge/search", body={"query": QUESTION}, header=False)[0] == 403
    for body in ({}, {"query": ""}, {"query": " "}, {"query": 9}, {"query": QUESTION, "scope": "unreviewed"}, {"query": "a" * 1001}):
        assert request(args.base, "/knowledge/search", body=body)[0] == 400, body
    assert request(args.base, "/knowledge/search", raw=b"{")[0] == 400
    assert request(args.base, "/knowledge/search", raw=b'{"query":"' + b"a" * 5000 + b'"}')[0] == 413
    assert request(args.base, "/knowledge/builds/99999999")[0] == 404
    code, results = request(args.base, "/knowledge/search", body={"query": QUESTION})
    assert code == 200, (code, results)
    assert len(results["value"]) == 5
    assert any("164.514" in hit["metadata"]["source_locator"] for hit in results["value"])
    for hit in results["value"]:
        assert hit["text"] and hit["metadata"]["source_url"].startswith("https://")
        assert hit["metadata"]["retrieval_scope"] in ("normative", "technical", "orientation", "organization_policy")
    print("PASS: authentication, reader/build separation, input boundaries, provenance and real retrieval")
    if args.build:
        code, result = request(args.base, "/knowledge/builds", account="ContestKnowledgeAdmin", body={})
        assert code == 202, (code, result)
        job = str(result["job_id"])
        deadline = time.monotonic() + 600
        observed_search = False
        last = None
        while time.monotonic() < deadline:
            code, last = request(args.base, f"/knowledge/builds/{job}")
            assert code == 200, (code, last)
            if last["state"] in ("failed", "interrupted"):
                raise AssertionError(last)
            if last["state"] == "completed":
                break
            if last["state"] == "running" and not observed_search:
                code, active = request(args.base, "/knowledge")
                assert code == 200 and active["index_version"] == before["index_version"]
                assert request(args.base, "/knowledge/search", body={"query": QUESTION})[0] == 200
                assert request(args.base, "/knowledge/builds", account="ContestKnowledgeAdmin", body={})[0] == 409
                observed_search = True
            time.sleep(2)
        assert last and last["state"] == "completed", last
        code, after = request(args.base, "/knowledge")
        assert code == 200 and str(after["index_version"]) == job and after["chunks"] == 1785
        assert observed_search, "Did not observe old-index retrieval during shadow build"
        assert request(args.base, "/knowledge/search", body={"query": QUESTION})[0] == 200
        print(f"PASS: persistent job {job}, concurrent old-index search, conflict guard, atomic activation and reader access")
    if args.failure:
        export = DIRECTORY.parent / "knowledge/platform-default.jsonl"
        original = export.read_bytes()
        code, before = request(args.base, "/knowledge")
        assert code == 200
        try:
            export.write_bytes(original + b"\n")
            code, result = request(args.base, "/knowledge/builds", account="ContestKnowledgeAdmin", body={})
            assert code == 202, (code, result)
            deadline = time.monotonic() + 60
            while time.monotonic() < deadline:
                code, last = request(args.base, f'/knowledge/builds/{result["job_id"]}')
                assert code == 200
                if last["state"] in ("failed", "completed", "interrupted"):
                    break
                time.sleep(1)
            assert last["state"] == "failed", last
            code, after = request(args.base, "/knowledge")
            assert code == 200 and after["index_version"] == before["index_version"]
            assert request(args.base, "/knowledge/search", body={"query": QUESTION})[0] == 200
            print("PASS: changed-source build fails explicitly; active version and retrieval remain unchanged")
        finally:
            export.write_bytes(original)


if __name__ == "__main__":
    main()
