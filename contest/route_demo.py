#!/usr/bin/env python3
"""Replace the local route demo explicitly. No action or paid inference by default."""
import argparse
import json
import subprocess

from business_privacy import require
from route_review_test import ROOT, TARGETS, configure, snapshot, verify
from staged_risk_acceptance import DIRECTORY
from staged_risk_smoke import source_records, verify_source
from utilization_test import MARKER, execute


def install():
    paths = ["RouteScenario", "RouteGovernance", "RouteUI", "RouteEvidence", "RiskReviewV4", "RouteReview"]
    for name in paths:
        execute("TRIAGE", f'Set sc=$SYSTEM.OBJ.Load("/contest/src/{name}.cls","ck") '
                'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
                f'Write "{MARKER}",{{"installed":"{name}"}}.%ToJSON(),!')
    execute("TRIAGE", 'Set sc=$SYSTEM.OBJ.Load("/contest/dev/RouteDemo.cls","ck") '
            'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
            f'Write "{MARKER}",{{"installed":true}}.%ToJSON(),!')
    for namespace, paths in (
        ("TRIAGE", ["/contest/pipeline/Runtime.cls", "/contest/utilization/Runtime.cls"]),
        ("UTILIZATION", ["/contest/utilization/Runtime.cls", "/contest/dev/UtilizationProvision.cls"]),
        ("PIPELINE", ["/contest/pipeline/Runtime.cls", "/contest/dev/AggregationProvision.cls"]),
    ):
        for path in paths:
            execute(namespace, f'Set sc=$SYSTEM.OBJ.Load("{path}","ck") '
                    'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
                    f'Write "{MARKER}",{{"installed":true}}.%ToJSON(),!')


def reset():
    # The server verifies ownership, in-flight work and the exact plan under its worker lock.
    plan = execute("TRIAGE", 'Set plan=##class(Contest.RouteDemo).Plan() '
                   f'Write "{MARKER}",{{"plan":(plan),"digest":(##class(Contest.ExportEvidence).Digest(plan))}}.%ToJSON(),!')
    print(json.dumps(plan["plan"], indent=2))
    execute("TRIAGE", f'Do ##class(Contest.RouteDemo).Reset("{plan["digest"]}") '
            f'Write "{MARKER}",{{"reset":true}}.%ToJSON(),!')
    names = {f'{row["batch"]}-{row["kind"]}.json' for row in plan["plan"]["batches"]}
    names.update(f'{row["batch"]}-route-evidence-v1.json' for row in plan["plan"]["batches"])
    names.update(f'{row["batch"]}-route-evidence.json' for row in plan["plan"]["batches"])
    names.update({"route-monitor-p6-20261016.json", "route-monitor-p6-v4-20261016.json",
                  "route-monitor-internal-use-demo.json"})
    for name in sorted(names):
        path = DIRECTORY / name
        if path.exists():
            require(path.is_file() and not path.is_symlink(), "Only named local demo result files may be removed")
            path.unlink()
    execute("PIPELINE", 'Set ref=##class(User.ContestAggregationProvision).PresetApproval() '
            f'Write "{MARKER}",ref.%ToJSON(),!')
    ref = execute("UTILIZATION", 'Set ref=##class(User.ContestUtilizationProvision).Register() '
                  f'Write "{MARKER}",ref.%ToJSON(),!')
    execute("UTILIZATION", f'Do ##class(User.ContestUtilizationProvision).Approve("{ref["id"]}","{ref["digest"]}") '
            f'Write "{MARKER}",{{"approved":true}}.%ToJSON(),!')
    subprocess.run(["python3", str(ROOT / "aggregation_test.py"), "--run", "--batch-id", TARGETS[0][1]], check=True)
    subprocess.run(["python3", str(ROOT / "utilization_test.py"), "--run", "--batch-id", TARGETS[1][1]], check=True)
    execute("TRIAGE", configure(False))
    print("Fresh policy-bound demo delivered. Observer enabled; NO model allowance granted.")


