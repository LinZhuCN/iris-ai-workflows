# Production HIPAA Risk Review Demo Guide

**Language:** English · [简体中文](./DEMO-GUIDE.zh-CN.md)

**For the current full live demo, use the [M5 onboarding-to-audit guide](./M5-ONBOARDING-DEMO.md).**
The fixed subject is `M5OBSERVATION / Contest.M5.Production`, demonstrated from
institution entry through a live trigger and review, rather than by substituting
historical report playback. The multi-organization scenario and numbered cases
below remain historical references. The M5-scoped reset archives the old
monitoring view; the old numbered cases should no longer be expected in the
current list.

## New main demo: FHIR distribution to three organizations

For installation, protocol boundaries and acceptance commands for the new
scenario, see the [multi-organization demo guide](./MULTI-ORGANIZATION-DEMO.md).
The original numbered M5 cases below remain as a historical demo; do not mix
their message numbers with those from the new scenario.

| Entry | Address | What to show |
|---|---|---|
| Organization profiles | [Organizations](http://localhost:5173/organizations) | Example values are editable; confirm responsibilities, business relationships and receiving scope; versions are retained |
| New main demo | [Synthetic demo](http://localhost:5173/demo) | FHIR source, three real protocol branches, receiver acknowledgements and per-organization AI audits |
| Production monitoring | [Productions](http://localhost:5173/pipelines) | Select `DEMODISTRIBUTION / Contest.Multi.Production`; inspect actual paths, Business Partners and human-event handling |
| Original Connector demo | [Legacy demo](http://localhost:5173/demo/legacy) | The original demo remains accessible; do not mix it with the new scenario |

Present the scenario in six steps:

1. **Organization profiles:** Create four profiles: one source hospital and three recipients. **Fill example** only populates the form; **Save for demo** saves it as a scenario premise and creates a version. No separate confirmation checkbox is required.
2. **Monitoring authorization:** Discover the Production on Productions and click **Enable read-only monitoring**. An already enrolled Production displays its status. General Production message-field inspection still has its own operation button, but no longer requires a prior checkbox.
3. **Prepare and distribute:** Return to the new demo and click **Prepare demo data** to prepare synthetic FHIR data; select a case and click **Run distribution**. Neither step requires a checkbox. The three organizations are in `DEMOQUALITY`, `DEMORESEARCH` and `DEMOCLINIC`.
4. **Actual receiver evidence:** SQL shows actual columns and database readback; REST shows actual JSON and its receipt; HL7 shows PID fields, an MLLP ACK and the stored message. Compare “permitted to receive” with “actually sent.”
5. **AI audit:** Keep the single model-cost confirmation, then click **Run AI audit**. Each run performs at most three reviews and six model requests, with no automatic paid retry. Do not reconfirm “this is synthetic data.” AI Hub runs inside the `AdvisoryAudit` BP; this sidecar audit does not block delivery.
6. **Read the results:** Start with Result / Why / Next step. Expand legal quotations, AI Hub sessions, usage and original output only when more detail is needed. A technical failure is not a no-risk result, and a review that has not run is not a no-risk result.

The risk narrative is: **both the research recipient's agreement and the
message declaration require Safe Harbor de-identification, but the actual REST
output still contains a name, MRN and full date of birth.** The treating clinic
provides a contrast: the same kinds of identifiers should not be treated as a
violation without considering the actual treatment context. Correcting the
research output proves only that the selected fields were removed; it does not
prove complete Safe Harbor compliance.

Viewing an existing run or opening `/demo?run=<已保存编号>` does not resend a
message or call a model. There is no real hospital, contract system or real
patient; the confirmed organization profiles are business premises established
within the demo.

**Show the verified result directly:**
[Open this round's main demo](http://localhost:5173/demo?run=multi-fe23cf92-73ec-45dc-91cc-77b0828e27dd).
The research branch found a Safe Harbor condition risk; whether other research
permissions are met remains separately marked as information required.
Quality and treatment branches found no signal only on the issues checked.
The actual audit BP session is `59`, and AI Hub sessions are `219–224`; viewing
these records incurs no new cost. The initial model-timeout failure remains
recorded and has not been “corrected” into a success.

## 1. Demo objective and route

This guide is for the current local demo environment and follows this sequence:

**Select a Production → inspect actual messages → explain user-approved context → show three assessment outcomes → inspect sources and audit records.**

The central capability to explain is:

> The user chooses which Production to monitor. The system collects actual messages, combines them with business context supplied during user approval, and uses a real AI Hub Agent to assess HIPAA conditions and present the assessment, legal sources and information still needed.

By default, this guide shows **results that have already been executed and
saved**. It does not send new messages or call a model. This is not a static
fake-data page, but viewing a historical report must not be described as
“inference happening live.”

### Scope

- Business context supplied and confirmed by the user is a **scenario premise established within the demo**; no connection to a real hospital, contract or authorization system is required.
- The user supplies facts, not the model answer to choose; unclear items can be entered as unknown.
- The monitored unit is the entire Production; individual business flows do not need separate registration.
- This demo shows **post-send risk review and notification**, not pre-send blocking.
- “No signal on the issues checked” does not mean the organization has received HIPAA compliance certification.
- The recipient's actual subsequent use is outside the current observation scope.

## 2. System addresses and entry points

The addresses below refer to the current **local deployment**. On another
computer, `localhost` resolves to that computer, not to this demo environment.
The current HTTP service is for local demonstration only and should not be
exposed directly to the public internet.

### 2.1 Required main-demo addresses

| System / page | Address | Purpose |
|---|---|---|
| Main Production monitoring page | [http://localhost:5173/pipelines](http://localhost:5173/pipelines) | Main entry for this demo: discover and select a Production, then inspect messages and review results |
| IRIS Management Portal, real AI Hub environment | [http://127.0.0.1:52779/csp/sys/UtilHome.csp](http://127.0.0.1:52779/csp/sys/UtilHome.csp) | Optional supporting view of namespaces, Productions and actual Interoperability messages; requires a separate sign-in |

Usually only the first address is needed for the main demo; **there is no need
to switch repeatedly among pages**. The frontend uses a local proxy to access
the current IRIS environment on `52779`.

### 2.2 Optional supporting pages

| Page | Address | When to use it |
|---|---|---|
| Workspace overview | [http://localhost:5173/overview](http://localhost:5173/overview) | Briefly introduce platform navigation; not primary evidence for this review result |
| Data-use requests and approvals | [http://localhost:5173/declarations](http://localhost:5173/declarations) | Optional introduction to the separate request, versioning, AI review and human-approval workflow; not a required step in this Production case |
| Agents | [http://localhost:5173/agents](http://localhost:5173/agents) | Optional introduction to Agent configuration and versions; the specific model-call records for this demo are in each message report |
| Knowledge | [http://localhost:5173/knowledge](http://localhost:5173/knowledge) | Optional introduction to knowledge retrieval and sources; do not rebuild the index casually for a demo |
| Runs | [http://localhost:5173/runs](http://localhost:5173/runs) | View other independent assessment tasks; view the four Production reports for this demo within Productions |

### 2.3 Addresses to avoid confusing

| Address | Explanation |
|---|---|
| [http://127.0.0.1:52777/csp/sys/UtilHome.csp](http://127.0.0.1:52777/csp/sys/UtilHome.csp) | Portal address for the basic mock deployment, available only when the corresponding service is running; this is not the `52779` environment used for the real-model acceptance run |
| [http://localhost:5173/governance](http://localhost:5173/governance) | Legacy routes page for a different fixed routing-governance demo; do not mistake it for the main Production page in this walkthrough |
| [http://localhost:5173/demo](http://localhost:5173/demo) | The original Synthetic demo page, not the page for the three HIPAA review outcomes in this guide |

### Sign-in notes

- Use an existing authorized local account on the workspace sign-in page. This guide does not record passwords, API keys or authorization headers.
- If the local sign-in page has a demo account prefilled, you must still click **Sign in**; it does not sign in automatically.
- Workspace pages share the current signed-in identity; after a full-page refresh or opening a new tab, you may need to sign in again.
- The IRIS Portal and frontend workspace do not share a sign-in session.
- A regular read-only account can inspect records it is authorized to access; discovery and approval operations require the appropriate permissions.

## 3. Fixed demo subject and case reference

### Demo subject

| Item | Value |
|---|---|
| Frontend page | Productions, path `/pipelines` |
| Business namespace | `M5OBSERVATION` |
| Business Production | `Contest.M5.Production` |
| Control plane, review and audit namespace | `TRIAGE` |
| Button for the selected object | **Inspect M5OBSERVATION / Contest.M5.Production** |

### Four actual reports

| Demo order | Case | Session | Representative message Header | Button | Expected display |
|---|---|---:|---:|---|---|
| 1 | Ordinary treatment disclosure, with message-to-business mapping supplied | 30 | 30 | **Review detail 30** | `no signal on checked issues` |
| 2 | Paid marketing, with required individual authorization explicitly absent | 22 | 22 | **Review detail 22** | `risk identified` |
| 3 | Recipient, purpose or permission condition unknown | 26 | 26 | **Review detail 26** | `information required` |
| 4, brief contrast | First treatment case, with insufficient mapping explanation | 18 | 18 | **Review detail 18** | `information required`, retained first result |

These Headers and Sessions are **historical identifiers from the current local
acceptance environment**; they are not fixed numbers for all deployments.
Select the relevant Production on the Productions page before opening each
report. There is currently no separate frontend URL that directly locates a
report by these numbers; do not invent query parameters.

A fresh clone does not include the complete local acceptance database or
Git-ignored runtime records. Starting the basic environment will not
automatically generate these four reports.

## 4. Pre-demo checks

1. Open the [Production page](http://localhost:5173/pipelines) and sign in.
2. Confirm the inventory contains **M5OBSERVATION / Contest.M5.Production**.
3. Click its **Inspect** button and confirm the page shows no error.
4. Confirm all four reports are available under **Sampled review records**;
   use **Older review records** pagination if necessary. Message evidence and
   review lists have independent pagination.
5. Confirm the relevant `m5-premises-*` model authorizations show **Revoked**.
6. For terminal verification, run from the repository root:

   ```sh
   python3 contest/production_premises_test.py --check-complete
   ```

   This is a read-only check; it does not send messages or call a model. It
   requires the existing local service, credential files and persistent reports.
   The final output should show:

   - `status: passed_after_explicit_input_mapping_repair`
   - `first_pass: 2/3`
   - `all_grants_revoked: true`
   - `new_model_calls: 0`
   - `new_business_sends: 0`

If data are missing or the check fails, investigate the environment first. Do
not clear historical data, reset the journal or immediately rerun the paid
acceptance test. The ports and results in this guide come from the existing
configuration and acceptance records; they do not mean that the services will
always be online.

## 5. Step-by-step demo and key points

### Step 1: Discover and select a Production

**Entry:** [Productions](http://localhost:5173/pipelines).

**Actions:**

1. Click **Discover active Productions**.
2. Show the discovered namespace / Production list.
3. Return to the inventory and click **Inspect M5OBSERVATION / Contest.M5.Production**.
4. This object is already enrolled; do not click **Enroll selected Production** again.

**Key points:**

- The system scans accessible IRIS namespaces and discovers active Productions.
- The user chooses what to monitor; the system does not indiscriminately take over all business operations.
- The Production is the enrollment unit. Its internal business paths are within the observation scope; individual path registration is unnecessary.
- Enrollment does not restart or modify the business Production, and does not automatically grant message-content access or model-spending permission.

**Suggested wording:**

> First decide which Production to monitor. Once selected, monitoring covers its component activity rather than only one route chosen manually.

### Step 2: Inspect actual messages and business-path evidence

**Location:** Actual message edges for the selected Production and sections such as **Message evidence and session correlation**.

**Actions:**

1. Show actual message edges between components.
2. Find a message and point out its Header, Session, Source, Target and capture status.
3. Click **Correlate session 30** (if the corresponding message is on the current page); alternatively, enter `30` in **Exact source session (optional)** and click **Filter evidence by session**.
4. Inspect related messages in the same session; expand minimized facts and provenance if needed.

Clicking **Inspect evidence / review …** or **Review detail …** loads the
corresponding detail and automatically scrolls to the detail area beneath
**Sampled review records**. You can click the same item again to reload it;
read errors appear in that area and do not call a model. If the status is
`unsupported`, that message type has no applicable structured-collection
adapter; the button has not failed, and this is not a “no risk” conclusion.
For the three main cases below, inspect Headers `30`, `22` and `26`.

**Key points:**

- These are records of actual messages, not just a static configuration diagram.
- A Session links related messages; a Header identifies one specific message record. They are different concepts.
- Collection scope, unsupported formats, missing authorization and collection failures all have explicit statuses.
- **Successful technical processing does not mean HIPAA compliance, and technical processing failure does not automatically mean HIPAA risk.**

**Caution:** Observation is sampled and bounded to structured fields. Do not claim that all content or all subsequent recipient behavior is fully known.

### Step 3: Explain how the user supplies business context

**Location:** **Use session … for demo approval** on a message and
**AI review approval, demo business premises and bounded funding**.

**Actions:**

1. Click **Use session … for demo approval** on a captured message.
2. Show the source session populated automatically.
3. Introduce the form fields in order; do not submit:

   | Input | Question to explain |
   |---|---|
   | Recipient / relationship | Who receives the data: an internal team, treating provider, business partner or another external organization? |
   | Actual intended use | What activity will actually use the data? |
   | Permission basis | Which type of permission is proposed for this case? The user does not decide the legal conclusion in advance. |
   | Individual authorization | Is it explicitly present, explicitly absent, not relied upon, or not yet known? |
   | Permission details | What data, authorization scope, validity and special conditions are involved? |
   | Safeguards / exceptions | What access limits, necessity explanation and applicable exceptions apply? |
   | Technical-host / recipient mapping | How do technical components such as `ProcessB` and `ReceiverB` represent the business recipient? |
   | Message data scope | Does this session's data belong to the stated patient, business activity and scope? |

4. Point out that business-premise confirmation, data-export confirmation, cost confirmation and final paid approval are explicit steps.
5. For this walkthrough, show the form only: leave confirmation boxes unchecked and do not perform final paid approval.

**Key points:**

- The user supplies and confirms demo business facts; there is no need to connect a real hospital system.
- Context is bound to the specified session for this Production/configuration and cannot be generalized to other messages.
- The user cannot enter the expected assessment result; the system still has to assess applicability, conditions and exceptions.
- Unknown is neither evidence of a violation nor permission by default.
- User input and collected facts are displayed separately in the report, with the confirming person and time recorded.

**Suggested wording:**

> IRIS can show how the message travelled, but the user needs to explain the business purpose. The approver states the demo premises, then AI assesses them: the AI does not guess organizational relationships, and the user does not select the assessment answer.

### Step 4: Ordinary treatment disclosure

**Action:** Click **Review detail 30** in **Sampled review records**.

Show these in order:

1. **No risk found in this check**: no risk was found in this check. Start with **Why** and **Next**.
2. Expand **Business background supplied by the user** and show the confirming person, confirmation time and session.
3. The scenario conditions: external treating provider, treatment purpose and no reliance on individual authorization.
4. The mapping between technical components and recipient, as well as patient / activity / data scope.
5. The explanation and exact source quotations:
   - `164.506(c)(2)`: permission for treatment disclosure;
   - `164.502(b)(2)(i)`: minimum-necessary exception for disclosure to a treating provider.

**Key point:**

> Do not mechanically flag a full birth date or lack of individual authorization. The system considers the treatment purpose, applicable conditions and exceptions when assessing this check.

**Expected result:** No risk found on the issues checked; do not present this as “the hospital is fully compliant.”

### Step 5: Paid marketing without required authorization

**Action:** Click **Review detail 22**.

Show these in order:

1. **Potential risk found**: a potential risk was found. Start with **Why** and **Next**; the full analysis and quotations are under **Full reasoning and legal references**.
2. The user explicitly states the paid marketing purpose and absence of individual authorization.
3. Applicable exceptions are explicitly excluded in the scenario.
4. The explanation and `164.508` marketing-authorization condition quotation.

**Key point:**

> The system identifies an explicitly failed applicable condition; it does not declare a violation merely because an uploaded document is missing. The conclusion changes when the business purpose and authorization change.

The business associate agreement in this scenario does not replace the
required individual marketing authorization. Do not generalize this to say
that “all business partners need individual authorization.”

### Step 6: Insufficient information; do not guess at risk

**Action:** Click **Review detail 26**.

Show these in order:

1. **More information needed**: information is insufficient. Go directly to the requested details under **Missing information**.
2. The user explicitly entered the recipient relationship and permission conditions as unknown.
3. The specific questions listed under **Material information required**.

**Key point:**

> “It is not known whether authorization exists” differs from “authorization is confirmed absent.” When evidence is insufficient, the system asks questions rather than inventing permission or inventing a violation.

### Step 7: Trace the reasoning and model calls

**Action:** Choose a report, such as **Review detail 30**, and expand:

- **AI Hub sessions, usage, prompts and preserved output**
- **Dated normative sources and provenance**
- **Frozen observation and optional context** (if needed)

Then inspect **Durable AI authorization history**.

**Key points:**

- The review used actual AI Hub locator / judge sessions; it is not a static rules result relabelled as AI.
- Business input, message evidence, model output and legal text can be traced.
- Citations are checked for issue association, content hash and exact text range.
- Authorization is separate and budget-limited; opening or refreshing the page does not keep calling the model.

**Historical usage for this run:**

| Item | Amount |
|---|---:|
| New synthetic messages sent | 4, including the first treatment attempt and follow-up validation |
| Model requests | 8 |
| Reported model tokens | 116,871 |
| Verified citations | 15 |
| Current authorizations | All four related grants are `Revoked` |

These are historical usage amounts already incurred; viewing reports adds no
calls. Token counts are not a monetary bill; do not invent a monetary cost from
them.

### Step 8: Show the first-pass issue and repair while preserving history

**Actions:**

1. Open **Review detail 18**.
2. Show that it remains **information required**.
3. Point out that the missing information was the mapping among technical components, the business recipient and message data scope.
4. Return to **Review detail 30** and show the result after providing explicit context.

**Key points:**

- Two of the first three cases passed; the treatment case required additional mapping information.
- The form and input contract changed; the expected answer was not changed to match the output.
- A new message was sent for separately authorized follow-up validation. The old report was not overwritten, and the old message was not replayed.
- Do not describe this as “all three passed on the first attempt” or as an independent blind test.

If time is short, this step can be a brief closing note; there is no need to
begin with development history.

## 6. Recommended concise demo sequence

| Order | Action | One-line takeaway |
|---|---|---|
| 1 | Discover Productions and select M5 | Enroll the whole Production, not individual flows |
| 2 | Inspect message edges and session evidence | Technical events come from actual messages, not a static diagram |
| 3 | Show the approval context form | The user supplies demo premises; AI does not guess business context |
| 4 | View report 30 | Understand permission and exceptions; do not flag mechanically |
| 5 | View report 22 | Identify an explicitly failed authorization condition as a risk |
| 6 | View report 26 | Ask when information is insufficient; do not confuse unknown with absent |
| 7 | Inspect sources, SDK sessions and revoked authorizations | Evidence is traceable and calls have boundaries |
| 8 | Compare 18 with 30 | Preserve the issue and repair history; do not overwrite results |

**Closing summary:**

> This demo connects actual Interoperability messages, user-approved context and HIPAA provisions, and shows three explainable outcomes: a risk identified, no signal on the issues checked, and more information required. It is a controlled after-send review, not automatic legal certification.

## 7. Optional supporting view in the IRIS Portal

If the audience wants to verify that the business Production is running in IRIS:

1. Open the [real-environment IRIS Portal](http://127.0.0.1:52779/csp/sys/UtilHome.csp) and sign in separately.
2. Switch the namespace to **M5OBSERVATION**.
3. In the Interoperability menus, open the Production configuration / status page and inspect **Contest.M5.Production**; menu labels may differ by IRIS version.
4. To inspect messages, use the message viewer in the relevant namespace and locate sessions `30`, `22`, `26` or `18`.
5. Return to the frontend without clicking start, stop, update, resend or cleanup operations.

The main point is the actual BS/BP/BO and message runtime record. `TRIAGE` is
the control-plane and review namespace; do not look for `M5OBSERVATION`
business messages in `TRIAGE`.

## 8. Operational boundaries and common questions

### Safe actions for this walkthrough

- Sign in, discover, select and refresh.
- Filter by Session, paginate and inspect details.
- Expand sources, audit data, sessions and authorization history.
- Open the approval form and fill it in without submitting.

### Not part of this read-only walkthrough

- **Confirm paid review authorization**: may immediately start paid background inference.
- **Authorize local synthetic inspection**: changes authorization for future message-content collection.
- Send a new message, rerun `--run`, restart or reconfigure the Production.
- Delete a journal, old report or historical authorization record.

### A report cannot be found

First confirm that **M5OBSERVATION / Contest.M5.Production** is selected, then
check pagination under **Sampled review records**. A new environment without
historical data must be prepared using the installation and acceptance
procedure; this guide does not imply that paid execution is required to “view
results.”

### The page shows a sign-in screen or a permission error

Sign in again after a full-page refresh. If permissions are insufficient, use
an existing authorized account; do not change account permissions or
credentials casually for a demo.

### The page cannot connect

Check that the local UI, IRIS and Web Gateway are running, and that the UI
targets `52779`. Do not accidentally connect to the `52777` mock environment.
See the [IRIS environment guide](./README.md) and [frontend guide](../web/README.md)
for installation and startup.

### Does “no risk” mean compliance certification?

No. It means only that no risk was found for the conditions checked within the
current demo premises and observation scope. Legal sources come from a
date-stamped prepared corpus; exact citation validation is not independent
certification of legal currency, semantics or overall compliance.

### Why is connection to a real business system not required?

This is a demo. Synthetic context confirmed by the user during approval can
serve as its scenario premise. Integration with real systems is a future
deployment extension, not a prerequisite for the current demo.

## 9. Related material

- [Separate English walkthrough script with historical numbered cases](./DEMO-WALKTHROUGH.md)
- [Implementation status, evidence boundaries and M5 acceptance record](./MONITORING.md#m5-approval-input-live-acceptance-and-explicit-repair)
- [Installation and runtime guide](./README.md)
- [Frontend runtime and sign-in guide](../web/README.md)
- [Original DataPipelineDemo project](https://github.com/zlnick/DataPipelineDemo)

This guide was added on 2026-10-21. Case numbers and usage amounts correspond
to saved local acceptance results from 2026-10-20.
