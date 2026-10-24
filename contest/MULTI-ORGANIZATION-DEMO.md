# Multi-organization FHIR distribution demo

This local synthetic demo reads an IRIS FHIR R4 Patient, transforms it into
three different representations and delivers them to three independently
stored simulated institutions in the same IRIS instance.

| Namespace | Role | Actual boundary |
|---|---|---|
| `FHIRDEMO` | Source covered-hospital scenario | Authenticated FHIR HTTP read |
| `DEMODISTRIBUTION` | `Contest.Multi.Production` | Source BS, distribution BP, three outbound BOs and advisory audit BP |
| `DEMOQUALITY` | Internal quality department | JDBC SQL connection, parameterized column insert and readback |
| `DEMORESEARCH` | External research center | Authenticated REST request and persisted JSON readback |
| `DEMOCLINIC` | External treating clinic | TCP/MLLP HL7 V2, correlated ACK and durable receipt |
| `TRIAGE` | Control plane | Versioned profiles, knowledge, AI Hub reports and human-review events |

These are logically separated systems, not three separate servers. Recipient
application data use separate databases. The clinic receiver is an IRIS-managed
listener job, not a separate receiver Production.

To inspect actual model work, click **AI log** immediately beside **Run AI audit**.
It displays the selected run's saved reports for the three recipients, including
the original locate/judge responses, AI Hub session IDs, usage and any errors.
Opening or closing the log does not start an audit or purchase a retry.
No saved response is claimed for an unaudited run or a failed phase without output.

## Installation into the existing local platform

Prerequisites: the real AI Hub deployment, authenticated platform API,
knowledge index and published privacy reviewer described in
[the installation guide](./README.md) and [monitoring guide](./MONITORING.md).
The ordinary Community image without AI Hub cannot replace the tested EAP build.
No real patient data, external recipient or new Python package is required.
The SQL client uses the JDBC driver and Java runtime bundled with this image.

```sh
# Existing owned FHIR repository/client foundation; does not send a batch.
python3 contest/aggregation_setup.py --apply
python3 contest/multiorg_receivers_setup.py --apply --verify
python3 contest/multi_setup.py --apply
docker compose -f web/compose.yaml up -d
```

The checked-in gateway configuration includes extensionless routing for
`/csp/multiresearch`. An already-running gateway must reload that configuration
after updating it; receiver provisioning alone cannot change Apache routing.
See [receiver setup](./multiorg/receiver/README.md) for exact credentials,
ownership checks, SQL schema and protocol tests. Credentials remain in ignored
local files and are never entered in organization profiles.

Provisioning refuses unrelated namespace ownership. Container startup restores
only owned recipient listeners and the owned distribution Production; it does
not seed patients, send messages or purchase model calls.

## Browser walkthrough

| Entry | Local URL |
|---|---|
| Organization forms | <http://localhost:5173/organizations> |
| Main distribution and audit page | <http://localhost:5173/demo> |
| Production observation and human event actions | <http://localhost:5173/pipelines> |
| Earlier synthetic connector demo | <http://localhost:5173/demo/legacy> |
| IRIS Portal | <http://127.0.0.1:52779/csp/sys/UtilHome.csp> |
| FHIR endpoint, separate authentication | <http://127.0.0.1:52779/csp/healthshare/fhirdemo/fhir/r4> |

1. **Save organizations.** Fill editable presets for the source hospital and
   three recipients, review responsibilities and allowed/prohibited fields,
   then click **Save for demo**. Saving establishes a versioned scenario
   premise; no additional checkbox is needed. Filling a form does not save,
   send data or call a model.
2. **Enroll observation.** On Productions, discover `DEMODISTRIBUTION /
   Contest.Multi.Production`, enroll read-only monitoring and separately
   authorize local synthetic inspection. This adds generic message observation;
   it is not model funding or legal permission.
3. **Prepare source data.** Click **Prepare demo data** to create only
   `Patient/agg-multi-p1` in the owned repository. Repeating it verifies identical
   existing data rather than silently replacing a different resource.
4. **Run distribution.** Choose the variant and click **Run distribution**.
   The button submits that variant and stable run ID; there is no additional
   confirmation checkbox. The BP reads
   the versioned FHIR source and sends SQL, REST and HL7 outputs. Inspect all
   three actual receipts, output fields and frozen profile revisions.
5. **Optionally run AI review.** A single cost acknowledgement followed by
   **Run AI audit** funds at most three reviews and six model requests for that
   run. There is no repeated synthetic-data acknowledgement: this workflow is
   restricted to its owned synthetic fixture and local receivers.
   A free Business Process preflight validates evidence and normative
   sources before the single-use grant is reserved.
6. **Read results.** Each branch leads with Result / Why / Next step.
   Receiving-policy mismatches are separate from AI HIPAA conclusions.
   Expand receipts and AI audit details only when investigating provenance.
   Production events support acknowledgement and human notes, not automatic
   delivery changes.

