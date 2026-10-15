---
name: iris-message-debug
description: 'Investigate TRIAGE Interoperability messages, failed routing, duplicate suppression, AI Hub policy rejection and missing audit stages using iris_query, iris_doc and iris_debug MCP tools.'
---

# Trace messages without replaying them

Project adaptation of Interop Skills message-search and lifecycle guidance.
See [provenance](../../../contest/dev/README.md#skills-provenance).

1. Verify `check_config` targets the pinned TRIAGE development connection.
2. Use SELECT-only `iris_query` calls with `namespace="TRIAGE"` and bounded
   results. Check the tool schema for the actual query/limit parameter names.
3. Inspect `Contest."Case"` (quote the reserved SQL identifier), then correlate
   its ID with `Contest.Event.CaseId` and `Contest.Destination.CaseId`.
   `RequestId`, `SessionId` and `AgentSession` link IRIS and AI Hub evidence.
4. Follow received -> tool_facts -> agent_decision -> policy -> executed.
   A failed case should have an explicit error and no destination. A duplicate
   of a completed case must not add a destination or invoke the model again.
5. Inspect `Ens.MessageHeader` and `Ens_Util.Log` only after discovering their
   real columns. Use `iris_symbols`, `iris_doc` and `iris_debug` for class
   definitions, method offsets and error locations; do not guess table names.
6. Never send raw business payloads, credentials or source code to a model or
   external service. Model usage in `Contest.Case.Usage` is final-response
   usage, not whole-loop totals or billed cost.
7. Do not clear message history, replay failures, mutate globals or change
   Production settings during diagnosis. Report inconclusive evidence as
   inconclusive. A running container is not proof of successful delivery.
