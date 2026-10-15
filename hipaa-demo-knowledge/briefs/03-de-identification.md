# De-identification and residual identifiers

Document type: LLM-authored synthesis; not an official determination.
Human legal review: not performed.

## Sources

- 45 CFR 164.502(d).
- 45 CFR 164.514(a), (b), (c), and (e).
- HHS De-identification Guidance:
  https://www.hhs.gov/hipaa/for-professionals/privacy/special-topics/de-identification/index.html

## Two paths, not a single masking rule

The standard concerns whether the information identifies an individual and
whether there is a reasonable basis to believe it can identify an individual.
The regulation provides Expert Determination and Safe Harbor paths. Do not
replace either path with "remove the name" or "replace identifiers with hashes".

Expert Determination requires an appropriately qualified expert's analysis,
methods and documented conclusion regarding very small identification risk.
An Agent's confidence score is not that determination. If an organization
claims this path, request the determination's reference, data/recipient scope
and evidence that the current release fits it. Do not claim that a document
reference alone proves its validity.

Safe Harbor involves the specified identifier categories and the actual-
knowledge condition. Preserve the complete conditions from 164.514(b)(2),
including geographic exceptions, date restrictions, ages over 89 and the
provisions concerning unique identifiers and re-identification codes.

Examples of easily missed residual information include:

- Medical record or account numbers outside the primary patient object.
- Telephone numbers or email addresses in a clinical narrative.
- Complete birth, admission or discharge dates.
- An identifier hidden in a URL, attachment filename or device field.
- A distinctive combination of retained attributes that can identify a person.

These examples are search prompts, not a complete implementation of all
identifier detection. A pattern match should record its type, location,
confidence and method. False positives and missed identifiers remain possible.

## Free text, hashes and limited data sets

HHS guidance addresses identifiers in free text as well as structured fields.
A successful field mapping does not prove that a narrative was de-identified.
Pseudonyms and hashes can remain identifying; review their derivation and
re-identification conditions rather than treating every token as anonymous.

A limited data set under 164.514(e) is not equivalent to fully de-identified
information. It has specific permitted purposes, exclusions and data-use-
agreement requirements. Do not treat a limited-data-set declaration as a
general permission to send data to an unapproved recipient.

## Detect locally without exporting original identifiers

The controlled observation component can examine original values and produce
evidence such as: "Patient.Identifier contains a likely medical record number;
still present after transformation; local evidence E17". The remote reviewer
can reason about presence and recipient policy without receiving the number.
Keep original values in access-controlled local evidence, not in findings,
LLM sessions, embedding requests, retry logs or test fixtures.

Some ambiguity may require locally authorized human or model review of the
original text. Mark that requirement explicitly instead of pretending that
redacted evidence proves the entire message has been de-identified.
