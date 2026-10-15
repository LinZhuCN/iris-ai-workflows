# IRIS AI Hub Interoperability Workflows

[Detailed English guide](./README.en.md) · [中文说明](./README.zh-CN.md)

A contest-focused InterSystems IRIS application demonstrating bounded AI Hub
decisions inside Interoperability workflows. The implemented triage workflow
uses an actual `%AI.Agent` and read-only fact tools; IRIS validates policy,
executes routing and records the outcome.

The next product stage is an independently deployed monitoring Production,
with pipeline observation components, failure diagnosis and sampled privacy/
security review. That monitoring application is not yet implemented; the
current runtime remains the verified message-triage demonstration.

## Quick start

Requirements: Docker Compose 2.24.4+, Python 3, an authorized AI Hub EAP image
and a valid local InterSystems license. Tested on ARM64 IRIS for Health
`2026.3.0AI.154.0`. This prerelease environment is not for production.

Place your own license at `iris/license/iris.key`, or set `IRIS_LICENSE_PATH`
to its absolute path, then run from the repository root:

```sh
python3 contest/prepare.py
docker compose --profile mock up -d --wait
python3 contest/test.py --restart
```

The mock provider is local, while BP, AI Hub SDK, tools, BO, persistence and
auditing are real. Open <http://127.0.0.1:52777/csp/sys/UtilHome.csp> and select
the dedicated **TRIAGE** namespace after signing in.
See the [installation and workflow guide](./contest/README.md) for real-provider
configuration, license/image requirements, test evidence and limitations.

## HIPAA demonstration knowledge

The [release knowledge package](./hipaa-demo-knowledge/README.md) contains
**approximately 23 MB of UTF-8 knowledge text**: prepared official evidence, five LLM-authored
briefs and one synthetic organization policy, with source/version citations.
It was organized with LLM-assisted briefs and deterministic extraction and
deduplication for reproducible contest verification. Original binary sources
are not needed to validate the published text.

**Not every source was LLM-rewritten.** The official evidence remains available
as extracted text; the briefs are explicitly non-authoritative summaries.
The complete prepared text is now published instead of a size-limited subset.
Historical explanations and unreviewed cases/proposals are retained in separate
scopes and excluded from default exports. Two NIST guides supplement the HHS
evidence. There is no 5–10 MB requirement.
The package is not legal advice or a complete HIPAA compliance assessment.

Two explicit input profiles separate development from release:

| Profile | Purpose | Git distribution |
|---|---|---|
| `demo` | Published complete prepared text, with scope-controlled exports | Included |
| `full` | Locally rebuilt copy for development comparison | Excluded |

```sh
# Verify release inputs without downloading the full archive.
python3 contest/knowledge.py verify --profile demo
python3 contest/knowledge.py select --profile demo
python3 contest/knowledge.py release-check
python3 contest/knowledge.py export --output contest/data/knowledge/default.jsonl

# Development only, after preparing the local full corpus:
python3 contest/knowledge.py select --profile full
```

Selection pins a corpus digest and a separate profile-specific index key.
These commands **prepare and select inputs only**: AI Hub knowledge ingestion
and use by a security-review Agent are not implemented yet. The existing triage
Agent does not automatically use either corpus.

For real use, users may choose a fuller approved knowledge base after checking
source currency, applicability, data flows and retrieval quality. The full
local archive must not be committed, silently uploaded, or indexed by default.
No patient messages belong in the normative knowledge corpus.

## Repository layout

- [contest/](./contest/): application source, deployment, tests and knowledge CLI.
- [hipaa-demo-knowledge/](./hipaa-demo-knowledge/): complete prepared text corpus.
- `hipaa-documents/`: ignored full source archive and prepared local full corpus;
  not required to validate the release package.
- [contest-knowledge/](./contest-knowledge/): project development notes/evidence.
- [IRIS development tools](./contest/dev/README.md): Agentic Dev MCP and Copilot
  Interop Skills, distinct from the runtime AI Hub Agent.

## Provenance and limitations

Forked from [zlnick/DataPipelineDemo](https://github.com/zlnick/DataPipelineDemo).
This fork adds runtime AI Hub triage, a dedicated Interoperability namespace,
policy enforcement, persistent destinations, auditing and mock/real-provider
verification. The inherited pipeline-generation stack was removed; its history
and attribution remain. No upstream repository is modified.

The current destination is local storage, human review is a queue rather than
a resolution UI, and whole-loop billing/external delivery are not implemented.
Contest eligibility and acceptance of the EAP build remain the organizer's
decision.

## License

Project code: [Apache-2.0](./LICENSE). See [NOTICE](./NOTICE) for attribution and
the separate treatment of government-source knowledge materials. No
InterSystems images, license keys, model credentials or full local archive are
distributed.
