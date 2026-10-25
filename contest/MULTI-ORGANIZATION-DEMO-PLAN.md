# Multi-organization FHIR distribution and advisory audit plan

[English](./MULTI-ORGANIZATION-DEMO-PLAN.md) | [简体中文](./MULTI-ORGANIZATION-DEMO-PLAN.zh-CN.md)

Status: M0-M6 implemented and validated in the owned local EAP environment.
See [setup and browser instructions](./MULTI-ORGANIZATION-DEMO.md).

## Implementation acceptance

| Gate | Verified result |
|---|---|
| M0 | Pinned TRIAGE development connection; actual FHIR, JDBC, REST and MLLP support checked; existing configuration baseline retained |
| M1 | Four editable synthetic profiles; authenticated UI-to-IRIS save, revision conflicts and frozen historical versions verified |
| M2 | Three recipient namespaces with separate application storage; 25 actual protocol acceptance checks, seven offline receiver tests and IRIS receiver assertions passed |
| M3 | Both output variants reached all three real interfaces; hashes, FHIR version, receipts and actual message/header/session IDs verified |
| M4 | JSON and HL7 actual-wire adapters captured all branches; minimized facts exclude raw MRN; a profile update did not change earlier evidence |
| M5 | Real audit BP session 59; six AI Hub sessions 219-224; research risk identified, quality/treatment scoped no-signal; exact source spans and usage preserved |
| M6 | Live browser flow and event deep links verified; restart preserved four complete run/report hashes and twelve fresh receiver readbacks without replay or model requests; frontend and affected regressions passed |

The accepted saved run is
`multi-fe23cf92-73ec-45dc-91cc-77b0828e27dd`. Research has both a supported
Safe Harbor risk and an unresolved alternative-permission question; the UI
keeps these separate. This is not a full legal-compliance result.

The first AI acceptance used six reserved requests but its research judge
request timed out at the provider. That run remains
`completed_with_errors`, with the research branch `not_assessed`. A second
six-request acceptance was explicitly authorized by the user, not retried
automatically. Earlier failed/partial distribution attempts also remain intact.

Final focused validation: 52 frontend tests; TypeScript, lint and Vite build;
11 deterministic Python tests; organization, multi-organization, Production
evidence and business-premise IRIS suites. Vite retains a bundle-size warning.
The older `production_premises_test.py --check-complete` environment baseline
check remains blocked by pre-existing historical Production drift: an old
expected Production is absent and its saved TRIAGE hash predates this round.
The round's M0 active configuration baseline was not rewritten.

## 1. Goal and scope

Build one reproducible local demo that reads synthetic clinical data from an
IRIS FHIR Repository, transforms and distributes it to three simulated
organizations, and audits each actual outbound branch using IRIS AI Hub.
The UI must support organization setup, execution, evidence inspection and
human review without requiring terminal operations during the demonstration.

All systems run in the existing IRIS instance. The three recipients have
separate namespaces and application storage. This is logical separation,
not three physically independent systems.

The audit is advisory and post-send. It does not block delivery, modify
Production configuration, authorize a disclosure or certify HIPAA compliance.
User-confirmed synthetic profiles are sufficient scenario premises; real
hospital, contract and authorization-system integrations are out of scope.

## 2. Existing components and reuse boundaries

- Reuse the authenticated workspace, API conventions and permissions.
- Reuse Production discovery, explicit observation consent, immutable evidence,
  bounded AI review grants, knowledge provenance and human-review patterns.
- Extend evidence adapters beyond the existing M5-specific request and policy.
  Do not relabel the hard-coded M5 policy as a configurable organization profile.
- Reuse the owned `FHIRDEMO` repository foundation where compatible. The existing
  aggregation workflow writes to it; this new workflow reads from it.
- Preserve `PIPELINE`, `M5OBSERVATION`, existing approvals and historical reports.
  Do not replace their Productions or reinterpret old evidence.
- Extend existing UI surfaces rather than adding another competing workspace.

Relevant implementation references:
[Production monitoring](./src/ProductionMonitor.cls),
[business evidence](./src/ProductionBusinessEvidence.cls),
[review grants](./src/ProductionReviewService.cls),
[FHIR provisioning](./dev/AggregationProvision.cls),
[Production UI](../web/src/productions-page.tsx), and
[workspace navigation](../web/src/app.tsx).

## 3. Deployment and protocol boundaries

| Namespace | Responsibility | Interface |
|---|---|---|
| `FHIRDEMO` | Synthetic source hospital's FHIR R4 repository | Authenticated FHIR HTTP |
| `DEMODISTRIBUTION` | New source service, transformation BP and three outbound BOs | FHIR read; SQL, REST and MLLP clients |
| `DEMOQUALITY` | Hospital quality department | SQL receipt tables |
| `DEMORESEARCH` | External research center | Authenticated REST receiver and stored JSON |
| `DEMOCLINIC` | External treating clinic | HL7 V2 MLLP receiver, stored messages and ACKs |
| `TRIAGE` | Organization catalog, execution coordination, observation and AI audit | Existing protected platform API |

