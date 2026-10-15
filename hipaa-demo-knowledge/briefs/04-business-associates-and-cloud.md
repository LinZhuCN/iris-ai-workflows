# Business associates, cloud services and onward transmission

Document type: LLM-authored synthesis; not a contract or legal opinion.
Human legal review: not performed.

## Sources

- 45 CFR 160.103, 164.502(e), 164.504(e), 164.308(b), and 164.314(a).
- HHS Business Associates:
  https://www.hhs.gov/hipaa/for-professionals/privacy/guidance/business-associates/index.html
- HHS Cloud Computing:
  https://www.hhs.gov/hipaa/for-professionals/special-topics/health-information-technology/cloud-computing/index.html

## Context to establish

A business associate relationship depends on activities and information,
not simply whether the recipient is outside the sender's network. A service
provider that creates, receives, maintains or transmits ePHI on behalf of a
covered entity or business associate can implicate business associate
requirements. Relevant exceptions and the actual service role must be checked.

For a cloud or AI endpoint, obtain the endpoint's registered identity, service
purpose, information handled, approval status and applicable agreement
reference. Encryption and absence of a decryption key do not by themselves
establish that a provider has no business associate obligations. Conversely,
do not label every service that touches a network packet a business associate
without checking the circumstances, including the narrow conduit distinction.

The existence of a contract identifier is not proof that all terms, permitted
uses, safeguards or subcontractor obligations have been satisfied. A monitor
can flag missing or contradictory evidence; it cannot negotiate or certify
the contract. Missing evidence should produce "requires verification".

## Interoperability monitoring use

- Patient-related output goes to a new vendor endpoint, but only the URL is
  registered: request vendor role and agreement evidence.
- A troubleshooting step forwards a complete failed message to an external
  model: assess that as another disclosure, not an invisible internal step.
- A receiver was approved for de-identified analytics, but output now includes
  identity fields: compare the data and purpose with the recorded approval.
- The endpoint is approved, but destination configuration changed: correlate
  the runtime destination with the reviewed configuration and policy version.

## Monitor the monitor

Sampling creates another copy or representation of information. Assess the
monitor's queue, backups, logs, LLM session store, evidence retention and access
permissions. A side-channel design avoids blocking the business pipeline, but
does not eliminate privacy obligations or data handling risk.

These notes do not establish that the contest's external inference service is
approved for real PHI. Demonstrations use synthetic messages and minimized
facts. Real deployments require their own approvals, controls and agreements.
