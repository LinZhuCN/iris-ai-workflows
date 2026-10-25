# Agentic Dev MCP and Copilot Interop Skills

[English](README.md) | [简体中文](README.zh-CN.md)

These are **development tools**, not the runtime AI Hub Agent. Runtime inference
continues to use `%AI.Agent`, `%AI.ToolSet` and `%AI.Tool` inside the BP.

## Install and connect

Prerequisites: Python 3.9+, curl, Docker/Colima, and the running real-demo
deployment described in [the workflow guide](../README.md). This workspace
configuration intentionally targets only `127.0.0.1:52779`, namespace `TRIAGE`.
It does not attach to other containers, the inherited application or production.

From the repository root:

```sh
python3 contest/dev/install.py
python3 contest/dev/prepare.py
python3 contest/dev/verify.py --tests
```

The installer downloads the official **iris-agentic-dev v1.5.0** macOS/Linux
ARM64 or x86_64 asset and verifies its pinned SHA-256 from GitHub's release asset
metadata. The executable and generated password stay under ignored
`contest/data/agentic-dev/`; no global install is required.

Provisioning requires Docker administration access and explicitly executes in
`iris-triage-real-iris-1`. It assigns the physical TRIAGE database a dedicated
`%DB_TRIAGE` resource, creates the `ContestDevelopment` role and
`ContestDeveloper` account, and sets `^UnitTestRoot="/contest/dev"` in TRIAGE.
Rerunning it preserves the local password. Re-run it after rebuilding the
database; it is intentionally not part of the runtime installation.

In VS Code, open this repository as the workspace. Start/trust
**iris-triage-dev** using **MCP: List Servers**. The checked-in
[workspace MCP configuration](../../.vscode/mcp.json) launches
[mcp.py](./mcp.py), which supplies the ignored password and pins the workspace
configuration. Inherited `IRIS_*` environment overrides are removed.
Restart the server if it was already running.

Call `check_config` and require `connection_source="config_file"`, host
`127.0.0.1`, port `52779`, namespace `TRIAGE`, and destructive tools disabled.
Do not continue against an automatically discovered connection. VS Code may
require a window reload/new chat to discover the skills; the standalone test
does not prove editor discovery or automatic skill invocation.

## Effective permissions and limits

[.iris-agentic-dev.toml](../../.iris-agentic-dev.toml) publishes only:

`check_config`, `iris_doc`, `iris_compile`, `iris_query`, `iris_search`,
`iris_symbols`, `iris_test`, `iris_debug`, `iris_get_log`.

Writes are enabled so development can compile and test. Destructive tools are
disabled. The role grants `%Development:U`, `%DB_TRIAGE:RW`, `%DB_IRISLIB:R`,
`%DB_ENSLIB:R`, `%DB_IRISTEMP:RW`; it is not `%All` or the broad `%Developer`.
Gateway routing enables extensionless `/api/atelier/` REST endpoints with
`CSP On`; IRIS authentication remains enabled.

**This is not a read-only interface or an ObjectScript sandbox.** Compiling
and running tests executes code; `iris_doc` can write/delete documents and
`iris_query` has write modes. Gate settings do not make these allowed tools
harmless. Use trusted local development only. Do not authorize production
changes, replay, credential access or real-provider calls implicitly.
The upstream server may attempt USER telemetry helpers; these are not granted
USER database writes by this role. Do not expand permissions for telemetry.

## What the acceptance script verifies

[verify.py](./verify.py) uses actual stdio JSON-RPC `initialize`,
`tools/list` and `tools/call`, not a simulated MCP response:

- Project configuration is loaded and the intended target is selected.
- The advertised tools do not exceed the project allowlist.
- `iris_doc` reads the deployed `Contest.Request` class.
- With `--tests`, `iris_doc` uploads [DevTests.cls](./DevTests.cls),
  `iris_compile` compiles it and `iris_test` runs the actual
  `%UnitTest.TestProduction` framework. Nested failures and empty suites fail
  verification; `iris_get_log` retrieves detailed evidence.

The three assertion-bearing methods check complete safe facts, incomplete /
unknown-code facts and unbound fact-tool rejection. The fourth method is a
no-op `TestControl`, deliberately avoiding Production lifecycle changes.
No unit test invokes a provider or replays a business message. Tests write
framework results and temporary helper classes; this is not a read-only check.
The client process is stopped when verification finishes.

## Skills provenance

The upstream [IRIS Interop Skills](https://github.com/intersystems-ib/iris-interop-skills)
was reviewed at commit
[`00faab5be2915357dd20941f4b7990a65e73523c`](https://github.com/intersystems-ib/iris-interop-skills/tree/00faab5be2915357dd20941f4b7990a65e73523c).
This project adapts the messages-first router and TDD/unit-test guidance into
three standalone Copilot Agent Skills, with project-specific debugging guidance:

- [iris-interop](../../.github/skills/iris-interop/SKILL.md)
- [iris-interop-tdd](../../.github/skills/iris-interop-tdd/SKILL.md)
- [iris-message-debug](../../.github/skills/iris-message-debug/SKILL.md)

These are curated **adaptations**, not an installation of the full upstream
Claude Code plugin or all 21 skills. No Claude hooks, subagents, CCR/BASE
workflow or unavailable sibling-skill dependency is installed. Names,
paths, MCP schemas, namespace and externally managed Production behavior are
adapted for this repository. Source credit: Pierre-Yves Duquesnoy,
MIT license, preserved in [interop-skills-LICENSE](./interop-skills-LICENSE).

The MCP binary is separately obtained from the official
[IRIS Agentic Dev release](https://github.com/intersystems-community/iris-agentic-dev/releases/tag/v1.5.0).
Its own upstream licensing applies; it is not redistributed in this Git tree.