Before implementation, verify namespace ownership, available FHIR/HL7 classes,
SQL connectivity/driver support, gateway paths, listener ports and license
capacity. Provision only explicitly owned resources; fail on conflicts.
Use dedicated database storage for recipient application records, not shared
recipient data-global mappings.

SQL delivery must use an actual SQL client connection to `DEMOQUALITY`, with
parameterized statements. REST must issue HTTP requests; HL7 must traverse
MLLP and correlate ACKs. Namespace switching or direct global writes are not
substitutes for these protocol boundaries.

Development MCP calls remain pinned to `TRIAGE`. Follow the existing explicit
administrative provisioning pattern for namespace creation and local deployment;
do not bypass the pinned MCP configuration or expose administrative execution
through the web UI.

## 4. Organization and policy records

Maintain structured, versioned records in `TRIAGE`, entered through forms.
Use stable organization IDs; names are display values, not identity keys.

1. **Organization profile:** ID, name, type, parent organization, responsibilities,
   synthetic-scenario flag, status, revision, confirmer and confirmation time.
2. **Host association:** instance, namespace, Production, host, Business Partner
   key and organization ID. Capture the association used for each observation;
   missing or ambiguous associations remain explicit gaps.
3. **Receiving policy:** source organization, target organization, purpose,
   allowed fields/categories, prohibited fields, transformation requirements,
   date precision, conditions, scenario basis and version.
4. **Per-run context:** selected synthetic cohort, actual purpose, export
   declaration, authorization/exception facts where relevant, and user confirmation.

Business Partner remains the native association, not a free-text policy store.
An institution's general duties do not establish the purpose or permission
basis for every message. Different institutions do not automatically mean
different covered entities; model parent organization and scenario relationship.

Drafts are editable. Confirmed versions are retained; edits create new versions.
Reports retain exact profile/policy/context snapshots and hashes. Configuration
changes must not silently change historical reports or active review scope.
Receiving-policy violations and HIPAA findings are separate result dimensions.

## 5. Frozen demo scenarios

Provide one source-hospital profile and three target profiles as editable
synthetic presets. A fixture defines inputs; a separate test oracle defines
expected results and must never be sent to the model as an answer.

| Branch | Purpose and recipient | Actual output | Acceptance intent |
|---|---|---|---|
| SQL / quality | Same-hospital quality statistics | Local patient code, birth year and bounded quality indicators | Demonstrate the configured minimization rule without claiming universal HIPAA compliance |
| REST / research | External statistical research; declared Safe Harbor export | Deliberately retains synthetic name, MRN and full birth date | Main contradiction: actual content conflicts with declaration and receiving policy |
| HL7 / clinic | Actual treatment of the referred synthetic patient | Patient identity and scoped referral data in a documented HL7 V2 message | Demonstrate treatment-context reasoning; identifiers alone are not an automatic violation |

Include a corrected research-output variant for deterministic comparison.
Removing these identifiers does not prove full Safe Harbor compliance.
Do not require a model to produce an all-clear or suppress unresolved results.
The unsafe synthetic variant must be explicitly labeled and restricted to the
owned local receiver; it is not a general-purpose export option.

## 6. Message and evidence contracts

Define request/reply contracts before implementing hosts. Each run has a stable
run ID; each recipient branch has an independent delivery ID. Bind source FHIR
resource IDs and versions, source snapshot digest, profile/policy versions,
transformation version, business context, IRIS session/header IDs and receipt IDs.

Capture the actual post-transformation boundary:

- SQL: executed column inventory, bound values/digest and committed readback.
- REST: actual outbound JSON/digest, HTTP status and matching stored receipt.
- HL7: actual wire-message digest, parsed field inventory, control ID and
  correlated ACK. A transport ACK is not proof of subsequent clinical use.

Distinguish prepared, attempted, acknowledged, failed and uncertain delivery.
Preserve partial success. Do not silently replay successful branches or claim
exactly-once network delivery. Receiver-side delivery IDs support idempotency;
ambiguous outcomes require reconciliation and explicit retry.

Keep raw synthetic receiver data local. The model receives minimized evidence:
field paths, presence, date precision, declarations and necessary context,
not unbounded raw records. Unsupported payloads and incomplete capture are
coverage gaps, not no-risk findings.

## 7. UI deliverables

### Organizations: new workspace page

- List source and target organizations and their configured host associations.
- Edit profile and receiving-policy forms; show draft/confirmed version state.
- Provide **Fill example organizations** and per-organization preset buttons.
  Filling changes form drafts only; saving/confirming is explicit.
- Warn before replacing unsaved edits; repeated saves must not duplicate identities.
- Make responsibilities, accepted data, prohibited data and conditions readable
  without displaying implementation JSON.

### Distribution demo: extend the existing Synthetic demo entry

- Keep the existing demo accessible as a clearly labeled legacy scenario.
- Present a guided sequence: confirm profiles, prepare synthetic FHIR data,
  inspect setup, run one distribution, inspect receipts, authorize AI audit.
