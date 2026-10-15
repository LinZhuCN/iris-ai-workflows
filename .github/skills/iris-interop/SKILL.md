---
name: iris-interop
description: 'Develop or modify this project IRIS Interoperability workflow, messages, Business Process, Business Operation, Production or AI Hub ToolSet. Use for BS/BP/BO wiring and TRIAGE namespace work.'
---

# TRIAGE Interoperability development

This is a project-specific Copilot adaptation of the upstream Interop Skills
router and messages-first workflow, not the Claude plugin.
See [provenance and license](../../../contest/dev/README.md#skills-provenance).

1. Call `check_config` on `iris-triage-dev`. Require host `127.0.0.1`, port
   `52779`, namespace `TRIAGE`, configuration source `config_file`, and
   `destructive_tools_enabled=false`. Stop on mismatch; never use auto-discovery.
2. Pass `namespace="TRIAGE"` on every namespace-aware MCP call. This is a
   dedicated Interoperability-enabled namespace. Do not add manual system
   package mappings or switch business code into USER/HSLIB.
3. Design the message contract first: `Contest.Request` extends `Ens.Request`;
   `Contest.Reply` extends `Ens.Response`. Determine required fields, response
   and error semantics before modifying the BP or BO.
4. Read [the TDD skill](../iris-interop-tdd/SKILL.md) for component changes.
   Inspect real superclass/method definitions with `iris_doc` or `iris_symbols`
   rather than inventing API names.
5. Keep ObjectScript source on disk as the source of truth. Use `iris_doc`
   `put` and `iris_compile` to validate explicitly named `Contest.*` classes
   through MCP. Inspect the actual tool schema before supplying parameters.
6. Runtime AI uses `%AI.Agent`, `%AI.ToolSet` and `%AI.Tool` in the BP. MCP
   and these development skills are not runtime tools for that Agent.
7. Preserve job-bound fact access, mandatory fact reading, delivery policy,
   failure auditing, no automatic replay, and unique destination writes.
8. Do not start/stop/reconfigure Production, edit credentials, delete data or
   call a real provider without explicit approval. Development credentials can
   modify TRIAGE; tool allowlisting does not sandbox arbitrary ObjectScript.
9. For message problems read [the debugging skill](../iris-message-debug/SKILL.md).
   Completion requires actual compiled classes and passing tests, not local
   edits or a successful-looking tool response alone.
