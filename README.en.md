# IRIS AI Hub Interoperability Workflows

[Main README](./README.md) · [Chinese README](./README.zh-CN.md)

A contest-focused message triage application: an **IRIS AI Hub Agent makes a
bounded runtime decision inside an Interoperability workflow**, while IRIS
validates policy, executes the action and records the outcome.

```text
Synthetic message -> deterministic facts -> AI Hub Agent + read-only ToolSet
                                                     |
                                               BP policy gate
                                                     |
                               BO -> deliver / quarantine / human review
                                                     |
                                        persistent destination and audit
```

## Quick start

Requirements: Docker Compose 2.24.4+, Python 3, an authorized AI Hub EAP image
and your own valid InterSystems license. Tested with ARM64 IRIS for Health
`2026.3.0AI.154.0`. EAP is prerelease software, not a production deployment.
The ordinary Community image is not a substitute for this AI Hub build.

Put your license in `iris/license/iris.key`, or set `IRIS_LICENSE_PATH` to an
absolute local file path. No license or EAP image is distributed here.

From the repository root:

```sh
python3 contest/prepare.py
docker compose --profile mock up -d --wait
python3 contest/test.py --restart
```

This uses a synthetic local mock provider but the real IRIS AI Hub SDK, BP,
ToolSet and BO. Open <http://127.0.0.1:52777/csp/sys/UtilHome.csp>, sign in
with your IRIS administrator credentials, and select **TRIAGE**.
The installer creates a dedicated database and namespace and enables
Interoperability; application code does not switch to USER or HSLIB.

For authorized real inference, populate an ignored root `.env` using
[.env.example](./.env.example), then:

```sh
docker compose --env-file .env -p iris-triage-real \
  -f contest/compose.yaml -f contest/real.yaml up -d --wait
COMPOSE_PROJECT_NAME=iris-triage-real python3 contest/test.py --real --restart
```

The real instance uses separate data and
<http://127.0.0.1:52779/csp/sys/UtilHome.csp>. Calls may incur provider charges.
Only synthetic case IDs and boolean facts are sent. Do not print resolved
Compose configuration containing credentials or use real patient data.

See the [full installation and workflow guide](./contest/README.md) and
[acceptance evidence](./contest-knowledge/Minimal-workflow-acceptance-2026-10-15.md).

## What is implemented

- An actual AI Hub fact-tool loop within an Interoperability Business Process.
- Three policy-controlled paths with persistent destinations and audit events.
- Delivery rejection for incomplete or unknown-code messages.
- Explicit failure handling and duplicate suppression, including after restart.
- Eight injected mock faults and real `deepseek-flash` three-route verification.
- Authenticated Web Gateway connectivity, with Gateway management paths denied.

The delivery destination is local storage; human review is a persistent queue,
not yet an operator-resolution UI. Whole-loop token/cost accounting, external
delivery and production hardening remain future work. The small real-model
verification is not a general model-quality benchmark.

## Development MCP and Interop Skills

The workspace integrates official IRIS Agentic Dev v1.5.0 through MCP and
three Copilot skills adapted from
[IRIS Interop Skills](https://github.com/intersystems-ib/iris-interop-skills).
They assist development, TDD and message diagnosis; they do not replace the
AI Hub Agent inside the runtime workflow. See the
[development guide](./contest/dev/README.md) for installation, permissions
and actual MCP compile / UnitTest verification.

## HIPAA knowledge inputs

The [knowledge package](./hipaa-demo-knowledge/README.md) contains
approximately 23 MB of actual UTF-8 knowledge text. It was organized and
summarized with LLM assistance to reduce the number and size of materials
needed for contest verification. Five LLM-authored briefs and a synthetic
organization policy are distinct from retained official evidence excerpts:
the entire package is **not** LLM-rewritten, and summaries are not official
legal authority. Historical and unreviewed records are included in the release
but excluded from default scope-filtered exports. NIST guidance supports
technical assessment. The former 5–10 MB size target has been retired.

The `demo` profile now distributes the complete prepared text; `full` is a
local rebuild and original binary sources remain Git-ignored. Development comparisons explicitly
select `full`; before release, select `demo` and run the release check:

```sh
python3 contest/knowledge.py verify --profile demo
python3 contest/knowledge.py select --profile demo
python3 contest/knowledge.py release-check
python3 contest/knowledge.py export --output contest/data/knowledge/default.jsonl
```

These are input-preparation commands, not completed AI Hub ingestion or a
security-review Agent implementation. A real deployment may use a fuller
approved corpus after legal/source and retrieval-quality review. See the
package guide for full-profile preparation and selection.

## Repository layout

- [contest/](./contest/): application classes, deployment, Gateway and tests.
- [contest-knowledge/](./contest-knowledge/): project knowledge and evidence.
- [hipaa-demo-knowledge/](./hipaa-demo-knowledge/): release knowledge inputs.
- `hipaa-documents/`: ignored full archive and full local prepared corpus.
- [iris/license/](./iris/license/): local license convention.
- `contest/data/`: ignored local databases and generated Gateway credential.

## Provenance and substantial changes

Forked from [zlnick/DataPipelineDemo](https://github.com/zlnick/DataPipelineDemo),
an AI-assisted data integration and pipeline-generation demo.
This fork adds runtime AI Hub decisions, the dedicated TRIAGE namespace,
bounded fact access, deterministic policy enforcement, persistent routing and
auditing, reproducible installation, and mock/real-provider acceptance tests.

The inherited frontend/backend, pipeline generator, terminology submodule,
embedding service and related datasets/tools have been removed from the current
tree to focus the entry. Their history and attribution remain; no submodule
initialization is required. No upstream repository is modified.

Contest eligibility and acceptance of this EAP build remain subject to the
organizer's decision.

## License

[Apache-2.0](./LICENSE). See [NOTICE](./NOTICE) for upstream attribution.
InterSystems software, licenses and model credentials are not distributed.
