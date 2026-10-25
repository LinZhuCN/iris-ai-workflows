# Non-Intrusive Privacy Risk Monitoring for IRIS Interoperability Workflows

> Developer Community article draft for **AI Agents in Interoperability
> Workflows**. Describes the locally implemented and tested application as of
> October 25, 2026. Publication, public demo hosting and the release package are
> separate steps; see the [submission checklist](./CONTEST-SUBMISSION.md).

**Project:** [IRIS AI Hub Interoperability Workflows](https://github.com/LinZhuCN/iris-ai-workflows)

**Language:** English · [简体中文](./CONTEST-ARTICLE.zh-CN.md)

**Live walkthrough:** [English](./M5-ONBOARDING-DEMO.md) ·
[中文](./M5-ONBOARDING-DEMO.zh-CN.md)

**Setup:** [runtime installation](./README.md) · [web interface](../web/README.md)

## Monitor data exchanges without changing the business flow

Healthcare organizations exchange data with research centers, treating clinics
and other partners. The information needed by each recipient depends on its
role, the purpose of the exchange and the applicable requirements. Reviewing
those exchanges means connecting technical message records with business
context that is often maintained separately.

This project provides **non-intrusive monitoring of inter-organization data
exchanges for potential privacy and compliance risks**. It collects evidence
alongside an existing IRIS Interoperability Production and uses an IRIS AI Hub
Agent to assist review. The observation path does not require changes to the
business BP or block its deliveries.

For example, a hospital configures a research export as de-identified using
Safe Harbor. The research recipient expects a birth year and a status, but
the observed output contains a name, a medical record number and a full date
of birth. A reviewer needs to see which message contained those fields, which
institution profile applied, and why the selected release conditions warrant
further investigation.

The application brings that evidence together: the source and recipient,
the declared purpose, the observed field inventory, relevant HIPAA source
passages and an inspectable AI assessment. Staff can use the report to
investigate the exchange; it is not an automatic legal determination.

## What non-intrusive monitoring means here

The main scenario uses a separate observation worker to collect supported
message evidence while the business Production operates. The reviewer is
not inserted into its BS/BP/BO delivery path. It does not rewrite routing,
change payloads or automatically resend messages.

Collection and AI review are separate operations. In the guided demo, the
user sends a message, inspects the collected evidence and then authorizes a
bounded audit. **This is post-send advisory review, not synchronous screening
or a promise of real-time detection.** A finding cannot prevent or reverse
a delivery that has already occurred.

Non-intrusive also does not mean access-free or overhead-free. Observation
requires configured access to message records, local inspection needs explicit
authorization, and model execution consumes a separately authorized budget.
The demo does not establish a production performance or latency guarantee.

## A walkthrough: enroll a Production and review a research export

The main presentation starts at the fixed
`M5OBSERVATION / Contest.M5.Production` demo. Its underlying business flow
is installed beforehand; the presenter does not need to build an integration
during the demonstration.

The user:

1. Enters descriptions for the source hospital and research recipient.
2. Saves responsibilities, intended use, permitted/prohibited fields and
   receiving requirements.
3. Enrolls the Production for observation and authorizes local synthetic-field
   inspection.
4. Sends the fixed synthetic research message through the actual BS/BP/BO
   chain and SQL receiver.
5. Inspects the newly collected message evidence.
6. Explicitly authorizes one bounded AI audit and reviews the identified
   concerns, supporting evidence and information still needed.

“Fill example” only fills an editable form. Saving creates a versioned
scenario premise, not a legal approval. Sending freezes the exact institution
profiles, so later edits cannot rewrite the context used for that message.

The fixed host-to-institution mapping is an explicit part of this simulation.
A Business Partner key helps associate a technical host with an institution,
but its name alone cannot establish that institution's responsibilities or
permission to receive data. Saving a profile does not silently reconfigure a
Business Host.

## From runtime activity to model-visible evidence

```text
Versioned institution profiles
             |
Actual BS -> BP -> BO -> SQL receipt/readback
             |
Production observer: header, session, supported structured-field facts
             |
Exact configuration + session + Agent + spending authorization
             |
AI Hub locator -> IRIS-prepared source evidence -> AI Hub judge
             |
IRIS schema / binding / citation checks
             |
Saved assessment + original responses + human review
```

Monitoring enrollment, message inspection and model spending are deliberately
separate. Enrolling a Production does not automatically authorize reading its
bodies or purchasing inference.

For supported messages, local inspection extracts facts such as which field
paths are present and whether a date is year-only or complete. Patient
identifier values are not needed in the model packet. Unsupported formats and
inspection failures remain visible rather than becoming an empty “safe” result.
This is bounded structured inspection, not comprehensive free-text PHI detection.

The review uses two constrained model phases. The locator identifies relevant
questions. IRIS prepares the source evidence between phases; the judge assesses
the facts and returns structured issues and citations. These review tasks have
no unrestricted runtime ToolSet. IRIS checks evidence references and exact
source quotations before accepting the report.

Checking that a quotation exists is useful, but it does not prove that the
legal interpretation is correct. The interface therefore preserves uncertainty
and uses “no signal on checked issues,” not “HIPAA certified.”

### Where the code runs, and what the Agent can decide

The fixed M5 reviewer runs in an independent background observation worker,
bound to a real business Production's evidence. It is not inserted into that
business BP.

The Agent assesses a supported observation as a scoped risk, information
required or no signal on the checked issues. IRIS validates the result and
citations, saves the report and leaves follow-up to a human.

The repository also includes two distinct Interoperability decision examples:

| Path | AI Hub decision | IRIS execution boundary |
|---|---|---|
| Optional multi-organization audit BP | Assess transformed recipient outputs after distribution | `AdvisoryAudit` invokes the reviewer and records an advisory report; it does not block the completed distribution |
| Bounded message triage BP | Propose `deliver`, `quarantine` or `human_review` | The BP checks the action and deterministic safety conditions before the BO persists an allowed outcome |

These are real `%AI.Agent` executions, not Python model calls renamed as
AI Hub. In triage, the Agent must call the registered read-only fact ToolSet
for the BP's current case. Cross-case access, missing tool use and unsupported
actions are rejected. It has no arbitrary Production administration capability.

The action-taking triage path is separate from the non-intrusive monitoring
scenario; enrolling a Production does not add a triage gate to its deliveries.
These distinctions also explain how the application addresses the
[contest's AI Hub decision task](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows).

## Reviewing exchanges with different recipient roles

The optional multi-organization demonstration reads a versioned FHIR Patient
and distributes actual transformed outputs to three simulated institutions:

| Recipient | Protocol and isolated namespace | Scoped question |
|---|---|---|
| Internal quality department | SQL / `DEMOQUALITY` | Does the output fit the configured internal-purpose/minimization context? |
| External research center | REST / `DEMORESEARCH` | Do actual identifiers contradict the asserted Safe Harbor path? |
| Treating clinic | HL7 V2 over MLLP / `DEMOCLINIC` | What permissions and exceptions apply to ordinary treatment of the same patient? |

Each branch has actual receiver evidence, not merely a proposed mapping.
The saved accepted audit identified the research contradiction while returning
scoped no-signal findings for quality and treatment. The clinic is an important
contrast: identifying information is not automatically a violation when the
applicable treatment context differs.

These receivers occupy separate namespaces/databases in one local IRIS
instance. They are not independent hospitals or remote production systems.
Removing selected fields in the comparison variant is not proof of complete
Safe Harbor de-identification.

## Inspect the assessment and the underlying model execution

Reviewers need to inspect how an assessment was produced, not just read its
conclusion. Every
model-execution action now has an adjacent **AI log** control. For the phased
audits it exposes:

- The preserved locator and judge responses.
- Model identity, AI Hub sessions and execution state.
- Recorded usage and errors.
- Expandable request inputs and system prompts.
- The original stored record for deeper investigation.

Opening the log performs no model request or retry. A legacy record that stores
only a validated result is not relabelled as the provider's original response.
Likewise, a session ID or a reserved request alone is not presented as proof of
successful inference.

The distinction between receipt, captured monitoring evidence and completed AI
assessment is visible throughout the demo. They are three different events.

## What we measured, and what we did not

The configured model identifier for these runs was `deepseek-flash`.

| Saved execution | Model requests | SDK prompt tokens | SDK completion tokens | SDK total |
|---|---:|---:|---:|---:|
| Fixed M5 onboarding audit | 2 | 28,912 | 14,714 | 43,626 |
| Accepted three-recipient audit | 6 | 70,768 | 26,301 | 97,069 |

The M5 run preserved AI Hub sessions **226–227**; the three-recipient run
preserved sessions **219–224** and audit BP session **59**. These are local
acceptance identifiers, not IDs that a fresh installation will reproduce.

The multi-organization table describes the accepted run only. An earlier
six-request attempt, including a research-provider timeout, remains recorded;
the successful run used a separately authorized budget. It was not a free or
hidden automatic retry.

Reasoning/cache counters are subsets of completion/prompt counts where the
provider reports them; they must not be added again. We have not reconciled
these counters with a provider invoice, so we do not claim a monetary cost.
The two-phase review reserves at most two model requests per selected review;
that cap is not a fixed dollar or token-price guarantee.

These runs establish that the runtime and evidence paths executed. They are
not a representative clinical benchmark or a legally validated accuracy score.

## Lessons from building with AI Hub and Agentic Dev

**Give IRIS the final say.** In triage, a valid-looking model answer still fails
if it asks to deliver incomplete data or use an unknown action. In review,
malformed output, missing evidence or an invalid quotation must not become a
substitute success result.

**Make context explicit.** In an earlier treatment test, the model asked how
technical hosts related to the stated clinic and patient activity. Adding
explicit mapping and data-scope inputs was more appropriate than forcing a
“no risk” answer. The original unresolved report was retained.

**Treat failure and spending as durable state.** A timeout may consume a
reservation. Refreshing the page, resubmitting the same run or restarting the
container must not silently purchase another attempt or resend a message.

**Use development tools without confusing them with the runtime Agent.**
We used [IRIS Agentic Dev](https://github.com/intersystems-community/iris-agentic-dev)
and adapted Interop Skills for class inspection, compilation, framework
tests and diagnostics against a pinned TRIAGE connection. Those MCP tools
helped build the application; they are not the business Agent or an unrestricted
ToolSet available to it.

**Preserve evidence during rehearsal.** The M5 reset archives its logical
enrollment, profiles and review workspace. It retains original IRIS messages,
SQL receipts and protected model reports, and leaves other Productions alone.
The next presentation can start clean without rewriting the previous result.

## Try the workflow

The tested platform is ARM64 IRIS for Health AI Hub EAP
`2026.3.0AI.154.0`, with Docker Compose, Python and the local web UI.
Obtain the authorized EAP image and appropriate license separately; neither
is redistributed here. The current contest announcement specifies AI Hub
Community build 154. Do not substitute an ordinary non-AI-Hub image or assume
that a newer EAP build is compatible.

Follow the [installation guide](./README.md), [web setup](../web/README.md)
and [fixed onboarding walkthrough](./M5-ONBOARDING-DEMO.md).
The base mock triage quick start is not a one-command installation of every
extended monitoring demo. The M5 walkthrough states its additional prerequisites.

After provisioning, the live M5 presentation uses `/demo/m5`. Read-only
acceptance verification and scoped reset are separate operations:

```sh
python3 contest/m5_demo.py --check
python3 contest/m5_demo.py --reset
```

`--check` requires a saved local acceptance journal; it does not fabricate one
on a fresh clone. Reset is an explicit state-changing rehearsal action, not
part of read-only inspection.

The release knowledge package contains approximately 23 MB of complete prepared
text, with provenance, plus separately identified LLM orientation briefs and a
synthetic policy. It is not entirely LLM-rewritten, and the briefs are not
official legal text. Historical/unreviewed material is excluded from default
retrieval exports. Corpus verification is not a completed import or an Agent
accuracy evaluation.

## What is new in this fork

The project originated as a fork of
[DataPipelineDemo](https://github.com/zlnick/DataPipelineDemo), which focused on
AI-assisted integration analysis and pipeline generation. This entry's additions
are ObjectScript AI Hub runtime decisions, deterministic execution boundaries,
Production observation, versioned organization context, evidence-backed review
and inspectable model logs.

The current distribution no longer includes the inherited pipeline-generation
application. The original project is credited rather than presented as new
work; upstream and UI/skills notices are retained in [NOTICE](../NOTICE).

## Boundaries and next steps

This is an open-source synthetic demonstration, not a production-ready
compliance service. It does not establish real institutional authority, inspect
all possible payloads, verify later recipient behavior, prove legal
applicability, or offer unrestricted autonomous remediation. There is no
independent legal validation of the author-defined test expectations.

Useful next steps are a clean-machine release rehearsal, a short public demo
video, independent review of the assessment rubric, and stronger real-world
context/format adapters with appropriately scoped permissions.

The demonstrated workflow lets a user enroll an existing Production, collect
evidence from a new exchange and review potential privacy risks without
altering that Production's delivery logic. The resulting report links the
finding to the message, institution context, source passages and model output
needed for human investigation.

## Implementation map

- [Triage BP and policy gate](./src/Process.cls)
- [Fixed M5 demo, profile freezing and scoped reset](./src/M5Demo.cls)
- [Production evidence capture](./src/ProductionEvidence.cls)
- [Production review authorization and worker](./src/ProductionReviewService.cls)
- [AI Hub review phases and stored responses](./src/RiskReview.cls)
- [Multi-organization audit BP](./multiorg/AuditProcess.cls)
- [Shared AI log interface](../web/src/components/ai-log.tsx)
- [M5 acceptance runner](./m5_demo.py) and
  [multi-organization acceptance runner](./multi_acceptance.py)

## Reading that shaped the presentation

Three previous entries offered useful examples of explaining technical work:

- [Comparing Apache logs and Yandex Metrika](https://community.intersystems.com/post/compare-apache-logs-yandex-metrika-google-analytics-analogue):
  begin with a concrete operational discrepancy rather than a technology list.
- [FHIR and IntegratedML overview](https://community.intersystems.com/post/fhir-integratedml-example-overview):
  explain the data-preparation/integration path, with executable detail in the
  companion repository.
- [AI-Powered System Management with IRIS Agent](https://community.intersystems.com/post/ai-powered-system-management-iris-agent):
  connect user-facing AI interactions to visible Production internals.

They are inspirations for presentation, not implementations claimed as our
work or proof that a particular article format wins a contest.
