# Production HIPAA review demo and recording script

For the current **live first-enrollment → new message → new audit** presentation,
use [the fixed M5 onboarding demo](./M5-ONBOARDING-DEMO.md).
The numbered records below are historical acceptance references. A scoped M5
reset archives their old monitoring view, so do not require them to appear in
the current Production review list or replay the old paid harness to restore it.

[Chinese operations guide with system URLs and step-by-step highlights](./DEMO-GUIDE.zh-CN.md)

## What this demonstration shows

An IRIS Interoperability Production carries synthetic messages. A separate
observer records actual message edges and minimized structured facts.
The user supplies and confirms the business background during review approval.
IRIS binds that approval to one message session, calls the real AI Hub Agent,
validates the structured result and exact source citations, and stores an
advisory finding.

**Demo inputs are usable facts within the simulation.** Connecting to a real
hospital, contract repository or authorization system is not required.
The UI distinguishes those inputs from collected message evidence. Unknown
answers remain unknown, and the approver does not choose the AI verdict.

The flow demonstrated here is:

```text
Actual synthetic BS -> BP -> BO message
                |
        Independent observation
                |
User-confirmed session-scoped business premises + paid-review consent
                |
  AI Hub locator -> IRIS prepares normative evidence -> AI Hub judge
                |
   IRIS grounding/citation checks -> stored finding -> human inspection
```

This Production-wide reviewer is **advisory after-send monitoring**. It does
not block delivery, quarantine a message or replay it. The repository's
separate original triage BP demonstrates bounded AI routing and execution;
see the [installation and triage guide](./README.md). Do not describe an
after-send finding as if it prevented the already completed disclosure.

## Choose the demonstration mode

| Mode | Suitable for | Side effects |
|---|---|---|
| Inspect saved real results | The fixed walkthrough and video below | Reads existing records; no new model requests or business sends |
| Preview a new approval | Explain how users supply demo facts | Unsaved form/preview only, unless final paid confirmation is clicked |
| Execute new cases | Separately authorized development acceptance | New synthetic sends and paid model calls; not part of this recording route |

The saved records are local acceptance data, not bundled fixtures in a clean
clone. Starting the basic mock stack does **not** recreate them. A missing
record is a setup gap, not permission to substitute screenshots or invented
success data.

## Before recording

