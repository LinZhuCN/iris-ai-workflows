# Declaration-to-monitoring demo: design and development plan

[English](./DECLARATION-WORKFLOW-PLAN.md) | [简体中文](./DECLARATION-WORKFLOW-PLAN.zh-CN.md)

## Goal and acceptance boundary

A user creates a new data-use declaration. An AI Hub Agent evaluates the
proposed use against HIPAA sources, explains risks or material missing inputs,
and supports revision before a human decision. An approved, executable
declaration can then drive a synthetic IRIS workflow. Automatic after-send
monitoring compares actual use with that exact approved declaration.

The UI identifies the application as a synthetic-data demo once. Ordinary
results use direct language: "No HIPAA compliance risk identified",
"HIPAA compliance risk identified", or "Additional information required".
The result describes the submitted proposal or the observed batch, as
appropriate. Technical failures are separate from business conclusions.

This plan supersedes treating the two fixed successful routes as completion of
the user-facing workflow. Existing deliveries and monitor results remain useful
baselines. No additional inference, sends, resets or deployment changes are
authorized by writing this plan.

## 1. User journey

1. Create and save a draft declaration.
2. Submit an immutable revision for automatic queued AI review. Show the model
   allowance before submission; ordinary navigation never triggers inference.
3. Inspect the assessment, issue-specific reasoning, source excerpts and
   requests for material information.
4. Edit a returned proposal as a new revision and submit it again. Retain the
   earlier revision and its assessment in that declaration's history.
5. A reviewer approves, returns for changes, or rejects the exact reviewed
   revision. A positive AI assessment is not itself human approval.
6. For an approved supported recipe, explicitly run a synthetic batch from the
   page. No global active-route pointer needs to be switched.
7. The observer automatically captures the batch and reviews actual behavior
   against the declaration and approval. Show the linked result and event.
8. Record event review and resolution without silently changing the approval,
   replaying the batch or triggering another model call.

Preset aggregation remains the upstream baseline. New utilization declarations
are the main interactive workflow; users do not have to reset the demo or
modify source code to create another one.

## 2. Declaration model

Use controlled selections where the demo has real registered capabilities,
with free-text business explanations rather than a fixed approved-purpose
paragraph.

| Group | Inputs |
|---|---|
| Identity | Declaration ID/title, revision, responsible office, submitter |
| Business use | Intended purpose/category, specific activities, intended output and why each requested data group is needed |
| Parties | Requesting team, recipient selection, internal/external relationship from the synthetic recipient catalog |
| Data | Requested resource/field selection, cohort and record limit |
| Handling | Identifiability/de-identification claim, processing recipe, intended access, retention and onward sharing |
| Applicable arrangements | When relevant: declared authorization, agreement or other supporting arrangement; not a universal mandatory checklist |
| Validity | Requested start and end |

Persist the declared recipient separately from the transport/service identity.
Registered organization facts, user statements, proposed processing and actual
observations have distinct provenance.

Initial executable support stays bounded: the existing four-resource cohort,
an explicit allowlist of projection fields/transformations, and the registered
internal SQL receiver. A catalogued simulated external use can be assessed
without creating an external connection. "Can be assessed" and "Can be run"
are separate properties. Unsupported execution must be shown explicitly; it
must not silently substitute the internal quality-improvement recipe.

## 3. Two review modes, one reusable evidence engine

### Declaration review: before approval or delivery

- Input: immutable declaration, registered synthetic organization/recipient
  facts, proposed data recipe and policy version.
- A statement is evidence of what the user proposes, not proof that the
  behavior has already occurred. A proposal may nevertheless be assessed on
  those stated premises.
- Do not require an approved scenario, receipt or verified delivery to assess
  a proposed use. Do not label all user-provided premises "unresolved" simply
  because they are declarations.
- Reuse the two-stage approach: identify relevant questions, retrieve source
  context server-side, then judge the questions with the AI Hub Agent.
- A contradictory proposal can be a risk even when it has no observed batch.
  Request more information only when a specific missing answer changes the
  assessment; do not ask every applicant for BAA/DUA/patient authorization.
- Return issue status, explanation, referenced declaration fields, legal
  citations and material questions. Use proposal-specific grounding rules,
  not the existing observation-only validator.

### Observed-use review: after delivery

- Input: exact declaration/review/approval IDs and hashes, current registered
  policy facts, frozen source/output/configuration and actual receipt.
- Reuse existing integrity checks and actual message/session linkage.
- Compare actual recipient, fields, transformations and purpose context with
  the approved proposal. Approval does not automatically make an inconsistent
  business purpose reasonable.
- Keep technical integrity failures distinguishable from an AI risk finding.
- Do not hold or undo a completed send. Pre-send deterministic constraints
  remain enforced by IRIS.

Both modes record Agent/model, prompt contract, knowledge index/source version,
SDK sessions, token usage, attempt count and timestamps. Source references must
resolve to materialized passages; no fabricated citations.

## 4. State, decision and message contracts

Keep independent state dimensions instead of one overloaded status:

- Revision: immutable submitted snapshot; edits create the next revision.
- Review task: queued / running / completed / failed / blocked_budget.
- Assessment: no_risk_identified / risk_identified / information_required.
  Failed tasks have no assessment.
- Human decision: pending / approved / returned / rejected.
- Execution readiness: supported / unsupported / expired / superseded.
- Batch and monitoring: reuse separate delivery, review and event states.

Approve only a completed assessment for the exact revision, current required
policy/configuration and valid interval. Require unresolved risks/questions to
be addressed in a new reviewed revision; do not add an override path in the
first implementation. Returning/rejecting records a reason. New revisions
cannot inherit assessments, approvals or execution rights. Block execution of
an older approved revision once a replacement revision is submitted; historical
batch evidence continues to reference the original revision.

Design these logical contracts before implementing BS/BP/BO changes:

- Review request: declaration ID, revision/digest, review mode, policy/index/
  prompt pins, task/idempotency ID and cost authorization ID.
- Review result: matching task/revision identities, task outcome, assessment
  when completed, issues/questions/citations and SDK provenance.
- Batch command: exact approved revision/digest, supported recipe/config hash,
  unique batch ID and execution authorization.

Use real `Ens.Request`/`Ens.Response` messages and an IRIS BP for the new review
path, with queued asynchronous execution; the browser does not wait for a
provider response. Inspect existing message/superclass APIs before selecting
physical class signatures. Reuse existing orchestration where compatible;
MCP remains a development tool, never the runtime Agent.

