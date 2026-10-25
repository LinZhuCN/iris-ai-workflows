# IRIS Workflows local demonstration UI

[English](README.md) | [简体中文](README.zh-CN.md)

For the main live presentation, see the
[M5 onboarding walkthrough](../contest/M5-ONBOARDING-DEMO.md):
enter institutions, enroll the Production, send new synthetic data and authorize
its audit. The [historical saved-result walkthrough](../contest/DEMO-WALKTHROUGH.md)
is a separate read-only reference, not the main onboarding sequence.

React + TypeScript + shadcn/ui + Tailwind CSS, adapted from
[Sat Naing's Shadcn Admin](https://github.com/satnaing/shadcn-admin).
Upstream commit: `e16c87f213a5ba5e45964e9b67c792105ec74d26`
(package version 2.2.1). The sidebar, selected UI primitives, mobile hook and
theme tokens originate from that MIT-licensed project. Its notice is preserved
in [LICENSE.shadcn-admin](./LICENSE.shadcn-admin). Application pages, navigation
and preview interactions are project-specific. Unneeded upstream features,
Clerk authentication and telemetry are not included.

## Scope

### Fixed M5 onboarding

Open **M5 onboarding** (`/demo/m5`) from the sidebar, `/demo` or Productions.
The existing distribution demo remains at `/demo`. The fixed onboarding route
is limited to `M5OBSERVATION / Contest.M5.Production`:

1. Enter and save the source hospital and research recipient profiles.
   **Fill example** changes an editable draft only. These versioned profiles are
   M5-only and never read or write the shared Organizations catalog.
2. Explicitly enroll the fixed Production, then separately authorize local
   synthetic inspection for its current configuration.
3. Send the fixed synthetic research flow. A stable run ID prevents repeated
   submission in the current workspace; interrupted sends are not auto-retried.
   The run freezes both confirmed profiles.
4. Wait for stored collector evidence with capture state `captured`, select a published eligible Agent revision and explicitly
   acknowledge model charges before authorizing **1 review / 2 requests**.
   The server uses the frozen profiles without retyping business premises.
5. Read Result / Why / Next alongside the saved AI log. Status polling is
   read-only; pending, missing and failed evidence never imply a no-risk result.
   The adjacent **AI log** button remains usable without authorizing inference.

Only model-cost consent uses a checkbox. Consent is scoped to the run,
Production configuration, Agent revision/configuration and review contract;
changing these identities or resetting the demo does not carry consent forward.
No audit starts automatically and the page never purchases a model retry.
If the submission result is uncertain, **Reconcile exact audit submission**
explicitly resubmits the original single-use authorization ID, pinned Agent
revision, hashes and cost acknowledgment; it does not generate a new ID or budget.
Saved pre-grant authorization prevents purchasing another consent even when a
grant response was lost. A deduplicated session/body review shows its
representative header separately from the target delivery header.
The receiver header and receipt are delivery references, not proof of collected
monitoring evidence. Current results separately display the collector capture
state, observed source/target/session and stored minimized fields/date precision.
Audit authorization stays disabled until the collector reports `captured`.
Reset requires typing `RESET M5 DEMO`: it archives M5-scoped records and clears
only the demo's logical enrollment, profiles and runs. Physical IRIS messages
and saved risk reports remain retained; other Productions and shared profiles
are untouched. Reset is not physical deletion.

### Saved AI execution logs

Every model-execution action has an adjacent **AI log** button: Agent generation,
test/retest, monitoring summary, independent event investigation, declaration
review, post-send comparison, Production review authorization and the
multi-organization audit. Opening it only reads saved records; it never starts,
retries or authorizes inference, sends business data or incurs a model charge.
The log remains usable when the execution action is disabled.

Phased audits show the preserved LLM responses, model, timestamps, AI Hub
sessions, usage and recorded errors. Request input and system prompts are
expandable. A three-recipient audit displays all three reports, including failed
phases. Production authorization logs collect reports for that exact grant.
Legacy executions expose their original saved record; when only a validated
result was stored, it is not presented as the original provider response.
Missing execution identity or output is reported explicitly, never inferred
from a session ID or a reserved request. SDK usage is not a provider invoice.
After reopening a page, generation logs use an explicit saved job-ID selector;
other legacy logs match persisted configuration/snapshot/event/Agent identities.
Historical investigation facts are labelled as captured facts, not asserted to
match an event's current revision.

This is a bounded local demonstration, not a production monitoring console.
**Knowledge uses a real authenticated
IRIS API** for local CPU embedding status, evidence retrieval and persistent
shadow-index builds. See [setup, credentials and security boundaries](../contest/KNOWLEDGE.md).
No paid model or business Production is called by this page.

**Productions** (`/pipelines`) is the multi-Production monitoring workspace:
discover active Productions in accessible local IRIS namespaces, explicitly
enroll a selected Production/configuration, then inspect its isolated events,
linked risk-review history and observation coverage. Enrollment covers all
current component activity, without manual per-flow registration. It does not
edit business hosts or grant payload/model access. M2 records actual edges and
session-linked evidence in the backend; separately authorized local inspection
supports registered FHIR/JSON message properties, without raw message values
in its observations. M3 adds separately funded sampled AI Hub review in the
backend; saved assessments appear in this page's existing risk feed and link
to their Production event for human review. Enrollment and browser refresh
grant no budget or inference. M4 adds actual message edges, session-filtered
immutable evidence, Production-wide capture/review dispositions and worker
health. Review details bind each report to its observation and show validated
question-specific citations, complete dated source text, missing-information
questions, SDK sessions and usage. These are scoped assessments, not compliance
certification. Builder-only controls separately authorize/revoke local synthetic
inspection and bounded AI funding. Funding requires an explicit pinned-command
preview and final paid confirmation; retries retain the same immutable budget.
Optional advanced semantic-context editing never gates Production observation
and does not itself authorize inspection, inference or replay. Reader accounts
can inspect evidence but cannot change authorizations/context.
M5's registered synthetic intake additionally shows verified local SQL intake,
its actual receiver/batch, frozen business policy and message/session/digest
bindings separately from the scoped AI assessment. The saved M5 Production
demonstrates normal, local-minimization-deviation, unknown-business-context and
newly observed activity-path cases; its model authorization is revoked.
This adapter-specific evidence is not an automatic legal conclusion for every
Production or proof of later recipient conduct.
The demo does not require a connection to real hospital systems. In **AI review
approval, demo business premises and bounded funding**, the approver can enter
recipient/relationship, actual intended purpose, relied-upon permission,
authorization status and scope, safeguards and special conditions/exceptions.
Also explain which technical hosts represent the business recipient, and
whether the session messages concern the same synthetic patient/activity and
data scope. These mappings are explicit user premises, not inferred identities.
Use **Use session … for demo approval** on a captured observation to select
the source session. Preparing approval establishes these inputs as synthetic
scenario premises; inspect the exact consent before separately confirming paid review.
That explicit action establishes the supplied facts **within the simulation**, not an
independently verified real-world situation or a predefined legal verdict.
Unknown answers remain unknown; absence and non-reliance are distinct choices.
Other sessions are still observed but use no budget under this scoped grant.
Completed/failed/skipped terminal reviews are not reassessed automatically.
The server freezes the inputs with the authenticated approver/time and exact
Production/configuration/Agent contract. Authorization history and review
details show those inputs separately from observed message facts. Editing any
premise requires preparing a new approval; prepared inputs are locked until discarded.

Ordinary profile/context saves, local inspection, monitoring enrollment and
revocation use explicit buttons without redundant confirmation checkboxes.
The multi-organization demo uses **Save for demo**, **Prepare demo data**,
**Run distribution**, and **Run AI audit**; only model spending retains a cost
checkbox. Scope options (such as including unreviewed stored captures) remain
available. Tested Agent publication and intent binding likewise use direct
buttons, retaining their server-side test, revision and permission checks.
Local knowledge-index builds and registry-only approvals also use direct
buttons. Consequential approvals for actual delivery/configuration changes
retain their exact-plan confirmations.
The shared legal reviewer also has a separate eight-case prospective Privacy
Rule benchmark on stipulated facts. That small assistant-authored benchmark
is not independent legal validation or certification of a real deployment.
Live Production acceptance passed the three demo outcome categories after an
explicit mapping-input repair: treatment header **30** (no scoped signal),
marketing header **22** (risk), and unknown header **26** (information required)
in **M5OBSERVATION / Contest.M5.Production**. The original treatment header
**18** remains unresolved and visible; it is not overwritten or counted as a
first-pass success. Inspect the four records to see approvals, source quotes,
material questions and actual SDK usage. All associated grants are revoked.
See [Production monitoring and acceptance](../contest/MONITORING.md#managed-active-productions).

Instances and Synthetic demo retain the real, pre-registered DEMO
Connector, discovery snapshots, exact-plan approval, probe verification and
durable observations. See [P2 setup and acceptance](../contest/MONITORING.md).
The legacy Synthetic demo page also supports an opt-in actual AI Hub Agent summary, with snapshot
binding, limitations and SDK model/session/usage provenance. Generating one
requires explicit cost acknowledgment; ordinary page refreshes do not call a model.
Agents now uses the [real bounded privacy Agent factory](../contest/AGENT-FACTORY.md):
configuration generation, pinned-evidence tests, immutable publication and
recorded intent bindings. Automatic observation review is not connected.
Overview, Events and Runs now use real persistent observations, coverage gaps,
events and human actions. Selected automatic reviews remain `blocked_budget`;
the automatic model budget is zero. A manual investigation requires separate
explicit cost confirmation; one real investigation has now completed.
The Events-page independent investigation supports only schema-2 synthetic
`analytics` observations. A destination `failure` event is not eligible for
this privacy template even if a published Agent is selected. The page displays
the blocking reason beside the disabled button and disables spending consent
for unsupported events; checking a cost box does not expand reviewer scope.
Runs also shows separately authorized twelve-case privacy evaluations:
original 9/12, corrected `privacy-review-v2` draft 12/12 on the same manifest,
model and knowledge index. Original failures are retained. Reports distinguish
prompt version/hash and the deterministic `no_finding` acceptance guard.
Agents can clone the legacy published version into an idempotent v2 draft
without inference. V2 publication requires a matching complete twelve-case
report and explicit confirmation; legacy three-case tests cannot bypass it.
The verified v2 candidate remains unpublished and unbound.
These are **mechanism regressions**, not validation that the Agent identifies
HIPAA risks from business context. Runs now labels that distinction explicitly.
The separate [business-context benchmark](../contest/MONITORING.md#business-context-hipaa-risk-benchmark)
has prepared facts, clause-linked author oracles and offline evidence checks.
Runs also reads `/business-evaluations`, separately displaying the independent
contextual AI Hub runtime's actual fact packets, searches, evidence and outputs.
Contract validity never becomes a legal pass; recommendations are not executed.
The first batch completed but did not pass acceptance: 9/12 valid output
contracts, 3/12 aligned with all author-oracle machine checks. Runs separates
these counts, shows unmet checks and preserves rejected raw output. Exact
regulation-locator coverage can reject relevant HHS guidance; the machine
alignment count is not legal accuracy. Human applicability review remains pending.
The decoder also recognizes opt-in `hipaa-business-runtime-v2`, retaining its
original proposal, evidence passages and server-materialized citations in case
details. One authorized v2 model retest is now displayed: 12/12 valid contracts
and 8/12 full author-machine alignment (10/12 expected assessment labels).
Human applicability review is still pending; the remaining differences are
preserved, not converted into an overall HIPAA pass.
Opt-in `hipaa-business-runtime-v3` has a separate claim-warning and
condition-state display, with versioned local action-policy conformance
separate from exact author-action matching. It retains the original proposal,
canonical tool responses and the actual compact `model_response`.
Runs now also displays the authorized real v3 batch: 6/12 accepted contracts,
1/12 full author-machine alignment, six failed cases with preserved evidence.
The claim/condition separation is visible for `business-08`, but v3 regressed
overall and is not promoted. All historical reports remain unchanged.
The decoder also recognizes opt-in `hipaa-business-runtime-v4`, retaining the
same claim/condition/action display. Its details include server-prefilled
`model_input`, component retrieval audits and the single-use parent evidence
tool's actual `model_response`. Components are not additional SDK tool calls.
Runs now retains the real v4 failure report: 0/12 accepted outputs, eleven
tool-argument-boundary failures and one condition/aggregate contradiction.
The failed tool plans and error responses also remain in SDK session history.
No inference is made that this integration failure measures legal accuracy.
Rules uses real manual AST drafts, deterministic golden tests, hash-bound
approval, fixed DEMO activation, source receipt verification and approved
rollback. See [event/rule operation](../contest/MONITORING.md#events-and-human-review-p5).
Only Settings remains a labelled synthetic preview.

### Data-use declarations (D3)

Open <http://localhost:5173/declarations> or choose **Data-use declarations** in
the sidebar. This is the new application workflow, separate from the fixed-route
baseline below. It uses the real [D1/D2 APIs](../contest/DECLARATION-WORKFLOW-PLAN.md).

1. Sign in once with an existing account at the workspace entrance. All pages
   share that sign-in during in-app navigation; credentials stay in React memory
   and are cleared on global sign-out or a full refresh, not on page changes.
   Local development demos can prefill the ignored environment credentials
   described below; credentials are never stored in browser storage.
   Readers can inspect records. Builder permission is required for mutations.
2. Choose **New declaration**. Enter your own purpose, activities, output,
   recipient, resources/fields, necessity, handling, arrangements and validity.
   Nothing automatically selects an approved QI scenario. Registered recipient
   relationships and processing capabilities are shown separately.
3. **Save draft revision** persists an immutable proposal without a model call.
   Edits use exact parent revision/digest pins and cannot reuse an assessment.
4. **Submit for AI review** records review intent and displays the exact
   two-request cost plan. It does not itself call a model. Only checking the
   initially empty authorization checkbox and choosing **Authorize and queue
   review** funds the task. No automatic retry or business delivery is included.
5. Stored queued/running task state refreshes every four seconds. This is
   read-only polling; the IRIS worker continues if the browser is closed.
   Technical failure remains distinct from risk/no-risk/information-required.
6. Inspect proposal-specific reasoning, material questions and expandable source
   excerpts. The decoder binds the report to the exact task, source Agent,
   input and prompt contract, and checks cited quotes against pinned sources.
   Expand provenance for actual Agent sessions, knowledge index, tokens and raw
   phase output. Missing usage is labelled unrecorded, never fabricated as zero.
7. A human can **Return for changes**, **Reject revision**, or approve only a
   completed no-risk, current, valid submitted revision. Every decision requires
   a reason and explicit exact-revision confirmation; the server rechecks all
   permissions, catalog/validity and task hashes. A positive AI result alone
   never becomes approval. Inspect prior revisions through paginated history.
8. D4 adds **Run an approved synthetic batch** below the exact revision.
   Choose a new batch ID, prepare the delivery plan and confirm the initially
   unchecked delivery authorization. The plan binds the declaration, task,
   human decision and UTILIZATION configuration. It sends only the existing
   four-resource/seven-field year-only recipe to the registered internal SQL
   receiver; no model call or global route switch is included. Unsupported,
   old, invalid-time and unapproved revisions cannot run.
9. Inspect linked execution history and expandable SQL readback receipts.
   Identical submissions return the same execution; an uncertain/failed task
   is never automatically replayed. A lost HTTP response requires reading the
   same batch history, not choosing another ID to force a retry.
   The receipt includes exact declaration/decision/review hashes, source/output
   digests and real BS/BP/BO message/session linkage. Post-send comparison is
   separate from delivery success. See the automatic comparison controls below.

**D4 live acceptance passed:** after the explicitly authorized local reload of
`UtilizationProcess` and `AnalysisReceiver`, the browser confirmed the new
`declaration-quality-d4-002` batch for `demo-d3-browser-quality` revision 2.
It delivered four resources with seven projected fields; SQL readback and the
exact declaration/review/decision links passed. Its IRIS session is 45, with
source body 33 and receiver body 34. Two identical command submissions returned
the same execution/receipt, leaving one SQL row and four session headers.
The earlier `declaration-quality-d4-001` remains `reconciliation_required`
with zero SQL rows; it was not replayed or relabelled. No whole-Production or
IRIS restart, global registration change or model call occurred.
Automatic post-send comparison is now connected as D5 below.

### Automatic declaration batch comparison (D5)

Each delivered execution displays its own **Automatic post-send comparison**.
The existing Production timer starts an independent, single-worker observer:
the browser neither scans batches nor starts the model runtime. It discovers
delivered declaration executions only, verifies the historical source,
projection, messages and SQL receipt, and freezes a comparison packet bound
to the exact declaration/review/human decision.

Automatic capture does **not** automatically authorize model charges. A new
batch initially shows `blocked_budget` and zero attempts. A writer can prepare
the exact receipt/evidence/Agent/prompt cost plan and separately confirm at most
two requests. The background worker then performs the real two-phase AI Hub
review. Repeated scans, refreshes and identical authorization requests never
add inference; failed/interrupted model work is not automatically retried.

The page distinguishes observed-use risks, material questions, no deviation on
checked use, and technical failure. Expand citations and raw phase provenance;
the explanation and applicability/condition chain come from the actual accepted
report. Requested purpose/safeguards remain claims, while observed delivery,
actual output, project approval and registered synthetic relationship have
explicit provenance. The page does not claim to observe later purpose,
onward use or deletion merely because a field projection matched.

Record a note and move the event through `open → in_review → resolved`, or
request information/ignore/reopen as allowed by the existing event state
machine. Event actions bind the exact event revision and preserve actor/time
history. They cannot change the declaration approval, re-send data, retry a
model or label an unfunded/failed review as completed.

Real acceptance on `declaration-quality-d4-002` completed with Agent sessions
169/170: **no deviation identified on checked use**, no material gaps,
two source-verified citations. The browser moved the event to `resolved` v3
with two notes. Only **2 requests / 23,568 tokens** were needed. SQL remains
one row, session 45 remains four headers, and the old failed batch is unchanged.
An initial free capture failed the fact-length contract; its error is retained
in `capture_failures` and audit, and was explicitly recaptured after splitting
the proposal into bounded semantic facts. No model failure was relabelled.

### Reproduce the completed walkthrough (D6)

No new model request or data delivery is necessary to inspect the demonstrated
chain. Open **Data-use declarations**, connect with a provisioned local account,
and inspect:

1. `demo-d3-browser-quality` revision 1: actual information request, material
   questions and human return. Historical approval/delivery is unavailable.
2. The same declaration revision 2: corrected proposal, independent no-risk
   review, exact human approval. Changes did not inherit the old task/decision.
3. Its `declaration-quality-d4-002` execution: expand the verified SQL receipt,
   four-resource/seven-field scope, hashes and real Interoperability session 45.
4. Its automatic after-send comparison: actual Agent sessions 169/170, cited
   reasoning/condition chain, and resolved event v3 with two human notes.
5. `demo-d3-browser-marketing` revision 2: real risk finding, rejected decision
   and disabled delivery. Revision 1 preserves the malformed-output technical
   failure as failure, not a risk verdict.

The full [D6 acceptance checker](../contest/declaration_acceptance_test.py)
walks every revision of the five D2/D3 examples, validates each real report and
canonical citation, links delivery/monitoring back to the corrected approval,
and reconciles all measured SDK usage including failures:

```sh
python3 contest/declaration_acceptance_test.py --check
```

Use the repository root and the already provisioned local services. This is
GET-only, creates no records, and does not fund, submit, deliver, reset or replay.
Expected persisted usage: **20 requests / 237,219 tokens**, including three
technical failure reports; **32 verified citations** across accepted reports.
That is this declaration-workflow evidence set, not total project lifetime usage.
Browser rereads and nine controlled historical drift tests passed in D6.
Remaining scope limits and the full negative-case matrix are in the
[workflow plan](../contest/DECLARATION-WORKFLOW-PLAN.md#d6-unified-end-to-end-acceptance).

Request failures are displayed without preview fallbacks. Unmounting cancels UI
requests, not the IRIS worker. Selection changes abort obsolete reads; failed
reads disable mutations until refreshed. Refresh/sign-in never authorize a model.
The existing `/governance` page remains available as **Legacy routes**.

**Route governance** at `/governance` now uses real P1–P4 records for the separate
SQL/FHIR aggregation and FHIR/utilization routes, not the older DEMO Connector.
It displays declaration, approval and actual observation in three columns.
Register a utilization purpose/owner and explicit validity, inspect the immutable
version/digest, then click **Approve exact revision · registry only**. The service
identity, recipient, cohort and seven-field/four-resource recipe are fixed and
visible, not arbitrary executable settings. New versions do not inherit approval.
There is no activation or send button; approvals do not change the active
utilization registration pointer.

Load the original saved P2/P3 receipt JSON locally, or enter its batch ID and
independently saved digest, to revalidate historical evidence. Only record ID,
batch ID and receipt digest are sent, not the receipt file or patient rows.
Actual counts, configured destination, message/session linkage, current
applicability and six source-referenced facts are displayed. Evidence cannot be
attached to another declaration revision. Historical applicability, current
admission and legal authorization are explicitly distinct.
See [route UI setup and walkthrough](../contest/MONITORING.md#route-governance-p5-live-onboarding-and-three-column-evidence).

This page uses the shared workspace sign-in, with no page-specific login or
page-specific credentials. Use an existing account with the required
cross-namespace access for the complete walkthrough. Reader accounts
can list registry records but cannot register/approve; existing database access
is still necessary for templates/evidence. The API adds no roles, permissions,
namespace mappings or credentials. Credentials stay in memory, and the UI never
calls a model on this page.

P6 adds an **automatic background sidecar** panel on the same page. The existing
IRIS monitoring timer discovers completed P2/P3 batches without a browser or
manual review-start action. It validates minimized evidence and records budget
gaps or technical failures explicitly. Only the two original, separately
authorized batches have inference grants (two `%AI.Agent` phases per batch,
four requests total); new batches are automatically observed but budget blocked.
Inspecting results and recording version-checked human event transitions never
calls a model, sends data or changes approval. This route event stream is
separate from older DEMO Operations.
See [automatic route monitoring](../contest/MONITORING.md#route-monitoring-p6-automatic-after-send-ai-hub-review)
for configuration, original versus first-observer receipt pins, no-replay
policy, service reload and deployment limitations.

The [current internal hospital demo](../contest/ROUTE-DEMO.md) replaces old route
trial records. Its approval panel shows the explicit synthetic organization
policy and permitted internal purpose. Review inspection separates policy and
approval, observed delivery, monitoring coverage and the scoped AI comparison.
The two paths do not rely on de-identification or individual patient signatures;
stable identifiers are not automatically a finding. Purpose contradictions,
excess data and recipient deviations remain relevant. A scoped no-finding is
not a legal certification or proof of all later recipient conduct.

Live event actions/opinions persist in IRIS; signing out clears in-memory
authentication, not saved evidence. Theme preference is local to the browser. Configuration previews are
fixed illustrations on the remaining preview pages, not LLM-generated results.
The API client rejects non-JSON/network errors and never falls back to fixtures.

## Run with Node

Use Node 22.12+ (tested with 22.23.3):

```sh
cd web
npm ci --legacy-peer-deps
npm run dev -- --host 127.0.0.1
```

Open <http://127.0.0.1:5173>. The lockfile was generated with npm's legacy peer
resolver after npm 10's default resolver failed with `edgesOut`; use the same
flag when restoring this lockfile.

For host Node, start with
`PLATFORM_API_TARGET=http://127.0.0.1:52779 npm run dev -- --host 127.0.0.1`.
Docker Node defaults to `http://host.docker.internal:52779`. Both proxies forward
only the monitoring API paths and use caller-supplied, in-memory credentials.

### Shared workspace sign-in

The application has one login entrance for all pages, including direct links.
After sign-in, sidebar navigation and browser back/forward keep the same
in-memory identity across Overview, Instances, Pipelines, Declarations, Legacy
routes, Events, Rules, Agents, Knowledge and Runs. Each page loads its own
records automatically; page-specific Connect/Sign out forms have been removed.
The sidebar and header show the authenticated account instead of a mock user.

The header **Sign out** clears the shared identity, unmounts authenticated
pages/confirmations and aborts in-flight requests for that identity. An HTTP 401
also returns the entire workspace to sign-in; HTTP 403 remains an explicit
page-level permission error and does not erase a valid session. Authentication
still uses the existing IRIS API and its server-side reader/builder checks;
there is no role change or auto-authorization of model calls or deliveries.

Credentials/Basic authorization stay only in memory, not cookies, URL,
localStorage or sessionStorage. Full browser refresh, a new tab or reopening
the app requires sign-in again; this is shared SPA authentication, not
cross-application SSO or a persistent server session. The old
`VITE_DEMO_USERNAME`/`VITE_DEMO_PASSWORD` settings in ignored `web/.env.local`
can prefill the shared login in Vite development mode on localhost only.
The local demo uses these existing settings: opening or signing out returns
to a prefilled form, but still requires clicking **Sign in**. Invalid credentials
clear the password instead of automatically retrying. No password is hardcoded
in source and no prefill is enabled in production or on a remote hostname.
Vite environment values are visible to the browser, not a secret store; use
only disposable local demo credentials and remove them before distributing
a build. Keep the HTTP demo on localhost;
use HTTPS and an appropriate session mechanism before remote deployment.

## Run without host Node

From the repository root, install declared dependencies in an isolated Node
container, then start the loopback-only preview:

```sh
docker run --rm -v "$PWD/web:/app" -w /app node:22-alpine \
  npm ci --legacy-peer-deps --no-audit --no-fund
docker compose -f web/compose.yaml up -d
```

This does not start or reconfigure IRIS. macOS bind mounts use polling for
development updates. Stop only this preview with:

```sh
docker compose -f web/compose.yaml down
```

Do not share one `node_modules` between host macOS and Linux containers: install
using the environment that will run the build. The lockfile is committed;
dependencies, build output and test artifacts are ignored.

## Validation

```sh
cd web
npm run build
npm test
npm run lint
```

Or run these inside the same Node container. Tests cover version activation,
publication invalidation and real API failure semantics. Browser checks cover
navigation, real event detail/opinions, Agent steps, live Rules, responsive
sidebar and theme persistence. Knowledge HTTP integration is independently
checked by `python3 contest/platform_test.py`; browser checks cover real
sign-in/retrieval, wrong passwords, reader restrictions and sign-out.
P2 HTTP acceptance is `python3 contest/monitor_test.py`. It sends synthetic
messages, injects concurrent duplicate observations, briefly pauses the demo
receiver and restores a temporary demo-only configuration drift in `finally`.
That command does not invoke the summary model.
Agent HTTP boundaries and saved report provenance are checked by
`python3 contest/agent_test.py`; it does not invoke a model either.
`python3 contest/event_test.py` verifies actual schema-2 events, concurrent
revision conflicts and human actions without inference.
`python3 contest/rule_test.py` requires a non-enforcing DEMO baseline, sends new
synthetic messages, activates the reviewed hold rule and restores the prior
non-enforcing policy through a separately approved rollback. It also checks
source preparation/hash/revision guards and does not replay held messages.
`python3 contest/privacy_evaluation_test.py` checks evaluation authentication,
cost and JSON boundaries without inference. Adding `--run` is a separately
authorized paid operation, not a routine regression command.
