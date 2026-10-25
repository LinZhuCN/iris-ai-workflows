# Privacy Agent factory (P4 slice)

[English](./AGENT-FACTORY.md) | [简体中文](./AGENT-FACTORY.zh-CN.md)

<http://127.0.0.1:5173/agents> 上的 **Agents** 页面使用真实 IRIS API、持久化版本和 `%AI.Agent` 调用。它不是早期的配置夹具。本切片仅支持一个有界的 `privacy_review` 模板，不支持任意 Agent 代码或不受限制的自然语言政策。

独立的[分阶段风险审核原型](./MONITORING.md#staged-risk-review-free-evaluation-only-prototype)使用两项无工具任务和服务器选择的开发证据。它仅用于终端/评估，不是另一工厂版本、UI 操作或业务 Agent 绑定。其单独授权的六案例模型冒烟测试完成 5/6，其中仅 2/6 符合全部四项作者判断检查；问题过度扩展且有一项定位器输出形状错误，未达到质量验收。可选的[仅定位器 v2 实验](./MONITORING.md#locator-only-v2-experiment-free-validation-no-model-result)保留判断/证据/聚合契约，与工厂发布保持独立。其[已授权重测](./MONITORING.md#authorized-staged-v2-run-six-completed-five-whole-case-matches)完成 6/6 案例，5/6 符合所有作者检查。独立的[仅判断器分阶段 v3 改进](./MONITORING.md#judge-only-staged-v3-refinement-free-validation-only)随后通过[授权重测](./MONITORING.md#authorized-staged-v3-run-six-machine-matches-semantic-review-still-open)，6/6 符合全部四项作者检查。语义解释和证据最小化问题仍然存在；这两项实验都未提升为正式版本或绑定。

独立的[前瞻性语义验收包](./MONITORING.md#prospective-semantic-acceptance-pack-frozen-runtime-external-review-pending)冻结了 v3，并新增八个案例/48 项人工评分标准判断。该包免费准备、由助手撰写、未经独立审核，也不是另一工厂版本。其[授权探索性运行](./MONITORING.md#authorized-prospective-challenge-run-six-label-matches-eight-safe-recommendations)完成 8/8，主要状态匹配为 6/8，未解决项/操作匹配为 8/8；语义结论和状态边界审核仍待完成，未发布。[未采纳的分类提案](./MONITORING.md#status-boundary-proposal-not-adopted-no-retrospective-regrading)现记录了针对实际输出的三项待决事项；它不是新的工厂/运行时版本，也不是回溯重新评分。

独立的[本地导出证据采集器](./MONITORING.md#source-backed-export-evidence-first-local-synthetic-slice)现从实际生成/转换的合成行中推导最小化事实，并进行限定范围的收据回读。它不是工厂版本或业务 Agent 绑定；未接入的权限/专家/审批证据仍属未知。

## Prerequisites and setup

使用现有的 [Knowledge 设置](./KNOWLEDGE.zh-CN.md)和 [DEMO Connector 设置](./MONITORING.md)。需要活动的本地索引、固定的 `local-demo / DEMO` Connector 和已配置的真实提供方。更新检出版本以加载工厂类后，运行现有监控准备流程；或者重启已配置的 IRIS 容器以运行其安装程序。无需新凭据或命名空间。

本地演示构建者可以写入；查看者可以读取。除 Knowledge 读取授权外，API 还复用 `ContestMonitorRead` 和 `ContestMonitorDeploy`。这些是单一演示的权限检查，不是租户隔离。密码保存在被忽略的文件中；可选 Vite 演示预填值会公开给浏览器，绝不能用于共享/生产部署。

## Workflow

1. 使用预填的本地演示账户连接。
2. **仅使用合成/公开信息**描述所需的隐私审核者。确认可能产生的模型费用，然后生成受限草稿。一次真实的无工具 Agent 调用会提出名称、所提供的用途和证据查询。服务器固定当前索引表/版本、语料指纹、模型、执行器版本和四轮迭代上限。
3. 选择生成的草稿。检查/编辑名称、用途和检索查询。用途仅作描述，不是可执行的系统提示。保存会使其测试资格失效；修订会拒绝并发编辑。
4. 显式授权三次真实合成测试（每个案例最多四轮 Agent 循环迭代）。每次测试都必须调用两个只读工具：`ReadPrivacyFacts(runId)` 和 `SearchPrivacyEvidence(runId)`。工具要求使用工作进程绑定的 run ID，不能接收其他命名空间、索引、端点、消息负载或可执行操作。
5. 检查每个结果、引用、实际工具调用、AI Hub 会话和用量。三个预期结果必须全部匹配：`risk`、`no_finding` 和 `insufficient_evidence`。失败/无效结果不能授权发布。
6. 确认发布确切经过测试的配置哈希。已发布配置不可编辑。后续更改需创建新草稿。
7. 加载发现快照，并显式记录与 DEMO 分析观察点的绑定。服务器会重新检查当前源哈希、支持状态和运行状态。**此操作仅记录意图：**不会连接由观察触发的执行、改变投递或启用 Gate 强制执行。禁用已发布版本也会禁用其记录的绑定。

只有在三案例报告中恰好一个场景失败时，才可显式进行单案例重测。重测需要新的费用确认，最多四轮迭代，并保留原来两个通过案例及其来源报告/会话来源信息。这不是自动重试，原失败报告仍可查看。

## Evidence and result boundaries

检索会打开固定的已完成索引，而不是之后变为活动状态的任意版本。检索到的五条片段保留块 ID、分数、来源 URL、定位符、种类、权威性标签和范围。每条命中片段文本最多 2,000 个字符。此路径不会加入历史/未审核材料。已准备的官方证据、LLM 撰写的导读和合成组织政策彼此可区分；并非所有结果都是法律权威。

结果模式严格包含 `assessment`、`reason` 和 `citations`。原因最多 2,000 个字符；一至五条引用必须指向该测试实际读取的证据。路由操作和捏造的引用 ID 都会被拒绝。参考文本是数据，不是指令。三个小型合成标记测试验证的是接线和受限行为，**不是广泛的隐私审核质量或 HIPAA 合规性**。单独授权的[十二案例合成评估](./MONITORING.md#twelve-case-privacy-evaluation)最初完成 **9/12 通过**，并不代表整体质量验收。两个缺少用途的案例错误地返回 `no_finding`；一个矛盾标识符案例保守地返回 `risk`，而非预期的 `insufficient_evidence`。原报告保持不变。

[P5 事件操作](./MONITORING.md#events-and-human-review-p5)现在使用真实观察结果并保存人工操作/意见。自动审核明确标记为 `blocked_budget`，不是已完成发现。手动调查路径已完成一项单独授权的真实调查，结果为限定范围的 `risk`，含真实工具引用和独立发现事件。源事件/意见未变。Agent 绑定仍只是非执行意图；自动执行和诊断模板尚未实现。

评估之后，加入了确定性的 `privacy-safety-v1` 验收防护。现在，`no_finding` 结论必须具备显式类型化的合成分析事实：已知用途、无直接标识符以及已验证的去标识化。缺失、类型错误或相互矛盾的值会导致输出被拒绝并保留供检查；不会悄然改写成通过的模型答案。保守的 `risk` 和 `insufficient_evidence` 仍属于非清洁发现。这是输出验收防护，不代表模型本身已得到纠正。已发布 Agent 提示/配置及其既有哈希没有重写。新案例会单独记录验收政策版本。框架断言和对两个原始不安全输出的重放验证了该防护，且没有再次调用模型。

### Versioned correction and full retest

`POST /agents/revise` 只接收已发布源版本的确切 `id` 和 `revision`。它会幂等地将该版本克隆为独立的 `privacy-review-v2` 草稿，不调用模型，也不编辑源版本。会持久化父版本身份/哈希以及固定的、由服务器管理的提示版本/SHA-256。新的配置哈希包含提示来源；旧版哈希语义保持不变。修正后的指令会先处理缺失或类型错误事实，再处理矛盾，然后才评估风险或有限的清洁结果。授权本身不能证明已经去标识化；嵌入的说明仍是不可信数据。

候选版本完成了单独授权的完整十二案例真实重测：使用原始清单、`deepseek-flash` 和索引 7，**12/12 通过，零技术失败**。详见[确切结果和累计用量](./MONITORING.md#versioned-v2-retest)。这不是统计基准、法律认证或诊断评估。更准确地说，这是**机制回归测试**：提示直接提供了标记到标签的规则。它不能证明可根据业务事实识别 HIPAA 风险，也不能证明检索条款能够支持推理。独立的[业务上下文基准](./MONITORING.md#business-context-hipaa-risk-benchmark)负责这些验收要求。其独立、版本化的只读运行时与此标记执行器相互独立，不会发布或绑定该版本。原始 9/12 报告和已发布配置保持不变。候选版本**仍是草稿**：未授权自动发布、绑定、重复调查、业务操作或持续审核。

V2 草稿不能使用旧版三案例测试或单案例重测作为发布捷径。发布需要匹配且完整的十二案例评估：配置/提示哈希、清单哈希和所有固定案例结果必须一致。Agents 页面会单独显示资格，并且仍要求对确切哈希进行确认。编辑草稿会使资格失效。此处的发布资格是技术生命周期门槛，不是法律审批或业务上下文验证。不要将 v2 宣传为经过验证的 HIPAA 审核者。

作业/配置/报告/绑定保存在 `^ContestAgents`；操作使用现有受保护的平台审计。作业不会自动重放。启动时会分配新的启动身份，因此上次服务器运行中未完成的作业会报告为 `interrupted`。这不是通用分布式租约/作业平台，且无法保证取消正在运行的提供方请求。

新的调用会在 `Chat` 后持久化 SDK 对话、用于调试的拒绝输出以及累计会话统计。较早的验收案例保留了显式工具/证据记录，但早于 SDK 历史持久化功能。此 EAP Agent 响应返回的 `Usage` 描述最终模型响应，不一定覆盖整个工具循环。UI 会将其与 `GetStats()` 累计会话计数器区分开。推理 token 已包含在完成 token 中，不得重复计数。若没有固定的提供方价格表，不推断货币成本。

## API

独立版本化的业务上下文审核者现还提供可选的 `hipaa-business-runtime-v2`，带有条款查找和来源句柄引用；参见[升级和限制](./MONITORING.md#v2-evidence-and-judgment-upgrade)。这**不是**工厂的 `privacy-review-v2` 标记分类候选版本，也不会修改任一工厂版本。单独授权的模型重测达到 12/12 输出契约通过、8/12 完整作者-机器一致；这不是法律合格结论，也不授权发布任一工厂版本。

可选的[业务运行时 v3](./MONITORING.md#v3-conditionclaim-separation-and-compact-evidence-free-only)将主张警告与条件证据分离，并生成紧凑的模型输入来源视图，同时保持规范审计证据不变。单独授权的真实模型重测回退为 6/12 契约接受、1/12 完整作者-机器一致；未推广。没有执行工厂发布/绑定。新的运行时版本需要新的明确费用同意，不能复用 v1/v2 请求密钥。后续的 [v4 证据计划改进](./MONITORING.md#v4-single-use-evidence-plan-free-implementation-not-model-evaluated)同样仅供评估且需选择启用：服务器预填事实和一个合并检索工具，v3 判断契约与请求限制不变。它具备免费的 SDK/本地检索覆盖，但授权模型批次由于工具参数错误和一项矛盾的最终评估，接受输出为 0/12。未推广，也不代表法律质量结果。这些运行时都不能使工厂 Agent 获得发布或绑定资格。

所有路径均位于 `/api/monitor/v1` 下；使用原生 Basic 身份验证。POST 要求 JSON、`X-Requested-With: IRIS-Workflows`，且不超过 4,096 字节。

| 方法 | 路径 | 正文 |
|---|---|---|
| GET | `/agents` | 版本、最新 20 个作业、已记录绑定、权限 |
| POST | `/agents/generate` | `purpose`、`acknowledge_cost: true` |
| POST | `/agents/edit` | `id`、`revision`、`draft: {name,purpose,retrieval_query}` |
| POST | `/agents/revise` | 已发布源版本 `id`、`revision`；幂等克隆 v2，不调用模型 |
| POST | `/agents/test` | `id`、`revision`、`acknowledge_cost: true` |
| POST | `/agents/retest` | `id`、`revision`、`report_id`、`acknowledge_cost: true` |
| POST | `/agents/publish` | `id`、`revision` |
| POST | `/agents/bind` | `id`、`revision`、`snapshot_id` |
| POST | `/agents/disable` | `id`、`revision` |

生成/测试会返回 HTTP 202 和持久化作业。常规读取、发布、绑定以及下述回归命令不会调用模型。

## Verification

不计费的 HTTP 检查：

```sh
python3 contest/agent_test.py
python3 contest/platform_test.py
```

编译 `contest/dev/AgentTests.cls`，并在 **TRIAGE** 中使用 `test_type="testproduction"` 运行 `Contest.AgentTests`。其 `TestControl` 不会停止/启动 Production。十个框架方法覆盖契约、工具隔离、版本失效、不可变发布、禁用行为、固定索引防护和启动范围、被中断作业以及 Connector 输出设备保留。生命周期测试夹具通过事务回滚，不会作为真实评估结果发布。前端验证使用现有构建、lint 和测试命令。

获授权的真实验收使用 `deepseek-flash`：一次构建者调用、三次初始测试调用，然后单独授权一次失败案例重测。初始风险和无发现案例通过；无充分证据输出被严格契约拒绝。重测通过，并保留前两个案例的来源信息。原始失败未保留确切输出，因此无法还原具体模式违规；之后的失败会保留被拒绝输出。不要将此描述为首次运行就通过全部三个案例。通过浏览器发布并绑定了已接受版本。容器重启后，版本、报告、知识索引和绑定均保留，未再次调用模型。

## Startup recovery

安装程序仅在预期的受管理 Production 出现故障时使用 `Ens.Director.GetProductionStatus` 和 `RecoverProduction`，然后启动该 Production。若正在运行的是其他 Production，则拒绝操作；有意暂停的 Production 需要人工干预。如果 DEMO 已存在且包含 `Demo.Production`，启动时也会恢复它。不会因副作用而创建 DEMO，也不会重放 Agent 作业。现有互操作队列保留正常 IRIS 恢复语义；这不能保证任意外部业务副作用恰好执行一次。

仍需要固定的 EAP 镜像/许可证配置和现有 Compose 文件。不会更改 Docker Desktop 或其他项目的自动启动政策。已验证常规重启后两个受管理 Productions 都在运行。执行工具阻止了一次突然终止故障注入尝试，因此不能声称已验证新注入突然关机后的自动恢复。先前发生的实际非正常状态已在本次启动加固之前通过同一官方恢复 API 恢复。
