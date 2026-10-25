# Internal hospital route demo

[English](./ROUTE-DEMO.md) | [简体中文](./ROUTE-DEMO.zh-CN.md)

The current route demo follows **organization policy -> project approval ->
observed behavior**. It replaces the earlier P5/P6 trial records, rather than
presenting multiple historical attempts as the current demonstration.

## Explicit synthetic organization policy

`Contest.RouteScenario` implements **DEMO-INTERNAL-USE-1, version 1**.
DEMO-HOSPITAL is a simulated covered entity. Its source SQL system, FHIR center
and technically isolated analysis receiver belong to that same organization.
All patient data is synthetic. Namespace isolation is not a legal or
organizational boundary.

| Route | Approved scenario | Registered recipient / configured identity |
|---|---|---|
| Internal aggregation | Consolidate eight synthetic resources to support approved hospital care and operations; no external export | `local-fhir-center` / `ContestAggregationFHIR` |
| Internal quality improvement | Compare encounter classes by birth-year cohort to improve hospital services; not research designed to produce generalizable knowledge, marketing or external commercial reuse | `local-analysis-receiver` / `local-utilization-service` |

Both paths handle simulated identifiable data under controlled internal access.
Neither relies on de-identification or individual patient authorization. Stable
IDs/references are permitted within the approved project scope; their presence
alone is not a policy finding. BAA, DUA, Safe Harbor and Expert Determination are
not a universal set of prerequisites for every HIPAA workflow.

Each project needs approval of its exact purpose, recipient, configured service
identity, resource/field scope, record limit, configuration and validity.
Changed purposes, external recipients or broader datasets require separate
review. A purpose code does not prove that contradictory free-text purposes are
appropriate: approvers and the Agent must compare them.

