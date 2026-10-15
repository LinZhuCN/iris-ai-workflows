# AI Hub EAP 环境与运行时验证

验证日期：2026-10-15

本文保留早期探针的历史结果和当时限制。后续已完成独立 TRIAGE 命名空间、
可复现初始化、Gateway 密码认证、真实模型三路分流、故障注入及重启验收，
最新状态以[最小业务闭环验收记录](./Minimal-workflow-acceptance-2026-10-15.md)为准。

## 验证目标

在不改动原始 `DataPipelineDemo` 仓库、项目默认 IRIS 环境和业务数据的前提下，验证 AI Hub EAP SDK 能否在 IRIS Interoperability Business Process 中调用受限 ToolSet、取得结构化决策，并由 IRIS 侧校验和处理失败结果。

## EAP 软件与隔离部署

- EAP 归档包含 AI Hub 预发布软件；EAP README 明确说明不应将其用于生产，API 与访问控制可能变化。
- 本次用于验证的镜像：`docker.iscinternal.com/docker-intersystems/intersystems/irishealth:2026.3.0AI.154.0`，平台为 `linux/arm64`。
- 另一个 `iris:2026.3.0AI.154.0` 镜像是 `linux/amd64`；在 ARM64 Docker 主机运行时，IRIS 报 `Unsupported CPU` 并退出。不要把该 amd64 镜像误认为 Apple Silicon 可用版本。
- 同版本 macOS 安装包中的 IRIS 可执行文件为 Mach-O arm64；本次未在宿主机安装该 kit。
- ARM64 EAP 容器以独立 Docker volume `ai-hub-eap-validation-data` 运行，宿主端口映射到 `127.0.0.1:1973`（IRIS superserver）和 `127.0.0.1:52775`（Web）。没有挂载项目的 `data/iris`，也没有替换项目默认的 IRIS Community 镜像。
- 初次无 key 启动时，Interoperability 因许可不足未自动启动。随后把开发者本机获得的 license key 只读挂载到测试容器，IRIS 日志显示许可有效（128 users）并报告 `Interoperability System Startup Complete`。
- key 文件本身及其内容不得复制到知识目录、Git 或其他共享位置。项目约定的本地路径为 `iris/license/iris.key`，并由根目录 `.gitignore` 排除；默认 Compose 配置不会自动挂载或使用它。

## 独立 Web Gateway 验证

- 原 EAP 容器虽然映射了宿主机 `127.0.0.1:52775` 到容器 `52773`，但容器中没有内置 HTTP listener。问题不是缺少 CSP.ini 配置，而是 EAP 实例未运行内置 Web Server；仅做端口映射不会启动它。
- 使用当前 active Docker context（Colima，ARM64）拉取并运行了原生 `linux/arm64` 的 `containers.intersystems.com/intersystems/webgateway:2026.2`。AMD64 manifest 存在，但在 ARM64 Colima 中请求 AMD64 时下载未完成，因此改用 native ARM64。
- 新建仅供验证的 Docker network `ai-hub-eap-webgateway`，将 EAP 与 Gateway 加入该网络。Gateway 使用 Server Profile `AIHubEAP` 连接 `ai-hub-eap-validation:1972`；Gateway 管理界面的 Test Server Connection 返回成功，确认能访问 IRIS 2026.3.0AI (Build 154U)。
- Gateway 的 HTTP 仅绑定宿主机 `127.0.0.1:52776` 到容器端口 `80`。镜像默认 Apache `CSP.conf` 仅为 Gateway 管理页面启用 CSP handler；新增 `/csp/` CSP handler 后，`http://127.0.0.1:52776/csp/sys/UtilHome.csp` 返回 IRIS 登录页面（HTTP 200）。没有尝试登录。
- 镜像默认运行正常，但首次用自定义 `ISC_CSP_INI_FILE` 和 durable directory 启动时，入口脚本报告将 `CSP.ini` 复制到 durable 目录失败（`copy_file_range: is a directory`）。本次因此在本地 Gateway 管理界面保存 Server Profile 和 `/csp` 路由，并在 Gateway 容器内更新 `CSP.conf` 后 reload Apache；配置保存在当前容器，不是可重建的项目配置。
- 结论：该 EAP 镜像适合通过单独 Web Gateway 容器访问，不必启用 IRIS 内置 Web Server。当前 Gateway 仅供本机验证；生产部署需持久化配置、限制 Gateway 管理界面并按正式安全要求配置 TLS/凭据。

## SDK 与 ToolSet 验证

后续实现更正：本节中的 `USER` / `HSLIB` 手工映射仅为早期探针的历史记录，不应作为项目安装方案。当前实现新建独立 `TRIAGE` 数据库及命名空间，调用 `%EnsembleMgr.EnableNamespace("TRIAGE")` 启用互操作；系统自动配置相关类库。应用 BP、AI Hub Agent、ToolSet、消息及持久化审计均在 `TRIAGE` 中运行，不需要应用代码切换到 `HSLIB` 或手工补系统库映射。已在全新数据目录验证自动初始化、12 个应用类编译和三种分流结果，详见[可复现工作流说明](../contest/README.md)。

