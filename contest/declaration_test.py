#!/usr/bin/env python3
"""D1 declaration installation and local API checks; never calls a model or sends business data."""
import argparse
import json
import re
import time

from business_privacy import require
from platform_test import request
from route_ui_test import admin_request, local_base
from utilization_test import MARKER, execute


def example(kind, now=None):
    now = int(time.time()) + 4070908800 if now is None else now
    proposal = {
        "schema": 1, "synthetic": True, "title": "Internal encounter quality analysis",
        "owner": "Quality office",
        "purpose": {
            "category": "quality_improvement",
            "text": "Compare encounter classes by birth-year cohort to improve hospital services.",
            "activities": "Calculate internal service quality indicators.",
            "expected_output": "An internal service improvement report.",
        },
        "recipient_id": "local-analysis-receiver",
        "data": {
            "resources": ["Patient", "Encounter"],
            "fields": ["Patient.id", "Patient.birthDate", "Encounter.id", "Encounter.status",
                       "Encounter.class.system", "Encounter.class.code", "Encounter.subject.reference"],
            "cohort": "synthetic-four-resources-v1", "max_records": 4,
            "necessity": "Birth year defines cohorts; encounter classes and references support comparison.",
        },
        "handling": {
            "recipe_id": "year-and-encounter-v1", "identifiability": "linkable",
            "access": "Internal quality team.", "retention": "30 days", "onward_sharing": "None",
        },
        "arrangements": {"status": "not_specified", "details": ""},
        "validity": {"from": now - 10, "until": now + 30 * 86400},
    }
    if kind == "marketing":
        proposal["title"] = "Proposed external patient marketing"
        proposal["purpose"] = {
            "category": "marketing",
            "text": "Provide identifiable patient details to an external marketing organization.",
            "activities": "Let the recipient contact patients for product promotion.",
            "expected_output": "A patient-linked promotional contact list.",
        }
        proposal["recipient_id"] = "external-marketing-demo"
        proposal["data"].update(resources=["Patient"], fields=["Patient.id", "Patient.name"],
                                necessity="The applicant proposes patient-level promotional contact.")
        proposal["handling"].update(recipe_id="retain-requested-fields", identifiability="identifiable",
                                    access="External marketing team.", onward_sharing="Not specified")
    elif kind == "incomplete":
        proposal["title"] = "Secondary data use with details pending"
        proposal["purpose"].update(category="unspecified", text="Use clinical records for secondary analysis.",
                                   activities="Not yet specified.", expected_output="Not yet specified.")
        proposal["recipient_id"] = "unspecified-recipient"
        proposal["handling"].update(identifiability="unspecified", access="Not yet specified.",
                                    retention="Not yet specified.", onward_sharing="Not yet specified.")
    else:
        require(kind == "quality", "Unknown declaration example")
    return proposal


def create_example(base, kind, declaration_id):
    require(isinstance(declaration_id, str) and
            re.fullmatch(r"[A-Za-z][A-Za-z0-9_.-]{0,127}", declaration_id),
            "Provide --declaration-id with a bounded new identity")
    status, result = admin_request(base, "/declarations", {
        "declaration_id": declaration_id, "expected_revision": 0, "expected_digest": "",
        "proposal": example(kind),
    })
    require(status == 200, "Draft creation failed: " + repr(result))
    require(result["state"] == "draft" and result["review"]["task"] is None and
            result["decision"] is None and result["model_calls"] == 0, "Expected a new unreviewed draft")
    print(json.dumps({"id": result["id"], "declaration_id": declaration_id, "revision": result["revision"],
                      "digest": result["digest"], "state": result["state"],
                      "capability": result["capability"]["state"], "model_calls": 0}))


def check(base):
    local_base(base)
    require(request(base, "/declarations", account=None)[0] == 401, "Anonymous access must be denied")
    status, before = request(base, "/declarations")
    require(status == 200 and not before["can_write"], "Reader can list without write capability")
    status, catalog = request(base, "/declarations/catalog")
    require(status == 200 and len(catalog["recipients"]) == 3 and catalog["model_calls"] == 0,
            "Real synthetic declaration catalog required")
    for path in ("/declarations", "/declarations/submit", "/declarations/decide"):
        require(request(base, path, body={})[0] == 403, "Reader mutations must be denied")
        require(admin_request(base, path, {}, header=False)[0] == 403, "CSRF header required")
        for raw in (b"null", b"[]", b'"scalar"', b"{"):
            require(admin_request(base, path, raw=raw)[0] == 400, "Malformed/object contract must be enforced")
    require(admin_request(base, "/declarations", raw=b" " * 65537)[0] == 413, "Declaration body cap required")
    require(admin_request(base, "/declarations/submit", raw=b" " * 4097)[0] == 413,
            "Small command body cap must be preserved")
    large = {"declaration_id": "invalid id", "expected_revision": 0, "expected_digest": "",
             "proposal": example("quality")}
    large["proposal"]["purpose"]["activities"] = "a" * 1900
    large["proposal"]["purpose"]["expected_output"] = "b" * 1900
    require(len(json.dumps(large).encode()) > 4096, "Exercise the extended declaration limit")
    status, rejected = admin_request(base, "/declarations", large)
    require(status == 409 and rejected["code"] == "declaration_rejected",
            "Larger proposals must reach schema validation, not the old global body limit")
    for cursor in ("../bad", "a" * 129):
        require(request(base, "/declarations?after=" + cursor)[0] == 409, "Bounded list cursor required")
    for record in before["items"]:
        status, detail = request(base, "/declarations/" + record["id"])
        require(status == 200 and detail == record, "Persisted detail must match latest record")
        status, history = request(base, "/declarations/" + record["declaration_id"] + "/history")
        require(status == 200 and history["items"][0]["id"] == record["id"], "Real version history required")
    status, after = request(base, "/declarations")
    require(status == 200 and before == after, "Boundary checks must not change declarations")
    print("PASS D1 catalog, authenticated list/detail/history, write separation, CSRF, body limits and schema rejection.")
    print("No model calls, approvals or deliveries; this check creates no declaration.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--install", action="store_true")
    group.add_argument("--check", action="store_true")
    group.add_argument("--create-example", choices=("quality", "marketing", "incomplete"))
    parser.add_argument("--declaration-id")
    parser.add_argument("--base", default="http://127.0.0.1:5173/api/monitor/v1")
    args = parser.parse_args(argv)
    if args.declaration_id and not args.create_example:
        parser.error("--declaration-id requires --create-example")
    if args.create_example and not args.declaration_id:
        parser.error("--create-example requires --declaration-id")
    if args.install:
        execute("TRIAGE",
                'For path="/contest/src/DeclarationCatalog.cls","/contest/src/DeclarationService.cls",'
                '"/contest/dev/DeclarationTests.cls","/contest/src/KnowledgeAPI.cls" { '
                'Set sc=$SYSTEM.OBJ.Load(path,"ck") '
                'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } '
                f'Write "{MARKER}",{{"installed":true}}.%ToJSON(),!', label="D1 declaration install")
        print("Compiled D1 classes and API only. No permission, model, delivery or Production changes.")
    elif args.check:
        check(args.base)
    elif args.create_example:
        create_example(args.base, args.create_example, args.declaration_id)
    else:
        print("Inactive. Use --install, --check, or explicit --create-example with --declaration-id.")


if __name__ == "__main__":
    main()
