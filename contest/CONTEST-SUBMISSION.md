# Contest submission copy and release checklist

Editorial draft, October 25, 2026. This document prepares copy; it does not
create an Open Exchange listing or submit the application. Organizer approval
and any Freshmen eligibility remain separate determinations.
**Language:** English · [简体中文](./CONTEST-SUBMISSION.zh-CN.md)

The [article's related reading](./CONTEST-ARTICLE.md#reading-that-shaped-the-presentation)
identifies the previous entries that informed the presentation.

## Application name

**IRIS AI Hub Interoperability Workflows**

## Short description

Non-intrusive monitoring of IRIS data exchanges for potential privacy and
compliance risks, using AI Hub, institution context and inspectable message
evidence without changing the observed business flow.

## Open Exchange description

Monitor inter-organization data exchanges for potential privacy and compliance
risks without changing the observed Production's business logic or blocking
its deliveries. A separate observation worker connects IRIS message evidence
with versioned institution profiles, declared purposes and an IRIS AI Hub
Agent to support human review.

The guided demo starts with a clean logical workspace: enter source/recipient
profiles, enroll the fixed Production, authorize local inspection, trigger a
synthetic BS/BP/BO data flow, and explicitly fund its audit. IRIS records the
actual message/session, SQL readback and minimized field facts. The Agent
examines the selected release conditions and source evidence; IRIS validates
the structured result and citations. An **AI log** beside the execution button
shows preserved responses, sessions, usage and errors without another model call.

Monitoring collects evidence while the business flow operates; the guided
audit reviews that evidence after delivery. It is not synchronous screening,
a real-time detection guarantee or automatic legal certification. Observation
requires configured access and inspection permission; model spending is
separately authorized.

The main review path and additional workflow examples have distinct roles:

- **Advisory review:** an independently monitored message receives a scoped
  risk, information-required or no-signal assessment. The optional FHIR
  distribution scenario also executes review through an audit BP and sends
  actual SQL, REST and HL7 V2 outputs to isolated local recipient namespaces.
- **Controlled triage:** a separate example uses a job-bound read-only fact
  ToolSet to propose delivery, quarantine or human review. Its Interoperability
  BP enforces deterministic policy before the BO persists an allowed outcome.
  This action-taking path is not installed into an observed Production by
  monitoring enrollment.

The fixed research example declares Safe Harbor de-identification but sends
synthetic identifiers and a full birth date. Institution profiles genuinely
participate in the frozen model input. A separate treatment contrast shows why
identifiers should not be classified without their business context.

Model spending is explicit and bounded; retries do not automatically replenish
budgets. Rehearsal reset archives only the fixed M5 logical workspace, retaining
original messages and model reports. The application uses synthetic data and
does not certify HIPAA compliance, block already completed disclosures or
authorize arbitrary Production changes.

Tested locally on ARM64 IRIS for Health AI Hub EAP `2026.3.0AI.154.0`.
Obtain the authorized EAP image and appropriate license separately.
Installation, additional demo prerequisites and known limitations are documented.
The basic mock triage setup and full monitoring demo are distinct setup paths.

## Links for the application listing

| Field | Target / status |
|---|---|
| Source repository | <https://github.com/LinZhuCN/iris-ai-workflows> |
| English README | [Main README](../README.md) |
| Installation | [Runtime guide](./README.md), [web setup](../web/README.md) |
| Main live scenario | [English guide](./M5-ONBOARDING-DEMO.md), [Chinese guide](./M5-ONBOARDING-DEMO.zh-CN.md) |
| Developer Community article | [Article draft](./CONTEST-ARTICLE.md); no publication URL yet |
| Public hosted demo | Not published; `localhost` is not a public evaluation link |
| Video | Not recorded/published; do not insert an invented URL |
| Upstream attribution | [DataPipelineDemo](https://github.com/zlnick/DataPipelineDemo), [NOTICE](../NOTICE) |

## How this addresses the contest task

The [official announcement](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows)
requires an IRIS Interoperability workflow using an AI Hub Agent for a
decision-making task. It also requires open-source publication, an English
README with installation and a video **or** a working-principle description,
and significant improvement rather than copying an existing application.

| Requirement | Concrete implementation / evidence |
|---|---|
| AI Hub runtime Agent | `%AI.Agent`, real model sessions and stored responses; not a Python API wrapper |
| Decision inside an Interoperability workflow | [Triage BP](./src/Process.cls): propose action → deterministic policy → BO persistence |
| Additional AI Hub audit BP | [Multi-organization audit BP](./multiorg/AuditProcess.cls), distinct from the M5 background reviewer |
| Useful application, not renamed fork | New runtime control, evidence collection, profile snapshots, review contracts, budget accounting and UI |
| Demonstrable end-to-end use | [Live M5 onboarding](./M5-ONBOARDING-DEMO.md): new profiles → enrollment → new message → new audit |
| Observability and costs | Preserved model input/output, sessions, errors and usage; no monetary cost claimed without billing evidence |
| Developer experience | Documented bounded demo, tests, explicit reset and known prerequisites; clean-machine release rehearsal still needed |

The announcement currently specifies **AI Hub Community build 154**, not 162.
The tested `2026.3.0AI.154.0` ARM64 runtime matches that build number; verify the
exact licensed image/distribution intended for release. The announcement
expressly permits EAP development and submission under its stated license
clarification; it is not a blanket redistribution grant for images or licenses.

Submission period: **October 26–November 8, 2026**, closing at 23:59 EST on
November 8; voting runs November 9–15. Recheck the
[contest page](https://openexchange.intersystems.com/contest/49) before publishing.
Do not turn the organizer's EST notation into an assumed local-time deadline.

## Evidence to show, without turning it into an accuracy claim

| Test scope | Recorded result |
|---|---|
| Fixed M5 audit | Actual scoped risk result; one synthetic message; two requests; sessions 226–227; 43,626 SDK tokens |
| Three-recipient accepted audit | Quality/treatment scoped no-signal, research risk; six requests; sessions 219–224; 97,069 SDK tokens |
| Earlier three-recipient attempt | Research-provider timeout retained; separate six-request attempt, not included in the successful-run usage total |
| UI checks at the end of M5 implementation | 250 frontend tests; typecheck, lint and build passed; existing bundle-size warning |
| Publication-time Python discovery | 242 tests: 226 passed; 16 historical staged-acceptance/taxonomy checks reject changed runtime source hashes; historical freezes not repinned |
| Reset | Clean logical M5 start; 52 original headers and 12 SQL receipts retained in that local test; other demo state unchanged |

These counts identify particular local runs and test revisions. They are not a
fresh-clone fixture promise, an independent benchmark, a provider invoice or a
guarantee of model availability on presentation day.

## Before publication

### Recording and screenshot plan

Capture these from a real run; the following is a shot list, not a claim that
media already exists.

| Frame | What the reviewer should understand |
|---|---|
| Editable source/recipient profiles, then enrollment | The user supplies business context and chooses a real Production |
| New receiver receipt beside captured evidence | The existing business flow runs normally while the observer collects facts for review |
| Research result with exact citation | The finding concerns the actual asserted release path, not an invented blanket rule |
| AI log with both phases and session IDs | The model really executed; original output, failure state and usage are inspectable |
| Triage policy/audit trace or the optional `AdvisoryAudit` BP trace | AI Hub participates in the required Interoperability decision workflow, not just a standalone dashboard |

Keep the live workflow as the main sequence. Use the optional multi-recipient
comparison only after the viewer understands that sequence; do not spend the
opening minutes touring every platform page or every historical benchmark.

### Release gates

- [ ] Commit and publish the intended source/docs on the fork; local untracked
  implementation is not an accessible public release. Inspect the final diff
  and preserve attribution. Verify the published revision before marking this gate.
- [ ] Tag the tested release and link the listing to that exact version.
- [ ] Rehearse installation from a clean checkout on the documented platform,
  including all M5 prerequisites, published reviewer and knowledge import.
  Simplify the setup path if the rehearsal exposes undocumented manual steps.
- [ ] Confirm the authorized build-154 image/license setup and whether other
  platforms have actually been tested. Do not imply x64 acceptance from ARM64.
- [ ] Run corpus release checks with `demo`, not the optional local `full`
  rebuild. Keep the full source archive out of Git.
- [ ] Record a short clean-state walkthrough: profiles → enroll → send →
  capture → audit → AI log. Include the action-taking triage path or audit BP
  trace so the contest's workflow decision requirement is immediately evident.
- [ ] Replace relative article links with absolute public links when posting on
  Developer Community; verify the linked files exist in the published release.
- [ ] Add actual screenshots/video only after capture. Never substitute planned
  UI mockups for runtime evidence or expose credentials/model keys.
- [ ] If hosting a demo, use an appropriately secured deployment, synthetic
  data, bounded spending and access instructions. The current localhost HTTP
  demo is not safe to expose unchanged; a video is an alternative presentation.
- [ ] Reconcile any claimed monetary cost against provider pricing and billing,
  or retain the explicit “SDK counters, monetary cost not verified” statement.
- [ ] Confirm author/team identity and add all required Developer Community
  profile links for a team. Do not invent a team or claim Freshmen eligibility.
- [ ] Create/update the actual Open Exchange entry, submit it to contest 49,
  publish the article and verify external links while signed out.

The [experts' preparation advice](https://community.intersystems.com/post/what-experts-look-contest-entries)
supports a distinctive idea, first-try setup, visible strongest work and an
explanation of challenges. It explicitly says it is advice, not a formal
scoring rubric. Neither it nor previous winners can guarantee approval or rank.