- EAP 的 `HSLIB` namespace 中存在 `%AI.Agent`、`%AI.ToolSet`、`%AI.Tool` 和 `Ens.BusinessProcess`。`%AI.Agent` 的可用方法包括 `CreateSession`、`Chat`、`Run` 和 `UseToolSet`。
- 为避免写入只读 SDK 库，验证类保存在 EAP 的 `USER` namespace。该实例中将 `%AI` 包映射到 `IRISLIB` 后，可编译继承 `%AI.Tool` / `%AI.ToolSet` 的类；将临时 `ContestValidation` 包映射到 `USER` 后，`HSLIB` 中的 Agent 可发现并使用它们。
- 最小 ToolSet 暴露了只读 `GetTriageFacts(messageId)` 工具。Agent 的 ToolManager 发现到 `GetTriageFacts` 及其 JSON 参数定义，直接调用返回测试消息的确定性事实。
- 使用兼容 OpenAI Chat Completions 的本地 mock provider（只监听 EAP 容器网络命名空间中的 `127.0.0.1:8088`）。本地 dummy key 仅用于该 mock，不是真实凭据；本次未向外部模型服务发起请求。
- 模型标识会影响工具能力：使用 `local-mock-model` 时，SDK 请求未包含工具 schema；改用支持工具调用的标识 `gpt-4o-mini` 后，请求包含 `tools` 中的 `GetTriageFacts`，Agent 收到工具调用后执行 Tool，并把工具结果以 `tool` 消息加入后续模型请求。这里验证的是 SDK 传输与工具循环，不代表真实 `gpt-4o-mini` 模型已被调用。

## Interoperability 端到端验证

在 EAP 的 `USER` namespace 编译并启动了隔离测试 Production，包含 `EnsLib.Testing.Service`、`EnsLib.Testing.Process` 和临时 `ContestValidation.TriageBP`。通过 `EnsLib.Testing.Service.SendTestRequest` 向 BP 发消息。BP 在 `HSLIB` 创建 AI Hub Agent，绑定 ToolSet，创建 session 并调用 Agent；之后由 BP 解析 JSON，并只允许 `deliver`、`quarantine`、`human_review` 三种动作。

本地 mock 记录到 13 次 provider HTTP 请求，其中 4 个 Agent tool-call 周期及 4 个对应的 Tool 结果；请求计数包含前期诊断调用及 provider 错误重试。最终验证结果：

| 场景 | 结果 |
|---|---|
| 允许的 `quarantine` 决策 | BP 成功，返回 `{"decision":"quarantine","reason":"Required fields are missing in the test facts."}` |
| Agent 返回不允许的 `delete_production` | BP 以 `#5001: AI Hub decision violates IRIS triage policy` 失败，没有执行该动作 |
| Agent 返回无效 JSON | JSON 解析报 `#5035 Parsing error`，BP 失败 |
| mock provider 返回 HTTP 503 | SDK 返回 `%AICore ProviderError`，BP 失败，没有默认成功 |

这些结果证明本次 EAP build 中，自定义 BP 可实际调用 AI Hub Agent、执行注册的 ToolSet，并将 Agent 输出留在 IRIS 策略检查之下；不构成对 EAP 正式支持状态或真实模型质量的保证。验证后已停止临时 Production 并移除 mock 容器；保留隔离的 EAP 实例、数据卷和测试类，以便后续验证。

## 限制与未决项

- 本轮未进行真实模型推理，也未验证真实 provider 的凭据管理、模型语义质量、token / 成本统计、超时及服务端追踪。当前仓库没有可供验证的本机 provider 配置；不得将密钥写入仓库。
- 测试使用固定、无业务数据的输入与测试 Tool；尚未接入真实生产消息事实、隔离队列或人工审核流程，也未验证重复消息、超时和副作用处理。
- EAP 容器内仍没有 `52773` 的 HTTP listener；这是当前独立容器运行方式的预期状态。Management Portal 已通过 Web Gateway `127.0.0.1:52776` 返回登录页面，EAP 上原 `52775` 映射仍不会提供门户服务。
- Gateway 配置目前是当前容器内的临时验证配置，未保存为项目 Compose/配置文件；容器删除重建后需重新配置。自定义 `ISC_CSP_INI_FILE` 持久化启动错误尚未解决。
- 项目默认 IRIS 镜像为 IRIS for Health Community `2026.1`；测试使用单独的 `2026.3.0AI.154.0` EAP 容器，因此尚未证明 AI Hub 可安装或兼容于项目现有 `2026.1` 实例。
- AI Hub EAP 是预发布软件，接口与治理功能可能变化。官方资料目前未给出针对当前 build 的详细兼容矩阵，也未确认 BP 对 Agent 调用的专门集成保证。

## 后续工作

1. 在获得授权的本地 provider 配置后，再单独验证真实推理；记录准确的 EAP build、provider / model、token 与成本统计方式、脱敏日志和可观察性，不把任何凭据提交到仓库。
2. 决定参赛实现范围后，再把验证原型整理为项目功能：接入真实消息事实、确定性 IRIS 策略、隔离/人工审核动作和审计记录；不要用 mock 结果冒充真实 AI 决策。
3. 将已验证的 Web Gateway Server Profile、`/csp` 路由和 Apache `CSP.conf` 整理为可重建的配置/Compose；当前容器内配置仅用于即时验证。
4. 确认竞赛目标平台是否接受该 EAP build。
5. 评估项目默认 IRIS `2026.1` 与 AI Hub EAP `2026.3` 的兼容路径；在确认之前，不替换项目默认 Compose 镜像或宿主数据。

## 参考资料

- [AI Hub EAP README](https://github.com/intersystems-community/ai-hub-eap/blob/main/README.md)：部署、许可及预发布说明。
- [ObjectScript SDK Guide](https://github.com/intersystems-community/ai-hub-eap/blob/main/ObjectScript_SDK_Guide.md)：Agent、session 和 ToolSet 示例。该指南提示 API 仍可能变化。
