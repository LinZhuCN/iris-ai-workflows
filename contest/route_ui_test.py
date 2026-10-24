#!/usr/bin/env python3
"""Install the route UI backend or check its local HTTP boundaries without sending data or models."""
import argparse
import base64
import json
from pathlib import Path
import urllib.error
import urllib.parse
import urllib.request

from business_privacy import require
from platform_test import request
from route_evidence_test import receipt_pin, validate
from utilization_test import MARKER, execute

ROOT = Path(__file__).resolve().parent


def local_base(base):
    url = urllib.parse.urlparse(base)
    require(url.scheme == "http" and url.hostname in ("127.0.0.1", "localhost") and
            not url.username and not url.password, "Local demo API only; never send admin credentials to a remote host")


def admin_request(base, path, body=None, *, header=True, raw=None):
    local_base(base)
    password = (ROOT / "data/portal-admin-password").read_text().strip()
    headers = {"Accept": "application/json",
               "Authorization": "Basic " + base64.b64encode(("superuser:" + password).encode()).decode()}
    if body is not None or raw is not None:
        headers["Content-Type"] = "application/json"
        if header:
            headers["X-Requested-With"] = "IRIS-Workflows"
    data = raw if raw is not None else json.dumps(body).encode() if body is not None else None
    try:
        response = urllib.request.urlopen(urllib.request.Request(base + path, data=data, headers=headers), timeout=120)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        require("application/json" in response.headers.get("Content-Type", ""), "Expected JSON response")
        return response.status, json.loads(response.read())


def check(base):
    local_base(base)
    require(request(base, "/governance", account=None)[0] == 401, "Anonymous access must be denied")
    status, before = request(base, "/governance")
    require(status == 200 and before["can_write"] in (False, 0), "Reader registry access required")
    for path in ("/governance/register", "/governance/approve"):
        require(request(base, path, body={})[0] == 403, "Readers cannot mutate registry")
    require(request(base, "/governance/template")[0] == 403, "Readers cannot prepare proposals")
    require(admin_request(base, "/governance/approve", {}, header=False)[0] == 403, "CSRF request header required")
    require(admin_request(base, "/governance/approve", raw=b"[" + b" " * 4096 + b"]")[0] == 413,
            "Request body must remain bounded")
    for raw in (b"null", b"[]", b'"invalid"', b"{"):
        require(admin_request(base, "/governance/register", raw=raw)[0] == 400, "Malformed/scalar bodies must be rejected")
    status, template = admin_request(base, "/governance/template")
    require(status == 200 and template["declaration"]["scope"]["max_records"] == 4 and
            len(template["declaration"]["scope"]["fields"]) == 7, "Fixed actual utilization template required")
    for kind, batch in (("aggregation", "aggregation-internal-demo"), ("utilization", "utilization-quality-demo")):
        path = ROOT / "data/evaluations" / (batch + "-" + kind + ".json")
        saved = json.loads(path.read_text())
        receipt = saved.get("receipt", saved)
        pin = receipt_pin(path, kind, batch)
        body = {"id": receipt["approval_id"], "batch_id": batch, "receipt_hash": pin}
        status, result = admin_request(base, "/governance/evidence", body)
        require(status == 200, "Actual historical evidence HTTP read failed: " + str(result))
        validate(result, kind, batch, pin)
        status, result = admin_request(base, "/governance/evidence", {**body, "receipt_hash": "0" * 64})
        require(status == 409 and result["code"] == "governance_rejected", "Wrong original pin must fail explicitly")
    status, after = request(base, "/governance")
    require(status == 200 and before == after, "Read-only checks must not mutate declarations/approvals")
    print("PASS authentication, reader/write separation, CSRF/body bounds, fixed template and both pinned evidence reads.")
    print("No declarations registered, approvals changed, data sent or model invoked.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--install", action="store_true")
    group.add_argument("--check", action="store_true")
    parser.add_argument("--base", default="http://127.0.0.1:5173/api/monitor/v1")
    args = parser.parse_args(argv)
    if args.install:
        execute("TRIAGE",
                'For path="/contest/src/RouteScenario.cls","/contest/src/RouteGovernance.cls",'
                '"/contest/src/RouteUI.cls","/contest/src/KnowledgeAPI.cls" { '
                'Set sc=$SYSTEM.OBJ.Load(path,"ck") '
                'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } '
                f'Write "{MARKER}",{{"installed":true}}.%ToJSON(),!', label="Route UI install")
        print("Compiled route UI service and API in TRIAGE. No permission or Production changes.")
    elif args.check:
        check(args.base)
    else:
        print("Inactive. Use --install for backend compilation or --check for local read-only HTTP verification.")


if __name__ == "__main__":
    main()