## 5. Cost, concurrency and execution controls

- Replace fixed two-batch allowances with atomic per-task reservations within
  an explicitly authorized bounded demo budget.
- Show declaration and post-send review costs separately. Submission consumes
  no provider requests without sufficient authorization.
- Preserve the two-phase request cap, no automatic retries, deduplication and
  explicit failure reporting. A manually authorized retry is a new linked task.
- Repeated clicks/polling must not create duplicate inference, approvals or
  deliveries. Concurrent revision/approval checks happen server-side.
- Future after-send review allowance can be reserved for an exact approved
  revision and new batch identity, then bound to its actual receipt on capture.
- Continue collecting evidence when no model allowance exists, but show
  blocked_budget rather than reusing a different declaration's assessment.
- No arbitrary URLs, credentials, executable expressions, SQL or Production
  edits are accepted in a declaration.

## 6. Integration map

| Existing surface | Planned change |
|---|---|
| `RouteUI` and governance page | Real proposal fields, submit/revise/decision/run actions, linked result views |
| `RouteGovernance` | Versioned declaration contract and approval bound to exact completed review |
| `RouteScenario` | Separate registered organization facts from a user's proposed purpose; stop assigning every submission the fixed QI scenario |
| `RiskReviewV4` and staged retrieval | Reuse retrieval/citation mechanisms; introduce a separate proposal-review contract instead of weakening observation validation |
| `RouteReview` | General per-task grants and revision/batch linkage, preserving automatic after-send discovery |
| Utilization runtime/projection | Explicit approved revision per batch, allowlisted configurable projection, existing unique receiver writes |
| Route evidence and frontend decoders | Distinct proposal/approval/observation provenance, typed new contracts |

Do not automatically backfill old reports as successful declaration reviews.
Legacy baseline records remain visibly legacy until explicitly reviewed through
the new path. Install/update behavior must be explicit and idempotent.

## 7. Development sequence and acceptance gates

| Phase | Deliverable | Required acceptance |
|---|---|---|
| D1: Contracts and persistence | Declaration/recipient/recipe schemas; revision and task state; review/decision binding | A new non-template proposal persists; invalid scope is reported; editing cannot reuse review/approval; no model calls |
| D2: Proposal review | IRIS request/BP/result path, proposal facts, retrieval, validator, per-task budget | Positive, risky and incomplete proposal fixtures produce distinguishable valid results; actual failures remain failures; duplicate submit reserves once |
| D3: Interactive review and approval | Form, queued progress, evidence, revision, return/reject/approve | From the browser, create a new declaration, inspect result, revise and decide; stale/failed/unreviewed approval is rejected |
| D4: Approved execution binding | Explicit batch action for supported recipes; approved projection and receipt linkage | New approved declaration drives its own real BS/BP/BO batch without reset or global pointer edits; unsupported/unapproved/stale proposal cannot send |
| D5: Automatic post-send comparison | General batch discovery/grants, exact approval linkage, event detail/actions | New batch is discovered without a manual review-start action; actual evidence links to the same revision; no duplicate sends or reviews |
| D6: End-to-end acceptance and documentation | Real browser walkthrough, real Agent checks and regression tests | Normal, risk and missing-input submissions work; correction/approval/send/monitor chain completes; token accounting matches authorized attempts |

Dependencies: D2 follows D1; D3 follows D1/D2; D4 follows the review/approval
contract in D3; D5 follows D4; D6 follows all prior gates. Update directly related
documentation and tests in each phase, not only at the end.

Free tests precede separately authorized real inference:

1. Internal quality-improvement proposal with a justified bounded dataset.
2. A proposed identifiable-data transfer for external marketing without an
   applicable permission established in the declared scenario.
3. An ambiguous secondary-use proposal missing a decision-relevant purpose
   or recipient relationship.
4. Corrected revision, with old review/approval unable to authorize it.
5. Approved real synthetic batch and automatic post-send comparison.
6. Controlled drift fixtures for recipient/field/configuration mismatch; never
   send out-of-scope data merely to obtain a risk demonstration.

Use actual Agent outputs for real-model acceptance, not predetermined status
labels. Freeze case expectations before running; count technical rejection
separately from assessment quality. Authorize a finite call cap after free
validation; no existing consumed allowance is reusable.

## Completion definition

The workflow is complete only when a user can create a new declaration through
the UI, obtain its own AI Hub assessment, revise it, receive a human decision,
run an approved supported synthetic batch, and inspect its automatically linked
post-send review. Two preconfigured successful batches alone do not meet this
definition. Contest packaging, remote systems and arbitrary pipeline generation
are outside this development plan.

## D1 implementation and local verification

D1 is implemented in [DeclarationCatalog](./src/DeclarationCatalog.cls) and
[DeclarationService](./src/DeclarationService.cls), with authenticated routes in
[KnowledgeAPI](./src/KnowledgeAPI.cls). The legacy route registry and its
business approvals are unchanged.

### Contract and API

The proposal stores title/owner, purpose category/text/activities/output,
recipient selection, resource/field/cohort/count/necessity, handling recipe/
identifiability/access/retention/onward sharing, arrangement status/details
and integer IRIS UTC validity bounds (seconds since 1840-12-31).
The concrete JSON examples are defined in
[declaration_test.py](./declaration_test.py).

Registered organization and recipient facts are captured separately in
`context`, pinned to a catalog version and hash. Selection never grants an
approved-use scenario or an AI assessment.

| Method | API path under `/api/monitor/v1` | Contract |
|---|---|---|
| GET | `/declarations/catalog` | Bounded synthetic organization, recipient, purpose, data and recipe selections |
| GET | `/declarations?after=...` | Up to 25 latest declaration revisions; stable declaration-ID cursor |
| GET | `/declarations/:record_id` | Exact immutable revision, linked task/decision and execution readiness |
| GET | `/declarations/:declaration_id/history?before=...` | Up to 25 revisions, newest first; `older_before_revision` continues the history |
| POST | `/declarations` | `declaration_id`, `expected_revision`, `expected_digest`, `proposal` |
| POST | `/declarations/submit` | `record_id`, `digest`; idempotent review-intent creation |
| POST | `/declarations/decide` | `record_id`, `digest`, `task_id`, `task_hash`, `action`, `reason` |

`expected_revision=0` and an empty parent digest create revision 1. Further
saves require the current revision and its digest; they create a new immutable
draft. Exact lost-response retries return the existing revision rather than
creating another one. The submit action accepts only the latest version.
Submitting its replacement marks an older approval superseded for future use
without erasing historical evidence.

