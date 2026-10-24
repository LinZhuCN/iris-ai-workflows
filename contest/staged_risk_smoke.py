#!/usr/bin/env python3
"""Check the frozen development smoke set; optionally prepare real IRIS evidence, never call a model."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from business_privacy import fingerprint, require

ROOT = Path(__file__).resolve().parent
FIXTURES = ROOT / "fixtures"
MARKER = "@@STAGED@@"
RUNTIMES = {"staged-risk-v1": "Contest.RiskReview", "staged-risk-v2": "Contest.RiskReviewV2",
            "staged-risk-v3": "Contest.RiskReviewV3"}


def runtime_class(version):
    require(version in RUNTIMES, "Unknown staged runtime")
    return RUNTIMES[version]


def runtime_freeze(freeze, version):
    runtime_class(version)
    if version == "staged-risk-v1":
        return dict(freeze)
    base = freeze if version == "staged-risk-v2" else runtime_freeze(freeze, "staged-risk-v2")
    profile = json.loads((FIXTURES / ("staged-risk-profile-" + version.rsplit("-", 1)[1] + ".json")).read_text())
    change = "locator_prompt_only" if version == "staged-risk-v2" else "judge_prompt_only"
    require(profile["schema_version"] == 1 and profile["runtime_version"] == version and
            profile["base_contract_hash"] == base["contract_hash"] and
            profile["suite_fingerprint"] == freeze["suite_fingerprint"] and
            profile["expectations_fingerprint"] == freeze["expectations_fingerprint"] and
            profile["change"] == change and
            profile["model_execution_authorized"] is False,
            "Runtime profile does not match frozen source/input contract")
    require(len(profile["contract_hash"]) == 64 and
            profile["contract_hash"] not in {freeze["contract_hash"], base["contract_hash"]},
            "Distinct runtime hash required")
    return dict(freeze, contract_hash=profile["contract_hash"], runtime_version=version)


def prepared_path(version):
    runtime_class(version)
    suffix = "" if version == "staged-risk-v1" else "-runtime-" + version.rsplit("-", 1)[1]
    return ROOT / ("data/evaluations/staged-risk-smoke-v1" + suffix + "-prepared.json")


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=True, separators=(",", ":"))


def locate_input(packet):
    return {key: packet[key] for key in ("synthetic", "stage", "facts")}


def verify_freeze(suite, expectations, freeze):
    require(suite["suite"] == expectations["suite"] == freeze["suite"] == "staged-risk-smoke-v1",
            "Smoke suite identity mismatch")
    require(fingerprint(suite) == freeze["suite_fingerprint"], "Frozen smoke input changed")
    require(fingerprint(expectations) == freeze["expectations_fingerprint"],
            "Frozen author expectations changed")
    require(len(suite["cases"]) == 6 and len(expectations["cases"]) == 6,
            "Six development smoke cases required")
    require([c["id"] for c in suite["cases"]] == [c["id"] for c in expectations["cases"]],
            "Case identity/order mismatch")
    require(freeze["maximum_proposed_model_requests"] == 12 and
            freeze["model_execution_authorized"] is False,
            "Freeze is not model-cost authorization")
    require(suite["classification"] == "synthetic_development_not_held_out" and
            expectations["review_status"] == "author_draft_requires_independent_human_review",
            "Development/human-review limitations required")
    for case in suite["cases"]:
        packet = case["packet"]
        require(set(case) == {"id", "packet"} and
                set(packet) == {"synthetic", "stage", "facts", "required_questions"} and
                packet["synthetic"] is True, "Only synthetic answer-free packets are prepared")
        require(len(packet["required_questions"]) == 1, "Smoke fixture uses one bounded topic per case")


def load():
    suite = json.loads((FIXTURES / "staged-risk-smoke-v1.json").read_text())
    expected = json.loads((FIXTURES / "staged-risk-expectations-v1.json").read_text())
    freeze = json.loads((FIXTURES / "staged-risk-freeze-v1.json").read_text())
    verify_freeze(suite, expected, freeze)
    return suite, expected, freeze


def source_records(freeze):
    records = {}
    for line in (ROOT.parent / "hipaa-demo-knowledge/documents.jsonl").read_text().splitlines():
        record = json.loads(line)
        section = record["source_locator"]
        if section in freeze["source_text_sha256"]:
            require(section not in records, "Ambiguous released section")
            require(record["kind"] == "regulation_snapshot" and
                    record["retrieval_scope"] == "normative", "Normative snapshots required")
            digest = hashlib.sha256(record["text"].encode("utf-8")).hexdigest()
            require(digest == record["content_sha256"] == freeze["source_text_sha256"][section],
                    "Released section does not match freeze")
            records[section] = record
    require(set(records) == set(freeze["source_text_sha256"]), "Frozen sources missing")
    return records


def verify_source(entry, records):
    meta = entry["metadata"]
    require(meta["source_locator"] in records, "Unexpected evidence section")
    expected = records[meta["source_locator"]]
    for key in ("id", "source_locator", "source_url", "source_version", "content_sha256",
                "source_sha256", "kind", "retrieval_scope"):
        require(meta[key] == expected[key], f"Source provenance changed: {key}")
    require(entry["text"] == expected["text"] and entry["source_hash_verified"] is True and
            entry["section_text_complete"] is True, "Complete released text/hash required")


def localization_checks(raw_plan, expected):
    if not (isinstance(raw_plan, dict) and isinstance(raw_plan.get("questions"), list) and
            all(isinstance(q, dict) and isinstance(q.get("topic"), str) and
                isinstance(q.get("fact_ids"), list) and
                all(isinstance(ref, str) for ref in q["fact_ids"])
                for q in raw_plan["questions"])):
        return {"shape_valid": False, "topic_found": False, "fact_coverage": False,
                "unexpected_topics": [], "semantic_human_review": "pending",
                "error": "Malformed locator proposal; no coercion or mandatory-merge substitution"}
    matches = [q for q in raw_plan["questions"] if q.get("topic") == expected["topic"]]
    return {
        "shape_valid": True,
        "topic_found": len(matches) == 1,
        "fact_coverage": len(matches) == 1 and
        set(expected["required_fact_ids"]).issubset(matches[0].get("fact_ids", [])),
        "unexpected_topics": sorted({q.get("topic", "") for q in raw_plan["questions"]} -
                                    {expected["topic"]}),
        "semantic_human_review": "pending",
    }


def report_checks(report, expected):
    """Compare accepted IRIS results with author checks; never substitute for semantic review."""
    checks = {"state": report["state"], "localization": None, "judgment": None,
              "independent_semantic_review": "pending"}
    if "plan" in report:
        checks["localization"] = localization_checks(report["plan"], expected)
    if report["state"] != "completed":
        require("result" not in report, "Technical failure must not contain a semantic result")
        return checks
    require("result" in report, "Completed report requires the accepted IRIS result")
    question_ids = [q["id"] for q in report["questions"] if q["topic"] == expected["topic"]]
    require(len(question_ids) == 1, "Expected server-mandatory scope missing")
    matches = [issue for issue in report["result"]["issues"]
               if issue["question_id"] == question_ids[0]]
    require(len(matches) == 1, "Accepted result must cover the mandatory question once")
    issue, summary = matches[0], report["result"]["summary"]
    checks["judgment"] = {
        "status_matches_author": issue["status"] == expected["status"],
        "fact_coverage": set(expected["required_fact_ids"]).issubset(issue["fact_ids"]),
        "unresolved_matches_author": summary["unresolved"] == expected["unresolved"],
        "recommendation_matches_author":
            summary["recommended_action"] == expected["recommended_action"],
        "additional_issue_count": len(report["result"]["issues"]) - 1,
    }
    return checks


def prepare(suite, freeze):
    records = source_records(freeze)
    reviewer = runtime_class(freeze.get("runtime_version", "staged-risk-v1"))
    source_id = freeze["source_agent_id"].replace('"', '""')
    commands = [
        f'Set config=##class(Contest.AgentService).Get("{source_id}")',
        'Set source={} For key="id","revision","config_hash","model","table","index_version","corpus" { Do source.%Set(key,config.%Get(key)) }',
    ]
    for case in suite["cases"]:
        # JSON remains an ObjectScript string literal; it is never executable source.
        packet = json.dumps(case["packet"], ensure_ascii=True, separators=(",", ":")).replace('"', '""')
        commands.append(f'Set packet={{}}.%FromJSON("{packet}")')
        commands.append(
            f'Try {{ Set questions=##class({reviewer}).Questions(packet,{{"questions":[]}}), '
            f'packages=##class({reviewer}).PrepareEvidence("free-smoke-preparation",config,questions), '
            f'locate=##class({reviewer}).LocateInput(packet), '
            f'judge={{"facts":(packet),"questions":(questions),"packages":(##class({reviewer}).ModelPackages(packages))}}, '
            f'row={{"case_id":"{case["id"]}","source":(source),'
            f'"contract_hash":(##class({reviewer}).ContractHash()),'
            '"input_hash":(##class(Demo.Protocol).Hash(packet.%ToJSON())),'
            '"locate_input":(locate),"fixed_questions":(questions),"packages":(packages),'
            '"judge_input":(judge),"judge_input_characters":($Length(judge.%ToJSON()))} '
            f'Write "{MARKER}",$ZConvert(row.%ToJSON(),"O","UTF8"),! '
            f'}} Catch ex {{ Write "{MARKER}",{{"error":(ex.DisplayString())}}.%ToJSON(),! }}'
        )
    commands.append("Halt")
    result = subprocess.run(
        ["docker", "exec", "-i", "iris-triage-real-iris-1", "iris", "session", "IRIS", "-U", "TRIAGE"],
        input="\n".join(commands) + "\n", text=True, capture_output=True, check=True, timeout=120,
    )
    rows = [json.loads(line.split(MARKER, 1)[1])
            for line in result.stdout.splitlines() if MARKER in line]
    require(len(rows) == len(suite["cases"]), "Missing IRIS preparation results")
    for row, case in zip(rows, suite["cases"]):
        require("error" not in row, f"IRIS preparation failed: {row.get('error')}")
        require(row["case_id"] == case["id"], "Preparation order changed")
        source = row["source"]
        for key in ("config_hash", "revision", "index_version", "corpus"):
            require(source[key] == freeze["source"][key], f"Pinned source changed: {key}")
        require(source["id"] == freeze["source_agent_id"] and
                row["contract_hash"] == freeze["contract_hash"], "Source/contract pin changed")
        require(row["locate_input"] == locate_input(case["packet"]), "Locator input scope leaked")
        require(0 < row["judge_input_characters"] <= 80000, "Judgment input bound exceeded")
        for package in row["packages"]:
            expected_topic = case["packet"]["required_questions"][0]["topic"]
            require(package["coverage"] == "unreviewed_partial" and package["coverage_gaps"],
                    "Legal coverage limitations missing")
            require(package["availability"] == ("unavailable" if expected_topic == "unclassified"
                                                else "available"), "Missing selected evidence")
            for entry in package["evidence"]:
                verify_source(entry, records)
                position = 0
                for passage in entry["passages"]:
                    require(passage["start"] == position and passage["end"] > position and
                            passage["text"] == entry["text"][position:passage["end"]],
                            "Source passage coordinates changed")
                    position = passage["end"]
                require(position == len(entry["text"]), "Passages do not cover full selected section")
        projected = row["judge_input"]["packages"]
        require(len(projected) == len(row["packages"]), "Projection lost a question")
        for package, view in zip(row["packages"], projected):
            require(len(package["evidence"]) == len(view["evidence"]),
                    "Projection lost an evidence entry")
            require(all("evidence" not in step for step in view["retrievals"]),
                    "Retrieval diagnostics duplicate source text")
            for entry, compact in zip(package["evidence"], view["evidence"]):
                require("text" not in compact and entry["id"] == compact["id"],
                        "Projected evidence duplicates text or changes identity")
                require([(p["id"], p["text"]) for p in entry["passages"]] ==
                        [(p["id"], p["text"]) for p in compact["passages"]],
                        "Projected passage content changed")
    return {"suite": suite["suite"], "suite_fingerprint": freeze["suite_fingerprint"],
            "contract_hash": freeze["contract_hash"], "model_calls": 0,
            "purpose": "free_preparation_and_isolated_judgment_baseline_not_model_results",
            "cases": rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare", action="store_true",
                        help="Read the pinned local IRIS index and save ignored prepared inputs; no Chat")
    parser.add_argument("--runtime-version", choices=tuple(RUNTIMES), default="staged-risk-v1")
    args = parser.parse_args()
    suite, _, freeze = load()
    freeze = runtime_freeze(freeze, args.runtime_version)
    source_records(freeze)
    if args.prepare:
        bundle = prepare(suite, freeze)
        target = prepared_path(args.runtime_version)
        if target.exists():
            require(json.loads(target.read_text()) == bundle,
                    "Immutable prepared bundle changed; use a new version, not an overwrite")
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(json.dumps(bundle, ensure_ascii=True, indent=2) + "\n")
        print("PASS: real pinned source text, hashes, full passages and compact projection checked")
        print("Judgment input characters:",
              [c["judge_input_characters"] for c in bundle["cases"]])
    print(f"PASS: {len(suite['cases'])} frozen synthetic development cases; no model calls")
    print("Proposed future ceiling: 12 Chat attempts (2 per case), NOT authorized by this command.")
    print("Author expectations are separate; semantic/applicability human review remains pending.")


if __name__ == "__main__":
    main()
