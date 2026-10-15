#!/usr/bin/env python3
"""Run synthetic end-to-end tests through a real IRIS Production."""
import os
from pathlib import Path
import subprocess
import sys
import json
import uuid
import time
import re

compose = [
    "docker", "compose", "-p", os.environ.get("COMPOSE_PROJECT_NAME", "iris-triage"),
    "-f", str(Path(__file__).with_name("compose.yaml")),
]

def terminal(code, marker):
    result = subprocess.run(
        compose + ["exec", "-T", "iris", "iris", "session", "IRIS", "-U", "TRIAGE"],
        input=code + "\nHalt\n", text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=180,
    )
    if marker != "SNAPSHOT_DONE":
        print(result.stdout)
    if result.returncode or not re.search(r"^" + re.escape(marker) + r"$", result.stdout, re.MULTILINE):
        raise RuntimeError("IRIS verification did not complete: " + marker)
    return result.stdout


def literal(value):
    return '"' + value.replace('"', '""') + '"'


def mock_call(path, body=None):
    script = (
        "const r=await fetch('http://127.0.0.1:8088" + path + "',"
        + json.dumps({"method": "POST", "headers": {"content-type": "application/json"},
                      "body": json.dumps(body)}) + ");"
        + "if(!r.ok)throw Error(await r.text());console.log(await r.text());"
        if body is not None else
        "const r=await fetch('http://127.0.0.1:8088" + path
        + "');if(!r.ok)throw Error(await r.text());console.log(await r.text());"
    )
    result = subprocess.run(
        compose + ["exec", "-T", "mock", "node", "--input-type=module", "-e", script],
        text=True, capture_output=True, check=True, timeout=20,
    )
    return json.loads(result.stdout)


if "--persistence-only" not in sys.argv:
    mode = "real" if "--real" in sys.argv else "mock"
    terminal('Set sc=##class(Contest.Tests).Run(' + literal(mode) + ')', "TRIAGE_TESTS_PASSED")
for mode, expected in ([] if "--real" in sys.argv or "--persistence-only" in sys.argv else [
    ("unsafe_deliver", "Policy forbids delivery"),
    ("unknown_action", "Policy rejected unknown action"),
    ("empty_reason", "Policy requires a nonempty reason"),
    ("wrong_type", "must be strings"),
    ("invalid_json", "Parsing error"),
    ("wrong_case", "Fact tool failed"),
    ("skip_tool", "did not read the bound case facts"),
    ("provider_error", "Injected mock failure"),
]):
    mock_call("/scenario", {"mode": mode})
    external_id = "failure-" + mode + "-" + uuid.uuid4().hex
    payload = json.dumps({"reference": "synthetic-only", "code": "OBS"})
    terminal(
        "Set sc=##class(Contest.Tests).Fail(" + literal(external_id) + ","
        + literal(payload) + "," + literal(expected) + ')\nIf sc Write "FAILURE_VERIFIED",!',
        "FAILURE_VERIFIED",
    )
if "--persistence-only" not in sys.argv:
    print("Real-provider workflow checks passed." if "--real" in sys.argv
          else "All synthetic end-to-end and injected-failure checks passed.")

if "--restart" in sys.argv or "--persistence-only" in sys.argv:
    code = 'Write "SNAPSHOT=",##class(Contest.Tests).Snapshot(),!\nWrite "SNAPSHOT_DONE",!'
    before = terminal(code, "SNAPSHOT_DONE")
    subprocess.run(compose + ["exec", "-T", "iris", "rm", "-f", "/tmp/triage-ready"], check=True)
    subprocess.run(compose + ["restart", "iris"], check=True, timeout=120)
    deadline = time.monotonic() + 180
    while True:
        ready = subprocess.run(
            compose + ["exec", "-T", "iris", "test", "-f", "/tmp/triage-ready"],
            capture_output=True, timeout=10,
        )
        if ready.returncode == 0:
            break
        if time.monotonic() >= deadline:
            raise RuntimeError("IRIS did not become ready after restart")
        time.sleep(2)
    after = terminal(code, "SNAPSHOT_DONE")
    def snapshot(output):
        return json.loads(next(line.removeprefix("SNAPSHOT=") for line in output.splitlines()
                               if line.startswith("SNAPSHOT=")))
    if snapshot(before) != snapshot(after):
        raise RuntimeError("Cases, destinations or audit history changed across restart")
    print("Restart persistence verified: all cases, destinations and audit events are unchanged.")
    terminal('Set sc=##class(Contest.Tests).Recheck()', "RESTART_DUPLICATES_VERIFIED")