D1 creates a `blocked_budget` task with **zero reserved/attempted requests**,
null assessment and null result. No worker or provider is called. Completed
reviews and decision bindings are tested using explicitly marked transaction-
rolled-back framework fixtures, not inserted as demonstration assessments.
There is no public completion/result-upload endpoint.

Approval requires an exact current completed no-risk task, a matching task hash,
current catalog and valid interval. Failed, risky, unanswered or unreviewed
proposals cannot be approved. Return/reject decisions require a terminal task
and a reason; decisions are immutable. D2 must supply real validated results
before the normal application can approve a new proposal.

Execution capability is distinct from execution readiness. The existing seven-
field internal recipe is recognized, but even an approved declaration remains
`not_connected` until D4. External or unsupported recipes remain assessable,
with `capability.state=unsupported`; D1 never sends data.

### Commands and current persisted examples

```sh
python3 contest/declaration_test.py --install
python3 contest/declaration_test.py --check

# Optional: explicitly create a NEW draft; choose an unused declaration ID.
# This neither submits it for review nor calls a model.
python3 contest/declaration_test.py --create-example quality \
  --declaration-id my-quality-proposal
```

The owned local installation now contains three persisted declarations:

- `demo-declaration-quality`: revision 1 submitted as a zero-budget review
  intent; no assessment or decision.
- `demo-declaration-marketing`: revision 1 external-use draft; no execution.
- `demo-declaration-incomplete`: revisions 1 and 2, with revision 2 the current
  draft; no inherited review or decision.

These are applicant proposals, not precomputed positive/negative AI results.
Real HTTP creation, resubmission deduplication, revision history and rejection
of an unreviewed approval were exercised. Reader/write separation, CSRF,
malformed input and bounded request sizes were checked. Only the full proposal
POST accepts up to 65,536 bytes; existing command endpoints retain 4,096 bytes.

Run [DeclarationTests](./dev/DeclarationTests.cls) through the project test
workflow and an authorized local session for persistence branches. Tests cover
distinct purposes, exact revisions/tasks/decisions, tampering, catalog changes,
25-item history pagination and no inference/execution side effects. All
persistence fixtures roll back. The existing governance HTTP checks and
`Contest.RouteUITests` remain passing.
The final authorized run passed 86 D1 assertions and 36 legacy UI assertions;
12 targeted Python tests passed. A separate permission-limited MCP run also
passed. Readback confirmed exactly three declarations, no leaked persistence
fixtures, and the original two routes/batches/reviews unchanged with no observer
error.

**D2 AI execution and D3 browser forms are not implemented by D1.** The current
governance page still uses the legacy fixed-route form; it must not be presented
as the completed new-declaration workflow.

## D2 implementation and acceptance status

### Runtime path

`POST /declarations/review` accepts explicit two-request consent and atomically
reserves the exact task once. A background dispatcher submits a persistent
[DeclarationReviewRequest](./src/DeclarationReviewRequest.cls) through
[DeclarationReviewService](./src/DeclarationReviewService.cls) to
[DeclarationReviewProcess](./src/DeclarationReviewProcess.cls).
The BP executes [DeclarationQueue](./src/DeclarationQueue.cls) and
[DeclarationReview](./src/DeclarationReview.cls); the latter uses real
`%AI.Agent` sessions for localization and judgment. HTTP submission does not
wait for inference.

The two dedicated hosts were added to the already running TRIAGE Production
using an explicitly authorized local update. The existing Production, IRIS and
other hosts were not stopped/restarted. Startup source now includes both hosts.
No role, password, namespace mapping or downstream destination was changed.

The task binds the declaration/revision digest, catalog hash, source Agent
revision/configuration, input hash, prompt contract and allowance. It records
actual Interoperability message/session IDs and the report ID. Reports preserve
phase inputs, raw outputs, Agent session IDs and SDK token statistics.
Repeated consent or duplicate messages cannot replenish attempts or replay a
terminal task. A source/contract change cannot spend an older reservation.
Repeating the exact original grant only returns that original task.

### Proposal facts and sources

Eleven facts carry purpose, activities, expected output, necessity, requested
scope, access, retention, sharing, arrangements, registered context and proposal
identity. Applicant statements remain claims; no prior approval or delivery
observation is manufactured. The pinned catalog's recipe definition is included
with registered context so a field path such as `Patient.birthDate` is interpreted
using the proposed year-only transformation, not automatically as a full date.

The server always retains a recipient/purpose/data-appropriateness question.
The Agent may identify an additional de-identification or unsupported issue,
without turning every request into a document checklist. Normative retrieval
reuses complete-source reconstruction/hash verification and reads sections
164.501, 164.502, 164.506 and 164.508 for the main question; 164.514 is available
when the declared path actually raises de-identification. Citation handles are
resolved server-side to exact source passages and offsets using the existing
canonical passage decorator. Source-hash checks revealed that the legacy
benchmark freezes its runtime files byte-for-byte. Its base evaluator/evidence
sources are therefore preserved unchanged: declaration-specific lookup,
citation materialization and the larger input bound live in new subclasses
rather than refactoring those frozen files or changing their freeze manifests.

The proposal validator accepts reasoning grounded in declared premises.
It does not weaken the observation-only contract for after-send review.
Server aggregation returns `no_risk_identified`, `risk_identified`, or
`information_required`. Substantiated risk and material outstanding questions
can coexist. An all-clear cannot contain hidden material questions.
Failed tasks have null assessment/result, not an invented business conclusion.

### Additional API

| Method | Path under `/api/monitor/v1` | Behavior |
|---|---|---|
| GET | `/declarations/:id/review-plan` | Write-capability-only plan; returns consent with `acknowledge_cost=false`; no inference |
| POST | `/declarations/review` | Exact cost consent; reserve once and dispatch asynchronously |
| GET | `/declarations/:id/review-report` | Authenticated read of actual phases, evidence, judgment and SDK provenance |
| POST | `/declarations/recover` | Exact task/hash; only when dispatcher and execution locks are free; mark an interrupted funded task failed without retry/refund |

Consent fields are `record_id`, `digest`, `task_id`, `agent_id`,
`source_revision`, `config_hash`, `input_hash`, `contract_hash`,
`max_model_requests=2`, and explicit boolean `acknowledge_cost=true`.
Plans and ordinary reads never authorize a call. No public fixture-completion
or result-upload endpoint exists. Recovery cannot interrupt a live dispatcher
or BP worker. A failed task requires a new reviewed revision for another run;
there is no automatic repair/retry.

