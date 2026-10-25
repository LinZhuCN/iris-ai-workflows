# AI Hub message triage (isolated EAP demo)

[English](README.md) | [简体中文](README.zh-CN.md)

This fork adds a runtime AI Hub decision to an IRIS Interoperability Production.
The inherited application stack has been removed from this fork's current tree;
the root Compose entry now includes this isolated deployment. The upstream
repository and other local projects are not modified.

**Live onboarding demo:** use the fixed
[M5 onboarding instructions](./M5-ONBOARDING-DEMO.md) or
[Chinese version](./M5-ONBOARDING-DEMO.zh-CN.md), starting at
<http://localhost:5173/demo/m5>. Enter institution profiles, enroll the existing
M5 Production, trigger a new message and authorize its real audit. The scoped
reset archives M5 logical state without purging original messages/model reports
or changing other demos.

**Historical saved-results walkthrough:** follow the
[fixed Production walkthrough and five-minute English recording script](./DEMO-WALKTHROUGH.md).
For Chinese step-by-step operations, system URLs and presentation highlights,
see the [Chinese demonstration guide](./DEMO-GUIDE.zh-CN.md).
It inspects saved real treatment/risk/unknown results without new model calls,
explains user-entered demo premises and preserves the first-pass repair history.
It is not a claim that a video has already been recorded or published.

