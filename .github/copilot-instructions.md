# Project conventions

- Write public-facing project documentation in English by default, including
  READMEs, installation guides, architecture documents and contest materials.
- Project knowledge-base notes under `contest-knowledge/` may remain in Chinese.
- Store HIPAA regulations, HHS guidance and related archive files exclusively in
  the root `hipaa-documents/` directory, separate from application code in
  `contest/` and project development knowledge in `contest-knowledge/`.
- Keep that full archive and full prepared corpus out of Git. The explicit
  release exception is `hipaa-demo-knowledge/`, containing complete prepared text,
  LLM-authored briefs and a synthetic organization policy. Never describe the
  entire package as LLM-rewritten or its summaries as official legal text.
- The published `demo` profile contains approximately 23 MB of prepared text;
  `full` is an optional local rebuild. Keep historical/unreviewed material out of
  default retrieval exports. Release checks require `demo`.
  Selection verifies inputs only and must not be described as a completed
  AI Hub import or an evaluated compliance Agent.
- Preserve explicitly requested translations; do not translate existing
  documents solely because of the default language convention.
