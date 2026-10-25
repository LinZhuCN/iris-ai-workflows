# Privacy Agent factory (P4 slice)

[English](./AGENT-FACTORY.md) | [简体中文](./AGENT-FACTORY.zh-CN.md)

The **Agents** page at <http://127.0.0.1:5173/agents> uses real IRIS APIs,
persisted versions and `%AI.Agent` calls. It is not the earlier configuration
fixture. This slice supports one bounded `privacy_review` template, not arbitrary
Agent code or unrestricted natural-language policies.

A separate [staged risk-review prototype](./MONITORING.md#staged-risk-review-free-evaluation-only-prototype)
uses two tool-free tasks and server-selected development evidence. It is
terminal/evaluation-only, not another factory version, UI action or business
Agent binding. Its separately authorized six-case model smoke run completed
5/6 with only 2/6 matching all four author judgment checks; over-expanded
questions and one wrong-shape locator output prevent quality acceptance.
An opt-in [locator-only v2 experiment](./MONITORING.md#locator-only-v2-experiment-free-validation-no-model-result)
preserves the judge/evidence/aggregation contract and remains separate from factory releases.
Its [authorized retest](./MONITORING.md#authorized-staged-v2-run-six-completed-five-whole-case-matches)
completed 6/6 cases with 5/6 matching all author checks. A separate
[judge-only staged v3 refinement](./MONITORING.md#judge-only-staged-v3-refinement-free-validation-only)
subsequently [completed its authorized retest](./MONITORING.md#authorized-staged-v3-run-six-machine-matches-semantic-review-still-open)
with 6/6 matching all four author checks. Semantic explanation and evidence
minimization concerns remain; neither experiment is promoted or bound.
A separate [prospective semantic acceptance pack](./MONITORING.md#prospective-semantic-acceptance-pack-frozen-runtime-external-review-pending)
freezes v3 and adds eight new cases/48 human rubric judgments. It is free-prepared,
assistant-authored, not independently reviewed and not another factory release.
Its [authorized exploratory run](./MONITORING.md#authorized-prospective-challenge-run-six-label-matches-eight-safe-recommendations)
completed 8/8 with 6/8 main-status matches and 8/8 unresolved/action matches;
semantic verdicts and status-boundary review remain pending, with no publication.
A [non-adopted taxonomy proposal](./MONITORING.md#status-boundary-proposal-not-adopted-no-retrospective-regrading)
now records three pending decisions against actual outputs; it is not a new
factory/runtime version or retrospective regrading.
An independent [local export evidence collector](./MONITORING.md#source-backed-export-evidence-first-local-synthetic-slice)
now derives minimized facts from actual generated/transformed synthetic rows,
with scoped receipt readback. It is not a factory release or business-Agent
binding, and unconnected permission/expert/approval evidence remains unknown.

## Prerequisites and setup

Use the existing [Knowledge setup](./KNOWLEDGE.md) and
[DEMO Connector setup](./MONITORING.md). An active local index, the fixed
`local-demo / DEMO` Connector and a configured real provider are required.
Run the existing monitor preparation after updating the checkout to load the
factory classes, or restart the configured IRIS container to run its installer.
No new credentials or namespaces are needed.

The local demo builder can write; the viewer can read. The API reuses
`ContestMonitorRead` and `ContestMonitorDeploy`, in addition to Knowledge read
authorization. These are single-demo capability checks, not tenant isolation.
Passwords remain in ignored files; optional Vite demo-prefill values are public
to the browser and must never be used for a shared/production deployment.

## Workflow

1. Connect with the prefilled local demo account.
2. Describe the desired privacy reviewer using **synthetic/public information
   only**. Confirm possible model charges, then generate a restricted draft.
   One real, tool-free Agent invocation proposes a name, the supplied purpose
   and an evidence query. The server pins the current index table/version,
   corpus fingerprint, model, executor version and four-iteration limit.
3. Select the resulting draft. Review/edit its name, purpose and retrieval
   query. The purpose is descriptive, not an executable system prompt.
   Saving invalidates its test eligibility; revisions reject concurrent edits.
4. Explicitly authorize three real synthetic tests (at most four agent-loop
   iterations per case). Each test must call both read-only tools:
   `ReadPrivacyFacts(runId)` and `SearchPrivacyEvidence(runId)`.
   Tools require the worker's bound run ID. They cannot accept another
   namespace, index, endpoint, message payload or executable action.
5. Inspect each result, citations, actual tool calls, AI Hub session and usage.
   All three expected outcomes must match: `risk`, `no_finding` and
   `insufficient_evidence`. A failed/invalid result cannot authorize publishing.
6. Confirm publication of the exact tested configuration hash. Published
   configurations cannot be edited. Create a new draft for subsequent changes.
7. Load a discovery snapshot and explicitly record a binding to the DEMO
   analytics observation point. The server rechecks the current source hash,
   support and running state. **This records intent only:** it does not connect
   observation-triggered execution, change delivery or enable Gate enforcement.
   Disabling a published version also disables its recorded binding.

An explicit single-case retest is available only when exactly one of a matching
three-case report's scenarios failed. It requires a new cost confirmation, is
bounded to four iterations and retains the original two passing cases with
their source report/session provenance. It is not an automatic retry, and the
original failing report remains available.

## Evidence and result boundaries

Retrieval opens the pinned completed index, not whichever version later becomes
active. The five retrieved snippets retain chunk IDs, scores, source URLs,
locators, kinds, authority labels and scopes. Snippet text is bounded to 2,000
characters per hit. Historical/unreviewed material is not added by this path.
Prepared official evidence, LLM-authored orientation and synthetic organization
policy remain distinguishable; not all results are legal authority.

The result schema contains exactly `assessment`, `reason` and `citations`.
Reasons are bounded to 2,000 characters; one to five citations must refer to
evidence actually read by that test. Routing actions and invented citation IDs
are rejected. Reference text is data, not instructions. The three tiny
synthetic-flag tests verify wiring and constrained behavior, **not broad privacy
review quality or HIPAA compliance**. A separately authorized
[twelve-case synthetic evaluation](./MONITORING.md#twelve-case-privacy-evaluation)
initially completed with **9/12 passing**, not overall quality acceptance.
Two missing-purpose cases incorrectly returned `no_finding`; a contradictory
identifier case returned conservative `risk` rather than the expected
`insufficient_evidence`. The original report remains unchanged.
[P5 event operations](./MONITORING.md#events-and-human-review-p5) now consume
real observations and save human actions/opinions. Automatic reviews are
explicitly `blocked_budget`, not completed findings. The manual investigation
path has now completed one separately authorized real investigation with a
scoped `risk` result, real tool citations and an independent finding event.
The source event/opinions were unchanged. Agent bindings remain non-executing
intent; automatic execution and the diagnosis template are not implemented.

After the evaluation, the deterministic `privacy-safety-v1` acceptance guard
was added. A `no_finding` conclusion now requires explicitly typed synthetic
analytics facts: known purpose, no direct identifiers and verified
de-identification. Missing, wrong-type or contradictory values reject the
output and retain it for inspection; they are not silently rewritten into a
passing model answer. Conservative `risk` and `insufficient_evidence` remain
non-clean findings. This is an output acceptance guard, not a claim that the
model itself was corrected. The published Agent prompt/configuration and its
existing hash were not rewritten. New cases record the acceptance-policy
version separately. Framework assertions and replay of the two original
unsafe outputs verified the guard without another model call.

### Versioned correction and full retest

`POST /agents/revise` takes only the published source `id` and exact `revision`.
It idempotently clones that version into a separate `privacy-review-v2` draft,
without calling a model or editing the source. Parent identity/hash and the
fixed server-owned prompt version/SHA-256 are persisted. The new configuration
hash includes prompt provenance; legacy hash semantics remain unchanged.
The corrected instructions prioritize missing or wrongly typed facts, then
contradictions, before assessing risk or a limited clean result. Authorization
does not establish de-identification; embedded notes remain untrusted data.

The candidate completed a separately authorized full twelve-case real retest:
**12/12 passed, zero technical failures**, using the original manifest,
`deepseek-flash` and index 7. See the [exact results and cumulative usage](./MONITORING.md#versioned-v2-retest).
This is not a statistical benchmark, legal certification or diagnosis evaluation.
More specifically, it is a **mechanism regression**: the prompt directly supplies
the flag-to-label rules. It does not demonstrate HIPAA risk identification from
business facts or that retrieved clauses support the reasoning. The separate
[business-context benchmark](./MONITORING.md#business-context-hipaa-risk-benchmark)
addresses those acceptance requirements. Its independent, versioned read-only
runtime is separate from this flag executor and does not publish or bind it.
The original 9/12 report and published configuration remain unchanged.
The candidate is **still a draft**: no automatic publication, binding,
investigation repeat, business action or ongoing review was authorized.

V2 drafts cannot use the legacy three-case test or single-case retest as a
publication shortcut. A matching, complete twelve-case evaluation is required:
configuration and prompt hashes, manifest hash and all fixed case outcomes
must agree. The Agents page shows this eligibility separately and still
requires exact-hash confirmation. Editing a draft invalidates eligibility.
Publication eligibility here is a technical lifecycle gate, not legal approval
or business-context validation. Do not promote v2 as a validated HIPAA reviewer.

Jobs/configurations/reports/binding live in `^ContestAgents`; actions use the
existing protected platform audit. Jobs are not automatically replayed.
Startup assigns a new boot identity so unfinished jobs from a previous server
run are reported `interrupted`. This is not a generic distributed lease/job
platform, and a running provider request has no cancellation guarantee.

New calls persist the SDK conversation after `Chat`, rejected output for
debugging, and cumulative session statistics. Earlier acceptance cases retain
their explicit tool/evidence records but predate SDK-history persistence.
`Usage` returned by this EAP's Agent response describes the final model
response, not necessarily the entire tool loop. The UI distinguishes it from
`GetStats()` cumulative session counters. Reasoning tokens are included in
completion tokens and must not be counted twice. No currency cost is inferred
without a pinned provider price schedule.

## API

The separately versioned business-context reviewer now also has an opt-in
`hipaa-business-runtime-v2` with clause lookup and source-handle citations;
see [upgrade and limitations](./MONITORING.md#v2-evidence-and-judgment-upgrade).
This is **not** the factory's `privacy-review-v2` flag-classification candidate,
does not modify either factory version. Its separately authorized model retest
achieved 12/12 output contracts and 8/12 full author-machine alignment, not a
legal pass or permission to publish either factory version.
The opt-in [business runtime v3](./MONITORING.md#v3-conditionclaim-separation-and-compact-evidence-free-only)
separates claim warnings from condition evidence and projects a compact
model-facing source view, with unchanged canonical audit evidence.
Its separately authorized real model retest regressed to 6/12 accepted
contracts and 1/12 full author-machine alignment; it is not promoted.
No factory publication/binding was performed. A new runtime version needs new
explicit cost consent and cannot reuse a v1/v2 request key.
The subsequent [v4 evidence-plan refinement](./MONITORING.md#v4-single-use-evidence-plan-free-implementation-not-model-evaluated)
is also evaluation-only and opt-in: server-prefilled facts and one bundled
retrieval tool, unchanged v3 judgment contract and request limits. It has free
SDK/local-retrieval coverage, but the authorized model batch accepted 0/12
outputs due to tool-argument failures and one contradictory final assessment.
It is not promoted and establishes no legal-quality result. Neither runtime
qualifies a factory Agent for publication or binding.

All paths are under `/api/monitor/v1`; native Basic authentication applies.
POST requires JSON, `X-Requested-With: IRIS-Workflows`, and at most 4,096 bytes.

| Method | Path | Body |
|---|---|---|
| GET | `/agents` | Versions, latest 20 jobs, recorded binding, permissions |
| POST | `/agents/generate` | `purpose`, `acknowledge_cost: true` |
| POST | `/agents/edit` | `id`, `revision`, `draft: {name,purpose,retrieval_query}` |
| POST | `/agents/revise` | Published source `id`, `revision`; idempotent v2 clone, no model call |
| POST | `/agents/test` | `id`, `revision`, `acknowledge_cost: true` |
| POST | `/agents/retest` | `id`, `revision`, `report_id`, `acknowledge_cost: true` |
| POST | `/agents/publish` | `id`, `revision` |
| POST | `/agents/bind` | `id`, `revision`, `snapshot_id` |
| POST | `/agents/disable` | `id`, `revision` |

Generation/testing return HTTP 202 and a durable job. Normal reads, publication,
binding and the regression commands below do not call a model.

## Verification

Non-billing HTTP checks:

```sh
python3 contest/agent_test.py
python3 contest/platform_test.py
```

Compile `contest/dev/AgentTests.cls` and run `Contest.AgentTests` in **TRIAGE**
with `test_type="testproduction"`. Its `TestControl` does not stop/start the
Production. Ten framework methods cover contracts, tool isolation, version
invalidation, immutable publication, disable behavior, pinned-index guards and
startup scope, interrupted jobs and Connector output-device preservation.
Lifecycle fixtures are transactionally rolled back, not published
as real evaluation results. Frontend validation uses the existing build, lint
and test commands.

Authorized real acceptance used `deepseek-flash`: one builder invocation,
three initial test invocations, then one separately authorized failed-case
retest. Initial risk and no-finding cases passed; insufficient-evidence output
was rejected by the strict contract. The retest passed, preserving the first
two cases' provenance. The original failure's exact output was not retained,
so its precise schema violation cannot be reconstructed; subsequent failures
retain rejected output. Do not describe this as a first-pass three-case success.
The accepted version was published and bound through the browser. A container
restart retained the version, reports, knowledge index and binding without
another model call.

## Startup recovery

The installer uses `Ens.Director.GetProductionStatus` and
`RecoverProduction` only for a troubled **expected** managed Production, then
starts it. A running different Production is rejected; an intentionally
suspended Production requires manual intervention. If DEMO already exists and
contains `Demo.Production`, startup restores it as well. It does not create
DEMO as a side effect or replay Agent jobs. Existing Interoperability queues
retain their normal IRIS recovery semantics; this is not a guarantee that
arbitrary external business side effects are exactly-once.

The pinned EAP image/license configuration and existing Compose files remain
required. No auto-start policy for Docker Desktop or other projects is changed.
Normal restart was verified with both managed Productions running afterward.
An abrupt-kill fault-injection attempt was blocked by the execution tool before
it ran; automated recovery after a newly injected abrupt shutdown is therefore
not claimed as verified. The earlier actual unclean state was recovered with
the same official recovery API before this startup hardening.
