#!/usr/bin/env python3
"""Prepare and check HIPAA business-case evidence offline; never call a model or execute an action."""
import argparse
import copy
import hashlib
import json
import re
from pathlib import Path

import knowledge

SUITE_PATH = knowledge.DEMO / "evaluation-cases.json"
ASSESSMENTS = {"risk", "no_finding", "insufficient_evidence"}
ACTIONS = {"hold_for_review", "manual_review", "continue_under_existing_controls"}
STAGES = {"before_send", "after_send", "config_review"}
RESPONSE_FIELDS = {"assessment", "recommended_action", "reason", "findings", "missing_information"}


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=True,
                                     separators=(",", ":")).encode()).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def text(value, label, maximum=4000):
    require(isinstance(value, str) and 0 < len(value.strip()) <= maximum, f"Invalid {label}")
    return value


def strings(value, label, maximum=20):
    require(isinstance(value, list) and len(value) <= maximum, f"Invalid {label}")
    for item in value:
        text(item, label)
    require(len(set(value)) == len(value), f"Duplicate {label}")
    return value


def load():
    manifest = knowledge.verify(knowledge.DEMO, "demo")
    suite = json.loads(SUITE_PATH.read_text())
    require(suite.get("corpus_id") == manifest["corpus_id"], "Benchmark corpus fingerprint mismatch")
    records = {r["id"]: r for r in
               map(json.loads, (knowledge.DEMO / "documents.jsonl").read_text().splitlines())}
    verify(suite, records)
    return suite, records


def verify(suite, records):
    require(suite.get("schema_version") == 2 and suite.get("suite") == "hipaa-business-context-v1",
            "Unsupported business benchmark")
    cases = suite.get("cases")
    require(isinstance(cases, list) and len(cases) == 12, "Twelve specifications required")
    require(len({c["id"] for c in cases}) == 12 and
            {c["case_id"] for c in cases} == {f"business-{i:02}" for i in range(1, 13)},
            "Duplicate or invalid case identities")
    for case in cases:
        require(case["category"] in {"business", "control"} and case["stage"] in STAGES,
                "Invalid case category/stage")
        facts = case["facts"]
        require(isinstance(facts, list) and 1 <= len(facts) <= 12, "Invalid business facts")
        ids = set()
        for fact in facts:
            require(set(fact) == {"id", "text"}, "Facts must not contain expected answers")
            text(fact["id"], "fact identity", 80)
            text(fact["text"], "fact text", 2000)
            require(fact["id"] not in ids, "Duplicate fact identity")
            ids.add(fact["id"])
        oracle = case["oracle"]
        require(oracle["assessment"] in ASSESSMENTS and oracle["recommended_action"] in ACTIONS,
                "Invalid oracle outcome")
        require(oracle["recommended_action"] != "hold_for_review" or case["stage"] == "before_send",
                "Cannot hold an already sent message or a configuration review")
        require(set(strings(oracle["critical_fact_ids"], "critical facts")).issubset(ids),
                "Oracle refers to missing business facts")
        for field in ("must_explain", "must_not_claim"):
            require(bool(strings(oracle[field], field)), "Empty human review rubric")
        sections = strings(case["required_sections"], "required sections")
        require(set(sections) == {a["section"] for a in oracle["authorities"]},
                "Authority coverage does not match required sections")
        for authority in oracle["authorities"]:
            text(authority["clause"], "clause")
            anchor = text(authority["anchor"], "source anchor")
            require(any(r["kind"] == "regulation_snapshot" and r["retrieval_scope"] == "normative"
                        and r["source_locator"] == authority["section"] and anchor in r["text"]
                        for r in records.values()), "Missing authentic clause anchor: " + authority["clause"])
    business = sum(c["category"] == "business" for c in cases)
    require(business == 10, "Ten business cases and two explicit controls required")
    return {"suite": suite["suite"], "manifest_hash": fingerprint(suite), "corpus_id": suite["corpus_id"],
            "business_cases": business, "control_cases": 12 - business, "status": "prepared_not_evaluated",
            "model_calls": 0, "business_actions": 0, "expert_legal_review": "not_performed"}


