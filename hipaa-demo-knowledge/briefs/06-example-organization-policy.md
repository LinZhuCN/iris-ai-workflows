# Synthetic organization data-sharing policy

Document type: demonstration policy authored with LLM assistance.
Policy ID: DEMO-SHARING-1. Version: 1.
This is not HIPAA text, an HHS recommendation or a real organization's approval.

## Registered destinations

TREATMENT-PARTNER is a synthetic health care provider receiving information for
patient treatment. The demo permits necessary patient identity and clinical
fields on this route, subject to actual role/purpose evidence and other
applicable controls. Do not classify any identifier as automatically forbidden.

ANALYTICS-SAFE-HARBOR is a synthetic analytics service. Its contract accepts
only data represented as meeting the Safe Harbor path with the applicable
conditions. A local detection of residual direct identifiers, prohibited date
elements or identifying narrative creates a policy finding. Do not claim that
a finding alone is a definitive legal violation.

ANALYTICS-EXPERT is a separate synthetic destination. It requires a locally
approved Expert Determination reference matching the dataset and anticipated
recipient. A missing reference requires review. An Agent cannot issue the
determination or turn a filename into proof of expert approval.

UNREGISTERED is any destination not matching a registered identity and purpose.
It requires human verification; no Agent may approve it or infer permissions.

## Evidence and data handling

Use synthetic values in all demonstrations. Local detectors may inspect the
synthetic original payload. Remote tools, model context, findings and logs
receive only identifier categories, locations and opaque evidence references.
Production deployments require independent authorization for real data.

Original evidence is accessible only to authorized local reviewers. This demo
policy does not prescribe a universal HIPAA retention period. An operational
installation must specify and enforce its own lawful retention schedule.

## Findings and authority

Allowed review dispositions are potential_risk, no_finding_in_observed_scope,
and insufficient_evidence. Each result needs scoped evidence and relevant
source references. No finding is a full compliance certificate.

Human review may confirm or dismiss a finding with a recorded reason. The
reviewer must not change original evidence silently. The Agent cannot modify
Production, replay messages, suspend a pipeline, notify patients or change
credentials. Review failure is explicit and does not block the business route.

## Knowledge profile

Development comparisons use the explicit full local profile; contest release
verification uses the demo profile. Log profile, corpus ID, document IDs and
source versions with every future review. Switching profiles must create a
separate index or rebuild it completely; never mix old chunks into the new
profile or silently fall back from a missing full corpus.