### Local commands

```sh
# Compile only, without deployment or inference.
python3 contest/declaration_review_test.py --install

# Separate operator consent: add/update only the two declaration hosts.
python3 contest/declaration_review_test.py --activate-hosts

# Free authentication/cost-plan boundary checks.
python3 contest/declaration_review_test.py --boundaries
python3 contest/declaration_review_test.py --status

# PAID, only with explicit approval: three exact targets, at most six requests.
# Refuses previously funded targets; never rerun to replenish a failed task.
python3 contest/declaration_review_test.py --authorize-six-requests

# Read-only; fails unless all three real assessments match the frozen cases.
python3 contest/declaration_review_test.py --check --wait-seconds 1000
```

The marketing proposal was revised before inference to state explicitly that
the proposed identifiable-data marketing disclosure relies on neither individual
authorization nor an applicable marketing exception. This is an applicant
premise, not a prefilled model verdict. Acceptance expectations were fixed
before inference: internal quality improvement/no risk; external marketing/risk;
unspecified secondary use/material information required.

### Real-model acceptance: all three current scenarios passed

| Declaration revision | Interop session | Agent sessions | Actual outcome |
|---|---|---|---|
| `demo-declaration-quality` v1 | 93 | 151 / 152 | Failed output validation; original raw judgment retained |
| `demo-declaration-quality` v2 | 99 | 157 / 158 | No-risk raw judgment, but invalid extra issue fields; failed task retained |
| `demo-declaration-quality` v3 (current) | 101 | 159 / 160 | Completed, `no_risk_identified`, no missing-information items |
| `demo-declaration-marketing` v2 | 94 | 153 / 154 | Completed, `risk_identified`, no missing-information items |
| `demo-declaration-incomplete` v2 | 95 | 155 / 156 | Completed, `information_required`, concrete questions retained |

The normal-use attempt exposed two coupled defects: its facts included a recipe
ID without the recipe definition, so the model treated birthDate as a full date;
and a risk plus material questions was incorrectly rejected by the validator.
Both are corrected in the current source and covered by free regressions.
The first separately authorized retest created revision 2, explaining the
necessity of all seven fields and their year-only transformation. Its real
judgment identified no risk and no missing information, but also included
unsupported issue-level empty `citation` and `passage_id` fields. Strict output
validation correctly rejected it. The prompt now supplies a concrete JSON shape
and explicitly prohibits those fields. The validator has not been relaxed:
even empty extra fields are still rejected and covered by a regression test.

After the operator explicitly authorized the necessary further retests without
an overall call-count cap, revision 3 clarified same-covered-entity internal
access and ran once with the strengthened prompt. It completed successfully.
Its four materialized citations were checked against supplied canonical passages
and full-source hashes. Neither earlier failure was rewritten or relabelled.
Marketing and incomplete cases retain their original accepted, contract-pinned
results; they were not called again. This establishes a validated current result
for each scenario, not a claim that all three were rerun on the final prompt.

Actual D2 usage across all five funded tasks is **10 requests**:
96,027 prompt tokens plus 25,480 completion tokens, **121,507 total**.
The two normal-use retests added four requests and 45,672 tokens to the original
six-request run. The three accepted reports contain **14 materialized citations**
checked against exact source offsets. Every task still requires a separate exact
two-request consent and retains that hard per-task cap; the runtime has no
automatic retry. No business delivery occurred.

The read-only `--check` command now includes all funded revision history when
summing reserved attempts, actual SDK interactions and token usage. It validates
each task's exact two-request allowance, preserves failed historical results,
and requires all three latest assessments to match the fixed expectations.
It exits successfully for the persisted results above. History beyond its
bounded acceptance window is rejected rather than silently omitted.

Use [DeclarationReviewTests](./dev/DeclarationReviewTests.cls) for free proposal
grounding, recipe provenance, three output shapes, citation rejection, budgets,
BP execution fixtures, duplicate-message handling and recovery assertions.
Framework transport fixtures are explicitly marked, transaction-rolled-back
reports; they are not application results and never call a provider. Existing
staged-review suites protect unchanged legacy and after-send behavior.
D3 browser implementation is described below. D4 execution binding remains pending.
The original free verification passed 145 Python tests and seven authorized IRIS
suites with 357 assertions (143 in the D2 suite, including inherited D1 tests).
After the retest changes, all **149 Python tests** passed, and the targeted
authorized D2 suite passed **147 assertions**, including inherited D1 tests.
The permission-limited MCP runner also passed all 15 D2 test methods.
Separate authenticated HTTP checks passed for D2 cost boundaries, D1 persistence
and the original route UI. The original two routes, two batches and two post-send
reviews are unchanged; all four Productions remain running without observer
errors. D2 acceptance does not complete the whole declaration-first workflow.

## D3 implementation and real browser acceptance

The new **Data-use declarations** workspace is available at
<http://localhost:5173/declarations>. Its
[page](../web/src/declarations-page.tsx),
[proposal form](../web/src/declaration-form.tsx) and
[typed contracts](../web/src/lib/declarations.ts) use the existing authenticated
D1/D2 APIs; no ObjectScript runtime, provider configuration, permissions or
Production hosts changed for D3. The previous fixed-route page remains at
`/governance`, labelled **Legacy routes**, with links between the two surfaces.

### Implemented journey

- New proposals start blank, with unspecified purpose/recipient and no selected
  data fields, rather than inheriting the approved QI scenario. Users enter all
  proposal fields from the catalog and free-text business context.
- Saving a draft uses the exact expected parent revision and digest. Editing
  creates an immutable new revision without inherited review or approval.
- Submission saves zero-budget intent and displays a pinned two-request plan.
  A separate initially unchecked checkbox and queue action authorize inference.
  Ordinary navigation, refresh, save, history and human decisions never fund a
  model call.
- Queued/running tasks poll stored state every four seconds. UI reads are
  cancelled when selection/session changes; the independent IRIS worker is not
  cancelled or replayed. Read failures are visible and disable mutations until
  successfully refreshed.
- Actual result labels, reasoning, material questions and source excerpts are
  displayed separately from technical failure. Citation text is checked against
  exact offsets in the supplied source, with complete-source hash provenance.
  Reports are bound to the selected task/input/prompt and source Agent revision.
  Expandable provenance preserves model sessions, index/corpus, tokens and raw
  phase output; absent usage is shown as unrecorded rather than zero.
