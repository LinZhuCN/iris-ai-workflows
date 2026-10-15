---
name: iris-interop-tdd
description: 'Test IRIS Interoperability component changes with Agentic Dev MCP, %UnitTest.TestProduction, iris_compile and iris_test. Use for regression tests, message facts, BP policy changes and red/green verification.'
---

# Interoperability TDD in TRIAGE

Adapted for Copilot from upstream Interop Skills `tdd` and `unit-tests`;
see [provenance](../../../contest/dev/README.md#skills-provenance).

1. State the behavior under test. Check the pinned connection using
   `check_config`; all namespace-aware calls must specify `TRIAGE`.
2. Use `%UnitTest.TestProduction` for interoperability unit tests and set
   `Parameter PRODUCTION = "Contest.Production"`.
3. The demo Production is already externally managed. Override `TestControl`
   with a no-op returning `$$$OK`; do not restart or stop the Production for
   a unit-test run. Capture an Event Log baseline if tests inspect runtime logs.
4. Write the regression test first. Use framework assertions in `Test*` methods,
   not self-reported success strings as a substitute for `%UnitTest`.
   A local example is [DevTests.cls](../../../contest/dev/DevTests.cls).
5. Upload with `iris_doc(mode="put", name="Contest.DevTests.cls", content=...,
   namespace="TRIAGE")`; compile the exact class using `iris_compile`.
6. Call `iris_test(pattern="Contest.DevTests", namespace="TRIAGE",
   test_type="testproduction")`. This pattern is a compiled class, not a
   package wildcard. Require nonzero tests and assertions, zero failures.
   `NO_TESTS_FOUND`, `isError`, internal `success=false`, or missing result
   counts are failures. Inspect `iris_get_log` when needed.
7. For a new regression, observe a relevant failure before implementation.
   Fix the behavior, then recompile and rerun the exact suite.
8. Framework unit tests complement, not replace, `contest/test.py` end-to-end
   fault and restart tests. Never run fault injection against the real provider.
   Do not make paid model calls just to verify development tooling.
