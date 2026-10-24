#!/usr/bin/env python3
"""Prospective HIPAA condition checks. Default is free; --run explicitly funds <=16 requests."""
import argparse
import hashlib
import json
import re
from pathlib import Path

from business_privacy import fingerprint, require
from declaration_review_test import BASE
from production_evidence_test import api
from route_ui_test import local_base
from utilization_test import MARKER, execute

ROOT = Path(__file__).resolve().parent
SUITE = ROOT / "fixtures/hipaa-conditions-v1.json"
DIRECTORY = ROOT / "data/evaluations"
RUNTIME = "Contest.HIPAAReview"


def literal(value):
    return json.dumps(value, ensure_ascii=True, separators=(",", ":")).replace('"', '""')


def packet(case):
    refs = [f["id"] for f in case["facts"]]
    return {"synthetic": True, "stage": "after_send", "facts": case["facts"],
            "required_questions": [{"topic": case["topic"], "fact_ids": refs,
                "question": "Assess the applicable HIPAA permission or condition for this observed use/disclosure. Consider relevant exceptions and distinguish verified absence from missing evidence. Do not substitute a local-rule check or certify overall compliance."}]}


def load():
    suite = json.loads(SUITE.read_text())
    require(suite["schema"] == 1 and suite["suite"] == "hipaa-conditions-v1" and
            suite["classification"] == "prospective_assistant_authored_not_expert_validated", "Wrong benchmark")
    require(len(suite["cases"]) == 8 and len({c["id"] for c in suite["cases"]}) == 8, "Eight distinct prospective cases required")
    records = {}
    with (ROOT.parent / "hipaa-demo-knowledge/documents.jsonl").open() as source:
        for line in source:
            record = json.loads(line)
            if record.get("kind") == "regulation_snapshot" and record.get("retrieval_scope") == "normative":
                require(record["source_locator"] not in records, "Ambiguous normative section")
                require(hashlib.sha256(record["text"].encode("utf-8")).hexdigest() == record["content_sha256"],
                        "Released normative section content hash mismatch")
                records[record["source_locator"]] = record
    for case in suite["cases"]:
        require(re.fullmatch(r"condition-[0-9]{2}", case["id"]), "Bounded case ID required")
        require(set(case) == {"id", "topic", "facts", "oracle"}, "Unexpected case fields")
        require(case["topic"] in {"recipient_purpose", "deidentification"}, "Unsupported topic")
        require(len(case["facts"]) == 2 and len({f["id"] for f in case["facts"]}) == 2, "Two distinct premise facts required")
        for fact in case["facts"]:
            require(set(fact) == {"id", "kind", "verification", "origin", "text"} and len(fact["text"]) <= 2000,
                    "Only bounded answer-free fact data allowed")
        oracle = case["oracle"]
        require(oracle["status"] in {"risk_signal", "no_signal_on_checked_issue", "unresolved"}, "Wrong expected status")
        require(set(oracle["critical_fact_ids"]).issubset({f["id"] for f in case["facts"]}), "Unknown critical premise")
        for authority in oracle["authorities"]:
            require(authority["anchor"].lower() in records[authority["section"]]["text"].lower(),
                    "Expected authority anchor missing from dated normative corpus: " + authority["clause"])
    return suite, records


def prepare(suite, base):
    pid = "production-2dc2e52128d8cd8d7f30762fd0ac212f54d106a143360108975813dc13ca31ca"
    plan = api(base, f"/productions/{pid}/review-plan")
    agents = [a for a in plan["eligible_agents"] if a["model"] == "deepseek-flash" and a["status"] == "published"]
    require(len(agents) == 1, "One exact published reviewer required")
    agent = agents[0]
    require(re.fullmatch(r"agent-[A-Za-z0-9-]+", agent["id"]), "Bounded Agent ID required")
    prepared = []
    for case in suite["cases"]:
        p = packet(case)
        row = execute("TRIAGE", (
            f'Set config=##class(Contest.AgentService).Get("{agent["id"]}"), packet={{}}.%FromJSON("{literal(p)}"), '
            f'questions=##class({RUNTIME}).Questions(packet,{{"questions":[]}}), '
            f'packages=##class({RUNTIME}).PrepareEvidence("free-hipaa-preflight",config,questions), '
            f'input={{"facts":(packet),"questions":(questions),"packages":(##class({RUNTIME}).ModelPackages(packages))}} '
            f'Set row={{"input_hash":(##class(Demo.Protocol).Hash(packet.%ToJSON())),'
            f'"contract_hash":(##class({RUNTIME}).ContractHash()),"packages":(packages),'
            '"judge_characters":($Length(input.%ToJSON()))} '
            f'Write "{MARKER}",$ZConvert(row.%ToJSON(),"O","UTF8"),!'))
        require(0 < row["judge_characters"] <= 160000, "Bounded complete-source input required")
        require(all(p["availability"] == "available" for p in row["packages"]), "Missing normative evidence")
        prepared.append({"case_id": case["id"], **row})
    require(len({p["contract_hash"] for p in prepared}) == 1, "Reviewer changed during preparation")
    return {"agent": agent, "cases": prepared, "suite_hash": fingerprint(suite),
            "packet_hash": fingerprint([packet(c) for c in suite["cases"]]),
            "classification": suite["classification"], "maximum_model_requests": 16}


