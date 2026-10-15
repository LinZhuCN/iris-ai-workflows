# HIPAA demonstration knowledge

The release ships the complete prepared text corpus, approximately **23 MB of
UTF-8 text**, rather than the former 2 MB selected subset. The original PDFs,
HTML snapshots, extraction intermediates and other binary sources remain under
the Git-ignored `hipaa-documents/` directory. A verifier does not need them.

## Preparation and limitations

The coding assistant selected preparation rules and authored five
[LLM orientation briefs](./briefs/) plus a synthetic organization policy.
Official source text is deterministically extracted and exact-text duplicates
within a document kind are collapsed. **The corpus is not entirely LLM-rewritten
or compressed.** Summaries are not official legal authority.

The release includes successfully archived HHS guidance, FAQs, cases, historical
explanations, other archived documents, Parts 160/162/164, the original Act and
annual CFR PDF text, and two selected NIST technical guides. Historical material
is included for contextual queries, not to inflate the corpus or represent
current law. It must not silently enter default normative retrieval.

No claim is made that every HIPAA publication was collected or reviewed. Fifty
failed archive URLs, pages without extractable text, navigation fallback notes
and source/version limitations are recorded in the manifest. OCR is not included.
Source dates do not establish effective dates; applicability and judicial status
need review. PDF tables are linearized. No legal review or Agent accuracy
benchmark has been performed.

## Files

- [documents.jsonl](./documents.jsonl): self-contained text with provenance.
- [manifest.json](./manifest.json): exact counts, text/file bytes, corpus SHA-256,
  retrieval-scope counts, failed sources and extraction notes.
- [catalogue.json](./catalogue.json): titles, IDs, source locations and scopes.
- [briefs/](./briefs/): LLM-authored orientation and synthetic organization policy.
- [evaluation-cases.json](./evaluation-cases.json): synthetic evaluation
  specifications, not retrieval content or completed evaluation results.
- [supplemental-sources.json](./supplemental-sources.json): pinned official NIST
  source URLs, checksums and inclusion reasons.

Each record preserves source URL, source checksum, document kind, source
version, section/page locator, content checksum, legal-status label and
`retrieval_scope`. A source checksum is useful for comparison; original source
files are not required to verify the distributed corpus checksum.

## Scope-controlled retrieval inputs

| Scope | Purpose | Default export |
|---|---|---|
| `normative` | Regulation snapshots and selected HHS guidance/FAQ | Yes |
| `technical` | Explicitly selected HHS/NIST implementation guidance | Yes |
| `orientation` | Non-authoritative LLM briefs | Yes |
| `organization_policy` | Synthetic demo policy | Yes |
| `historical` | Historical final-rule explanations | **No** |
| `unreviewed` | Cases, proposals, other archived documents not individually classified | **No** |

`normative` is a retrieval role, not a declaration that every passage is
currently binding law. Case/proposal/historical classification is intentionally
conservative: unreviewed materials require explicit contextual retrieval and
cannot support a current legal conclusion without further source review.
Do not present an index of the entire file as a current-law-only index.

From the repository root, using Python 3.9+:

```sh
python3 contest/knowledge.py verify
python3 contest/knowledge.py select --profile demo
python3 contest/knowledge.py release-check

# New file only; refuses to overwrite existing exports.
python3 contest/knowledge.py export \
  --output contest/data/knowledge/default.jsonl

# Explicit background-only export, kept separate.
python3 contest/knowledge.py export --scope historical \
  --output contest/data/knowledge/historical.jsonl
```

The scope export implements filtering of input records, not an AI Hub search
endpoint. A future ingestion/retrieval layer must enforce the same separation
and preserve metadata and citations. Each review should retrieve only relevant
chunks, not send 23 MB in a prompt.

## Release and local profiles

`demo` now means **the published complete prepared text corpus**, not a small
selection. `full` remains an optional locally rebuilt copy for development
comparison. Both contain the same text when rebuilt from identical sources.
The release is independent of the raw archive. Selection pins the corpus digest
and a profile-specific index key in ignored local state. Missing sources and
changed digests are errors, not silent fallbacks.

Selection and export do **not** build vector indices, invoke embedding models
or make the current triage Agent use this knowledge. AI Hub import, index
measurements and retrieval/Agent evaluation remain the next implementation
stage. `index_status=not_imported` is intentional. No production behavior changed.

Rebuilding requires the original dated local archive and macOS PDFKit:

```sh
python3 contest/knowledge.py fetch-supplemental
swift hipaa-demo-knowledge/extract_pdfs.swift
python3 contest/knowledge.py build --profile demo
python3 contest/knowledge.py build --profile full
python3 -m unittest discover -s contest -p test_knowledge.py -v
```

Validation and export of the published package work without Swift, network
access or raw PDF downloads. No inference or embedding charges are incurred by
these commands. Import latency, index size, embedding dependencies and review
quality must be measured separately before promising one-click AI Hub setup.

## Attribution and use

Official evidence is attributed to HHS, eCFR and NIST. It is not authored by
this project and is not relicensed wholesale under Apache-2.0. Original notices
and applicable third-party rights remain. Project LLM briefs are not HHS
publications, legal advice or a compliance certification.
Use synthetic messages in demonstrations; never mix raw patient messages into
this normative/background document corpus.