- Human approve/return/reject requires a reason, explicit exact-revision
  confirmation and the current task hash. UI gates unreviewed, running, failed,
  risky, incomplete, old and invalid-time approvals; server checks remain
  authoritative, including current catalog hashes and concurrent edits.
- Paginated history shows each revision's own assessment, attempts and decision.
  Supported execution is distinct from approval; unsupported recipients/recipes
  remain assessable. D3 deliberately provides no activation or delivery action.

### Persisted browser walkthrough

The following proposals were entered and submitted through the form, not
inserted as test results. Their Agent outputs and decisions are persisted:

| Declaration | Revision | Interop session | Agent sessions | Actual review | Browser human decision |
|---|---|---|---|---|---|
| `demo-d3-browser-quality` | 1 | 103 | 161 / 162 | `information_required` | Returned with a reason |
| `demo-d3-browser-quality` | 2 | 105 | 163 / 164 | `no_risk_identified` | Approved with exact-version confirmation |
| `demo-d3-browser-marketing` | 1 | 107 | 165 / 166 | Failed: malformed provider JSON | Returned as technical failure, not a risk finding |
| `demo-d3-browser-marketing` | 2 | 109 | 167 / 168 | `risk_identified` | Rejected with a reason |

The quality application was initially missing purpose/recipient/handling
details. After the real information request, the browser revision supplied
internal quality activities/output, same-covered-entity recipient, seven-field
necessity, year-only transformation and access/retention/sharing limits. The
new draft had no inherited task or decision before its independently funded
review. Its approval remains `execution_state=not_connected`, ready for D4
rather than falsely claiming a batch was sent.

The first marketing provider response contained a malformed JSON trailing
fragment. The UI displayed a technical failure, null assessment and preserved
raw output, with approval disabled. A separately submitted revision received
a valid risk result. No parser repair, relaxed validator, replacement label or
automatic retry was used. The original D2 acceptance records were not changed.

All four browser tasks count toward usage, including that failed attempt:
**8 requests**, **77,709 prompt + 14,435 completion = 92,144 tokens**.
The three accepted browser reports contain **16 exact source-verified
citations**. The earlier D2 usage remains 10 requests / 121,507 tokens;
combined D2/D3 usage is **18 requests / 213,651 tokens**. Necessary retests were
explicitly authorized by the operator; every runtime task still has a hard
two-request allowance.

### Verification and remaining scope

- All **76 frontend tests** passed, including 22 new declaration-contract tests;
  TypeScript production build and ESLint passed.
- Live authenticated D1/D2 and legacy-governance HTTP checks passed, covering
  reader/write separation, cost planning, input bounds, history and stored data.
  Incorrect task hashes were rejected with HTTP 409 without changing decisions.
- The browser verified unreviewed/stale/failed approval buttons are disabled,
  unchecked cost confirmation cannot queue, human confirmation is required,
  history preserves returned/failed versions, and source excerpts expand.
- The two original routes, two batches and two after-send reviews are unchanged;
  all four Productions remain running with no observer error. No business
  delivery, Production restart, account change or demo reset occurred.

D3 is complete. D4 must bind the approved declaration to an actual bounded
batch; D5 must connect that new batch to automatic comparison. D6 remains the
full declaration/approval/send/monitor end-to-end gate.

## D4 implementation and completed real acceptance

### Exact approved execution contract

[DeclarationExecution](./src/DeclarationExecution.cls) provides per-batch
grants, independent of the legacy global utilization registration. The plan
requires the latest current submitted revision, a completed no-risk task,
immutable human approval, current catalog, valid interval and supported
four-resource/seven-field internal recipe. It pins proposal digest,
decision/task hashes, actual Production binding/configuration and a bounded
caller-chosen batch ID. A plan has `acknowledge_delivery=false` and performs
neither inference nor delivery.

Explicit confirmation atomically reserves that exact batch once. The existing
persistent `Contest.Aggregation.Request` and `SendRequest` carry the execution
grant ID/hash in `ApprovalId`/`ScopeHash`; no persistent message Storage was
changed. Dispatch uses the real `FHIRSource → UtilizationProcess →
AnalysisReceiver` BS/BP/BO in UTILIZATION.

The new [DeclarationBridge](./utilization/DeclarationBridge.cls) resolves
declaration grants rather than creating a legacy registry approval. The BO
revalidates the exact current declaration immediately before SQL insertion,
holding the shared declaration lock until the transaction finishes. A
concurrently replaced, expired or changed approval/configuration fails closed.
Projection uses the existing source-derived year-only transform and checks
actual leaf fields against the approved scope.

Declaration batches live in
`^ContestUtilization("declarationBatch",batch)`; legacy batches remain under
`("batch",batch)`. Both share batch/receiver locks and the SQL primary key.
The existing legacy observer is intentionally not fed an incompatible approval
format. D5 must discover declaration batches and supply the new after-send
adapter; D4 displays `monitoring_state=pending_d5`.

The receiver commits one SQL row and a receipt in the same transaction. The
receipt adds declaration ID/revision/digest, exact human-decision and review
hashes, recipe and execution grant. Subsequent reads verify receipt integrity,
frozen source/configuration/output, source-derived projection, actual scope,
historical validity, persisted request/send messages and their session headers,
and current SQL payload/hash readback. Uncertain results remain
`reconciliation_required` without a successful receipt or automatic replay.
An identical POST returns the same execution, not another send.

### API and browser

| Method | Path under `/api/monitor/v1` | Behavior |
|---|---|---|
| GET | `/declarations/:id/execution-plan?batch_id=...` | Writer-only exact approval/configuration plan; no send or model call |
| POST | `/declarations/execute` | Exact plan plus explicit boolean delivery confirmation; reserve/dispatch once |
| GET | `/declarations/:id/executions?before=...` | Reader-accessible paginated linked execution history |
| GET | `/declarations/executions/:run` | Verified historical batch and SQL readback |

The [execution panel](../web/src/declaration-execution-panel.tsx) is integrated
into the declaration page. It shows the fixed local destination and recipe,
requires a distinct initially unchecked delivery confirmation, and separates
execution state from AI review and human approval. Unsupported/old/unapproved
proposals cannot request a delivery plan. Errors never become a success-shaped
receipt. Navigation/sign-out aborts obsolete browser requests but cannot undo
an already accepted IRIS send; receipt history is the reconciliation surface.