def grade(case, report, records):
    if report["state"] != "completed":
        return {"accepted": False, "technical_failure": True, "expected": case["oracle"]["status"], "actual": None}
    oracle = case["oracle"]
    q = next(q for q in report["questions"] if q["topic"] == case["topic"])
    issue = next(i for i in report["result"]["issues"] if i["question_id"] == q["id"])
    packages = {p["question_id"]: p for p in report["packages"]}
    cited = []
    for finding in report["result"]["issues"]:
        hits = {h["id"]: h for h in packages[finding["question_id"]]["evidence"]}
        for citation in finding["citations"]:
            hit = hits[citation["evidence_id"]]
            meta = hit["metadata"]
            record = records[meta["source_locator"]]
            passage = next(p for p in hit["passages"] if p["id"] == citation["passage_id"])
            require(hit["source_hash_verified"] is True and hit["section_text_complete"] is True and
                    meta["content_sha256"] == record["content_sha256"] and hit["text"] == record["text"] and
                    citation["quote"] == passage["text"] == hit["text"][citation["start"]:citation["end"]] and
                    citation["start"] == passage["start"] and citation["end"] == passage["end"],
                    "Citation differs from complete released normative source")
            if finding["question_id"] == q["id"]:
                cited.append((meta["source_locator"], citation["quote"].lower()))
    authority_checks = [{"clause": a["clause"], "cited": any(section == a["section"] and a["anchor"].lower() in quote
                        for section, quote in cited)} for a in oracle["authorities"]]
    checks = {
        "status": issue["status"] == oracle["status"],
        "applicability": issue["applicability"] in oracle["applicability"],
        "condition": issue["condition_status"] in oracle["condition_status"],
        "critical_facts": set(oracle["critical_fact_ids"]).issubset(issue["fact_ids"]),
        "decisive_clauses": all(c["cited"] for c in authority_checks),
        "material_gap": bool(report["result"]["missing_information"]) if oracle["status"] == "unresolved"
                        else not report["result"]["missing_information"],
        "other_issues": all(i["status"] == oracle["status"] for i in report["result"]["issues"]),
    }
    return {"accepted": all(checks.values()), "technical_failure": False, "expected": oracle["status"],
            "actual": issue["status"], "checks": checks, "authority_checks": authority_checks,
            "citations": sum(len(i["citations"]) for i in report["result"]["issues"]),
            "explanation": issue["explanation"], "semantic_entailment_review": "pending"}