These are fictional scenario premises, not real hospital credentials, legal
authorization or a compliance certificate. Relevant concepts are explained in
[HHS TPO guidance](https://www.hhs.gov/hipaa/for-professionals/privacy/guidance/disclosures-treatment-payment-health-care-operations/index.html)
and [HHS minimum necessary guidance](https://www.hhs.gov/hipaa/for-professionals/privacy/guidance/minimum-necessary-requirement/index.html).
Neither source approves this demo or makes every analytics project a health
care operation.

The policy is supplied as bounded application facts. It does not silently
replace the separate treatment/Safe Harbor/expert examples in the prepared
knowledge corpus or claim that an updated corpus was imported into AI Hub.

## Approval and evidence

Registration alone grants nothing. Explicit approval binds the synthetic
scenario to the declaration/configuration/validity digest and approver record.
Readback verifies both that binding and the registered scenario definition.
The free-text purpose remains a **claim**; it is not promoted to an observation.

`route-evidence-v2` contains eight minimized facts:

- Submitted purpose and context: unverified claims.
- Exact approved scope, recomputed output and persisted delivery: observations.
- Monitoring coverage: explicit boundaries, not a blanket legal-document list.
- Organization policy: a local synthetic policy.
- Approved scenario: an observation of the verified synthetic approval binding,
  not evidence about a real institution.

The server supplies a required scoped comparison of policy, purpose, recipient,
service configuration and data scope. It no longer requires a de-identification
investigation on every batch. A contradictory de-identification claim can
still raise an actual relevant question.

IRIS handles exact scope/configuration/validity checks. The AI Hub Agent
examines purpose consistency, data appropriateness and relevant conditions
using the supplied facts and dated normative sources. It may return a scoped
no-finding, a potential deviation or a material information gap. Conditions,
fact references and materialized citations are checked server-side; that does
not prove semantic entailment.

Later recipient conduct, source freshness beyond the snapshots and overall
legal compliance remain coverage boundaries. They are not automatically
missing prerequisites for each otherwise verifiable batch. After-send review
cannot hold, replay or undo completed delivery.

## Run on the existing local installation

These commands target the existing owned local instance and running
PIPELINE/UTILIZATION/TRIAGE Productions. They do not provision environments,
change credentials or restart Productions.

```sh
# Free: compile only the exact updated classes.
python3 contest/route_demo.py --install

# DESTRUCTIVE: explicit consent required. Replace only the route demo records,
# approvals, batch snapshots, linked AI reports, named result files and SQL
# receiver rows. Register/approve both scenarios and perform two fresh sends.
python3 contest/route_demo.py --reset-demo

# PAID: separate explicit consent, at most four deepseek-flash requests.
# The existing background timer discovers and reviews the two exact batches.
python3 contest/route_demo.py --authorize-four-requests

# Read-only, after both tasks are terminal; fail on missing/failed results.
python3 contest/route_demo.py --check
```

Reset verifies the inspected plan under the observer lock and refuses unknown
registrations, foreign instances, in-flight batches or running reviews. It
does not delete unrelated workflow data, engine message logs, HIPAA sources,
FHIR repository history or other Agent evaluations. Fresh aggregation updates
the same eight synthetic FHIR resources. The downstream SQL table contains one
fresh demonstration receipt.

The two current batches are `aggregation-internal-demo` and
`utilization-quality-demo`. Opening `/governance` never initiates inference.
Arbitrary future batches have zero model allowance. Repeated authorization
does not replenish a reservation; failures are explicit and are not retried.
There is no fabricated result if the provider or output contract fails.

An optional `--replace-failed-utilization-two-requests` command is a separate,
explicitly authorized one-time output retest, not an automatic retry. It
requires a terminal failed two-phase quality-improvement review, replaces that
failed displayed report without resending data, and retains its consumed
allowance and SDK counters. The additional two-request allowance is displayed
separately. It refuses a second replacement or changed evidence/source Agent.

## Free regression coverage

Run `Contest.RouteScenarioTests`, `Contest.RouteGovernanceTests`,
`Contest.RouteEvidenceTests`, `Contest.RouteUITests`, `Contest.RouteReviewTests`
and `Contest.RiskReviewV4Tests` using the project Interoperability test workflow.
Privileged persistence tests must also run through an authorized local session;
the lower-privilege development MCP deliberately skips those branches.

Tests cover scenario binding/tampering, unknown purposes and recipients,
unchanged claim provenance, conditional question scope, exact delivery
evidence, excess fields/configuration rejection, stale reset plans, immutable
request budgets and separate reset/cost-consent commands. Fixtures do not send
out-of-scope data to the real receiver or call a provider.

## Verified local outcome

Both fresh batches completed real BS/BP/BO delivery and automatic AI Hub review:

| Batch | AI Hub sessions | Accepted scoped result |
|---|---|---|
| `aggregation-internal-demo` | 145 / 146 | No signal on the checked issue; applicable condition met; no material information request |
| `utilization-quality-demo` | 149 / 150 | No signal on the checked issue; applicable condition met; no material information request |

The first utilization response had invalid grounding references and exceeded
the explanation limit. It was rejected, not truncated or relabelled. After
separate explicit consent, one two-request output retest passed the unchanged
validator. The failed displayed report was replaced; its consumed allowance
and SDK counters remain in the cost accounting, not as another demo row.
There were **six interactions total**, 41,292 prompt and 41,635 completion
tokens (82,927 total), including the rejected attempt. No automatic retry ran.

Five materialized citations were verified against the complete frozen source
text and exact offsets. Both results retain coverage limitations and the
staged evaluator's conservative `manual_review` / `human_review_required`
markers; these are not a pipeline hold or evidence of a missing prerequisite.
The operational events are `no_signal_on_checked_issues`, not `unresolved`.
This validates two normal synthetic scenarios, not general legal accuracy.

The current registry has two approved routes, two batch snapshots and one SQL
receiver receipt. All four existing Productions remain running; none was
restarted. The prepared HIPAA corpus and source Agent/index are unchanged.
Verification passed 135 Python tests, 54 frontend tests plus lint/type-check/
build, and eight authorized IRIS suites with 345 assertions.