def context(case):
    """Only this projection may be supplied to an Agent, never the full specification."""
    return {"case_id": case["case_id"], "stage": case["stage"], "synthetic": True,
            "facts": [dict(fact) for fact in case["facts"]]}


def runtime_inputs(suite):
    bundle = {"suite": suite["suite"], "corpus_id": suite["corpus_id"],
              "manifest_hash": fingerprint(suite), "cases": [context(case) for case in suite["cases"]]}
    raw = json.dumps(bundle, sort_keys=True, ensure_ascii=True, separators=(",", ":"))
    return raw, knowledge.digest(raw.encode())


def grade(case, response, evidence, records, *, finding_limit=10):
    """Check shape/provenance and author-oracle alignment, never semantic legal correctness."""
    errors, sections, fact_ids = [], set(), set()
    try:
        require(isinstance(response, dict) and set(response) == RESPONSE_FIELDS,
                "Response must have exactly assessment, recommended_action, reason, findings, missing_information")
        require(isinstance(response["assessment"], str) and response["assessment"] in ASSESSMENTS,
                "Unsupported assessment")
        require(isinstance(response["recommended_action"], str) and response["recommended_action"] in ACTIONS,
                "Unsupported recommendation; arbitrary execution is prohibited")
        require(response["assessment"] == "no_finding" or
                response["recommended_action"] != "continue_under_existing_controls",
                "Risk or insufficient evidence cannot authorize continuing")
        require(response["recommended_action"] != "hold_for_review" or case["stage"] == "before_send",
                "A hold cannot undo delivery or execute a configuration change")
        text(response["reason"], "reason", 2000)
        strings(response["missing_information"], "missing information")
        if response["assessment"] == "insufficient_evidence":
            require(bool(response["missing_information"]), "Specify what information is missing")
        require(isinstance(evidence, list) and len(evidence) <= 20, "Invalid retrieved evidence list")
        hits = {}
        for hit in evidence:
            require(isinstance(hit, dict) and set(hit) == {"id", "record_id", "text"},
                    "Evidence requires id, record_id and text")
            identity = text(hit["id"], "evidence identity", 100)
            record_id = text(hit["record_id"], "record identity", 100)
            require(identity not in hits, "Duplicate evidence identity")
            require(record_id in records, "Unknown evidence source")
            record = records[record_id]
            require(record["retrieval_scope"] == "normative" and
                    record["kind"] in {"regulation_snapshot", "official_guidance"},
                    "Historical, unreviewed, synthetic and LLM sources cannot establish a normative claim")
            excerpt = text(hit["text"], "evidence excerpt", 2000)
            require(excerpt in record["text"], "Evidence excerpt is not authentic source text")
            hits[identity] = (hit, record)
        findings = response["findings"]
        require(isinstance(findings, list) and len(findings) <= finding_limit, "Invalid findings")
        retrieval_failure = case["id"] == "retrieval-failure"
        if retrieval_failure:
            require(not evidence and not findings, "Retrieval failure must not fabricate evidence or legal findings")
        else:
            require(bool(findings), "At least one explained, cited business finding is required")
        available_facts = {f["id"] for f in case["facts"]}
        for finding in findings:
            require(isinstance(finding, dict) and set(finding) == {"fact_ids", "explanation", "citations"},
                    "Each finding requires fact_ids, explanation and citations")
            refs = strings(finding["fact_ids"], "finding fact references")
            require(bool(refs) and set(refs).issubset(available_facts), "Unknown or empty business fact references")
            fact_ids.update(refs)
            text(finding["explanation"], "finding explanation", 2000)
            citations = finding["citations"]
            require(isinstance(citations, list) and 1 <= len(citations) <= 10, "Invalid finding citations")
            for citation in citations:
                require(isinstance(citation, dict) and set(citation) == {"evidence_id", "quote"},
                        "Citation requires evidence_id and exact quote")
                identity = text(citation["evidence_id"], "citation evidence identity", 100)
                require(identity in hits, "Citation was not retrieved")
                quote = text(citation["quote"], "citation quote", 1000)
                require(len(quote) >= 16 and quote in hits[identity][0]["text"],
                        "Citation quote must appear verbatim in the retrieved excerpt")
                sections.add(hits[identity][1]["source_locator"])
    except ValueError as error:
        errors.append(str(error))
    oracle = case["oracle"]
    checks = {
        "expected_assessment": isinstance(response, dict) and response.get("assessment") == oracle["assessment"],
        "expected_recommendation": isinstance(response, dict) and response.get("recommended_action") == oracle["recommended_action"],
        "critical_facts_referenced": set(oracle["critical_fact_ids"]).issubset(fact_ids),
        "required_sections_cited": case["id"] == "retrieval-failure" or set(case["required_sections"]).issubset(sections),
    }
    return {"suite": "hipaa-business-context-v1", "case_id": case["case_id"],
            "case_hash": fingerprint(case), "response_hash": fingerprint(response),
            "evidence_hash": fingerprint(evidence), "structural_pass": not errors, "errors": errors,
            "oracle_alignment": not errors and all(checks.values()), "checks": checks,
            "human_review_required": True, "hipaa_risk_validation": "not_completed",
            "review_rubric": {"must_explain": oracle["must_explain"], "must_not_claim": oracle["must_not_claim"],
                             "authorities": oracle["authorities"]},
            "limitations": "Author-oracle alignment and exact-quote presence are not entailment or applicability checks. "
                            "A human must assess the explanation, exceptions, missing facts and dated-source applicability. "
                            "Recommendations are previews only; no IRIS action or publication is performed."}