def summarize(suite, journal, records):
    require(journal["freeze"]["suite_hash"] == fingerprint(suite), "Frozen oracle or inputs changed")
    require(journal["freeze"]["packet_hash"] == fingerprint([packet(c) for c in suite["cases"]]),
            "Frozen model input projection changed")
    require([p["case_id"] for p in journal["freeze"]["cases"]] == [c["id"] for c in suite["cases"]],
            "Prepared cases differ from prospective suite")
    require(len(journal["cases"]) <= len(suite["cases"]), "Unexpected extra funded cases")
    rows = []
    usage = {"requests": 0, "tokens": 0, "citations": 0}
    confusion = {}
    for case, entry, prepared in zip(suite["cases"], journal["cases"], journal["freeze"]["cases"]):
        require(entry["case_id"] == case["id"], "Journal case mismatch")
        report = entry["report"]
        agent, consent = journal["freeze"]["agent"], entry["consent"]
        require(consent["input_hash"] == prepared["input_hash"] and consent["contract_hash"] == prepared["contract_hash"] and
                consent["agent_id"] == agent["id"] and consent["source_revision"] == agent["revision"] and
                consent["config_hash"] == agent["config_hash"] and consent["max_model_requests"] == 2 and
                consent["acknowledge_cost"] is True, "Consent differs from frozen source/input contract")
        require(report["packet"] == packet(case) and report["authorization"] == entry["consent"] and
                report["version"] == "hipaa-conditions-v1" and report["execution"] == "evaluation_only",
                "Bound runtime identity/packet mismatch")
        require(report["source"]["id"] == agent["id"] and report["source"]["revision"] == agent["revision"] and
                report["source"]["config_hash"] == agent["config_hash"], "Report source revision differs from freeze")
        require(report["reserved_model_requests"] <= 2, "Per-case budget exceeded")
        if report["state"] == "completed":
            require(report["reserved_model_requests"] == 2 and
                    [p["phase"] for p in report["phases"]] == ["locate", "judge"],
                    "Completed case requires both actual funded phases")
        for phase in report["phases"]:
            require(phase["agent_session"] and phase["sdk_stats"]["total_interactions"] == 1 and
                    phase["sdk_stats"]["total_tool_calls"] == 0, "Real tool-free SDK interaction required")
            if phase["phase"] == "locate":
                require(phase["input"] == {k: packet(case)[k] for k in ("synthetic", "stage", "facts")},
                        "Locator received labels or oracle")
            else:
                require(phase["input"]["facts"] == packet(case), "Judge received labels or substituted premises")
            phase_usage = phase.get("usage")
            require(isinstance(phase_usage, dict) and type(phase_usage.get("total_tokens")) is int and
                    phase_usage["total_tokens"] > 0, "Explicit provider token accounting required")
            usage["tokens"] += phase_usage["total_tokens"]
        row = grade(case, report, records)
        rows.append({"case_id": case["id"], "report_id": report["id"], **row})
        usage["requests"] += report["reserved_model_requests"]
        usage["citations"] += row.get("citations", 0)
        key = row["expected"] + " -> " + (row["actual"] or "technical_failure")
        confusion[key] = confusion.get(key, 0) + 1
    require(usage["requests"] <= journal["freeze"]["maximum_model_requests"] == 16,
            "Prospective batch budget exceeded")
    complete = len(rows) == len(suite["cases"])
    return {"suite": suite["suite"], "complete": complete, "accepted_cases": sum(r["accepted"] for r in rows),
            "total_cases": len(suite["cases"]), "all_checks_passed": complete and all(r["accepted"] for r in rows),
            "false_positive_cases": [r["case_id"] for r in rows if r["actual"] == "risk_signal" and r["expected"] != "risk_signal"],
            "missed_risk_cases": [r["case_id"] for r in rows if r["expected"] == "risk_signal" and r["actual"] != "risk_signal"],
            "confusion": confusion, "usage": usage, "cases": rows, "independent_expert_review": "not_performed",
            "production_fact_coverage": "not_validated_by_this_benchmark", "legal_effectiveness": "not_established"}


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def run(suite, base, key):
    require(re.fullmatch(r"[A-Za-z0-9-]{1,60}", key), "Bounded immutable run key required")
    path = DIRECTORY / (key + "-hipaa.json")
    require(not path.exists(), "Run already exists; never reset or automatically repeat paid requests")
    frozen = prepare(suite, base)
    journal = {"state": "running", "freeze": frozen, "cases": []}
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    with path.open("x") as output:
        json.dump(journal, output, indent=2)
    for case, prepared in zip(suite["cases"], frozen["cases"]):
        agent = frozen["agent"]
        consent = {"request_key": key + "-" + case["id"], "agent_id": agent["id"],
            "source_revision": agent["revision"], "config_hash": agent["config_hash"],
            "input_hash": prepared["input_hash"], "contract_hash": prepared["contract_hash"],
            "acknowledge_cost": True, "max_model_requests": 2}
        entry = {"case_id": case["id"], "state": "attempting", "consent": consent}
        journal["cases"].append(entry)
        write(path, journal)
        report = execute("TRIAGE", (
            f'Set packet={{}}.%FromJSON("{literal(packet(case))}"), consent={{}}.%FromJSON("{literal(consent)}"), '
            f'report=##class({RUNTIME}).Run(packet,consent) '
            f'Write "{MARKER}",$ZConvert(report.%ToJSON(),"O","UTF8"),!'), label="HIPAA prospective review")
        entry.update(state=report["state"], report=report)
        write(path, journal)
        print(case["id"], report["state"], flush=True)
    journal["state"] = "finished"
    _, records = load()
    journal["analysis"] = summarize(suite, journal, records)
    write(path, journal)
    print(json.dumps(journal["analysis"], indent=2), flush=True)
    require(journal["analysis"]["all_checks_passed"], "HIPAA condition benchmark failed; original failures retained, no automatic retry")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--prepare", action="store_true")
    group.add_argument("--run", action="store_true")
    group.add_argument("--check", type=Path)
    parser.add_argument("--request-key")
    parser.add_argument("--base", default=BASE)
    args = parser.parse_args(argv)
    local_base(args.base)
    suite, records = load()
    if args.run:
        require(args.request_key is not None, "--run requires an immutable request key and prior paid authorization")
        run(suite, args.base, args.request_key)
    elif args.prepare:
        frozen = prepare(suite, args.base)
        print(json.dumps({k: v for k, v in frozen.items() if k != "cases"}, indent=2))
    elif args.check:
        journal = json.loads(args.check.read_text())
        for entry in journal["cases"]:
            identifier = entry["report"]["id"]
            require(re.fullmatch(r"risk-evaluation-[A-Za-z0-9-]+", identifier), "Bounded report ID required")
            actual = execute("TRIAGE", f'Set report=##class({RUNTIME}).Status("{identifier}") '
                f'Write "{MARKER}",$ZConvert(report.%ToJSON(),"O","UTF8"),!')
            require(actual == entry["report"], "Persistent report differs; do not re-run requests")
        analysis = summarize(suite, journal, records)
        print(json.dumps(analysis, indent=2))
        require(analysis["all_checks_passed"], "Saved HIPAA condition benchmark did not pass every check")
    else:
        print("Eight prospective clause-anchored cases verified locally. No model calls. Not expert/legal validation.")


if __name__ == "__main__":
    main()
