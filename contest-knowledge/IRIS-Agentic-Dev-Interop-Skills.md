# IRIS Agentic Dev 与 Interop Skills 调研

## 结论

可以把 Interop Skills 作为本项目的**开发期辅助知识**，尤其用于设计和实现 IRIS Interoperability 组件、编写测试、检查 Production 及排查消息；它不是业务 Production 中运行的 AI Hub Agent，也不能替代本项目已经验证的 AI Hub 决策闭环。

初次调研时尚未安装。现已接入项目级 IRIS Agentic Dev v1.5.0 MCP，
固定连接隔离实例 `127.0.0.1:52779 / TRIAGE`，并将相关指引精简适配为
3 个 Copilot Skills；不是安装完整 Claude 插件。
真实 stdio MCP 读取、上传、编译、框架单元测试与日志提取已通过；
详见[接入验收记录](./Agentic-Dev-MCP-acceptance.md)。
VS Code 内的发现/自动调用仍需客户端启动或重载后确认。

## 相关项目的角色

- [`iris-agentic-dev`](https://github.com/intersystems-community/iris-agentic-dev) 是 MCP Server，可让 Copilot 等客户端通过 Atelier API 查询/搜索 IRIS 命名空间、读取和编译类、执行代码与 SQL、运行单元测试、查看 Interoperability Production 和消息等。它提供开发期的 IRIS 实例访问能力。
- [`iris-interop-skills`](https://github.com/intersystems-ib/iris-interop-skills) 是针对 IRIS Interoperability 的技能包，涵盖消息类、Business Service / Process / Operation、BPL、DTL、Production 生命周期、消息调试、测试等。其 README 说明可配合 `iris-agentic-dev` 或 `iris-interop-dev` MCP Server 使用。
- 两者职责不同：Skills 提供开发指引，MCP 提供对 IRIS 实例的工具连接；二者都不等同于在业务消息流程中做决策的 AI Hub Agent。

## 技能清单与计数

Interop Skills README 列出的技能为：`interop`、`component-map`、`messages`、`business-services`、`business-operations`、`soap-bo`、`bpl`、`transformations`、`hl7-schemas`、`lookup-tables`、`fhir`、`dicom`、`alerting`、`security`、`production-lifecycle`、`message-search-debug`、`tdd`、`unit-tests`、`conformance-review`、`ccr-workflow`、`report-issue`，共 **21 项**。README 简介仍称 20 项，因此简介与清单存在一项差异；按实际列出的名称计数为 21。

仓库还提供四个 Claude Code subagents：`interop-builder`、`deploy-smoke-test`、`introspect-dont-guess` 和 `conformance-reviewer`。README 将它们描述为插件安装时自动注册的 subagents。该 Claude 插件和 subagents 不应假定能在 Copilot 中原样运行。

## 对本项目的适用性

优先参考以下技能内容：

- `interop`、`component-map`、`messages`：从消息契约出发选择互操作组件，避免直接跳入 BP 实现。
- `bpl`：构建和检查消息异常分诊的 Business Process。
- `tdd`、`unit-tests`、`conformance-review`：为决策边界、允许动作、拒绝非法输出和错误路径补测试与构建后检查。
- `production-lifecycle`、`message-search-debug`：启动/检查 Production、追踪消息与定位失败，支撑端到端演示和审计。
- 按实际数据接口需要再选 `business-services`、`business-operations`、`transformations` 或 `fhir`。

暂不建议启用整个技能包。`ccr-workflow` 面向 IRIS BASE 命名空间的 CCR 变更控制，与本项目目前的 Git 源码开发方式并不匹配；HL7、DICOM、SOAP 等技能只有在相应接口成为本项目范围时才需要。

## Copilot 兼容性与使用边界

- Interop Skills 仓库 README 的安装说明面向 Claude Code 插件；其四个 subagents、hooks、插件权限配置不能当作 Copilot 插件原生支持。
- VS Code 官方文档支持 Agent Skills 标准，项目技能目录包括 `.github/skills/`、`.claude/skills/` 和 `.agents/skills/`。本项目现采用 `.github/skills/` 保存精简适配版，已按实际 MCP schema 验证核心调用；不宣称上游 Claude 插件能原样加载，或本会话已自动加载新增 Skills。
- `iris-agentic-dev` 自身的技能与 Interop Skills 是不同技能集。其 CLI 文档给出的 Copilot 安装方式 `iris-agentic-dev skill install --agent copilot` 会把它自己的技能写入 `.github/instructions/`，不能据此认为 Interop Skills 已安装。
- MCP 工具可编译、执行代码，运行 SQL、测试或影响 Production。试用时应使用隔离 EAP、专用测试命名空间和最小权限；不要暴露真实患者数据、凭据，或允许 Agent 对 Production 执行未确认的破坏性操作。任何部署、重放或可能触发外部副作用的操作都应由人明确批准。

## 社区文章的范围

用户提供的 [Part 1：Give Your AI a Live Connection to IRIS](https://community.intersystems.com/post/iris-agentic-dev-give-your-ai-live-connection-iris-part-1-problem-tool-and-getting-started) 主要介绍 `iris-agentic-dev` MCP Server 如何让 Copilot 等助手访问完整 IRIS 命名空间，并提供 VS Code/Copilot 配置与 Interoperability 应用分析示例。文章明确把内容分成系列：Part 2 讲工具目录，Part 3 讲 ObjectScript skills，Part 4 讲基准测试。它不是 Interop Skills 仓库的安装指南，也没有把 MCP/Skills 描述为运行时 AI Hub Agent。

文章提到的 ObjectScript skills 用于改善模型对 ObjectScript 语法和惯例的掌握；与 `iris-interop-skills` 的互操作领域技能包相关但不是同一组内容。文章报告的技能基准是小型、单模型、单次运行结果，不能直接作为本项目效果承诺。

用户补充的 [Part 2：A Short Tour of Some of iris-agentic-dev's Tools](https://community.intersystems.com/post/give-your-ai-live-connection-iris-%E2%80%94-part-2-short-tour-some-iris-agentic-devs-tools) 延续介绍 MCP 工具层，重点是工具如何让助手通过 IRIS 接口做代码读取/编辑、编译、执行、查询、测试、搜索和互操作相关检查。文章适合作为工具用途的导览；具体工具名称、参数和保护规则应以当前版本的 [`docs/tools.md`](https://github.com/intersystems-community/iris-agentic-dev/blob/master/docs/tools.md) 及实际 MCP schema 为准，因为项目持续演进。

当前工具文档明确指出工具面包含只读能力，也包含写入及破坏性操作：部分写入工具受 `write_tools_enabled` / Live 实例保护约束；破坏性工具还需单独启用 `destructive_tools_enabled`。所以即使使用工具导览和技能指引，也不能将 MCP 视为只读查询接口；在本项目里仍应连接隔离 EAP、确认当前工具的有效参数与实例身份，并对 Production 变更、全局删除、重放等有副作用操作要求人工确认。

## 建议的下一步

当前已按本项目范围合并为互操作开发、TDD 和消息调试三个 Skills，
并完成受控的读取/编译/测试闭环。下一步在 VS Code 启动 `iris-triage-dev`，
确认客户端发现并调用对应 Skills，再用该流程推进真实业务改进；
不启用 Claude hooks/subagents，不为开发遥测扩大 USER 权限。

## 参考资料

- [IRIS Agentic Dev](https://github.com/intersystems-community/iris-agentic-dev)
- [IRIS Agentic Dev：Skills 文档](https://github.com/intersystems-community/iris-agentic-dev/blob/master/docs/skills.md)
- [IRIS Interop Skills](https://github.com/intersystems-ib/iris-interop-skills)
- [VS Code：Use Agent Skills](https://code.visualstudio.com/docs/agent-customization/agent-skills)
- [社区文章 Part 1](https://community.intersystems.com/post/iris-agentic-dev-give-your-ai-live-connection-iris-part-1-problem-tool-and-getting-started)
- [社区文章 Part 2](https://community.intersystems.com/post/give-your-ai-live-connection-iris-%E2%80%94-part-2-short-tour-some-iris-agentic-devs-tools)
- [IRIS Agentic Dev 工具目录](https://github.com/intersystems-community/iris-agentic-dev/blob/master/docs/tools.md)