### Verification

- Regression-first framework tests observed missing implementation failures.
  The authorized execution suite now passes **117 assertions**, including
  inherited D1 guards, per-batch grant/duplicate/conflict tests, expiry/catalog/
  supersession checks, and a fresh configured receiver fixture that inserts,
  reads back and **rolls back** its synthetic SQL row and batch.
- The legacy utilization suite passes **22 assertions**, and declaration-review
  tests pass **147 assertions**. Existing D1/D2/legacy HTTP checks remain passing.
- All **83 frontend tests** pass, including seven new execution-contract cases;
  production TypeScript build and ESLint pass. Compilation, reload and send are
  separate actions. The CLI defaults to no work.
- All **155 Python tests** pass, including six new execution CLI safeguards.
  The live execution API rejects reader mutations, absent CSRF header, unchecked
  delivery consent, wrong human-decision hash, malformed JSON and oversized
  commands without sending. The permission-limited MCP framework run passed
  12 execution-suite methods; the authorized 117-assertion run above covers
  persistence branches that the development account cannot exercise.
- The browser prepared `declaration-quality-d4-001` from the genuinely reviewed
  and approved `demo-d3-browser-quality` revision 2. Its delivery checkbox was
  initially unchecked and the send button disabled until confirmation.

### Initial deployment failure and authorized resolution

The first real request reserved
`declaration-run-6D69B60D-C9FE-11F1-A15D-A263F534EED8`. The BP read the four
synthetic FHIR resources and prepared their bounded projection, but the
long-lived receiver still used its old legacy batch lookup. It rejected the
new declaration batch with `Prepared utilization batch required`.
SQL readback confirmed **zero rows** for that batch; the task remains
`reconciliation_required`, with the original failure and no receipt preserved.
No replay or relabelling was performed.

The compiled source was current; a fresh configured receiver instance passed
the new path in a rolled-back framework test. The initial authorization forms
returned no concrete selection, so deployment was paused rather than assumed.
The operator then explicitly authorized removing the blocker and proceeding.
Only `UtilizationProcess` and `AnalysisReceiver` were briefly paused/resumed
using `TempStopConfigItem` and local `UpdateProduction`, with no IRIS or
whole-Production restart. UTILIZATION returned running with no pending update.

The browser then prepared a fresh batch, verified the initially unchecked
delivery confirmation, and explicitly sent it through the existing hosts:

| Evidence | Persisted value |
|---|---|
| Declaration | `demo-d3-browser-quality`, revision 2 |
| Record | `declaration-FE1ACC74-C9E2-11F1-A15D-A263F534EED8` |
| Batch | `declaration-quality-d4-002` |
| Execution | `declaration-run-C920CB44-CA0C-11F1-A15D-A263F534EED8` |
| Grant hash | `a551881170e968f0bb1ebd0237be1a1da3531cf7e0aebffc756c4ad01edfc528` |
| Outcome | `delivered`, SQL readback verified |
| Actual scope | Two Patient + two Encounter resources; seven declared fields; birth year only |
| IRIS session | 45 |
| Source / receiver message bodies | 33 / 34 |
| Headers | 45: BS→BP; 46: BP→BO; 47/48: reply path |
| Receipt hash | `da593adaa099366bc163fb4f2f376993eee0f0a1e3dfd1de68b01becff64e6b7` |

The read-only acceptance checker now exits successfully for this declaration,
including the retained first failure. Actual source/output hashes, projection,
exact human decision/review and message/session links passed verification.
The receipt was also expanded in the browser, showing the verified SQL row,
scope and exact revision linkage.

The same exact POST command was submitted twice more. Both returned the
identical execution and receipt. SQL remained **one row** for the successful
batch and session 45 remained **four headers**: no duplicate dispatch/write.
The original failed batch still has **zero SQL rows** and was not retried.
All four Productions remain running, the legacy registration pointer is
unchanged, and the original two routes/two batches/two observer reviews remain
unchanged with no observer error.

**D4 real acceptance is complete.** The new batch is explicitly
`monitoring_state=pending_d5`; delivery success does not claim that automatic
after-send AI comparison has already run.

Reproducible commands, deliberately separated:

```sh
# Compilation only; does not reload existing host jobs or send data.
python3 contest/declaration_execution_test.py --install

# ONLY after explicit operator approval: two-host local reload, no batch replay.
python3 contest/declaration_execution_test.py --reload-hosts

# After installing changed code, use the page to explicitly confirm a NEW
# batch. Never replay a preserved uncertain/failed batch without reconciliation.

# Read-only acceptance: passes for the persisted successful batch above,
# while preserving and reporting the original failed batch as well.
python3 contest/declaration_execution_test.py --check \
  --record-id declaration-FE1ACC74-C9E2-11F1-A15D-A263F534EED8
```

D4 made **zero model calls**. The prior D2/D3 results and usage remain unchanged.
D5 automatic comparison and D6 full end-to-end acceptance remain the next
implementation gates.

## D5 automatic observed-use comparison and event handling

### Runtime wiring

[DeclarationMonitor](./src/DeclarationMonitor.cls) is an independent observer
for completed declaration executions. The already running timer still starts
`RouteReview.Pump`; that fresh background job now also launches the declaration
observer. Its separate worker lock prevents concurrent scans/inference.
The legacy route observer, grants and reports remain unchanged.
No browser call to `Scan`/`Pump`, new Production host, host reload or
Production restart was needed for D5.

The observer discovers only persisted `delivered` executions. The old D4
`reconciliation_required` batch cannot be treated as a successfully observed
use. Capture reuses D4's full source/configuration/projection/message/session/
SQL verification and freezes:

- Exact declaration ID/revision/digest, review task/hash and human-decision hash.
- Execution grant, batch and original receipt hash.
- Twelve bounded facts: declared purpose, activities, output, access, retention,
  onward sharing and necessity remain **claims**; actual scoped output and
  delivery, project approval and registered synthetic relationship are verified
  **observations**; later unobserved conduct is a coverage boundary.
- An after-send question comparing the actual output/recipient with that
  specific approved use, not a universal de-identification/signature checklist.

Captured evidence has its own hash. Reads and model admission reverify that
the original receipt and underlying actual batch still match. Reports must
match the frozen input, prompt contract and source Agent, and accepted results
must match the actual stored report. The frozen historical approval is not
silently replaced with the latest declaration after later edits.

### Funding, failure and idempotence

