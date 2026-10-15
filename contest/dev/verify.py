#!/usr/bin/env python3
"""Exercise the real stdio MCP protocol, not just the Agentic Dev CLI."""
import json
from pathlib import Path
import queue
import subprocess
import sys
import threading

root = Path(__file__).resolve().parents[2]
process = subprocess.Popen(
    [sys.executable, str(root / "contest/dev/mcp.py"), "mcp"],
    cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
    text=True, bufsize=1,
)
lines = queue.Queue()
def read_output():
    for line in process.stdout:
        lines.put(line)
    lines.put(None)
threading.Thread(target=read_output, daemon=True).start()
sequence = 0

def request(method, params):
    global sequence
    sequence += 1
    process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": sequence,
                                    "method": method, "params": params}) + "\n")
    process.stdin.flush()
    while True:
        line = lines.get(timeout=90)
        if line is None:
            raise RuntimeError("MCP process exited before responding")
        message = json.loads(line)
        if message.get("id") == sequence:
            if "error" in message:
                raise RuntimeError(json.dumps(message["error"]))
            return message["result"]

def tool(name, arguments):
    result = request("tools/call", {"name": name, "arguments": arguments})
    texts = [entry["text"] for entry in result.get("content", []) if entry.get("type") == "text"]
    text = "\n".join(texts)
    if result.get("isError"):
        raise RuntimeError(name + ": " + text)
    payload = json.loads(text)
    if payload.get("success") is False or payload.get("error"):
        raise RuntimeError(name + ": " + text)
    print(name + ": " + text[:6000])
    return payload

try:
    initialized = request("initialize", {
        "protocolVersion": "2024-11-05", "capabilities": {},
        "clientInfo": {"name": "triage-mcp-acceptance", "version": "1"},
    })
    print("MCP initialized:", initialized["serverInfo"])
    if initialized["serverInfo"] != {"name": "iris-agentic-dev", "version": "1.5.0"}:
        raise RuntimeError("Unexpected MCP server or version")
    process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
    process.stdin.flush()
    catalog = request("tools/list", {})
    names = {entry["name"] for entry in catalog["tools"]}
    print("Advertised tools:", sorted(names))
    if names - {"check_config", "iris_doc", "iris_compile", "iris_query", "iris_search",
                "iris_symbols", "iris_test", "iris_debug", "iris_get_log"}:
        raise RuntimeError("MCP advertised tools outside the project allowlist")
    config = tool("check_config", {})
    if (config.get("host") != "127.0.0.1" or config.get("port") != 52779
            or config.get("namespace") != "TRIAGE"
            or config.get("connection_source") != "config_file"):
        raise RuntimeError("MCP is not pinned to the contest instance")
    if not config.get("config_file") or config.get("destructive_tools_enabled"):
        raise RuntimeError("Workspace configuration or destructive gate not verified")
    tool("iris_doc", {"mode": "get", "name": "Contest.Request.cls", "namespace": "TRIAGE"})
    if "--tests" in sys.argv:
        tool("iris_doc", {"mode": "put", "name": "Contest.DevTests.cls",
                         "content": (root / "contest/dev/DevTests.cls").read_text(),
                         "namespace": "TRIAGE", "compile": False})
        tool("iris_compile", {"target": "Contest.DevTests.cls", "namespace": "TRIAGE"})
        result = tool("iris_test", {"pattern": "Contest.DevTests", "namespace": "TRIAGE",
                                   "test_type": "testproduction"})
        if (result.get("total", 0) < 4 or result.get("failed") != 0
                or result.get("errors") != 0 or result.get("passed") != result["total"]):
            raise RuntimeError("UnitTest did not report the required passing test methods")
        log = tool("iris_get_log", {"id": result["log_id"]})
        output = log["result"]["raw_output"]
        assertions = [line for line in output.splitlines()
                      if "AssertEquals:" in line or "AssertTrue:" in line]
        if len(assertions) < 7 or any("(passed)" not in line for line in assertions):
            raise RuntimeError("Required framework assertions did not all pass")
        print("Verified passing framework assertions:", len(assertions))
    print("MCP_ACCEPTANCE_PASSED")
finally:
    process.stdin.close()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.terminate()
        process.wait(timeout=5)