Select a saved run or use `/demo?run=<saved-run-id>` to reopen evidence without
sending or paying again. Loading a historical report is not live inference.
Refresh may require signing in again; it does not replay an execution.

### Verified saved demonstration

Open [the accepted run](http://localhost:5173/demo?run=multi-fe23cf92-73ec-45dc-91cc-77b0828e27dd)
to replay the actual results without model charges:

| Branch | Saved result |
|---|---|
| Quality / SQL | No signal on the checked internal-operations/minimization issues |
| Research / REST | Risk identified: actual identifiers conflict with the asserted Safe Harbor path; alternative research permission remains unresolved |
| Clinic / HL7 | No signal on the checked same-patient treatment disclosure, with treatment-context exceptions considered |

The audit ran in BP session 59 and preserved AI Hub sessions 219-224,
including actual prompts, output, token usage and exact source spans.
The SDK reported 70,768 prompt and 26,301 completion tokens (97,069 total)
for that accepted run. Its 24,775 reasoning tokens are included in completion
tokens; 10,624 cache-read tokens are included in prompt tokens, not additional
usage. These counters are not a provider invoice or a verified monetary cost.
An earlier research-provider timeout remains visible in the previous run;
the accepted run followed a separately authorized second six-request budget.
No failed report was relabeled or replaced.

A real IRIS container restart preserved four saved complete run/report hashes,
twelve independently reread recipient receipts and all AI report budgets.
The only additional message header was IRIS scheduler startup traffic, not
a business resend or AI request. Human review of the research event was
recorded as `in_review` followed by `needs_information`, without delivery
changes or additional inference.

## What the three branches demonstrate

- **SQL / internal quality:** a local patient code, numeric birth year and
  scoped status. SQL readback independently checks the actual column values.
  This demonstrates the configured local minimization policy, not complete
  HIPAA compliance.
- **REST / research:** the `identifier-leak` variant declares Safe Harbor
  de-identification while actually sending synthetic name, MRN and full birth
  date. The `corrected` variant removes those selected identifiers; it is not
  proof of complete Safe Harbor compliance.
- **HL7 / treatment:** PID carries identity and birth date for the stipulated
  actual treatment of the same referred patient. The reviewer must consider
  treatment permission and relevant exceptions rather than treating every
  identifier as an automatic violation.

The outbound hosts have native Business Partner associations. Profiles use
stable organization IDs and preserve revision, confirmer, time and content
hash. Editing a current profile cannot rewrite the profile snapshot in an
earlier run. Changing a partner key requires explicit reconciliation with the
host configuration; saving a profile never silently reconfigures Production.

## Evidence and execution boundaries

The sidecar reads persisted outbound message bodies and actual header edges
after delivery, checks receiver readback, and records minimized field facts.
It does not infer recipient contents merely from the original FHIR resource.
Raw synthetic receiver payloads stay local; model packets contain field
presence, date precision, institution context and provenance, not patient
identity values.

The `AdvisoryAudit` Business Process executes actual `%AI.Agent` phases, using
`TRIAGE` for protected knowledge and report storage. Reports preserve that
Business Process session, AI Hub session IDs, input, system prompts, output,
usage, citations and contract validation.

Delivery acknowledgement does not establish later clinical use. AI review is
post-send advisory, not interception, legal certification or business approval.
Failed contract/model execution is `not_assessed`, not a no-risk result.
Unresolved material facts remain explicit.

Duplicate submission of the same run ID returns the saved run; it does not
resend. Partial, failed and uncertain attempts remain visible. A different
future export requires a new explicitly confirmed run ID. Restarted in-flight
work is marked interrupted instead of being automatically replayed.

Ordinary saves, preparing synthetic data, enabling read-only monitoring and
revoking grants use direct action buttons, not additional confirmation
checkboxes. Inspection remains a separate direct action on the generic
Production page because enabling header observation does not imply permission
to inspect arbitrary message bodies. Already monitored objects display their
status instead of a disabled confirmation. Model charges still require explicit
consent; scope choices such as including unreviewed historical captures remain
available. Server permission, revision, budget and duplicate-execution checks
are unchanged.

## Verification commands

```sh
python3 -m unittest discover -s contest -p test_multi_runtime.py
python3 -m unittest discover -s contest -p test_multiorg_receivers.py
python3 contest/multiorg_receivers_setup.py --apply --verify

# Explicitly sends two local synthetic variants; never calls a model.
python3 contest/multi_acceptance.py --run

# Reads saved acceptance records only; no sends or model calls.
python3 contest/multi_acceptance.py --check
```

The acceptance runner refuses to replace existing attempts. An explicit
`--new-attempt` allocates new free synthetic run IDs and retains prior
development attempts. `--audit` is separately cost-bearing and refuses an
existing audit record. Do not use it merely to inspect saved results.

Frontend validation uses the existing Vitest, TypeScript, ESLint and Vite
commands in [the web project](../web/package.json). See the
[development plan](./MULTI-ORGANIZATION-DEMO-PLAN.md) for staged acceptance gates.