def source_passages(source):
    """Mirror IRIS spans: zero-based, end-exclusive UTF-16 code-unit offsets."""
    raw = source.encode("utf-16-le")
    passages, start, size = [], 0, len(raw) // 2
    while start < size:
        end = min(start + 800, size)
        newline = raw.find(b"\n\x00", start * 2)
        while newline >= 0 and newline % 2:
            newline = raw.find(b"\n\x00", newline + 1)
        newline = newline // 2 + 1 if newline >= 0 else -1
        if start + 15 < newline < end:
            end = newline
        if size - end < 16:
            end = size
        if 0xD800 <= int.from_bytes(raw[(end - 1) * 2:end * 2], "little") <= 0xDBFF:
            end -= 1
        passages.append({"id": f"p{len(passages)}", "start": start, "end": end,
                         "text": raw[start * 2:end * 2].decode("utf-16-le")})
        start = end
    return passages


def resolve_business_v2(proposal, packet, evidence):
    """Materialize selected source handles, never repair a model's classification or schema."""
    require(isinstance(proposal, dict) and set(proposal) == RESPONSE_FIELDS, "Invalid v2 proposal fields")
    require(isinstance(proposal["assessment"], str) and proposal["assessment"] in ASSESSMENTS and
            isinstance(proposal["recommended_action"], str) and proposal["recommended_action"] in ACTIONS,
            "Unknown v2 assessment/action")
    require(proposal["assessment"] == "no_finding" or
            proposal["recommended_action"] != "continue_under_existing_controls", "Non-clean cannot continue")
    require(proposal["recommended_action"] != "hold_for_review" or packet["stage"] == "before_send",
            "Only a pre-send message can be held")
    text(proposal["reason"], "reason", 2000)
    missing = strings(proposal["missing_information"], "missing information")
    findings = proposal["findings"]
    require(isinstance(findings, list) and len(findings) <= 10, "Invalid findings")
    require(isinstance(evidence, list) and len(evidence) <= 15, "Invalid evidence")
    allowed = {}
    for hit in evidence:
        require(isinstance(hit, dict), "Evidence must be an object")
        identity = text(hit.get("id"), "evidence identity", 100)
        require(identity not in allowed, "Duplicate evidence identity")
        excerpt = text(hit.get("text"), "evidence excerpt", 2000)
        require(hit.get("passages") == source_passages(excerpt), "Source passages were altered")
        allowed[identity] = hit
    result, statuses = copy.deepcopy(proposal), []
    for finding in result["findings"]:
        require(isinstance(finding, dict) and set(finding) ==
                {"fact_ids", "condition", "evidence_status", "explanation", "citations"}, "Invalid v2 finding fields")
        text(finding["condition"], "condition", 1000)
        text(finding["explanation"], "explanation", 2000)
        status = finding["evidence_status"]
        require(isinstance(status, str) and status in {"supported_risk", "supported_no_finding", "unresolved"},
                "Invalid evidence status")
        statuses.append(status)
        refs = strings(finding["fact_ids"], "fact references", 12)
        require(bool(refs) and set(refs).issubset({f["id"] for f in packet["facts"]}), "Unknown fact references")
        citations = finding["citations"]
        require(isinstance(citations, list) and 1 <= len(citations) <= 10, "Invalid citations")
        for citation in citations:
            require(isinstance(citation, dict) and set(citation) == {"evidence_id", "passage_id"},
                    "V2 citations select evidence_id and passage_id only")
            identity = text(citation["evidence_id"], "evidence identity", 100)
            passage_id = text(citation["passage_id"], "passage identity", 30)
            require(identity in allowed, "Unknown evidence identity")
            passage = next((p for p in allowed[identity]["passages"] if p["id"] == passage_id), None)
            require(passage is not None, "Unknown passage identity")
            require(16 <= len(passage["text"].encode("utf-16-le")) // 2 <= 1000, "Invalid quote length")
            citation.update(quote=passage["text"], start=passage["start"], end=passage["end"])
    if evidence:
        require(bool(findings), "Evidence requires at least one finding")
        expected = ("risk" if "supported_risk" in statuses else
                    "insufficient_evidence" if "unresolved" in statuses else "no_finding")
        require(proposal["assessment"] == expected, "Assessment contradicts declared evidence status")
    else:
        require(not findings and proposal["assessment"] == "insufficient_evidence" and
                proposal["recommended_action"] == "manual_review", "No evidence cannot produce findings or success")
    require(proposal["assessment"] != "no_finding" or not missing, "No finding cannot hide missing information")
    require(not (proposal["assessment"] == "insufficient_evidence" or "unresolved" in statuses) or bool(missing),
            "Unresolved issues require missing information")
    return result


def business_bundle_response(components):
    evidence, steps = [], []
    for component in components:
        response = component["response"]
        step = {k: copy.deepcopy(v) for k, v in response.items() if k != "evidence"}
        step["tool"] = component["tool"]
        if component["tool"] == "SearchBusinessEvidence":
            step["query"] = component["query"]
        steps.append(step)
        evidence.extend(copy.deepcopy(response["evidence"]))
    return {"availability": "available" if evidence else "unavailable", "evidence": evidence, "steps": steps}


def check_business_bundle(item):
    tools = item.get("tools")
    require(isinstance(tools, list) and len(tools) in (4, 5) and all(isinstance(t, dict) for t in tools),
            "V4 requires server facts, two/three component retrievals and exactly one bundle")
    require(tools[0].get("tool") == "ReadBusinessFacts" and tools[0].get("origin") == "server_prefill",
            "V4 facts must be server-prefilled before retrieval")
    bundle, components = tools[-1], tools[1:-1]
    require(bundle.get("tool") == "GatherBusinessEvidence", "Missing V4 evidence bundle")
    require([c.get("tool") for c in components] ==
            ["SearchBusinessEvidence"] + ["LookupBusinessClause"] * (len(components) - 1) and
            all(c.get("parent_tool") == "GatherBusinessEvidence" for c in components),
            "Missing or out-of-order V4 component retrieval")
    initial = item.get("model_input")
    require(isinstance(initial, dict) and set(initial) == {"runId", "facts"} and
            isinstance(initial["runId"], str) and bool(initial["runId"]) and
            initial["runId"] == bundle.get("runId") and initial["facts"] == item.get("packet"),
            "V4 initial model input differs from bound facts/run")
    require(isinstance(bundle.get("query"), str) and 0 < len(bundle["query"].strip()) <= 600 and
            components[0].get("query") == bundle["query"], "V4 discovery differs from declared plan")
    for n, prefix in ((1, ""), (2, "second")):
        section_key, anchor_key = ("section", "anchor") if not prefix else ("secondSection", "secondAnchor")
        section, anchor = bundle.get(section_key), bundle.get(anchor_key)
        require(isinstance(section, str) and isinstance(anchor, str) and len(anchor) <= 160,
                "Invalid V4 section plan")
        if n == 2 and not section:
            require(not anchor and len(components) == 2, "Unexpected second V4 lookup")
            continue
        require(re.fullmatch(r"45 CFR 16[04]\.[0-9]{3}", section) is not None and n < len(components),
                "Missing planned V4 section")
        require(n == 1 or section != bundle["section"], "Duplicate V4 section")
        require(components[n].get("section") == section and components[n].get("anchor") == anchor and
                isinstance(components[n].get("response"), dict) and
                components[n]["response"].get("section") == section and
                components[n]["response"].get("anchor") == anchor, "V4 lookup differs from declared plan")
    require(all(isinstance(c.get("response"), dict) and isinstance(c["response"].get("evidence"), list)
                for c in components), "Missing V4 canonical response")
    response = business_bundle_response(components)
    require(bundle.get("response") == response and response["evidence"] == item.get("evidence"),
            "V4 bundle differs from canonical retrieval/evidence")
    require(bundle.get("model_response") == business_model_view(response), "V4 model projection differs")


def business_model_view(response):
    """Model text appears once; complete canonical provenance remains server-side."""
    view = copy.deepcopy(response)
    view["evidence"] = []
    for hit in response["evidence"]:
        passages = []
        for i, span in enumerate(hit["passages"]):
            passage = {"id": span["id"], "text": span["text"], "boundary_review_required": True}
            if i:
                passage["previous_id"] = hit["passages"][i - 1]["id"]
            if i + 1 < len(hit["passages"]):
                passage["next_id"] = hit["passages"][i + 1]["id"]
            passages.append(passage)
        source = {k: hit["metadata"][k] for k in
                  ("source_locator", "source_url", "kind", "source_version", "legal_status", "title", "retrieved_on")
                  if k in hit["metadata"]}
        view["evidence"].append({"id": hit["id"], "source": source, "passages": passages, "partial_context": True})
    return view


def resolve_business_v3(proposal, packet, evidence):
    require(isinstance(proposal, dict) and set(proposal) == RESPONSE_FIELDS | {"claims"},
            "V3 requires exactly six fields including claims")
    require(isinstance(proposal["findings"], list) and len(proposal["findings"]) <= 10 and
            isinstance(proposal["claims"], list) and len(proposal["claims"]) <= 10, "Invalid v3 finding/claim list")
    condition_fields = {"fact_ids", "condition", "applicability", "applicability_fact_ids",
                        "condition_status", "affirmative_fact_ids", "exceptions", "explanation", "citations"}
    normalized, risks, unknown, unverified = copy.deepcopy(proposal), 0, 0, False
    del normalized["claims"]
    for i, finding in enumerate(proposal["findings"]):
        require(isinstance(finding, dict) and set(finding) == condition_fields, "Invalid condition chain fields")
        refs = strings(finding["fact_ids"], "condition facts", 12)
        require(bool(refs) and set(refs).issubset({f["id"] for f in packet["facts"]}), "Unknown condition fact")
        app, state, exceptions = finding["applicability"], finding["condition_status"], finding["exceptions"]
        require(isinstance(app, str) and app in {"applicable", "not_applicable", "unknown"}, "Unknown applicability")
        require(isinstance(state, str) and state in {"met", "not_met", "unknown", "not_applicable"},
                "Unknown condition status")
        require(isinstance(exceptions, dict) and set(exceptions) == {"status", "explanation"},
                "Missing exception review")
        text(exceptions["explanation"], "exception review", 1000)
        require(isinstance(exceptions["status"], str) and exceptions["status"] in {"resolved", "unresolved"},
                "Unknown exception status")
        app_refs = strings(finding["applicability_fact_ids"], "applicability facts", 12)
        affirmative = strings(finding["affirmative_fact_ids"], "affirmative facts", 12)
        require(set(app_refs).issubset(refs) and set(affirmative).issubset(refs), "Chain facts must be in finding facts")
        require(app == "unknown" or bool(app_refs), "Known applicability requires facts")
        if state in {"met", "not_met"}:
            require(app == "applicable" and bool(affirmative) and exceptions["status"] == "resolved",
                    "Met/not_met requires applicable condition, affirmative facts and resolved exceptions")
        elif state == "not_applicable":
            require(app == "not_applicable" and not affirmative and exceptions["status"] == "resolved",
                    "Invalid not-applicable condition")
        else:
            require(app != "not_applicable" and not affirmative, "Unknown cannot assert affirmative success/failure")
        risks += state == "not_met"
        unknown += state == "unknown"
        normalized["findings"][i] = {k: copy.deepcopy(finding[k]) for k in
                                     ("fact_ids", "condition", "explanation", "citations")}
        normalized["findings"][i]["evidence_status"] = (
            "supported_risk" if state == "not_met" else "unresolved" if state == "unknown" else "supported_no_finding")
    claims = []
    for claim in proposal["claims"]:
        require(isinstance(claim, dict) and set(claim) == {"fact_ids", "status", "explanation", "citations"},
                "Invalid claim fields")
        require(isinstance(claim["status"], str) and claim["status"] in {"supported", "contradicted", "unverified"},
                "Unknown claim status")
        unverified |= claim["status"] == "unverified"
        check = {"assessment": "no_finding", "recommended_action": "manual_review",
                 "reason": "Claim citation validation only.", "findings": [{
                     "fact_ids": claim["fact_ids"], "condition": "Supplied claim evidence",
                     "evidence_status": "supported_no_finding", "explanation": claim["explanation"],
                     "citations": claim["citations"]}], "missing_information": []}
        checked = resolve_business_v2(check, packet, evidence)
        claims.append({**copy.deepcopy(claim), "citations": checked["findings"][0]["citations"]})
    missing = strings(proposal["missing_information"], "missing information")
    expected = "risk" if risks else "insufficient_evidence" if unknown or unverified or not evidence else "no_finding"
    require(proposal["assessment"] == expected, "Assessment contradicts condition/claim states")
    require(not (unknown or unverified or expected == "insufficient_evidence") or bool(missing),
            "Unresolved conditions/claims require missing information")
    require(expected != "no_finding" or not missing, "No finding cannot hide missing information")
    require(expected == "no_finding" or proposal["recommended_action"] != "continue_under_existing_controls",
            "Non-clean cannot continue")
    normalized["assessment"] = "risk" if risks else "insufficient_evidence" if unknown or not evidence else "no_finding"
    if normalized["assessment"] == "no_finding":
        normalized["missing_information"] = []
    checked = resolve_business_v2(normalized, packet, evidence)
    result = copy.deepcopy(proposal)
    for finding, resolved in zip(result["findings"], checked["findings"]):
        finding["citations"] = resolved["citations"]
    result["claims"] = claims
    return result


def grade_runtime_case(case, item, records, runtime_version="hipaa-business-runtime-v1"):
    require(runtime_version in {"hipaa-business-runtime-v1", "hipaa-business-runtime-v2",
                                "hipaa-business-runtime-v3", "hipaa-business-runtime-v4"},
            "Unknown business runtime version")
    separated = runtime_version in {"hipaa-business-runtime-v3", "hipaa-business-runtime-v4"}
    evidence = [{key: hit[key] for key in ("id", "record_id", "text")} for hit in item.get("evidence", [])]
    response, resolution_error = item.get("result"), None
    if runtime_version != "hipaa-business-runtime-v1":
        try:
            resolver = resolve_business_v3 if separated else resolve_business_v2
            resolved = resolver(item.get("proposal"), context(case), item.get("evidence", []))
            require(resolved == response, "Runtime result differs from the preserved proposal/source-span resolution")
            response = copy.deepcopy(resolved)
            if separated:
                response["findings"] = [{k: f[k] for k in ("fact_ids", "explanation", "citations")}
                                        for f in response["findings"]]
                # Coverage includes both explicit claim and condition evidence; only conditions determine risk.
                for claim in response.pop("claims"):
                    response["findings"].append({k: claim[k] for k in ("fact_ids", "explanation", "citations")})
            else:
                for finding in response["findings"]:
                    del finding["condition"], finding["evidence_status"]
            for finding in response["findings"]:
                finding["citations"] = [{key: citation[key] for key in ("evidence_id", "quote")}
                                       for citation in finding["citations"]]
        except ValueError as error:
            resolution_error = str(error)
            response = None
    # V3's resolver already limits conditions and claims separately to ten each.
    result = grade(case, response, evidence, records,
                   finding_limit=20 if separated else 10)
    if resolution_error:
        result["errors"].append(resolution_error)
    result["response_hash"] = fingerprint(item.get("result"))
    tools = item.get("tools", [])
    read_positions = [i for i, call in enumerate(tools) if call.get("tool") == "ReadBusinessFacts"]
    retrieval_tools = {"SearchBusinessEvidence"}
    if runtime_version != "hipaa-business-runtime-v1":
        retrieval_tools.add("LookupBusinessClause")
    searches = [(i, call) for i, call in enumerate(tools) if call.get("tool") in retrieval_tools]
    actual = []
    for _, call in searches:
        for hit in call.get("response", {}).get("evidence", []):
            actual.append({key: hit[key] for key in ("id", "record_id", "text")})
    provenance = (item.get("case_id") == case["case_id"] and item.get("packet") == context(case)
                  and item.get("state") == "completed" and bool(item.get("agent_session"))
                  and bool(read_positions) and 1 <= len(searches) <= 3
                  and all(read_positions[0] < i for i, _ in searches) and actual == evidence)
    if runtime_version != "hipaa-business-runtime-v1":
        provenance = provenance and not resolution_error and (not evidence or any(
            call["tool"] == "LookupBusinessClause" for _, call in searches))
    if runtime_version == "hipaa-business-runtime-v4":
        try:
            check_business_bundle(item)
            provenance = not resolution_error and item.get("case_id") == case["case_id"] and \
                item.get("packet") == context(case) and item.get("state") == "completed" and bool(item.get("agent_session"))
        except ValueError as error:
            provenance = False
            result["errors"].append(str(error))
    elif runtime_version == "hipaa-business-runtime-v3":
        provenance = provenance and all(call.get("model_response") == business_model_view(call["response"])
                                        for _, call in searches)
        provenance = provenance and [h for _, call in searches for h in call["response"]["evidence"]] == item.get("evidence", [])
    result["checks"]["runtime_provenance"] = provenance
    if not provenance:
        result["errors"].append("Runtime case failed, facts changed or actual facts/search evidence provenance is missing")
        result["structural_pass"] = False
        result["oracle_alignment"] = False
    if separated:
        result["action_policy"] = {
            "version": "stage-conservative-v1", "conforms": result["structural_pass"],
            "expected_action_exact_match": result["checks"]["expected_recommendation"],
            "limitations": "Contract-permitted action, not authorization to execute or a legal finding.",
        }
        result["coverage_version"] = "claim-and-condition-v1"
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("verify", "context", "grade"), nargs="?", default="verify")
    parser.add_argument("--case-id", help="Opaque business-01 through business-12, not an expected label")
    parser.add_argument("--response", type=Path, help="Saved structured response JSON; never an instruction to invoke a model")
    parser.add_argument("--evidence", type=Path, help="Saved retrieved snippets JSON: id, record_id, exact text")
    args = parser.parse_args()
    suite, records = load()
    if args.command == "verify":
        result = verify(suite, records)
    else:
        case = next((c for c in suite["cases"] if c["case_id"] == args.case_id), None)
        if case is None:
            parser.error("Select an existing --case-id business-01 through business-12")
        if args.command == "context":
            result = context(case)
        else:
            if args.response is None or args.evidence is None:
                parser.error("grade requires --response and --evidence saved JSON files")
            result = grade(case, json.loads(args.response.read_text()), json.loads(args.evidence.read_text()), records)
    print(json.dumps(result, indent=2, ensure_ascii=True))
    if args.command == "grade" and not result["oracle_alignment"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