Automatic discovery is free and creates a zero-budget `blocked_budget` record.
A writer-only read returns a two-request cost plan bound to the captured
evidence/receipt and source Agent revision/configuration. Explicit confirmation
stores one immutable grant; the independent background worker picks it up.
The browser never invokes the provider.

The worker reuses the strict `staged-risk-v4` two-phase `%AI.Agent` runtime:
no tools, no hidden iterations, at most two requests per receipt, canonical
citations and verified-observation applicability/condition grounding.
Technical failures have no substitute finding. A worker interrupted in
`running` is marked interrupted without automatic retry or allowance reset.
Identical consent returns the existing record without issuing another call.
There is no unlimited default budget for future batches.

The first development capture failed before inference because the full
proposal/receipt exceeded the existing 2,000-character **per-fact** bound.
The implementation was corrected by selecting and separating semantic facts,
not truncating text or weakening the validator. The capture failure was
preserved in audit and `capture_failures`; an explicit, free `Recapture`
revalidated the same actual batch. Only unfunded evidence failures can use
that recovery method; it cannot retry a paid failed review.

The operator explicitly allowed the requests needed to complete D5 real
validation. Only one bounded two-request grant was required and used; no
additional batch was delivered and no prior provider run was repeated.

### API and browser

| Method | Path under `/api/monitor/v1` | Behavior |
|---|---|---|
| GET | `/declarations/monitor/:run` | Verified captured evidence, actual result/report, heartbeat and event |
| GET | `/declarations/monitor/:run/plan` | Writer-only exact two-request cost plan; no inference |
| POST | `/declarations/monitor/authorize` | Explicit immutable consent; background worker executes |
| POST | `/declarations/monitor/action` | Exact event revision, allowed next state and mandatory note |

The [monitor panel](../web/src/declaration-monitor-panel.tsx) is nested under
each delivered execution in the declaration page. It polls stored state,
shows funding separately from completion, validates the receipt/declaration
links and materialized citation excerpts, and displays the actual explanation,
applicability/condition chain, model sessions and raw phase output.
Delivery APIs now return `monitoring_state=automatic_observer`; that signals
the connected observer, not a fabricated completed model assessment.

Human event actions reuse the existing event transition policy. They preserve
actor/time/notes and use optimistic event revision checks. Resolution does not
alter the immutable human approval or review result, deliver/replay data,
grant model budget or turn an unfunded/failed task into a completed review.

### Persisted real acceptance

| Evidence | Result |
|---|---|
| Batch | `declaration-quality-d4-002` |
| Approved declaration | `demo-d3-browser-quality` revision 2 |
| Execution | `declaration-run-C920CB44-CA0C-11F1-A15D-A263F534EED8` |
| Original receipt | `da593adaa099366bc163fb4f2f376993eee0f0a1e3dfd1de68b01becff64e6b7` |
| Automatic report | `risk-evaluation-D4ECCC8B-CA10-11F1-A15D-A263F534EED8` |
| Agent sessions | 169 / 170 |
| Actual model conclusion | No deviation identified on checked use; no material missing information |
| Condition chain | Applicable, met, exceptions resolved; verified observed grounding |
| Citations | Two exact source-verified quotations |
| SDK usage | 2 interactions; 13,541 prompt + 10,027 completion = **23,568 tokens** |
| Human event | Browser `open → in_review → resolved`, revision 3, two recorded notes |

The model compared the actual internal receiver, seven fields, year-only birth
dates and real delivery to the approved internal quality use. Its explanation
explicitly retains later conduct/disposal as a coverage boundary, not an
observed fact or a deviation inferred solely from missing monitoring.

Two repeated identical monitoring authorizations returned the original report
without changing the grant/report count or two-attempt usage. A stale event
revision was rejected with HTTP 409. SQL still has one successful row, and
delivery session 45 still has four headers: neither review nor event handling
caused another delivery. D2/D3 usage is unchanged; cumulative D2-D5 usage is
**20 requests / 237,219 tokens**.

### Verification

- Regression-first ObjectScript tests observed missing-class failures, then
  passed **12 authorized assertions** for packet/consent, event concurrency,
  evidence tampering, failed-evidence funding and non-executing event actions.
- Related authorized suites passed: execution **117**, legacy route observer
  **49**, V4 grounding **29** assertions; total **207** across these four suites.
- The permission-limited MCP monitor suite also passed four reported methods.
- All **160 Python tests** and **89 frontend tests** passed; production
  TypeScript build and ESLint passed. Existing bundle-size warning remains.
- Real D5 source/citation/SDK checker, D4 receipt checker, D2 boundaries and
  legacy route HTTP checks passed without further model calls.
- The browser verified initially unchecked post-send cost consent, accepted
  actual result/excerpts, and two durable human event transitions.

Read-only reproduction:

```sh
python3 contest/declaration_monitor_test.py --check \
  --run-id declaration-run-C920CB44-CA0C-11F1-A15D-A263F534EED8
```

Compilation-only installation, without funding or manual scans:

```sh
python3 contest/declaration_monitor_test.py --install
```

**D5 is complete.** D6 remains the combined end-to-end acceptance stage,
including planned negative scenarios and reproducible walkthrough checks.
No contest release, commit/push, credential change or corpus rebuild was
performed as part of D5.

## D6 unified end-to-end acceptance

### Acceptance scope and repeatable entry point

D6 validates the existing real browser/Agent/delivery evidence as a connected
journey, rather than issuing more paid calls just to recreate it. The
[unified checker](./declaration_acceptance_test.py) follows every history page
of the five D2/D3 example declarations. It includes failed funded revisions,
checks report/grant/task/decision identity, validates materialized source
quotations, and reconciles actual SDK sessions/requests/tokens.
It then follows the corrected browser proposal into the exact real execution,
receiver readback, independent automatic comparison and durable human event
resolution. Latest baseline normal/risk/missing assessments must match their
frozen expectations. Old/rejected execution-plan requests must fail.

```sh
# Repository root; existing provisioned local services and credentials required.
# GET only: no new declaration, budget grant, provider call, delivery or replay.
python3 contest/declaration_acceptance_test.py --check
```

The CLI defaults to inactive without `--check`, rejects remote API origins
before loading credentials, and fails if evidence is missing or inconsistent.
Its output is computed from live saved records, not a hardcoded success marker
or preset token total. It is specifically an acceptance of this saved
walkthrough dataset, not a fresh-install seeding tool or a new model experiment.