For the new declaration-first workflow, see the
[design, D1 implementation and development sequence](./DECLARATION-WORKFLOW-PLAN.md).
D1 provides versioned proposal persistence and review/decision contracts.
D2 adds real asynchronous AI Hub proposal review. All three acceptance scenarios
now have validated real results: internal quality improvement/no risk identified,
external marketing/risk identified, and unspecified secondary use/information
required. The normal-use case passed on revision 3 after two retained failures.
The [D3 browser workspace](http://localhost:5173/declarations) now supports new
proposals, explicit AI review funding, results/evidence, revision history and
human return/reject/approve decisions. D4 now adds exact-batch execution plans,
approval/configuration checks, receiver revalidation and linked SQL readback
receipts. After the authorized local two-host reload, a new browser-confirmed
batch completed real BS/BP/BO delivery and SQL readback. Repeating its exact
command twice returned the same receipt without another row or message.
The first failed batch remains preserved with zero SQL rows.
D5 now automatically captures delivered declaration batches and compares actual
use with their exact approved revision after separate bounded model consent.
The real D4 batch passed its after-send comparison and browser human event
review; later recipient conduct remains outside observed coverage.
The legacy fixed-route page remains separate.

**D1-D6 declaration workflow acceptance is complete.** Recheck the saved real
normal/risk/missing-input results, corrected-version approval, actual delivery,
automatic comparison, human resolution and historical SDK usage without
another model request or delivery:

```sh
python3 contest/declaration_acceptance_test.py --check
```

Run that command from the repository root against the existing local demo.
It requires the provisioned local API and admin credential file, and is
intentionally fail-closed if the walkthrough evidence is absent or changed.
See the [browser walkthrough and negative-case matrix](./DECLARATION-WORKFLOW-PLAN.md#d6-unified-end-to-end-acceptance).
This completes the bounded application workflow, not arbitrary recipient or
pipeline support; contest release preparation remains separate.
The **[Productions workspace](http://localhost:5173/pipelines)** now additionally
discovers active local IRIS Productions and lets a user explicitly enroll each
as an independent observed object. It provides per-Production operational
events, review notes, pause/resume and linked existing business-risk history.
Generic observation defaults to metadata and makes coverage gaps explicit;
M2 additionally supports separately authorized local inspection of registered
FHIR/JSON message properties. Neither path infers HIPAA findings by itself.
See [setup, source attribution, API and actual two-Production acceptance](./MONITORING.md#managed-active-productions).
Reusable business-risk monitoring for newly added pipelines is a separate
M1-M5 extension, not a capability implied by operational enrollment.
**Production is the only enrollment unit**: users discover running Productions
and choose which to manage, without registering individual business flows.
The earlier M1 manual-flow registry is retained only as optional versioned
review context; it must not filter or gate collection. M2 now records actual
message edges, session-linked immutable observations and consented local
structured-property facts without per-route registration. An independent
three-route synthetic Production passed real five-batch evidence acceptance.
M3 now adds separately funded, Production-scoped sampling and two-phase AI Hub
review with normative sources, validated citations, durable request budgets and
explicit information gaps/failures. Three saved A/B/C observations completed
real review without manual contexts or new business sends: six requests,
68,373 reported tokens and eleven verified citations. All correctly requested
missing business context rather than claiming a violation or compliance.
That acceptance grant is revoked. Saved results also appear in the existing
Production risk feed. M4 now exposes actual message edges, session-filtered
evidence, capture/review coverage, exact-source review details and independent
inspection/model authorization controls in the Production workspace. Optional
semantic context remains enrichment, never a flow-enrollment prerequisite.
No new model budget or business delivery was used for M4 verification.
M5's technical/local-rule test passed on a separate registered synthetic-intake adapter: four
actual A/B/C/D intakes, automatic discovery of D's first activity, two scoped
no-deviation results, one explicit local minimization risk and one
missing-business-information result. Message/session/configuration and SQL
receipt hashes bind the evidence; no manual flow context is required.
The four real reviews used eight requests / 98,219 reported tokens / eleven
validated citations, and the model grant is revoked. This validates the
supported intake contract only. **M5's scoped demo acceptance is now complete,
after an explicitly recorded input-mapping repair**, not a claim of
real-world compliance certification.
It is not evidence of reliable HIPAA assessment merely because local rules and
exact quotations were checked. A separate prospective eight-case Privacy Rule
condition benchmark now passes all predeclared automated checks (16 requests,
158,476 reported tokens, 31 exact citations), including treatment exceptions,
psychotherapy-note authorization, paid marketing, own quality operations and
Safe Harbor ZIP thresholds. It tests stipulated facts, uses an assistant-authored
oracle without independent expert validation, and does not establish real-world
fact coverage. Real-system integration is **not a prerequisite for this demo**:
the Production approval UI now accepts session-scoped user-confirmed recipient,
purpose, permission/authorization, safeguards and exceptions. These are usable
simulation premises, frozen with server-side approver/time and displayed
separately from collected message evidence; explicit unknowns remain unknown.
No per-flow enrollment or real hospital/contract-system connection is needed.
Live Production acceptance now covers treatment disclosure (no scoped signal),
paid marketing with affirmatively absent authorization (risk), and unknown
recipient/permission (information required). The first pass was **2/3**:
treatment correctly asked how technical hosts and message data mapped to its
business scenario. Two explicit form inputs now capture that mapping and data
scope. One separately authorized new treatment message passed the unchanged
oracle; the original unresolved report remains preserved. Total including
that first attempt: **4 synthetic sends, 8 requests, 116,871 reported tokens,
15 exact citations**. All four model grants are revoked. Read both original
and follow-up reports without inference using:

```sh
python3 contest/production_premises_test.py --check-complete
```

See the
[implementation status and contract boundaries](./MONITORING.md#business-flow-risk-monitoring-m1-m5).
The contest control plane, AI reviewers, governance and audit records live in
the dedicated **TRIAGE** namespace, backed by its own database. Independently
managed business demos retain their own namespaces; the isolated M2 and M5
acceptance Productions use **OBSERVATION** and **M5OBSERVATION**, respectively.

The installer creates this namespace and calls
`%EnsembleMgr.EnableNamespace("TRIAGE")`. Interoperability configures its own
system-library mappings. The installer does not manually map `Ens`, `EnsLib`,
`%AI` or application packages into `USER` or `HSLIB`. The BP and AI Hub tool
execute in TRIAGE without namespace switching.

## Requirements

The next monitoring/security-review stage has separate
[HIPAA knowledge inputs](../hipaa-demo-knowledge/README.md).
`knowledge.py` prepares/selects `demo` or `full` inputs; the current triage
runtime does not yet import them or perform HIPAA review. The complete
source archive and full local profile are excluded from Git.

For optional development-time MCP and Copilot Interop Skills, see
[the development guide](./dev/README.md). These tools are separate from the
runtime AI Hub SDK described below.

- Docker Compose 2.24.4+ with sufficient resources for an additional IRIS instance
  (the real-provider override uses `!override`).
- Locally obtained AI Hub EAP image, tested with ARM64 IRIS for Health
  `2026.3.0AI.154.0`. EAP is prerelease software; obtain it and an appropriate
  license through the official distribution process. The inherited Community
  2026.1 deployment is no longer used and is not an AI Hub substitute.
- Place your own license at `iris/license/iris.key` in the repository root,
  or set `IRIS_LICENSE_PATH` to an absolute local path. No license is distributed.
- Python 3 for the test runner. No additional Python packages are required.

## Start and test

Run from the repository root:

```sh
python3 contest/prepare.py
docker compose -p iris-triage -f contest/compose.yaml --profile mock up -d --wait
python3 contest/test.py --restart
```

The default uses a **synthetic local mock provider**, not real model inference.
It still exercises the real AI Hub SDK, registered ToolSet, Business Process,
Business Operation, persistent destination and audit records.
`gpt-4o-mini` is only the mock configuration's tool-capable model identifier;
these tests do not call that external model.

The Gateway publishes
<http://127.0.0.1:52777/csp/sys/UtilHome.csp>. `prepare.py` generates an ignored
local password file. The installer provisions the dedicated `ContestGateway`
service user (no application or administrative roles), and the Gateway uses it
for password-authenticated IRIS connections over the private Docker network.
The Portal login page is verified to return HTTP 200; use your IRIS administrator
credentials to sign in and select TRIAGE. This service account is not a Portal
administrator. Do not treat container health alone as Portal verification.
For an optional **local-demo-only** administrator, run
`python3 contest/prepare.py --portal-admin` and enter/confirm a password.
The ignored mode-600 `contest/data/portal-admin-password` file is read at startup
to configure `superuser` with `%All`, an enabled account, no password expiry
and no first-login password change. Without that file the installer leaves
administrator accounts unchanged. The local password is reapplied on each
startup while the file exists; remove the file and rotate the account password
to stop this behavior. This does not change the separate Gateway service user,
the instance-wide password policy, or other users. Never use a weak/shared
password or non-expiring administrator credentials on a public/production instance.
Gateway administration paths are denied by the supplied Apache configuration.
Neither the mock nor IRIS Superserver is exposed on host ports.

Data is persisted in ignored `contest/data/dur/`. For an independent clean
instance, use another Compose project name, a different unused
`TRIAGE_WEB_PORT`, and an absolute `TRIAGE_DATA_PATH` pointing to a new writable,
empty directory. Do not point it to the original application's data directory.
The instance creates the `irissys` subdirectory itself.

Stop without deleting data:

```sh
docker compose -p iris-triage -f contest/compose.yaml --profile mock down
```

## Workflow and evidence

For the current SQL/FHIR aggregation and internal quality-improvement sidecar,
see [Internal hospital route demo](./ROUTE-DEMO.md). It uses explicit synthetic
organization policy, exact project approval and real delivery observations,
with separate destructive demo replacement and paid-inference commands.
The workflow below describes the original message-triage slice.

1. `Contest.Setup.Submit` sends an `Ens.Request` through the test Business
   Service into `Contest.Process`.
2. IRIS derives facts from synthetic JSON (`reference`, `code`, `value`).
   Only completeness and known-code flags are made available to the Agent,
   not raw message contents.
3. The AI Hub Agent calls the read-only `GetTriageFacts` tool. The tool only
   permits the case bound to the current BP job.
4. The BP validates the JSON action and reason. Delivery is forbidden for
   incomplete messages or codes outside `OBS` and `LAB`.
5. A synchronous Business Operation atomically persists one destination and the
   final state: `delivered`, `quarantined`, or `pending_review`.
6. `Contest.Event` records receipt, tool access, decision, policy and execution.
   `Contest.Case` includes IRIS message/session IDs, the AI Hub session ID,
   model, mode, elapsed time, facts, provider-reported usage and errors.
   Usage currently describes the final SDK response, not the sum of every
   tool-loop request. No billed cost is inferred from those partial counters.

Delivery is a local persistent demo sink, not an external system. Quarantine and
human review are persistent work queues; an operator review/resolution UI and
automatic replay are not implemented. Successful duplicates return their original
outcome without another model call or destination write. Conflicting IDs and
failed/incomplete retries are rejected rather than silently replayed.

To inspect evidence:

```sh
docker compose -p iris-triage -f contest/compose.yaml exec iris iris session IRIS -U TRIAGE
```

In the IRIS terminal:

```objectscript
Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT ID,ExternalId,Decision,Policy,Outcome FROM Contest.""Case""") Do rs.%Display()
Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT CaseId,Stage,Detail FROM Contest.Event ORDER BY ID") Do rs.%Display()
Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT CaseId,Queue FROM Contest.Destination") Do rs.%Display()
```

## Real-provider validation

Do not use real patient data in this demo. Put your authorized provider
configuration in the repository-root ignored `.env`:

```dotenv
LLM_BASE_URL=https://your-provider.example/v1
LLM_MODEL=your-tool-capable-model
LLM_API_KEY=your-local-key
```

Do not copy actual credentials into documentation or Git. Launch a separate
real-provider instance (no mock service) with its own database:

```sh
python3 contest/prepare.py
docker compose --env-file .env -p iris-triage-real \
  -f contest/compose.yaml -f contest/real.yaml up -d --wait
COMPOSE_PROJECT_NAME=iris-triage-real python3 contest/test.py --real --restart
```

This makes real external requests and may incur provider charges. Only the
synthetic case ID and boolean facts are sent, not raw input messages.
The real-provider override injects the API key as a container environment
variable: Docker administrators can inspect it. Do not print `compose config`
or environment dumps when using real credentials. Keep Docker access restricted.
The real Portal is at <http://127.0.0.1:52779/csp/sys/UtilHome.csp>.

To recheck persistence without making any new inference calls:

```sh
COMPOSE_PROJECT_NAME=iris-triage-real python3 contest/test.py --real --persistence-only
```

The provider must support the OpenAI-compatible Chat Completions tool-call
protocol used by this EAP SDK. The mock regression suite is not a model-quality
benchmark. Never run mock fault injection against a real-provider instance;
the base tests verify the requested mode before sending requests.

## Validation status (2026-10-15)

Verified using a completely new data directory, not the original probe's
`USER` or `HSLIB` configuration:

- Dedicated database and namespace creation; Interoperability enablement.
- All 12 application classes compile without manual package/routine mappings.
- Real BP -> AI Hub -> read-only ToolSet -> policy -> BO execution with the
  synthetic provider, including all three persistent destinations.
- Duplicate delivery suppression, conflicting-ID rejection, invalid JSON
  failure and persisted failure evidence.
- Eight mock fault scenarios: unsafe delivery, unknown action, empty reason,
  invalid field type, malformed JSON, cross-case tool access, skipped fact tool,
  and provider HTTP 503. Each checks explicit failure, persisted evidence, zero
  destination writes and rejection of automatic retry.
- Cases, destination contents and ordered audit history remain identical over
  IRIS restart; duplicate submissions after restart do not repeat inference
  or add destination writes.
- Authenticated Gateway connection, Portal HTTP 200, Gateway admin HTTP 403.
- Real `deepseek-flash` inference through the locally configured compatible
  provider: all three routes, actual fact tools, AI Hub sessions, usage and
  restart-persistence checks passed.

See the acceptance results and limitations documented above.
This completes the minimal terminal-driven demo acceptance, not production or
contest-release certification. Operator resolution UI, external delivery,
load/concurrency/crash-recovery testing, whole-loop token/cost accounting,
and broad model-quality evaluations remain outside this milestone.
