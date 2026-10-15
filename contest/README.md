# AI Hub message triage (isolated EAP demo)

This fork adds a runtime AI Hub decision to an IRIS Interoperability Production.
The inherited application stack has been removed from this fork's current tree;
the root Compose entry now includes this isolated deployment. The upstream
repository and other local projects are not modified.
All contest application classes, messages, destinations and audit records live
in the dedicated **TRIAGE** namespace, backed by its own database.

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

See the [acceptance record](../contest-knowledge/Minimal-workflow-acceptance-2026-10-15.md).
This completes the minimal terminal-driven demo acceptance, not production or
contest-release certification. Operator resolution UI, external delivery,
load/concurrency/crash-recovery testing, whole-loop token/cost accounting,
and broad model-quality evaluations remain outside this milestone.