def check():
    value = snapshot()
    result = verify(value)
    require(result["completed"] == 2, "Both actual scenario reviews must complete; no substitute outputs")
    freeze = json.loads((ROOT / "fixtures/staged-risk-freeze-v1.json").read_text())
    records = source_records(freeze)
    citations = 0
    for item in value["details"]:
        require(item["evidence"]["adapter"] == "route-evidence-v2", "Updated evidence adapter required")
        require(item["evidence"]["approved"]["scenario"]["policy_id"] == "DEMO-INTERNAL-USE-1",
                "Explicit policy approval required")
        require(not item["result"]["summary"]["risk_detected"] and not item["result"]["summary"]["unresolved"] and
                not item["result"]["missing_information"] and
                all(issue["status"] == "no_signal_on_checked_issue" for issue in item["result"]["issues"]),
                "Normal approved demo must not invent a deviation or a blanket document gap")
        report = next(r for r in value["reports"] if r["id"] == item["report_id"])
        require(report["source"]["id"] == freeze["source_agent_id"] and
                all(report["source"][field] == freeze["source"][field]
                    for field in ("revision", "config_hash", "index_version", "corpus")),
                "Pinned source Agent/index changed")
        packages = {package["question_id"]: package for package in report["packages"]}
        for package in packages.values():
            for hit in package["evidence"]:
                verify_source(hit, records)
        for issue in item["result"]["issues"]:
            hits = {hit["id"]: hit for hit in packages[issue["question_id"]]["evidence"]}
            for citation in issue["citations"]:
                hit = hits[citation["evidence_id"]]
                span = next(p for p in hit["passages"] if p["id"] == citation["passage_id"])
                require(citation["quote"] == span["text"] == hit["text"][citation["start"]:citation["end"]] and
                        citation["start"] == span["start"] and citation["end"] == span["end"],
                        "Citation text differs from its complete frozen source")
                citations += 1
    consumed = execute("TRIAGE", 'Set usage=[] '
                       'If $Data(^ContestRouteReview("allow","utilization-utilization-quality-demo-consumed")) { '
                       'Set grant={}.%FromJSON(^ContestRouteReview("allow","utilization-utilization-quality-demo-consumed")), usage=grant.%Get("consumed_sdk_stats") } '
                       f'Write "{MARKER}",{{"discarded_output_usage":(usage)}}.%ToJSON(),!')
    value.update(consumed)
    stats = [phase["sdk_stats"] for report in value["reports"] for phase in report["phases"]]
    stats.extend(consumed["discarded_output_usage"])
    totals = {field: sum(s[field] for s in stats)
              for field in ("total_interactions", "total_prompt_tokens", "total_completion_tokens")}
    authorized = sum(g["authorized_requests"] for g in value["monitor"]["authorizations"].values())
    reserved = sum(g["reserved_requests"] for g in value["monitor"]["authorizations"].values())
    require(authorized == reserved == totals["total_interactions"] and authorized in (4, 6),
            "Explicit four-request demonstration plus optional two-request retest ceiling exceeded")
    value["verification"] = {"current_completed_reviews": 2, "materialized_citations": citations,
                             "explicitly_authorized_requests": authorized, "sdk_totals": totals,
                             "semantic_scope": "two normal synthetic demonstrations, not a general legal accuracy benchmark"}
    path = DIRECTORY / "route-monitor-internal-use-demo.json"
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(value["verification"]))
    for item in value["details"]:
        print(item["route_kind"], json.dumps(item["result"], ensure_ascii=False))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--install", action="store_true")
    group.add_argument("--reset-demo", action="store_true", help="Explicitly delete and replace only the route demo")
    group.add_argument("--authorize-four-requests", action="store_true", help="Explicit new cost consent; never automatic")
    group.add_argument("--replace-failed-utilization-two-requests", action="store_true",
                       help="Separate explicit two-request consent; one terminal output retest, no new delivery")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    if args.install:
        install()
    elif args.reset_demo:
        reset()
    elif args.authorize_four_requests:
        execute("TRIAGE", configure(True))
        print("Authorized at most four deepseek-flash requests for the two exact saved receipt pins; no retries.")
    elif args.replace_failed_utilization_two_requests:
        execute("TRIAGE", 'Do ##class(Contest.RouteDemo).ReplaceFailedUtilization() '
                f'Write "{MARKER}",{{"additional_authorized_requests":2}}.%ToJSON(),!')
        print("Authorized one exact utilization output retest, at most two additional requests; consumed counters retained.")
    elif args.check:
        check()
    else:
        print("No action. Install, reset, explicit four-request consent and result check are separate operations.")


if __name__ == "__main__":
    main()