- Show the FHIR source and three branches with organization, protocol,
  namespace, mapping version, readiness and per-branch progress.
- Separate **Load synthetic FHIR data**, **Run distribution**, and
  **Authorize AI audit**. State changes, business sends and model charges
  must never be hidden behind a form-fill button.
- Display real status, errors, receipt counts and partial outcomes. Disable
  duplicate submissions and retain server-side execution state across refresh.
- Do not offer runtime infrastructure provisioning from the browser.

### Productions and review details: extend existing observation UI

- Show source/target organization badges and Business Partner mappings.
- Link each run branch to its actual message evidence and receiver receipt.
- Lead with **Result / Why / Next step**.
- Compare **allowed or declared** versus **actually sent** fields.
- Separate local-policy mismatch, AI HIPAA assessment and missing information.
- Put full citations, hashes, prompts, usage and preserved model output in
  expandable audit sections. Preserve easy access to historical reports.
- Show not-reviewed, pending, failed and unresolved states explicitly.

All new pages follow existing English UI conventions, authentication,
authorization, error handling, responsive layout and accessible form labels.

## 8. Implementation milestones and acceptance gates

| Milestone | Work, including UI | Gate before proceeding |
|---|---|---|
| M0: contracts and readiness | Verify actual IRIS APIs/protocol support; freeze scenarios, data contracts, API shapes and page flow | Deployment conflicts identified; no existing Production replaced; no model calls |
| M1: organization catalog | Persistent profiles, host associations, policies, versioned confirmation, API and Organizations forms/preset buttons | Form-to-IRIS round trip; version history; no sends or model calls from presets |
| M2: three receivers | Owned namespaces, SQL schema/client, REST receiver, MLLP receiver/ACK, authenticated access and readiness UI | Each protocol actually delivers and independently reads back a correlated receipt; negative paths tested |
| M3: FHIR distribution | Fixed synthetic FHIR seed/read, transformations, BP/BO wiring, bounded execution, distribution UI and receipts | One run reads FHIR and reaches all three recipients; expected payloads verified; no model calls |
| M4: evidence integration | Production-wide observation, actual branch inventory, organization/version binding, linked evidence UI | Actual outputs, not just FHIR inputs, reach immutable evidence; missing/mismatched bindings fail explicitly |
| M5: AI advisory audit | Existing AI Hub runtime adapted to branch evidence; bounded grants; concise comparison and report UI | Authorized real AI Hub run, preserved output/usage, validated citations and explicit per-branch conclusions |
| M6: integrated acceptance | Browser walkthrough, restart tests, regression suite and English setup documentation; update Chinese demo guide | UI-only demonstration completes; evidence survives restart; old reports remain readable |

Implement M1 with its UI rather than deferring all frontend work to the end.
M1 and M2 follow M0; M3 needs both. M4 needs the catalog, receiver evidence and
working distribution. M5 needs M4. M6 covers the complete integrated workflow.

## 9. Verification strategy

- Write regressions first for new ObjectScript behavior; compile exact classes.
  Use `%UnitTest.TestProduction` with externally managed Production lifecycle,
  nonzero test/assertion counts and zero failures.
- Run focused tests in the actual dedicated namespaces through the controlled
  deployment/test harness where necessary; keep MCP calls pinned to `TRIAGE`.
- Test profile validation, ambiguous partner mappings, stale revisions,
  permission failures and immutable report snapshots.
- Test real FHIR read and source version capture, SQL commit/readback, REST
  rejection/timeouts, HL7 parsing and negative/mismatched ACKs.
- Test identifiers in nested JSON and HL7 PID fields, birth-year versus full-date
  precision, forbidden SQL columns, missing source context and unsupported bodies.
- Verify profile fields and source text are untrusted data, not agent instructions.
- Verify partial delivery, duplicate clicks, explicit retries, receiver deduplication
  and restart persistence without re-sending completed work.
- Run focused Vitest tests, TypeScript checking, lint and production build for
  touched frontend surfaces. Validate the guided flow in a real browser.
- Keep deterministic evidence/policy checks separate from model evaluation.
  Real-provider calls require an explicit bounded authorization, with request
  limits and preserved failed attempts; no paid calls during routine development.

## 10. Final acceptance and handoff

The demo is complete only when a user can:

1. Fill, edit and confirm the source/three recipient profiles in the UI.
2. Load the fixed synthetic FHIR cohort separately from message dispatch.
3. Run distribution and inspect independently persisted SQL, REST and HL7 receipts.
4. Follow each branch to its actual outbound field inventory and organization context.
5. Explicitly authorize a bounded real AI Hub audit and inspect saved results.
6. Explain the research contradiction and the treatment-context contrast without
   treating incomplete checks as legal certification.
7. Reload/restart and reopen the same reports without replay or new model calls.

Publish setup and test commands, exact local URLs and ports verified during
implementation, namespace ownership, required privileges, fixtures and limitations.
Update the existing demo guide rather than describing new functionality as
already available. No upstream repository changes or historical evidence resets.
