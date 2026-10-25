# Live M5 Production onboarding demonstration

[English](./M5-ONBOARDING-DEMO.md) · [简体中文](./M5-ONBOARDING-DEMO.zh-CN.md)

## Fixed demonstration

Open <http://localhost:5173/demo/m5>. The only target is
`M5OBSERVATION / Contest.M5.Production`; the business Production and SQL receiver
are already deployed. The presentation is **enter organizations → enroll →
send → observe → audit → explain**, not a replay of precomputed findings.
No new namespace or Production copy is needed.

The fixed flow is `M5Source → ProcessB → ReceiverB → SQLUser.M5Receipt`.
Within this simulation, the first two hosts represent the source hospital and
`ReceiverB` represents the external research institution. This protected
scenario mapping and the profile Business Partner keys are frozen with each
run; saving a profile does not rewrite native host configuration.

The synthetic research message declares Safe Harbor de-identification while
containing a synthetic name, MRN and complete birth date. The recipient's
default profile permits only birth year/status. The reviewer compares the
actual field inventory and date precision against the declared release path
and the frozen profiles. Alternative PHI permission is not invented.

## Before presenting

The existing real AI Hub/EAP installation, M5 foundation, timer/observer,
published reviewer, knowledge index and local workspace authentication must
already work. See [platform requirements](./README.md) and
[generic monitoring](./MONITORING.md). If the owned M5 foundation has not yet
been provisioned, use the explicit `setup()` implementation in
[the M5 acceptance harness](./production_acceptance_test.py); never run its
paid acceptance merely to install the new UI.

Install the new sources without sending or invoking a model:

```sh
python3 contest/m5_demo.py --install
```

Development acceptance (not a presentation prerequisite on every launch):

```sh
# Archives M5 logical state, sends ONE synthetic message, funds at most TWO
# model requests. Refuses an existing acceptance journal.
python3 contest/m5_demo.py --run

# Read-only: verify the saved real report, even after logical reset.
python3 contest/m5_demo.py --check

# Archive/reset only the fixed M5 demonstration to a clean logical start.
python3 contest/m5_demo.py --reset
```

The first acceptance stopped before inference because the eligible list also
contained a draft Agent. After explicitly filtering for the published reviewer,
the same saved message and consent were resumed. A JSON-boolean defect was
also corrected before any model request. There was no replacement message or
extra paid attempt. One real audit completed with sessions **226 and 227**,
two requests, and a scoped `risk_identified` result. SDK usage was 28,912 prompt
and 14,714 completion tokens (43,626 total); this is not a provider invoice.
The harness keeps the attempt journal in ignored local data.

`--resume` only reconciles that retained delivered attempt and its exact
consent. It never allocates another message or replacement budget.

## Presentation steps

1. **Start clean.** Sign in at `/demo/m5`. Confirm the fixed namespace and
   Production, no saved M5 profiles/runs, and an unenrolled status.
   For another rehearsal, use **Archive and reset M5 demo** only after checking
   its scope and typing `RESET M5 DEMO`.
2. **Enter organization descriptions.** For **Source hospital** and
   **Research recipient**, click **Fill example**, explain responsibilities,
   purpose, allowed/prohibited fields and receiving requirements, then click
   **Save for demo** on each form. Presets only populate editable drafts.
   These profiles belong to the M5 demo, not the shared multi-organization
   catalog. Each send freezes the exact saved revisions and hashes.
3. **Enroll.** Click **Enroll M5 Production**. Explain that this enrolls the
   entire fixed Production for independent observation without restarting it.
   The linked Productions workspace also shows its inventory and events.
4. **Authorize local inspection.** Click **Authorize local inspection**
   before sending. This authorizes registered synthetic-property capture;
   it does not fund AI or backfill old bodies.
5. **Trigger the business flow.** Click **Send fixed synthetic research data**
   once. This is an actual BS/BP/BO execution and SQL receiver readback.
   Show the message ID, source session and receiver header. A header/receipt
   alone is not a completed field capture or a compliance verdict.
6. **Show new monitoring evidence.** Wait for the background observer.
   Show the actual captured state, host edge, field inventory and full-date
   precision. Use **Refresh status** if needed; it never resends. The
   Productions workspace provides the broader observed edges, session
   correlation and monitoring events.
7. **Authorize the audit.** Select the published reviewer, acknowledge model
   charges and click **Authorize bounded AI audit**. It permits one eligible
   session/body review and at most two requests, expires after 30 minutes,
   and cannot fund other source sessions. Failed/reserved requests do not
   automatically receive replacements.
8. **Explain the new result.** After completion, show **Result / Why / Next**.
   With unchanged example profiles, the expected finding is the observed
   contradiction with the selected Safe Harbor path. This is not an exhaustive
   legal assessment or proof that every external research disclosure is
   prohibited. If a receiver header is deduplicated, the page identifies the
   representative review header for the same body/session.
9. **Prove model execution.** Click **AI log** immediately beside the audit
   button. Show both preserved responses, actual session IDs, model and usage.
   Inspect the saved report for exact citations and the profile facts sent to
   the model. Missing output, provider errors and incomplete work are explicit;
   viewing the log neither starts nor retries inference.
10. **Conclude.** The audit occurred after delivery. It did not prevent
    disclosure, rewrite the Production, replay a message or certify compliance.
    Human event notes and review transitions are available in Productions.

### Suggested narration

- Profiles establish business premises within this demo, not official law or
  a prewritten model conclusion. Saving, not filling the form, creates a version.
- The observation unit is the entire Production; no per-flow registration or
  business restart is required.
- Header observation and body inspection have separate authorization.
  Inspection neither calls AI nor backfills old bodies.
- A missing capture, missing audit or failure must never be described as
  "no risk." Show Result / Why / Next before opening technical details.
- The example is not based on writing "no individual authorization" as a
  predetermined answer. It tests the actual field/release-path contradiction.

## Reset and evidence boundaries

Reset archives the fixed M5 object's enrollment, observer evidence/events,
inspection permission, review records/budgets and M5-only profiles/runs under
`^ContestM5DemoArchive`. It refuses an active review worker or unresolved
in-flight records. The next enrollment starts at the current header/log cursors.

Original IRIS messages, SQL receipts, protected RiskReview reports, audit logs,
Agent/provider configuration and knowledge remain intact. Other Productions,
shared organization profiles and the multi-organization demo are unchanged.
Thus “clean” means a clean **logical demo workspace**, not a physical purge.
The acceptance report remains read-only verifiable after reset.

Use a fresh run identifier after reset; the UI generates it. Duplicate sends
with the same ID return their saved attempt, never a business replay. An
uncertain audit submission can be explicitly reconciled with its exact saved
authorization; a new identity cannot silently buy a retry.
