# IRIS AI Hub Interoperability Workflows

[English setup guide](./README.en.md) · [中文说明](./README.zh-CN.md)

**Non-intrusive monitoring of inter-organization data exchanges for potential
privacy and compliance risks.**

Observe an existing InterSystems IRIS Interoperability Production without
changing its business process or blocking deliveries. Combine message evidence,
source/recipient institution profiles and HIPAA reference material with an
**IRIS AI Hub Agent** to support human investigation.

This is a synthetic demonstration for
[AI Agents in Interoperability Workflows](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows),
not a production compliance service or legal certification.

## What the application does

Healthcare data exchanges have different requirements depending on the
recipient and intended use. A research export, an internal quality report and
a treatment message should not be assessed using the same assumptions.

The application collects supported message evidence alongside a running
Production, binds it to versioned institution context, and uses AI Hub to
identify potential concerns or missing information. The report links each
finding to observed facts, source passages and preserved model output.

| Capability | Implemented behavior |
|---|---|
| Production observation | Discover and explicitly enroll local Productions; collect message edges, sessions, events and coverage without changing business hosts |
| Bounded local inspection | Separately authorized inspection of registered structured properties; minimized field facts rather than patient identifier values in review packets |
| Context-aware review | Frozen institution profiles and purpose declarations, two AI Hub phases, validated report structure and source quotations |
| Inspectable inference | **AI log** beside model-execution actions: saved inputs, responses, sessions, usage and errors; viewing does not call a model |
| Spending controls | Explicit bounded grants; enrollment, refresh and retries do not silently purchase inference |
| Additional workflow decisions | A separate triage BP uses a read-only fact ToolSet and a deterministic policy gate before persisting delivery, quarantine or human-review outcomes |

Monitoring is **post-send and advisory**. It does not prevent a completed
disclosure, automatically modify a Production or guarantee real-time detection.
Non-intrusive refers to the delivery architecture, not a claim of zero
resource overhead.

## Main demonstration

Use the [live M5 walkthrough](./contest/M5-ONBOARDING-DEMO.md)
([中文](./contest/M5-ONBOARDING-DEMO.zh-CN.md)).
After provisioning, open <http://localhost:5173/demo/m5>.

1. Enter and save the source hospital and research recipient profiles.
   **Fill example** populates editable test data.
2. Enroll the fixed `M5OBSERVATION / Contest.M5.Production`.
3. Separately authorize local synthetic-field inspection.
4. Send a new synthetic research message through the actual BS/BP/BO flow
   and SQL receiver.
5. Inspect the newly collected field evidence and message/session linkage.
6. Authorize one bounded AI audit, review the result and open its **AI log**.

The example declares Safe Harbor de-identification while retaining synthetic
identifiers and a complete birth date. The report highlights the contradiction
with that selected release path; it does not declare all research disclosures
unlawful.

```text
Existing business Production: BS -> BP -> BO -> receiver
                                      |
                               observed evidence
                                      |
                  minimized facts + frozen institution context
                                      |
                 AI Hub locator -> source evidence -> AI Hub judge
                                      |
                    IRIS validation -> report -> human review
```

The M5 reviewer runs in an independent observation worker, not inside the
observed business BP. Reset archives only the fixed demo's logical state;
original IRIS messages, SQL receipts and model reports remain retained.

### Three recipients, three protocols

The [optional multi-organization scenario](./contest/MULTI-ORGANIZATION-DEMO.md)
reads a versioned FHIR Patient, transforms it and distributes actual outputs:

| Simulated recipient | Interface | Isolated namespace |
|---|---|---|
| Internal quality department | SQL | `DEMOQUALITY` |
| External research center | REST | `DEMORESEARCH` |
| Treating clinic | HL7 V2 / MLLP | `DEMOCLINIC` |

All receivers run locally in one IRIS instance. Receiver readbacks support
branch-specific review. This scenario also demonstrates an `AdvisoryAudit`
BP that invokes AI Hub review after distribution.

## Installation

### Requirements

- Docker Compose **2.24.4+** and Python 3.
- An authorized **AI Hub EAP image** and appropriate local InterSystems license,
  obtained separately. Neither is included.
- Tested runtime: **ARM64 IRIS for Health `2026.3.0AI.154.0`**. An ordinary
  non-AI-Hub Community image is not a substitute. The contest announcement
  currently specifies AI Hub Community build 154.
- For the UI: Node **22.12+**, or the documented Docker-based alternative.
- For real review: model credentials, a provisioned reviewer and knowledge index.
  Provider calls can incur charges.

### Start with the bounded mock triage workflow

This verifies the real IRIS BP, AI Hub SDK, ToolSet, policy gate and BO with a
local mock provider. **It does not provision the complete M5 monitoring demo.**

Place your license at `iris/license/iris.key`, or set `IRIS_LICENSE_PATH` to
its absolute path. From the repository root:

```sh
python3 contest/prepare.py
docker compose --profile mock up -d --wait
python3 contest/test.py --restart
```

Open <http://127.0.0.1:52777/csp/sys/UtilHome.csp>, sign in and select
**TRIAGE**. See the [runtime installation guide](./contest/README.md) for
image selection, credentials, real-provider configuration and troubleshooting.