### Real scenario matrix and browser recheck

| Scenario | Actual persisted outcome | D6 check |
|---|---|---|
| Normal internal QI | Baseline quality v3: real no-risk result, following two retained technical failures | Actual result/report and all funded historical usage checked |
| Ambiguous proposal | Baseline incomplete v2 and browser quality v1: `information_required` | Real material questions preserved, no fabricated no-risk |
| Correction and approval | Browser quality v1 returned; v2 independently reviewed no-risk and human approved | Parent digest, changed proposal, distinct tasks and exact decision binding checked |
| External marketing | Baseline marketing v2 and browser marketing v2: `risk_identified`; browser v2 rejected | Risk result and disabled/rejected execution plan checked |
| Provider formatting failure | Browser marketing v1 failed and returned | Null business assessment retained; failed SDK calls counted |
| Real approved execution | `declaration-quality-d4-002`, session 45, four resources/seven fields, one SQL row | Verified message/session/receipt/scope lineage to browser quality v2 |
| Initial deployment failure | `declaration-quality-d4-001`, no receipt, zero SQL rows | Preserved `reconciliation_required`, never replayed |
| Automatic comparison | Agent 169/170: no deviation on checked use, two canonical citations | Same approval/task/receipt and actual accepted report checked |
| Human monitoring disposition | Browser event `open → in_review → resolved`, revision 3 | Two notes with actor/time retained; no inference or delivery action |

D6 reopened the live browser page, inspected the rejected marketing result
with delivery disabled, and inspected historical quality v1 with its actual
material questions and approval/delivery unavailable. The corrected revision,
actual receipt and resolved automatic comparison remain accessible from the
same page. D3-D5's persisted creation/modification/decision/send events supply
the actual mutation evidence; D6 did not pretend that rereading it created a
new proposal or a new model run.

### Negative cases without unsafe live sends

[DeclarationAcceptanceTests](./dev/DeclarationAcceptanceTests.cls) extends the
existing execution suite. It first requires an actual delivered declaration
batch and verifies its untouched baseline, then deep-copies its snapshot and
tests nine independent deviations. The modified copies never replace globals,
SQL rows, production settings or sent messages.

| Negative case | Tested rejection boundary |
|---|---|
| Wrong recipient | Change recipient and recompute its local config hash: approved grant configuration still rejects it |
| Excess output field | Add synthetic `Patient.name` and recompute local output hashes: frozen source-derived projection rejects it |
| Altered source value | Change a copied birth date: frozen source integrity rejects it |
| Configuration drift | Change config digest: grant/configuration match fails |
| Wrong human decision | Change receipt decision hash: exact approval binding fails |
| Wrong review task | Change receipt task hash: review binding fails |
| Wrong declaration revision | Change receipt revision: immutable-version binding fails |
| Missing/wrong message body | Change both copied receipt and record message ID: persisted message validation rejects it |
| Expired historical delivery | Set observed delivery to validity end: historical interval validation rejects it |

The inherited suite also verifies unreviewed/unapproved/risky/unsupported,
future/expired, catalog-changed, nonlatest and superseded execution denial;
initially unchecked delivery consent; wrong grant/configuration; duplicate
batch reservation and cross-declaration batch conflicts; BO revalidation and
SQL transactional readback. These framework fixtures roll back all test writes.
Existing monitor tests cover capture tampering, no funding after evidence
failure, stale event actions and separation of event resolution from model
completion. No out-of-scope data was actually delivered to demonstrate risk.

The acceptance suite passed **129 authorized assertions**, including **12**
new live-snapshot/bounded-drift assertions and **117** inherited execution
assertions. Related suites passed proposal review **147**, monitoring **12**,
legacy observer **49** and utilization **22**: **359 assertions** in the five
suites. The original delivered global and receiver output remained intact.
All **171 Python tests** passed, including eleven new D6 checker regressions
for incomplete history, duplicate/looping pagination, missing SDK usage,
unfunded findings, duplicate sessions, hidden tools and invalid citations.
All **89 frontend tests**, TypeScript production build and ESLint passed;
the existing bundle-size warning is unchanged. The permission-limited MCP
acceptance suite reported 13 passing methods; the authorized terminal run
above supplies coverage for its permission-gated persistence/drift branches.
Final checks found all four Productions running, no observer error, exactly two
declaration executions (one retained failure, one delivered) and one completed
monitor, with no test fixtures left behind. The successful batch still has one
SQL row and four message headers; the failed batch still has zero SQL rows.
The legacy registration and original two routes/batches/reviews are unchanged.

### Historical cost and failure accounting

The GET-only checker produced:

| Metric | Measured value |
|---|---|
| Funded two-phase reports | 10 |
| Actual SDK interactions | 20, with 20 distinct Agent sessions |
| Prompt tokens | 187,277 |
| Completion tokens | 49,942 |
| Total tokens | **237,219** |
| Technical failure reports | **3**, counted separately, not accepted as business findings |
| Accepted-report exact verified citations | **32** |
| New model requests / deliveries during D6 | **0 / 0** |

This scope is all funded revisions of the five D2/D3 examples plus their linked
D5 comparison. It deliberately does not claim to be total project lifetime
usage or imply that tokens have a known currency price. D4 dispatch itself
made no model calls. Failed attempts were neither omitted nor refunded.

### Completion and boundaries

**D1-D6 are complete for the bounded synthetic application.** A user-created
proposal now has its own review, correction/history, human approval, explicit
supported execution, automatic observed-use comparison and event disposition.
The original fixed-route baseline is not being substituted for that journey.

Remaining boundaries are intentional, not hidden completed capabilities:

- Execution supports the registered internal four-resource/seven-field
  year/encounter recipe only. Other declared purposes/recipients are assessable,
  but arbitrary external destinations/projections/pipeline generation are not
  connected.
- Actual observations cover configuration, bounded output, messages and SQL
  persistence, not future recipient behavior, use purpose in practice or
  retention/deletion. The model keeps those as coverage boundaries.
- New model work still requires a distinct bounded grant. Failed/interrupted
  work and uncertain deliveries do not automatically replay.
- The existing demo uses separate read and builder capabilities, not an
  enforced organizational separation between applicant and approver identities.
- This gate validates a working local environment and saved walkthrough. A
  clean-environment installation acceptance and contest packaging/publication
  remain separate tasks, not work performed by this D6 checker.

No contest release preparation, commit/push, account changes, Production
restart, demo reset or corpus rebuild was performed for D6.