1. Use the already provisioned local environment. For a new installation, first
   follow the [IRIS/EAP requirements and setup](./README.md#requirements) and
   [UI setup](../web/README.md#run-without-host-node). The tested runtime is
   IRIS for Health `2026.3.0AI.154.0`; an authorized EAP image and your own
   license are required. AI Hub EAP APIs may change.
2. Open <http://localhost:5173/pipelines>. Sign in with an existing authorized
   local account, then start screen capture **after** login. Do not record
   credentials, environment files, provider keys or authorization headers.
   A full browser reload requires signing in again.
3. Confirm **M5OBSERVATION / Contest.M5.Production** appears in the inventory.
   It is already enrolled. Do not re-enroll, restart or reconfigure it.
4. Run the read-only saved-result check from the repository root:

   ```sh
   python3 contest/production_premises_test.py --check-complete
   ```

   It requires the provisioned local API, its existing local credential files
   and persistent IRIS reports. The final summary must contain:

   ```json
   {
     "status": "passed_after_explicit_input_mapping_repair",
     "first_pass": "2/3",
     "usage_including_failed_first_case": {
       "requests": 8,
       "tokens": 116871,
       "citations": 15
     },
     "business_sends_in_saved_runs": 4,
     "all_grants_revoked": true,
     "new_model_calls": 0,
     "new_business_sends": 0
   }
   ```

   The actual command also prints per-case checks and the follow-up summary.
   Stop if it fails. Do not delete the journals or rerun paid commands to
   conceal a failure.
5. Use a readable browser zoom and close unrelated tabs, notifications and
   developer tools. Keep raw JSON panels closed until needed.

## Fixed browser walkthrough

### 1. Discover and select a Production

On **Managed Productions**, click **Discover active Productions** to display
the accessible active namespaces/Productions. This is a read, not enrollment
or paid inference. Explain that the user chooses which Production to monitor.

Click **Inspect M5OBSERVATION / Contest.M5.Production** in the inventory.
Show the Production-wide scope and actual message-edge/evidence panels.
Individual business flows are not an enrollment prerequisite. The evidence
is bounded and sampled; it is not proof of all downstream behavior.

### 2. Normal treatment disclosure: header 30

In **Sampled review records**, click **Review detail 30**.
If needed, use the review pagination controls; do not confuse the evidence
page's pagination with the review page's pagination.

Show these items in order:

- **Scoped assessment: no signal on checked issues**.
- **User-approved demo premises**: confirming user/time, session 30, external
  treating clinic, treatment purpose, authorization not relied upon.
- The explicit technical-host/recipient mapping and message data scope:
  internal transport hosts are not separate business recipients; the receiver
  represents the named clinic in this simulation.
- The reasoning and exact quotations supporting treatment permission under
  164.506(c)(2) and the treatment-disclosure exception under 164.502(b)(2)(i).

Explain: a full birth date and lack of individual authorization do not,
by themselves, establish a failure for this stipulated treatment disclosure.
This is a scoped result, not a blanket declaration that the organization is
HIPAA compliant.

### 3. Paid marketing without required authorization: header 22

Click **Review detail 22**. Show **risk identified**, the paid unrelated-product
marketing purpose, the explicitly absent authorization and the excluded
applicable exceptions. Show the 164.508 marketing-condition citation.

Explain that this finding is based on an affirmative failed condition, not
merely a document that was not supplied. A processor agreement does not
substitute for the required individual authorization in this scenario.

### 4. Unknown business conditions: header 26

Click **Review detail 26**. Show **information required**, the explicit unknown
recipient/permission inputs, and **Material information required**.

Explain that the system asks for the missing facts rather than inventing
permission, inventing a violation or equating unknown with absent authorization.

### 5. Show the retained failure and repair

Click **Review detail 18**. The original treatment result is still
**information required** because its approval did not explain the connection
between technical hosts, business recipient and patient/activity scope.

Return to **Review detail 30** to show the separately approved mapping repair.
The first pass was 2/3; the treatment follow-up passed the unchanged expected
legal conditions after the form/input contract was fixed. The original report
was not overwritten. Do not present this as a first-pass 3/3 or held-out test.

### 6. Show auditability and spending boundaries

Expand **AI Hub sessions, usage, prompts and preserved output** on one report
to show the real locator/judge sessions and recorded usage. Expand **Dated
normative sources and provenance** only if a closer source inspection is useful.

In **Durable AI authorization history**, show the four `m5-premises-*` grants:
each is revoked and has one reserved review/two requests. The combined run
used four new synthetic messages, eight requests, 116,871 reported tokens and
15 exact citations, including the first treatment attempt. Token counts are
not a monetary cost estimate; pricing and billing have not been calculated.

### 7. Optional form preview, without a new call

On a captured message, click **Use session ... for demo approval**.
The **AI review approval, demo business premises and bounded funding** panel
opens. Explain the recipient, purpose, permission/authorization, safeguards,
special conditions, host mapping and data-scope inputs.

Keep the business-premise confirmation and cost/export confirmations unchecked
for this recording. Explain that final paid confirmation is a separate step.
Do **not** click **Confirm paid review authorization** or authorize new
inspection. Existing terminal reviews are not automatically reassessed.
Selecting a session or typing into the form does not itself call a model.

## Five-minute English narration

| Time | Screen | Suggested narration |
|---|---|---|
| 0:00-0:25 | Production inventory | "This demo combines IRIS Interoperability events, user-approved business context and an actual AI Hub Agent. We select a Production, not individual business flows. Today I am inspecting stored results from real local executions; playback makes no new model calls." |
| 0:25-0:55 | Actual edges and message evidence | "IRIS records actual message edges and bounded, minimized field evidence. Business facts such as recipient relationship and intended purpose are supplied by the approver as explicit demo premises. No connection to a real hospital is needed." |
| 0:55-1:45 | Review 30 | "For ordinary disclosure to the treating clinic, the result is no signal on the checked issues. The approval explains how technical hosts represent the clinic and which patient activity the message concerns. The reviewer cites treatment permission and the minimum-necessary treatment exception, rather than treating a full birth date as automatically prohibited." |
| 1:45-2:25 | Review 22 | "The second case is paid marketing without the required authorization, with relevant exceptions excluded. The Agent identifies a specific authorization risk and supplies exact, source-bound citations. A general approval label or processor agreement is not treated as legal permission." |
| 2:25-3:00 | Review 26 | "Here, recipient and permission are explicitly unknown. The correct result is information required. Missing facts do not become a violation, and unknown authorization does not become absent authorization." |
| 3:00-3:35 | Reviews 18, then 30 | "We preserve unsuccessful attempts. Our first treatment test lacked a clear link from technical hosts to business context. We added explicit mapping fields and ran a separately authorized follow-up with the same expected legal conditions. The old report remains visible." |
| 3:35-4:15 | SDK usage, sources, revoked grants | "These are actual AI Hub locator and judge sessions. IRIS validates structured grounding and exact source passages. All four grants are revoked. Including the first attempt, this run used eight requests and 116,871 reported tokens. These counts are not a monetary cost estimate." |
| 4:15-5:00 | Approval form, then final report | "Users provide the scenario during approval, and the report separates their inputs from message evidence. Unknowns remain explicit. This is advisory after-send monitoring: it does not claim to prevent an already completed disclosure, execute arbitrary actions or certify real-world compliance." |

## Recording and publication checklist

- Record a continuous browser walkthrough or label edits/time cuts clearly.
  Saved results must be introduced as saved real executions, not live inference.
- Keep the English narration and captions consistent with the script; show the
  scoped result, approval inputs and citations, not just a green status badge.
- Do not show credentials, local secret files, real PHI or unrelated data.
- Identify the tested EAP build and the published `deepseek-flash` Agent used
  by these reports. Preserve the stored revision/contract provenance.
- Source evidence uses released dated normative snapshots, not independently
  verified live law. The broader eight-case benchmark is assistant-authored,
  not independent expert validation or a population accuracy estimate.
- The development MCP/IRIS Agentic Dev tools assist implementation and testing;
  they are not the runtime business Agent.
- Credit the [original DataPipelineDemo](https://github.com/zlnick/DataPipelineDemo)
  and the inherited UI notices. Explain the fork's added workflows and evidence
  controls rather than implying the entire project was created from scratch.
- Add a public video URL only after a recording is created, reviewed and
  uploaded with approval. This guide is a recording script, **not a recorded
  or published video**. Contest submission and organizer acceptance remain
  separate from this technical demonstration.

For full results, limitations and the repair history, see
[M5 live acceptance](./MONITORING.md#m5-approval-input-live-acceptance-and-explicit-repair).