### Set up the monitoring demonstration and UI

Follow these guides in order; do not treat an existing acceptance journal as
a fresh-install fixture:

1. [Real runtime setup](./README.en.md#real-model-runtime).
2. [Knowledge API and local embedding setup](./contest/KNOWLEDGE.md).
3. [Production monitoring infrastructure](./contest/MONITORING.md).
4. [M5 prerequisites, source installation and live steps](./contest/M5-ONBOARDING-DEMO.md).
5. [Frontend installation and shared sign-in](./web/README.md#run-with-node).

The UI uses the existing IRIS API identity. Credentials remain in browser
memory; model authorization is separate from sign-in. Keep this HTTP demo on
localhost. Do not expose the current development deployment unchanged online.

## Verification and recorded evidence

Free checks, without new model calls:

```sh
python3 contest/knowledge.py verify --profile demo
python3 contest/knowledge.py release-check

cd web
npm test
npm run lint
npm run build
```

Restore frontend dependencies with `npm ci --legacy-peer-deps` in the
environment that runs the UI. See [frontend validation](./web/README.md#validation)
for Docker use.

Recorded local acceptance, not fresh-install guarantees:

| Scope | Recorded result |
|---|---|
| M5 onboarding audit | One synthetic message; two model requests; scoped risk finding; 43,626 SDK tokens |
| Three-recipient accepted audit | Six requests; research risk and scoped quality/treatment no-signal findings; 97,069 SDK tokens |
| Frontend at M5 completion | 250 tests passed; typecheck, lint and build passed |

An earlier multi-recipient attempt included a provider timeout and remains
recorded separately. SDK counts are not reconciled billing or legal accuracy
measurements. Historical experiments, including failures and unpromoted
variants, remain documented in [MONITORING](./contest/MONITORING.md).

A publication-time Python discovery run executed 242 tests: 226 passed and
16 historical staged-acceptance/taxonomy checks rejected changed runtime
source hashes. Those historical freezes have not been repinned or presented
as current passing acceptance.

`python3 contest/m5_demo.py --check` reads a previously saved local acceptance
journal. `--run` sends data and authorizes paid inference; it is not a routine
free check. See the [M5 guide](./contest/M5-ONBOARDING-DEMO.md) before using
installation, acceptance or reset commands.

## Knowledge provenance and boundaries

The [demo knowledge package](./hipaa-demo-knowledge/README.md) contains
approximately **23 MB of complete prepared text**, plus separately identified
LLM-authored briefs and a synthetic organization policy. Official extracted
text is not described as LLM-rewritten, and briefs are not official legal text.
Historical/unreviewed material is excluded from default retrieval exports.

Use the published `demo` profile for release checks; `full` is an optional
local rebuild. The full source archive and full local prepared corpus remain
outside Git. Input selection is not a completed AI Hub import or an assessment
quality evaluation.

Supported structured inspection is not comprehensive free-text PHI detection.
Institution profiles are user-supplied scenario premises, not verified legal
authority. Exact quotation validation does not establish correct legal
interpretation or later recipient behavior.

## Documentation

| Topic | Guide |
|---|---|
| Main presentation | [English live demo](./contest/M5-ONBOARDING-DEMO.md) · [中文](./contest/M5-ONBOARDING-DEMO.zh-CN.md) |
| Extended scenario | [FHIR-to-SQL/REST/HL7 distribution](./contest/MULTI-ORGANIZATION-DEMO.md) |
| Runtime and UI | [IRIS setup](./contest/README.md) · [frontend](./web/README.md) |
| Review and evidence | [Production monitoring](./contest/MONITORING.md) · [Knowledge API](./contest/KNOWLEDGE.md) |
| Additional workflows | [Agent factory](./contest/AGENT-FACTORY.md) · [declarations](./contest/DECLARATION-WORKFLOW-PLAN.md) |
| Contest materials | [Article draft](./contest/CONTEST-ARTICLE.md) · [submission checklist](./contest/CONTEST-SUBMISSION.md) |
| Development | [Agentic Dev and Skills](./contest/dev/README.md) · [research notes](./contest-knowledge/README.md) |

Agentic Dev MCP and Interop Skills assist development; they are not the runtime
business Agent. Article publication, video, clean-machine full-demo rehearsal
and actual contest submission are separate release tasks.

## Repository and attribution

- [contest/](./contest/): ObjectScript components, deployment, Python harnesses
  and workflow documentation.
- [web/](./web/): React/TypeScript demonstration UI.
- [hipaa-demo-knowledge/](./hipaa-demo-knowledge/): published prepared corpus.
- [contest-knowledge/](./contest-knowledge/): development research and evidence.

Forked from [zlnick/DataPipelineDemo](https://github.com/zlnick/DataPipelineDemo).
This fork adds runtime AI Hub decisions, independent Production observation,
institution-aware review and evidence inspection. The inherited
pipeline-generation application is no longer included in the current tree;
its history and attribution remain. Work here does not modify upstream.

Project code is [Apache-2.0](./LICENSE); see [NOTICE](./NOTICE) for upstream,
UI, Skills and knowledge-material attribution. No license keys, model
credentials, InterSystems images or full local source archive are distributed.
