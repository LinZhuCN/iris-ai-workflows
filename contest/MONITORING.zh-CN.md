<a id="production-monitoring-and-the-legacy-demo-connector"></a>

# Production 监控与旧版 DEMO Connector

**语言：** [English](./MONITORING.md) | 简体中文

对于固定的现场演示 **organizations → first enrollment → new message → AI audit**，
请使用 [M5 入驻演示](./M5-ONBOARDING-DEMO.md)
([中文](./M5-ONBOARDING-DEMO.zh-CN.md))：
<http://localhost:5173/demo/m5>。它使用相同的 Production 观察器/审核器，
并采用仅限 M5 的配置快照、范围受限的合成发送以及受限归档/重置。
无需创建第二个 Production。

<a id="managed-active-productions"></a>

## 受管的活动 Production

在共享工作区登录后打开 **[Productions](http://localhost:5173/pipelines)**。
受监控对象由**本地 IRIS 实例、命名空间和确切的 Production 类**标识，
而不是由批次或猜测的流水线边确定。用户选择一个或多个正在运行的 Production，
而非单独的业务流。登记会将该 Production 当前组件中的所有活动纳入观察范围；
无需手动登记业务流或关联声明。下文所述的轮询、保留和归因限制仍然适用：
范围界定并不保证完整捕获或语义审核。

1. 单击 **Discover active Productions**。仅构建者可用的发现功能会枚举可访问的
   本地命名空间，并读取其实际活动的 Interoperability Production/配置。
   它不会启动 Production，也不会更改命名空间映射/角色。无法访问的命名空间会
   明确报告，不会被悄悄视为空命名空间。发现本身不会登记任何对象。
2. 选择命名空间 / Production，检查其实际组件数量和配置指纹，然后单击
   **Enable read-only monitoring**。已登记对象会显示 **Already monitored**。
   登记时会重新检查活动身份/配置，以拒绝过时的发现结果。
3. 在清单中选择 **Inspect namespace / Production**。每个对象都有独立的启用状态、
   管理修订号、扫描时间戳、错误、游标、事件及关联的业务审核历史。
4. 检查运维事件和元数据，添加审核备注，并使用现有的
   `open → in_review → resolved` / information / ignore / reopen 状态转换。
   操作要求提供确切的 Production/事件修订号。操作不会重启主机、更改审批、
   重放业务消息或调用 AI。
5. **Pause observation** 只会暂停该对象的观察器。**Resume observation**
   要求该确切 Production 处于活动状态；保留的游标随后会追赶新数据。
   这两个操作都不会停止或启动业务 Production。

<a id="generic-observation-and-attribution"></a>

### 通用观察与归因

[ProductionMonitor](./src/ProductionMonitor.cls) 在现有定时器的
`RouteReview.Pump` 启动的新后台作业中运行。它使用独立的工作器锁和已存储的
登记记录；打开/刷新浏览器不会运行采集器。安装无需修改源主机或重启 Production。
每个启用对象每轮轮询都会读取状态/配置，并从 `Ens.MessageHeader` 和
`Ens_Util.Log` 各读取最多 200 条新记录。游标/事件/计数器更新会一并提交；
采集失败时会保留之前的游标，并显示明确错误。重复扫描不会覆盖已有事件或人工备注。

默认情况下，仅公开组件名称/类/启用状态/池、配置摘要、消息头/正文引用 ID、
源/目标主机、会话 ID、对应消息头 ID、消息类型、状态/错误标记、日志 ID/类型/
组件和时间戳。**登记不授权读取消息正文。** 如下文所述，M2 可在单独获得明确的
Production/配置范围内同意后，在本地检查已注册的结构化属性。不会读取消息描述/
错误状态文本和自由文本事件日志。配置设置值只会临时用于生成摘要，不会返回或
存入快照。消息头/日志的采集从登记时开始，不会回填历史正文。元数据按受管
Production ID 存储，事件分页彼此独立。

IRIS 命名空间消息头没有明确的 Production 名称列。归因依据登记时间、匹配的主机名，
以及读取前后相同的活动 Production/配置。这只能证明采样到的活动快照中的运维观察，
**不能证明扫描间隔内没有发生 Production 切换**。页面会说明这一限制。
不得将这条仅含元数据的路径视为权威法律/业务证据。已停止/替换的 Production 和
已更改的配置会明确显示，不会悄悄将受管身份重新绑定到新的 Production。

<a id="per-production-business-risks"></a>

### 各 Production 的业务风险

详情页会单独列出已保存且绑定来源的审核/事件历史：

| Production | 现有审核适配器 |
|---|---|
| `DEMO / Demo.Production` | 持久化观察事件，包括实际范围内的 `risk`、信息缺口、业务失败和规则拦截；链接到源事件详情 |
| `PIPELINE / Contest.Aggregation.Production` | 历史聚合发送后审核 |
| `UTILIZATION / Contest.Utilization.Production` | 利用率发送后审核，以及确切声明/批次审核与处置 |
| 其他活动 Production，包括控制平面 TRIAGE | 通用观察；M2 注册结构化属性证据和 M3 采样审核需要单独授予检查/导出/模型权限 |

关联审核可能早于登记，并会标注为历史记录。源适配器以及确切的
Production-观察/报告绑定可建立来源链；但两者都不能单独证明法律合规。
任意 Production 无需模板专属类清单即可登记，但其元数据本身**并不能**证明业务目的或
HIPAA 风险。其初始 `coverage_gap` 事件及详情文字会明确区分“没有可用审核”和
“所检查用途未发现偏差”。登记不会授予模型预算，也不会安装不受限制的 Agent。
现有的确切回执模型同意流程仍保留在声明/旧版审核流程中。

通用运维事件与关联审核采用彼此独立的分页和人工工作流。现有 **Events** 工作区会链接到
**Events & risks by Production**；较旧的 DEMO 事件工作流仍可使用。

<a id="api-permissions-and-installation"></a>

### API、权限与安装

| 方法 | `/api/monitor/v1` 下的路径 | 访问权限 / 效果 |
|---|---|---|
| GET | `/productions` | Reader；已登记对象和采集器健康状态 |
| GET | `/productions/discover` | Builder；仅发现本地活动对象 |
| POST | `/productions/enroll` | Builder + CSRF；确切活动名称/配置及明确确认 |
| POST | `/productions/manage` | Builder + CSRF；确切管理修订号、启用布尔值 |
| GET | `/productions/:id` | Reader；单个对象的状态/事件/审核历史 |
| GET | `/productions/:id/events?before=...` | Reader；每页 25 个事件的游标分页，最新优先 |
| GET | `/productions/:id/risks?before=...` | Reader；每页 25 条审核的偏移分页 |
| POST | `/productions/action` | Builder + CSRF；Production/来源键/事件修订号/允许的操作/备注 |

现有 reader/builder 资源检查及源数据库权限仍然适用。不会添加任何角色或系统映射。
该 Connector 仍表示**现有的本地 IRIS 实例**：本次变更不包含远程实例登记。

<a id="business-flow-risk-monitoring-m1-m5"></a>

### 业务流风险监控：M1-M5

**2026-10-20 更正：** Production 是唯一的登记单位。IRIS 可以在不同的
Interoperability 命名空间运行多个 Production；发现功能会列出可访问的活动对象，
由用户选择要管理哪些对象。不要再引入第二个按业务流登记的步骤。

Production 全范围观察支持通过已注册证据适配器进行有界审核；它不会让任意有效载荷
或下游业务行为自动具备语义可知性。更正后的实施顺序如下：

| 阶段 | 交付内容 | 状态 |
|---|---|---|
| M1 | Production 级登记范围和隔离；可选的版本化语义上下文绝不是采集前提 | 范围/API/UI 更正已实现；早期的上下文/证据脚手架不代表已完成可复用监控 |
| M2 | 自动关联所选各 Production 中的实际消息/会话活动；无需手动输入路由即可捕获可复用的受支持格式 | 已实现并经运行时验证：已观察的边/会话关联、经同意的结构化属性捕获和明确的覆盖处置 |
| M3 | Production 范围内采样及单独授权的有界 AI 审核；上下文缺失、不支持的格式、预算限制和失败均保持可见 | 已实现；3 次真实 A/B/C 审核、6 次请求、确切引文及已撤销的验收授权 |
| M4 | Production 级发现/登记、已观察路径、覆盖情况和结果；语义上下文仅作可选增强，不提供业务流登记向导 | 已实现并经浏览器验证：实际边/会话证据、覆盖情况、绑定报告和独立同意控制 |
| M5 | 多路径观察/隔离，以及演示中的范围化 HIPAA 条件评估 | **已完成文档所述演示范围，但需先明确修复输入映射。** 三类结果已通过真实 Production 事件和 AI Hub 验证。首轮 2/3，单独批准的治疗跟进 1/1；原始报告均予以保留。真实系统证据集成不是演示的前提 |

M2 必须根据实际消息/会话关联发现已观察到的边，包括登记后出现的新路径。
配置是补充信息；推断的拓扑不是已验证的运行时路径。每个观察项都必须有明确的
捕获/审核处置（包括不支持、失败、未采样或预算受限），不能因为没有声明或可选上下文
匹配就消失。捕获健康状态、积压和丢失情况必须可见。登记时的历史游标和归因边界仍须
明确说明。

审核策略适用于 Production 级别；观察所有业务路径并不意味着要对每条消息都调用外部模型。
采样、明确的模型经费授权和本地有效载荷访问授权是相互独立的控制措施。可选上下文
有助于解析业务目的、接收方或确切声明版本，但不能作为采集允许列表。缺失或含糊的匹配
必须保持可见，不能据此臆造审批、实际目的或 HIPAA 违规。

现有的 `FlowEvidence` 信封要求手动配置 flow ID 和修订号。它是**旧版 M1 脚手架**，
不是 M2 所需的观察契约。M2 必须将证据锚定到受管 Production 和实际消息/会话身份，
并可选引用上下文。不要为了满足该旧版校验器而伪造手动业务流记录。

<a id="retained-optional-review-context-scaffolding"></a>

#### 保留的可选审核上下文脚手架

M1 增加了 [ProductionFlow](./src/ProductionFlow.cls) 和
[FlowEvidence](./src/FlowEvidence.cls)。旧的手动业务流设计已被取代：
`ProductionFlow` 记录保留为可选审核上下文，不再是实际业务流清单。为兼容性和历史完整性，
现有端点和存储名称仍予保留。上下文身份包含其 Production ID 和字面 flow key；
两个 Production 中相同的 key 并不代表同一个 flow。每次保存都会追加不可变修订，
固定实际活动 Production 配置哈希，并检查所选主机是否存在且已启用。主机选择说明的是
已配置拓扑，**不是已验证的消息边**。针对完全相同命令的丢失响应重试会返回已保存修订；
过时/冲突命令会失败。更改配置要求提供确切的父修订号和摘要。

每个配置都会记录标题/所有者、来源、有序处理器、发送方、声明用途、目录中的合成接收方、
可选声明记录/摘要、已注册采集器契约和审核策略。当前格式契约是 `structured-message-v1`
下的 `fhir-r4` 和 `json-object`；在注册表中存在这些契约**不表示**已安装 M2 运行时采集器。
字面的有界字段路径是检查配置，不代表已证明未发送其他字段，也不代表已批准的数据范围。
不接受 URL、SQL、可执行选择器、任意采集器类或模型授权。

用途仍由用户声明；已注册的接收方选择并不是实际交付的证据。可选声明链接会在配置时冻结
该确切提案、上下文和决定。可以关联草稿，但不得伪造审批。后续编辑或审批不能改写快照；
如需纳入这些变更，必须创建新的业务流修订。也可以不关联声明，但这不代表合规，
也不会自动证明存在 HIPAA 违规。

内部证据信封会将观察绑定到确切的 flow ID、修订/摘要、Production 和配置。
它携带消息/会话/批次引用、交付结果/证据级别、本地引用摘要、现有类型化风险审核包以及
明确的覆盖限制。`attempted`、`failed`、`received`、`held` 和 `unknown` 结果彼此有别。
消息头或发送方结果不能证明接收方已接受；receipt/readback 级别需要相应的本地引用。
不得将声明重新标记为已验证观察。现有审核包的 `after_send` 阶段表示已观察用途的审核模式；
单独的结果字段会记录是否实际发生交付。

**信封校验检查的是契约，而不是引用内容的真实性。** M1 没有公开的证据提交 API。
M2 必须在持久化观察前，针对可信的本地捕获内容解析并验证引用；API 调用方不能只提交一个哈希
或设置 `synthetic=true` 就获得已验证的来源链。同样，配置也不能证明真实有效载荷是合成数据。
此合成演示未授权收集真实 PHI。

上下文详情响应现在会报告 `coverage.state=optional_context_only`、
`monitoring_prerequisite=false`、`automatic_review=false` 和零次模型调用。
上下文列表会标识为 `record_kind=optional_review_context` 和
`discovered_flows=false`。不得将它们呈现为已发现路径。保存记录不会激活采集、
授予模型预算、更改审批、发送/重放消息或更改 Production。M4 不得要求先存在这些记录才能
监控 Production。主要清单是观察到的运行时活动，而不是此列表。
Production 详情还会单独返回 `monitoring_scope`，标明
`unit=production`、`flow_registration_required=false` 和
`component_scope=all_current_components`。实际边并不能证明路径完整；
注册属性检查和采样 AI 审核各有独立的授权与覆盖边界。

| 方法 | `/api/monitor/v1` 下的路径 | 访问权限 / 效果 |
|---|---|---|
| GET | `/productions/:id/flows?after=...` | Reader；每页 25 条可选上下文，不是已发现的业务路径 |
| GET | `/production-flows/:id?revision=...` | Reader；最新或确切的不可变修订；即使 Production 不活动也可读取保留版本 |
| POST | `/production-flows/save` | Builder + CSRF；32 KiB 限制；只创建新修订，不激活 |

保存命令恰好包含 `production_id`、`flow_key`、`expected_revision`、
`expected_digest`、`production_config_hash` 和 `config`。首个修订使用
`expected_revision=0` 和空的 `expected_digest`。Schema 1 配置恰好包含
`schema`、`synthetic`、`title`、`owner`、`source`、`processors`、`sender`、
`purpose`、`recipient_id`、`declaration`、`collector` 和 `review_policy`。
`declaration` 是 JSON null 或 `{record_id,digest}`；`collector` 含
`id`、`format` 和 `fields`；`review_policy` 为 `observed-use-v1`。
此契约不授予执行权限或 AI 同意。

仅编译安装和只读 API 边界检查：

```sh
python3 contest/production_flow_test.py --install
python3 contest/production_flow_test.py --check
python3 -m unittest discover -s contest -p 'test_production*.py'
```

[ProductionFlowTests](./dev/ProductionFlowTests.cls) 使用实际的
`%UnitTest.TestProduction` 框架和无操作生命周期控制器。其注册表测试数据会回滚，
不会重启业务主机。登记、修订、声明、分页和跨 Production 分支需要完整的构建者授权执行；
开发 MCP 身份会在不扩大权限的情况下测试 schema 和拒绝写入分支。

原先已被取代的 M1 设计于 2026-10-20 的本地验收通过了 61 项构建者授权框架断言，
以及既有的 81 项 Production-monitor 和 86 项 declaration 断言。随后实际 HTTP API
在 `UTILIZATION / Contest.Utilization.Production` 下保存了 `quality-monitoring`
修订 1，并链接到现有已批准的 `demo-d3-browser-quality` 修订。重复保存和确切版本读取
返回了同一记录，包括冻结的审批哈希。只读检查器检查了跨两个受管 Production 的持久化 flow；
原有 D1-D6 检查器仍核对了 20 条历史请求和 237,219 个 token。没有模型请求、业务交付、
主机重新加载或 Production 生命周期变更。这些测试证明可选上下文注册表完整可靠，
**不代表更正后的 M1-M5 Production 全范围监控设计已完成**。

范围更正另经 91 项 Production-monitor 和 63 项可选上下文框架断言、9 项定向 Python 测试、
前端类型检查/lint 及 8 项 Production 解码器测试验证。实际 API 检查仍发现了 4 个正在运行
的 Production，并读取了两个已登记对象，其中一个保留了可选上下文记录。D1-D6 已保存证据
检查保持不变。没有删除或改写任何已存上下文；本次更正没有执行推理、业务发送或
Production 重启。

<a id="m2-production-wide-observations-and-local-evidence"></a>

#### M2：Production 全范围观察与本地证据

[ProductionEvidence](./src/ProductionEvidence.cls) 会由现有 Production 观察器调用，
针对**归属于该 Production 的每个新采集消息头**执行，不受手动上下文/声明记录影响。
安装不会重置登记游标，也不会回填旧消息正文。每条观察以 Production ID 和消息头 ID
标识，附带完整性摘要冻结，并按源会话及实际源/目标边建立索引。请求和响应消息头分别
作为独立观察项，包括其对应消息头引用。边/会话归属不能证明完整、有序的端到端路径，
也不能判定业务目的。

证据、索引、计数、覆盖事件和消息头游标会在同一个现有观察器事务中提交。重复捕获不会
覆盖观察记录或增加计数。采集级失败会保留游标。单条消息检查失败会存储
`evidence_failed` 并正常前进，避免阻塞后续消息；不会自动重试。对尚无当前同意的受支持
属性会存储 `not_authorized`；未注册消息类会存储 `unsupported`，且不会读取其正文。
不可变的捕获时 `review_state=not_enabled_m3` 会保留以维护历史完整性，绝不是安全结论。
M3 会增加一个实时 `current_review` 覆盖层，明确不计入观察记录的 `record_hash`。
证据 API 的 `model_calls=0` 仅描述本地捕获，不包括另行资助的审核；审核请求和 SDK 用量
有各自的记录。

当前可复用适配器识别：

| 消息契约 | 本地检查的属性 | 格式 |
|---|---|---|
| `Contest.Aggregation.SendRequest` | `Bundle` | FHIR R4 Bundle |
| `Contest.StructuredRequest` | `PayloadJson`，并检查其声明的 `Format` | FHIR R4 Bundle 或结构化 JSON 对象 |

适配器以明确消息契约为键，**不以 Production 名称或预注册路由为键**。
任意 FHIR/JSON 存储类、HL7、XML、流属性或自定义消息都不受支持，除非另有已注册属性适配器。
不支持的消息仍会生成观察记录和覆盖事件。格式声明会被验证，不会被直接当作证据接受。
结构化请求是可复用的真实 `Ens.Request`；独立的
[合成多路径 Production](./structured/Production.cls) 使用普通 BS/BP/BO 和本地唯一键 SQL
接收器，不涉及模型或外部传输。

本地检查对有效载荷大小（100,000 个字符）、FHIR 资源数（1-100）、递归深度（16）、
已访问节点数（2,000）和分类字段路径数（64）均有上限。支持的 FHIR 资源包括
Patient、Encounter、Condition 和 MedicationRequest。存储观察项只包含允许列表中的字段名/
路径、字段存在性、记录数、标识符/日期存在性、日期表示计数、未知子树计数及有效载荷摘要。
不会存储原始值或任意未知键名。未知子树只计数，不会递归分类；Bundle 级元数据并非全面的
标识符检查。这既不是 Safe Harbor，也不是 Expert Determination。字段是否存在/采用何种
表示形式不能验证源到输出的转换。除非另有依据，业务目的和实际业务接收方身份仍未确立；
传输主机名不等于接收方身份。

检查消息正文需要构建者针对确切的活动 Production/配置明确同意使用本地合成数据。
登记本身不授予此权利。配置发生漂移后会禁用读取，直到重新同意为止。撤销同意会停止
后续读取，但不会删除观察记录；之前跳过/失败的记录不会被悄悄重新处理。同意表示操作员
授权的合成演示范围；其本身不能证明有效载荷中不含真实 PHI。M2 不会调用提供方、Agent
或外部模型。

| 方法 | `/api/monitor/v1` 下的路径 | 效果 |
|---|---|---|
| GET | `/productions/:id/evidence?before=...&session=...` | Reader；每页 25 条不可变观察，可按确切源会话筛选，并返回捕获计数和观察器健康状况 |
| GET | `/productions/:id/paths?after=...` | Reader；每页 25 条实际观察到的边，并非猜测的完整路径 |
| POST | `/productions/authorize-inspection` | Builder + CSRF；仅接受 `production_id`、`config_hash`、`acknowledge_local_synthetic_inspection=true`；仅本地读取 |
| POST | `/productions/revoke-inspection` | Builder + CSRF；仅接受 `production_id`；禁用后续读取 |

观察器健康状态包括上次扫描/错误、是否积压完整的 200 条消息头批次，以及无法归属到当前组件
的命名空间消息头数量。这并非经测量保证零丢失：上游保留策略删除和轮询间的切换仍是不可检测
的覆盖限制。没有自动清除观察记录的功能；在非演示用途前必须制定运行保留策略。完整性哈希
只是本地一致性检查，不能抵御拥有高权限的数据库管理员。配置哈希标识扫描时快照，**不代表
已独立证明发送时的原始配置**。成功消息头仍记为 `outcome=attempted`、
`delivery_evidence=message_header_only`；不会仅因测试发送方报告成功就被观察器升级为
接收方已接受。

从仓库根目录执行的明确设置/验证命令：

```sh
# Compile M2 classes/API; no enrollment, body consent or sends.
python3 contest/production_evidence_test.py --install
# Only after local deployment approval: create/start independent OBSERVATION.
python3 contest/production_evidence_test.py --setup
# Only after synthetic-send approval: enroll, authorize local reads and send five batches.
# Refuses to rerun after saving its immutable local acceptance record.
python3 contest/production_evidence_test.py --run-acceptance
# Re-read saved observations and actual SQL receipts; no new sends or inference.
python3 contest/production_evidence_test.py --check
```

Production 选择器仍是登记 UI。M4 会在同一个 Production 工作区中呈现证据/路径及独立授权端点。

**M2 实际验收，2026-10-20：** 经批准的隔离对象 `OBSERVATION /
Contest.StructuredProduction` 已创建并选中；原先 4 个 Production 保持运行。
未创建任何 flow/context 记录。同意前的一个 route-A 批次生成了两条
`not_authorized` 请求观察记录。获准的 JSON route A 和 FHIR route B 生成了最小化事实。
首次使用前，已观察到的边中没有 route C；它的空 FHIR Bundle 生成了两条明确的检查失败，
但业务 SQL 交付仍成功；随后有效 JSON 生成了事实，其中包括未知字段计数。5 个批次共生成
5 条唯一 SQL 回执、20 条消息头观察记录和 12 条实际请求/响应边：6 条已捕获、2 条未经授权、
2 条 `evidence_failed`，以及 10 条不支持的回复。只读检查器验证了会话分组、
Production 隔离以及未存储原始值。重复自动扫描保留了相同计数。这是 M2 证据验收，
不是 M3 HIPAA 结论或最终 M5 AI 验收。

M2 最终回归验证通过 41 项构建者授权证据断言、93 项 Production-monitor 断言、
63 项可选上下文断言，以及 14 项定向 Python 测试。证据测试覆盖准确的 2,000/2,001 节点和
100/101 资源边界、最小化值、分页、重复计数器、防篡改拒绝、正文缺失失败、同意/撤销以及
Production/会话隔离。开发 MCP 测试套件也在未扩大权限的情况下通过。UI 类型检查、
定向 lint 和 8 项 Production 解码器测试均通过。原始 D1-D6 已保存证据检查器仍保留
20 条历史请求 / 237,219 个 token；该工作流中没有新增模型请求或交付。

```sh
# Compilation only; no enrollment, manual Pump, host edits or restart.
python3 contest/production_monitor_test.py --install

# Read persisted two-Production acceptance and exercise API refusal boundaries.
# First enroll DEMO and UTILIZATION from the page and run the local test cases.
python3 contest/production_monitor_test.py --check
```

根安装程序已加载 `contest/src` 中的所有类。CLI 默认处于非活动状态。本地 Demo 不提供通用
事件保留/清理或多远程实例连接管理。

<a id="m3-production-scoped-sampling-and-bounded-ai-hub-review"></a>

#### M3：Production 范围内采样及有界 AI Hub 审核

[ProductionReviewService](./src/ProductionReviewService.cls) 是由现有定时器入口启动的
独立工作器，与采集器以及旧版/声明审核锁相互独立。它每轮每个 Production 最多检查
200 条新观察记录。一个 Production 失败时会保留其审核游标、记录 Production 专属错误，
且不会妨碍处理其他对象。API 会公开工作器心跳、上次扫描、游标、是否有剩余记录、
暂停状态和错误。这是有界追赶机制，并不保证零丢失或精确积压数量。

**三项独立控制仍彼此独立：**登记允许观察元数据；M2 同意允许本地检查已注册属性；
M3 同意允许导出最小化的**合成**事实/可选声明上下文并有界使用模型。授权审核不会读取
尚未捕获的正文、回填检查失败项、配置业务主机或重放消息。此确认不是自动 PHI/合成数据
检测器；本演示不授权使用真实患者数据。

每个新授权都会固定 Production/配置、符合条件的 Agent ID、修订/配置摘要、审核器契约、
采样间隔、到期时间和请求预算，并使用调用方选择的不可变身份。完全相同的重试会返回当前
记录，不补充预算，也不会重新启用已撤销授权；冲突重用会失败。每个 Production 同一时间
最多只能有一个未过期的启用授权。授权在 24 小时内到期，允许 1-20 次审核，每次恰好预留
两次请求。这是**请求数量预算，不是货币或 token 单价保证**。现有资格规则支持已发布且
符合条件的草稿 Agent；实际验收使用确切的已发布 `deepseek-flash` 修订 3。

采样单位是某个 Production 中首次捕获的 `(source session, body class, body ID)`。
同一正文的转发消息头仍会显示为 `not_sampled_duplicate`，并附代表消息头。系统会选择首个
符合条件的正文及此后每 N 个正文；此确定性策略不是随机采样、风险分层、按边公平分配，
也不保证审核每条路径。`include_existing=true` 会明确包含以前未审核的捕获记录；否则授权
从最新已存消息头之后开始。终态的已采样、已跳过、受阻和失败处置不会被新授权自动重新评估。
检查失败和不支持的正文仍保持可见，不会被伪造成审核事实。

调用模型前，服务会冻结已验证的观察摘要、数据包和匹配的可选上下文修订。上下文查找要求
Production/配置和两个已观察主机完全匹配，最多检查 100 条可选记录。唯一匹配可以添加
声明用途的**主张**，但绝不能增加已观察到的接收方或权限。多个匹配会标为含糊，不会猜测
用途。没有匹配是有效情况，并非采集或审核排除条件。数据包过大或无效时会明确作为技术失败，
绝不会静默截断。

[ProductionReview](./src/ProductionReview.cls) 复用现有 AI Hub `%AI.Agent` 运行时：
定位问题、确定性地选择/检索有日期的完整规范章节，然后进行判断。两个 SDK Agent 均只有
一次交互且没有运行时工具；这些 Agent 不会使用开发 MCP。检索复用固定的知识索引验证和
完整章节组装器。风险/无信号依据规则及精确证据/段落引文检查继承自 v4 运行时。每个阶段的
输入限制为 160,000 个字符、输出限制为 18,000 个字符；失败不会修复或重试。共享基础审核器
仍保留原有 80,000 字符默认限制。

对于仅检查消息头/属性的采集器，软件主机和成功的消息头**无法证明实际业务接收方、用途、
披露依据或接收方接受情况**。因此，接收方/用途这个必需问题必须保持未解决；服务器会拒绝
模型将其转为“全部正常”或已确认违规的尝试。这是刻意设定的证据边界，并非声称所有
Production 都无法了解：更丰富的来源绑定声明/路由适配器会继续保留各自不同的真实发现。
一般正常/偏差结论需要比这些消息头/属性事实更强的业务来源依据。M3 验收验证通用信息缺口
路径。下文 M5 增加单独注册且绑定接收方回读的合成业务适配器；对于其他所有观察记录，
消息头级保护仍然有效。

每次模型调用前会持久预留两次请求。预留与运行项原子化，即使尚有剩余预算也不能重复使用。
每个 SDK 阶段都会重新检查 Production 是否活动、是否启用及授权是否过期；继承的评估器也会
重新检查源 Agent 的有效性。即使提供方、检索、输出或进程发生故障，预留仍然有效。
后续工作器会将未完成的 pending/running 工作标记为 `interrupted`，保留任何报告/用量，
且永不重放。撤销会等待工作器锁；若正忙，则明确失败，不会假装取消正在进行的请求。
预算及观察/会话身份不得跨 Production 边界。

独立的审核处置状态包括带原因的 `not_authorized`、`unsupported`、`evidence_failed`、
`not_sampled`、`not_sampled_duplicate`、`blocked_budget`、`running`、`completed`、
`failed` 和 `interrupted`。审核观察器尚未处理某条捕获记录时，实时覆盖层会显示
`pending_observer`。已完成结果和技术失败也会出现在现有 Production 风险信息流中；
对应的 Production 事件支持现有人工备注/状态转换。范围内的结果仅供参考：
不会执行业务交付、审批、隔离或重放。M4 会在同一工作区中增加专用采样/授权/证据控制。

| 方法 | `/api/monitor/v1` 下的路径 | 访问权限 / 效果 |
|---|---|---|
| GET | `/productions/:id/review-plan` | Reader；当前固定项、符合条件的来源和限制；零推理 |
| POST | `/productions/authorize-review` | Builder + CSRF；不可变的限时 Production 授权，可启用后续工作器推理 |
| POST | `/productions/revoke-review` | Builder + CSRF；禁用此确切授权，同时保留预算/历史 |
| GET | `/productions/:id/reviews?before=...` | Reader；25 条项目、处置、授权预算、用量和工作器健康状态 |
| GET | `/productions/:id/reviews/:header` | Reader；确切的观察/报告绑定、来源、阶段、SDK 会话和结果 |

授权命令恰好包含 `authorization_id`、`production_id`、`config_hash`、`agent_id`、
`source_revision`、`agent_config_hash`、`contract_hash`、`every_n`、`max_reviews`、
`max_model_requests`、`expires_at`、`include_existing`、`acknowledge_cost` 和
`acknowledge_synthetic_data_export`。最后两项必须明确设置为 `true`；
`include_existing` 必须是明确的布尔值。`expires_at` 使用计划返回的 IRIS 时间戳，
而不是 Unix 时间戳。撤销命令恰好包含 `production_id` 和 `authorization_id`。
所有现有 JSON 大小、身份验证、角色和 CSRF 边界均适用。

```sh
# Default is inactive. Installation compiles only; no budget grant or restart.
python3 contest/production_review_test.py --install
python3 contest/production_review_test.py --plan
python3 -m unittest discover -s contest -p 'test_production*.py'

# Only after separately approving up to 3 reviews / 6 real requests:
# python3 contest/production_review_test.py --authorize-acceptance

# Read the original saved acceptance; no authorization, inference or send.
python3 contest/production_review_test.py --check
```

明确的验收命令会使用已保存的 M2 合成证据。它要求恰好有 3 条符合条件且会话/正文互不相同
的引用，不允许手动上下文；它会在 POST 前持久保存授权身份，拒绝重复已保存的验收，并会在
即使失败时也尝试撤销。仅编译安装不会重置授权、观察记录或旧报告。

**M3 实际验收，2026-10-20：**另行取得用户批准后，A、B 和 C 各自完成了两次真实
`deepseek-flash` AI Hub 阶段，持久化 6 个 SDK 会话，共计**6 次请求 / 报告的 68,373 个
token / 11 条经精确验证的引文**。每个阶段均报告一次交互和零次工具调用。三者均返回
`information_required`，并提出具体的接收方/用途/权限问题；没有任何一个臆造 HIPAA 违规
或“无风险”结论。20 条观察处置中，3 条已完成、3 条重复/未采样、2 条未获授权检查、
2 条检查失败，以及 10 条不支持的回复。后续自动扫描/检查中的请求和阶段总数保持不变。
验收授权已撤销；无需新增业务消息、SQL 回执、手动 flow/context、主机重新加载或
Production 重启。

原生回归覆盖严格同意/固定项/到期检查、相同命令幂等性、不补充预算/不重放、
唯一正文采样、预算耗尽可见性、Production 隔离、中断恢复、类型化事实来源，
以及对不受支持的“全部正常”结论的拒绝。已回滚的测试数据会持有审核工作器锁，
防止并发作业观察临时证据/授权，或将持久游标推进到这些测试数据之后。事件、证据和审核
游标在填充后会断言 JSON 数值类型：浏览器验证发现并回归修复了此前首个 25 条事件之后
返回字符串游标的问题。

最终六个原生测试套件通过 **436 项断言**（61 项审核、42 项证据、94 项监控、63 项可选上下文、
29 项 v4 依据和 147 项声明审核），并通过 22 项 Python 测试、9 项 Production 解码器测试、
TypeScript 和定向 lint。M2 和原始 D1-D6 已保存验收仍然通过；声明工作流仍单独保留
20 条历史请求 / 237,219 个 token。这些评估范围彼此独立，不能合并宣称 HIPAA 已全面验证。
使用共享登录的实际浏览器显示了三个 Production 评估，且没有解码错误。从较旧的事件页出发，
每个来源链接均可打开确切事件页，并显示对应的人工审核备注控件。此导航不会授予模型预算，
也不会执行业务操作。

<a id="m4-production-evidence-and-authorization-workspace"></a>

#### M4：Production 证据与授权工作区

现有 **Productions** 页面现在包含：

- **证据覆盖与审核健康状态：**Production 全范围捕获和审核处置计数、扫描/工作器健康状态、
  游标/积压，以及明确的保留/归因限制。计数不会因证据分页/会话而筛选；不会伪造覆盖率百分比
  或“全部正常”结论。
- **观察到的消息边：**实际源/目标消息头边，包括响应，并采用独立分页。不会声称已重建有序的
  端到端业务路径。
- **消息证据与会话关联：**不可变观察记录、最小化事实、捕获原因、哈希、配置和限制；
  可按确切源会话筛选，并有单独的实时审核覆盖层。
- **采样审核记录：**全部处置、已预留/尝试的请求以及确切观察/报告绑定。已完成报告显示每个
  问题的发现、缺失信息，以及绑定来源/段落的 Unicode 引文跨度。只接受哈希验证过的完整规范来源；
  带日期的来源文本/元数据、冻结观察记录、AI Hub 会话、用量、提示词和保留输出均可检查。
  技术处置不会伪造裁定。现有风险信息流链接/人工备注仍可用。
- **独立授权：**仅构建者可操作的本地合成检查和撤销控件，与限时 AI 经费授权分开。
  AI 同意会固定 Production/配置、Agent 修订/配置、契约、采样、最大审核数/每次两请求预算和
  到期时间。数据导出/费用确认默认为未选中；**Prepare exact review authorization** 不发出请求。
  只有 **Confirm paid review authorization** 才会提交命令，并可能立即启用后台推理。
  失败/响应丢失的重试会保留相同的预备 ID/请求正文；授权、已花费预留和撤销状态始终可见。
  当前 API 没有 inspection-grant GET：不得将历史捕获成功误读为当前本地检查同意。
- **可选语义上下文：**检查不可变修订，或使用高级精确契约编辑器添加/修订声明上下文。
  服务器要求真实启用的主机名和目录中的合成接收方。这只是增强信息，不是业务流登记、
  下游使用证明、权限、检查同意或模型经费授权。允许上下文记录数量为零。

更改所选 Production 会重新挂载此工作区，并清除筛选器、详情、待确认同意和编辑确认。
读取失败会明确显示并禁用写入；Reader 账户仍可查看证据，但变更控件处于禁用状态。
常规刷新只执行 GET，不会授权推理、业务发送、重放或 Production 重新配置。

**M4 验证，2026-10-20：**全部 **119 项前端测试**、TypeScript、定向 ESLint 和生产构建均通过
（Vite 仍显示包体积提示）。经身份验证的浏览器显示了真实的 header-18 审核，其中有 4 条
确切引文和缺失信息问题，关联了其 4 条 session-18 消息头；切换到 DEMO 时详情已重置。
经费预览显示精确的两次审核/四次请求上限；丢弃操作清除了付费确认。两个浏览器拦截的失败
提交使用相同的固定同意信息，并且均未到达 IRIS；未发送真实经费 POST。检查了上下文编辑器的
确认/取消和 Reader 禁用控件，没有保存虚假上下文。Reader 权限门控通过渲染测试验证，没有新建
实时 Reader 登录。已保存的 M2/M3、多 Production 监控及 D1-D6 只读验收仍全部通过：
**20 条观察、12 条边、零条手动上下文；M3 仍为 3 次审核 / 6 次请求 / 报告的 68,373 个
token / 11 条已验证引文，授权已撤销**。M4 没有新增业务消息或付费推理。M5 支持的正常/
偏差/信息缺口验收另行记录在下文；UI 不会将仅有消息头的证据变成实际接收方/用途证明。

<a id="m5-multi-path-business-evidence-acceptance"></a>

#### M5：多路径业务证据验收

经明确批准进行隔离本地部署、最多四次合成业务发送和付费 AI 验证后，
`M5OBSERVATION / Contest.M5.Production` 已创建、发现并**仅作为一个 Production 登记一次**。
没有创建上下文/flow 记录，也没有按路径分别登记。此前五个活动 Production 的身份和配置指纹
均保持不变。

业务证据适配器（[ProductionBusinessEvidence](./src/ProductionBusinessEvidence.cls)）
仅支持此已注册的合成接入契约。它会重新打开持久化请求、验证捕获时的有效载荷哈希、
在同一源会话中查找恰好一条实际 BP 到接收器的边，然后独立查询 `SQLUser.M5Receipt`。
消息/正文/会话、实际接收器和有效载荷哈希都必须匹配。执行新读取前会检查已观察到的
Production/配置及本地检查同意；读取后会再次检查 Production/配置。缺少/不匹配的回执会明确
作为技术失败，绝不会推断为已接受，也不会自动重发。如果采样时接入尚未完成，审核会明确失败，
不会替换成其他裁定或自动重试。

虚构的版本化 `synthetic-quality-intake-v1` 策略规定 ReceiverA/B/D 是某个模拟受覆盖实体
内部的质量接入端点。允许的字段为 `patient_id`、`birthDate` 和 `status`；日期必须精确到年。
稳定 ID 仍可关联，且在此情景中允许使用：**不作去标识声明**。ReceiverC 刻意不设业务关系分类。
此代码发布的固定策略是明确的合成前提，不是发现的真实组织权限证明。不包含预期模型裁定。
接收器和审核器都不会强制执行交付门控；这是接入后的咨询式监控。

适配器会单独冻结带哈希的回执/策略/配置快照，与不可变消息头观察记录区分，并将其哈希绑定到
确切的模型审核数据包。服务器详情读取会验证两种绑定；浏览器会检查身份匹配，并将
**Verified local business intake** 与范围内评估分开展示。如果没有受保护且绑定作业的适配器证据，
注入的 `approved_scenario` 标签不能绕过通用接收方/用途未解决保护。可选用户上下文不能确立此
业务证据级别。

**实际验收，2026-10-20：**

| 路径 | 实际合成接入 | AI Hub 结果 |
|---|---|---|
| A | 已知内部接收器、允许的字段、仅含年份的出生日期 | `no_signal_on_checked_issues` |
| B | 已知内部接收器，出生日期包含完整日期而非允许的仅年份格式 | `risk_identified`：明确的本地最小化偏差，不是对 HIPAA 违法性的裁定 |
| C | 回执已验证，但接收方关系/用途尚未分类 | `information_required`，并提出重要业务问题 |
| D | 之前未观察到的已配置路径；已知内部接收器和仅含年份的日期 | 自动观察并审核，`no_signal_on_checked_issues` |

D 的主机在初次启动时已配置，但首次发送前没有消息边。保存的发送前 D 边页面证明新**活动路径**
可在无需登记的情况下被发现；这不表示运行中的 Production 可热添加新业务主机或重新配置。

全部四次接入均通过实际 BS/BP/BO 处理和 SQL 回读：**16 条不可变消息头观察和 16 条实际
请求/响应边，零条手动上下文**。每个转发正文只付费审核一次，而不是按每条边重复审核。
首个有界授权已足够：**4 次已完成审核 / 8 次真实请求 / 报告的 98,219 个 token /
11 条确切规范引文**；持久化 8 个 SDK 会话，每个会话均只有一次交互和零次工具调用。
无需重试或额外授权；模型授权已**撤销**，但支出/历史记录保留。B 报告还保留了后续使用/
法律认证不在覆盖范围内的说明；不会为了伪造无条件结论而将其隐藏。本地合成检查仍单独启用。

Production 风险信息流和浏览器显示了两个范围内的无偏差结果、本地风险及信息缺失案例，
并提供 SQL 来源、带日期的引文和人工审核链接。重复的已保存证据检查不会调用模型或发送业务
消息；它会重新验证全部 4 条持久化消息/SQL 回执，确认其他 Production 配置未变化，并拒绝
跨 Production 的审核/授权泄漏。原始 M2/M3 和 D1-D6 验收仍通过。原生测试覆盖伪造观察/
摘要、替换冻结回执、跨 Production 绑定、未知接收方处理以及采集器作业保护。
最终验证通过 **7 个套件中的 535 项原生断言**（97 项业务证据、61 项审核、42 项捕获、
96 项多 Production 监控、63 项可选上下文、29 项 v4 依据和 147 项声明审核）、
**27 项 Production Python 测试**、**121 项前端测试**、TypeScript、定向 ESLint 和生产构建。
同时使用了受限 MCP 执行器和本地管理员执行器：后者实际运行了前者有意跳过的仅部署分支。
Vite 的包体积提示仍然存在，但不表示构建失败。浏览器检查显示全部 4 条真实发现、SQL 来源、
确切引文和未知关系标注，没有解码警告；切回 M3 时也没有为旧报告臆造业务回执证据。

```sh
# Compile the monitoring runtime, including the registered adapter; no funding/sends.
python3 contest/production_review_test.py --install
# Only after local deployment approval; creates/starts the isolated M5 Production.
python3 contest/production_acceptance_test.py --setup
# Only after synthetic-send AND paid-model approval; four sends, <=8 model requests.
# Refuses to repeat if its local durable manifest already exists, including failure.
python3 contest/production_acceptance_test.py --run-acceptance
# Existing acceptance only: live message/receipt validation, zero new inference/sends.
python3 contest/production_acceptance_test.py --check
```

清单保存在 `contest/data/` 下的本地 Git 忽略路径中；发送意图会在副作用发生前保存。
中断/失败工作必须先检查，不得悄悄重置或重放。仅当此前已安装时，安装程序才会在正常环境
启动时启动自有 M5 Production；默认不会创建此验收命名空间。验证编译了此启动路径，
但未重启业务 Production，也未更改凭据。

**历史状态更正：**仅本地规则测试并未完成 M5。后来为法律条件和审批输入验收重新开放。
后续演示验收记录在下文；本地规则结果本身仍不能证明一般 HIPAA 评估有效。

**边界：**已实现的 M1-M5 界面展示了 Production 全范围观察，以及针对受支持证据契约的
来源绑定 AI 审核。这不等于对任何新登记 Production 进行普遍 HIPAA 认证。新格式/接收方需要
可信证据适配器/前提，而不是手动登记 flow 或弱化模型提示词。未观察到的下游行为不在覆盖范围内。

<a id="hipaa-condition-validation-first-prospective-batch-not-m5-completion"></a>

#### HIPAA 条件验证：首个前瞻性批次，并非 M5 完成

用户质疑早先的完成声明后，M5 重新开放。通过上述合成接入规则**不能**证明 HIPAA 评估有效。
现有独立基准测试评估具体法律条件，而不是检查输出是否符合臆造的仅年份策略。

[HIPAAReview](./src/HIPAAReview.cls) 复用 v4 的适用性/条件/例外依据和精确段落物化逻辑，
并使用现有完整章节检索器处理 164.501/502/506/508 和 164.514。要审查心理治疗记录和营销，
而不是仅依赖宽泛的治疗/医疗运作许可，纳入 164.508 是必要的。ProductionReview 现在继承此
共享法律核心，但仍保留更严格的证据可用性保护和“仅限本地接入”限定。该包装器以前保存的报告
属于历史结果，并非按新契约重新运行。不会重用旧同意。

[前瞻性案例](./fixtures/hipaa-conditions-v1.json)以及预期适用性、条件、决定性条款锚点和
关键事实引用均在运行模型**之前**固定。预期判定由助手编写，并非独立法律意见或留出的专家
数据集。案例身份、预期标签、权威评分标准或评分文字均不会进入任一模型阶段。业务事实是合成
设定，不是从实际 Production 派生的授权/用途证据。部分事实明确规定已完成完整许可审查；
这简化了法律测试，并不证明采集器在实践中能够证实这些条件。

| 条件 | 预先声明的结果 | 首次实际结果 |
|---|---|---|
| 向另一提供方披露以用于治疗，包含完整日期，无个人授权 | 无信号；治疗许可及最小必要例外 | 匹配 |
| 单独保存的心理治疗记录；明确没有授权且不存在适用例外 | 特殊授权条件未满足，发出风险信号 | 匹配 |
| 同类记录，但授权/例外证据未知 | 需要更多信息；不得臆造缺少授权 | 匹配 |
| 付费电子营销、无授权、不适用任何例外 | 风险信号 | 匹配 |
| 同类付费营销，但有确切有效授权和报酬说明 | 对已检查条件无信号 | 匹配 |
| 自身内部质量改进，且已验证最小必要访问 | 无信号；仅存在可识别数据并不要求授权/去标识化 | 匹配 |
| 唯一 Safe Harbor 路径保留了单位恰为 20,000 的非 000 ZIP 前缀 | 针对 ZIP 条件发出风险信号 | 匹配 |
| Safe Harbor ZIP 单位为 20,001，其他标识符/实际知情条件均满足 | 对已检查条件无信号 | 匹配 |

首批完成了 **8/8** 项预先声明的自动化检查：**3 项风险 / 4 项无信号 / 1 项未解决**，
没有状态误报或漏报，*但仅限这 8 个作者编写的案例*。必需的决定性条款、适用性/条件值和
关键事实也都匹配。每条引文来源均通过已发布完整章节内容哈希验证，每处引文均与问题专属段落
偏移量精确匹配。共有 **16 次请求 / 报告的 158,476 个 token / 31 条物化引文**，
以及 16 个真实、无工具的 AI Hub 会话。此次结果没有重试、替换案例、查看输出后调优提示词、
新增业务发送或更改 Production 配置。继承运行时仍记录
`hipaa_risk_validation=not_completed`。

[运行器](./hipaa_conditions_test.py)会在调用前固定套件/判定标准/投影哈希、Agent 修订/
配置、审核器契约、确切输入哈希以及每案例两次请求的同意。每次尝试前都会持久保存意图。
已有日志绝不会重置/重放；技术故障计为失败案例。
`--check` 会将每份已存报告与 IRIS 中的实时持久报告比较，重新检查冻结绑定、条款、
引文及明确的 token 计数；任何自动化检查失败都会使其失败。批次日志在
`contest/data/evaluations/` 下由 Git 忽略。

```sh
# Offline source-anchor/projection checks; zero calls.
python3 contest/hipaa_conditions_test.py
python3 -m unittest discover -s contest -p 'test_hipaa_conditions.py'
# Free actual-IRIS source/input preflight; no Chat.
python3 contest/hipaa_conditions_test.py --prepare
# Requires explicit model-cost authorization, <=16 requests, no business sends.
python3 contest/hipaa_conditions_test.py --run --request-key UNIQUE-KEY
# Read the already completed first batch; zero new model calls.
python3 contest/hipaa_conditions_test.py --check \
  contest/data/evaluations/hipaa-conditions-20261020-first-hipaa.json
```

新的原生测试在实现前和 Production 集成前均先失败，随后通过了**7 项实际断言**；
共享审核、业务证据和 v4 依据在具备部署能力的原生运行器下另通过 187 项断言。
14 项新的 Python 安全测试以及现有 27 项 Production Python 测试均通过。较早的 M2/M3/M5
技术验收在不推理的情况下仍通过。接入适配器的本地策略结果与 HIPAA 条件推理分开标注。

**演示范围更正：**要求此演示必须具备真实接收方/授权系统和独立专家裁定才接受，是错误的
范围扩大。经用户确认的合成业务事实是演示评估的有效前提。UI 必须解释其含义和限制；
不能仅因其由用户输入就拒绝，也不能将用户批准视为法律许可。专家验证和真实系统集成可以
支持未来部署，但不是竞赛演示的先决条件。所需的演示验收是以这些已批准的业务前提进行
前瞻性的 Production 到发现全流程，而不是接入真实医院。该运行及其明确映射修复记录在下文。
8 个理想化作者编写案例不能估算总体准确率。未独立确认当前法律的新鲜度：自动抓取 HHS/eCFR
页面遭到阻止，因此本测试使用已发布的带日期规范快照，不声称实时法律验证。

<a id="user-approved-demo-premises-in-production-review"></a>

#### Production 审核中的用户批准演示前提

在 Production 工作区中，对已捕获消息选择 **Use session … for demo approval**，
或在 AI 审核批准面板中启用 **Supply user-approved demo business premises**。
无需登记 flow。表单会询问：

- 源会话、接收方及关系（内部实体、治疗提供方、业务伙伴、外部或未知）。
- 实际预期用途和建议的许可依据。
- 技术主机到业务接收方的明确映射，以及会话消息涉及的患者/活动/数据范围。这些是用户规定，
  不能根据组件名称自动推断。
- 个人授权状态：存在、明确不存在、不依赖授权或未知。范围、有效性/撤销、数据类别，
  以及任何相关报酬或特殊条件须分别说明。
- 数据必要性/保障措施及适用限制/例外；未知事实应明确填为未知，不得臆造。

操作员确认这些是**合成情景前提**，然后另行批准确切的付费模型同意。服务器端
`demo_premises` 契约会拒绝额外裁定/来源字段、未经确认的输入和无效范围。
持久授权会将这些前提与已验证操作者及确认时间一起冻结。使用相同授权 ID 更改输入会被拒绝；
重试相同请求正文不会补充预算。

采集器会将这些前提绑定到确切登记 Production/配置中的一个源会话。其他会话仍会被观察，
但不会在此授权下预留模型请求。现有终态审核绝不会被改写或自动重新评估。更改审批范围不会
重放消息。

模型数据包会明确区分已采集消息观察与 `user_confirmed_demo_premise` 记录。其内部观察/
验证标签表示**已记录、已确认的模拟前提**，而非独立的现实验证。已知的实质前提可以支撑
范围内的 HIPAA 条件发现；一个批准标签本身不是许可，也不是预选裁定。接收方/许可事实未知时
仍保持缺失。不会伪造真实接收方回读。对于未使用此新前提模式的审批，已注册的 M5 本地策略
适配器仍可用。

审核详情和持久审批历史会显示谁在何时确认了哪些前提、适用于哪个会话，并与消息证据和来源
引文分开。相同的受保护两阶段 AI Hub 运行时、带日期完整章节、依据要求、预算/撤销检查及
不重放策略仍然适用。新的原生套件测试数据包构建、未知/范围隔离、法律结果 schema 接受
（使用作者编写的契约测试夹具，而非模型预测）、撤销同意及已持久审批的不可变性。
这些测试不声称取得了新的模型验收结果。

验证通过 25 项新的原生断言、165 项现有审核/业务/法律核心断言、18 项定向前端测试、
27 项 Production Python 测试、TypeScript/构建及定向 ESLint。浏览器检查确认可以选择实际
捕获的会话、纳入已存捕获记录、拒绝未确认前提、编辑后清除确认状态、冻结预览输入，
以及不授权即可丢弃。此次检查未进行付费确认、未发起新模型调用，也未发送业务消息。
现有 M3/M5 报告仍通过只读历史验收。

<a id="m5-approval-input-live-acceptance-and-explicit-repair"></a>

#### M5 审批输入实时验收及明确修复

[前瞻性三案例夹具](./fixtures/production-premises-v1.json)在发送消息或调用模型前已冻结。
[验收运行器](./production_premises_test.py)使用现有隔离 M5 Production、3 条新建且 ID 唯一的
本地消息、每案例一个确切的会话范围授权，并为每个授权设置两次请求上限。后台观察器捕获了
每条消息实际 BS/BP/BO 请求边，后台审核器执行了真实的无工具 AI Hub 定位/判断阶段。
判定标签和引文评分标准未包含在审批/模型输入中。

**首轮结果是 2/3，而非 3/3。** 付费营销和未知条件案例匹配。普通治疗案例返回需要更多信息，
因为审批没有解释 `ProcessB` 代表具名诊所、内部中介还是额外接收方，也没有说明观察到的字段
是否属于指定患者/活动。这是演示输入关联缺失，并非未能发现治疗许可。

修复添加了两个明确表单字段 `recipient_mapping` 和 `data_scope`，与同一审批一同验证并冻结，
且作为独立的用户确认演示前提导出。没有这些字段的现有审批仍可读取，但不符合该治疗案例的条件。
不会伪造追溯性事实。契约哈希已更改；没有重用旧模型授权。红/绿 ObjectScript 和前端回归测试
覆盖新映射、缺失/部分值以及旧审批结构的保留。这并非要求模型忽略未知接收方：现在用户提供了
此前缺失的关联，仍可明确回答“未知”。

用户另行授权了**一条额外消息和两次请求**。只重新运行治疗案例，使用原始业务前提和
**不变的预期裁定、关键事实和决定性条款**，并增加两项明确映射说明。该案例通过了所有自动检查。
这是经过检查的修复，**不是留出的评估，也不表示三个案例都按最终契约重新运行**。

| 案例 | 会话 / 代表消息头 | 实际结果 | 确切引用材料 |
|---|---|---|---|
| 原始治疗案例，主机/数据映射不完整 | 18 / 18 | 需要更多信息；保留首轮失败 | 找到了治疗许可和例外，但消息关联仍未解决 |
| 付费营销，明确无授权且不适用例外 | 22 / 22 | 发现风险 | 164.508 营销授权条件；4 条引文 |
| 接收方/许可明确未知 | 26 / 26 | 需要更多信息；不臆造不存在或违规 | 4 条引文；有关实质接收方/用途/许可的问题 |
| 单独批准的治疗映射修复 | 30 / 30 | 对已检查事项无信号 | 164.506(c)(2) 和 164.502(b)(2)(i)；4 条引文 |

首轮用量：**6 次请求 / 报告的 92,187 个 token / 11 条确切引文**。
明确的治疗跟进：**2 次请求 / 报告的 24,684 个 token / 4 条确切引文**。
包括首轮失败在内的总计：**4 条新的合成消息 / 8 次请求 / 报告的 116,871 个 token /
15 条确切引文**。每项授权都使用一个审核名额，现已撤销，且仅资助其确切源会话。
未使用自动重试、重放、替换历史报告、按 flow 登记、凭据更改或 Production 配置/重启。
运行后所有活动 Production 配置哈希均与基线一致。

Git 忽略的原始及跟进日志保存在 `contest/data/` 下。原始首轮的 `--check` 按设计仍会失败。
`--check-complete` 会重新读取两组持久化 IRIS 报告，要求原始风险/未知案例成功及单独验证的
治疗修复通过，保留原始治疗失败，并统计**全部**用量：

```sh
# Read-only completed demo verification, including the retained first failure.
python3 contest/production_premises_test.py --check-complete
# Original result remains a failing first pass; no requests/sends.
python3 contest/production_premises_test.py --check
# Read-only separately approved treatment repair.
python3 contest/production_premises_test.py --check --treatment-mapping-followup
```

运行器检查冻结的夹具/审批/Agent/契约绑定、存储与实时报告是否相同、模型阶段输入、明确的
提供方用量、会话范围、转发正文的唯一付费审核、两个已捕获请求边、预先声明的裁定/
适用性/条件/事实覆盖情况及决定性来源锚点。它会将引文与已发布完整规范内容哈希及问题专属
精确跨度重新核对。这些自动检查不构成独立法律/专家验证。

浏览器检查通过，覆盖全部四份实际报告：可见用户批准和时间、单独的消息证据、最终结果、
确切引用、治疗映射/数据范围及实质性未知项，且没有错误。现有 M3 和原始本地规则 M5 历史
验收也通过；其测试现在针对原始已保存运行进行限定，而不再假设 Production 永远不会有新活动。
原生验证通过 **195 项实际断言**（30 项前提、61 项审核、97 项业务绑定、7 项法律核心），
完整前端 **125 项测试**及构建均通过。**M5 已完成此范围内的合成演示**，但不代表真实世界
HIPAA 认证或普遍法律准确性。

<a id="real-acceptance"></a>

### 实际验收

发现功能返回全部**四个**活动本地 Production：DEMO、PIPELINE、TRIAGE 和 UTILIZATION，
没有发现错误。浏览器中明确选择/登记了两个不同对象：DEMO 和 UTILIZATION。

随后通过现有 BS/BP/BO API 实际提交了两条合成 DEMO 业务消息：治疗（已交付，消息正文 357 /
会话 513）以及预定义的本地目标失败情景（失败，正文 361 / 会话 519）。没有调用外部系统或
真实提供方。后台采集器自动捕获了**16 个消息头**（包括异步观察传输）和**一个错误日志元数据
事件**，源消息头 ID 为 513–528，日志 ID 为 180。该日志事件通过新页面按 v3 状态
`open → in_review → resolved` 进行审核，并添加两条备注。这些 DEMO 事件没有出现在
UTILIZATION 中。

DEMO 详情显示了其现有真实范围风险事件，与新增运维失败事件分开。UTILIZATION 显示了两个
现有发送后审核，包括已完成/无偏差的声明批次结果及已解决的人工事件。浏览器暂停/恢复和事件
操作均通过，且未停止源 Production。测试期间，一个 JSON false 值最初被动态属性赋值序列化
为字符串；严格解码发现了问题，随后改用显式布尔赋值修复，并通过管理 API 恢复了确切的暂停
观察器。没有删除任何已存事件历史来掩盖该修复。

新测试覆盖真实的两个 Production 身份、过时登记、初始未勾选确认、不会重置游标的重复登记、
隔离审核适配器/事件、暂停不停止业务 Production、JSON 布尔类型、过时事件/管理修订、
去重捕获和有界事件分页。测试会回滚其合成记录/备注。最终验证在 Production 监控套件中
通过 **81 项授权断言**，并通过声明验收 129 项、声明监控 12 项及旧路由观察 49 项
（这四次运行共 271 项断言）。权限受限 MCP 套件报告了 5 个通过的方法；获授权的终端运行
负责覆盖其权限门控分支。全部 **176 项 Python 测试**和 **105 项前端测试**、TypeScript
生产构建及 ESLint 均通过。原有包体积警告仍存在。原始 D1-D6 只读验收仍通过，历史用量
保持 20 次请求 / 237,219 个 token；本扩展没有调用模型。

<a id="legacy-p2-real-demo-connector-and-observation-transport"></a>

## 旧版 P2：真实 DEMO Connector 与观察传输

此切片在已测试的 ARM64 IRIS for Health AI Hub EAP `2026.3.0AI.154.0` 实例中增加了一个
隔离的合成业务 Production。它**不是**通用远程实例监控产品。

<a id="install"></a>

## 安装

首先完成运行实例和 [Knowledge API 设置](./KNOWLEDGE.md)。以下明确命令会创建 DEMO 数据库/
Interoperability 命名空间、编译预装的演示包、启动 `Demo.Production`，并使用
`Ens.Director.UpdateProduction` 将自有 `PlatformMonitorInbox` 服务添加到正在运行的 TRIAGE
`Contest.Production`。它不会停止或重启该 Production，也不会更改现有分流流程/接收器。

```sh
python3 contest/monitor_prepare.py
docker compose -f web/compose.yaml up -d
```

安装程序当前明确以 `iris-triage-real-iris-1` 为目标。DEMO 和 TRIAGE 位于同一实例，
但运行时流量通过 `gateway` Compose 服务进行显式的已认证 HTTP 通信，而不切换命名空间。
不会手动构造系统映射。

重新运行准备步骤会保留现有机器密码和应用数据。这不是实时代码升级控制器：若运行中的
BS/BP/BO 实现已更改，可能需要明确重新加载这些自有组件。初次安装不依赖此类重新加载。

<a id="try-it"></a>

## 试用

1. 打开 <http://127.0.0.1:5173/instances>，使用专用平台构建者账户连接。本地专用演示预填说明
   见 [web 设置](../web/README.md)。
2. 单击 **Discover legacy DEMO configuration**，然后单击 **Legacy DEMO connector**
   （或打开 `/demo`）。`/pipelines` 现在是上文所述的受管 Production 工作区。
3. 检查真实组件快照、已确认的演示路由和配置哈希。
4. 单击 **Plan monitoring deployment**，阅读差异/影响，勾选明确批准复选框，然后单击
   **Approve exact plan**。
5. 单击 **Apply and verify probe**。`verifying` 不代表成功：只有匹配的已接收合成探测才会将部署
   状态改为 `active`。
6. 发送治疗、分析或失败消息。消息会通过真实 Business Process 和本地 Business Operation。
   失败情景会故意返回合成目标错误；绝不会调用外部系统。
7. 在接收列表（最新 50 条）中查看源消息/会话 ID、部署和观察 ID。活动标签页每三秒刷新状态，
   返回页面时也会刷新。浏览器可能会降低隐藏标签页定时器的频率；**Refresh live status**
   也会立即获取状态，但不会创建快照。
8. 可选：模拟接收器中断，发送新消息并查看待处理/重试计数。恢复接收器以清空队列。
9. 可选：勾选模型费用确认并单击 **Generate AI Hub summary**。这是一次真实且可能收费的模型调用，
   不是夹具。后台作业结果、限制、SDK 用量和 AI Hub 会话仅显示于该特定快照。

预先登记的实例 ID 为 `local-demo`；只有 **DEMO** 命名空间可发现。浏览器/Connector 契约中
没有任意 URL、SQL、类执行或命名空间参数。

<a id="runtime-path"></a>

## 运行时路径

```text
DEMO EnsLib.Testing.Service / Process
  -> DemoRouter (reviewed before_send Gate; initially non-enforcing)
  -> held_for_review OR TreatmentSink | AnalyticsSink | FailureSink
  -> local bounded durable outbox
     -> ObservationDispatcher BS -> ObservationSender BO
        -> authenticated HTTP POST
           -> TRIAGE durable inbox -> PlatformMonitorInbox BS
              -> immutable observation and receipt
```

业务处理不会等待远程模型或 HTTP 观察交付。传输重试只针对观察项，不会重试业务事务。
稳定观察 ID 根据源实例、观察点和提交身份生成。不完整的业务提交会被拒绝，而不会悄悄重放。
目标是本地幂等演示接收器，不是真实集成。

发件箱最多保存 1,000 条待处理观察项。溢出/锁争用会增加明确的丢失覆盖计数器；不会将观察项
悄悄标记为成功。传输错误和工作器心跳年龄均可见。每次轮询最多发送十条待处理记录，
并采用上限为 30 秒的指数退避。这是至少一次传输并由幂等接收处理，不保证网络层恰好一次。

接收锁/事务使同一观察/正文保持幂等，并会对同一键对应的冲突正文返回 HTTP 409。
独立 BS 会幂等消费其持久收件箱。记录、待处理工作、快照、计划和审计均存放在持久命名空间
全局变量中。

<a id="discovery-and-deployment-boundaries"></a>

## 发现和部署边界

- 快照包含实际活动的 Production/配置、组件类、启用/池设置和配置 SHA-256（不返回设置值）。
  快照不可变。
- 已确认边仅适用于固定的演示实现。不支持的类/组件或已禁用的必需主机会导致自动部署不受支持；
  不会猜测任意自定义路由。
- 图表上方的实现说明是**确定性生成**的。单独选择加入的 **AI Hub pipeline summary**
  由真实 `%AI.Agent` 生成，不带 ToolSet，且只进行一次 Agent 迭代。只发送已清理的演示路由
  元数据/计数；不会发送设置、凭据或消息有效载荷。它使用现有真实提供方配置，可能产生费用，
  且不会由发现、部署或核心测试自动调用。
- 摘要作业绑定不可变快照 ID/配置哈希，并保留 SDK 会话、模型、用量、已验证摘要/限制和失败状态。
  输出不会成为拓扑事实或可执行操作。新快照不会悄悄重用旧快照的说明。调用失败时绝不会回退到
  确定性文本并标注为 AI。180 秒的过时状态不表示底层提供方请求已取消。
- 计划绑定快照/配置哈希、目标、能力版本、观察器修订和摘要。应用前须批准确切摘要。
- 目标端会在部署锁下重新检查 Production/哈希及观察器修订。配置/基线发生变化时会拒绝过时批准。
- 应用仅会原子更新预装观察器的自有配置。不会生成/编译代码、重启 Production 或启用策略执行。
  P2 会传输每条捕获观察；P5 会在源端单独选择潜在隐私审核样本。
- 仅确认已加载并不足够；必须收到匹配的探测结果。结果不确定时标记为 `unknown`；重试同一部署
  会进行幂等协调，而非盲目回滚/重放。
- 观察器计划不会激活执行。下文单独的 P6 规则计划可激活预装 `before_send` Gate。
  它支持拦截和获批回滚，不支持释放或重放旧的拦截消息。

<a id="identities-and-api"></a>

## 身份与 API

Platform Reader 可检查现有发现/部署/观察数据。Platform Builder 可发现、计划、批准、部署，
并发送固定合成情景。这些权限对应不同的 `ContestMonitorRead`/`ContestMonitorDeploy` 资源。
与 Knowledge 切片一样，角色拥有数据库权限，**并不是**数据库/租户沙箱。统一平台登录/TLS
尚未完成。

本地忽略的机器密码文件以 0600 权限创建：

- `ContestConnectorReader`：发现能力。
- `ContestConnectorManager`：发现及固定部署/合成提交能力。
- `ContestDemoSource`：仅观察数据摄取，绑定到 `local-demo/DEMO`。

机器身份与浏览器身份不同，绝不会发送到浏览器。Gateway 连接凭据不是应用身份。
若用户缺少 CSP 应用资源，原生 IRIS 身份验证可能返回 HTTP 401；处理器级授权会返回 HTTP 403。

平台 API 位于 `/api/monitor/v1` 下：

| 方法 | 路径 | 用途 |
|---|---|---|
| GET | `/instances` | 已注册 Connector 的健康/能力 |
| POST | `/instances/local-demo/discover` | 不可变快照，空 JSON |
| GET | `/pipelines` | 快照、部署、健康状态和已接收观察 |
| POST | `/deployments/plan` | 针对 `snapshot_id` 创建计划 |
| POST | `/deployments/:id/approve` | 批准确切 `digest` |
| POST | `/deployments/:id/apply` | 应用/协调确切的 `digest` |
| POST | `/demo/messages` | 固定 `scenario`：treatment/analytics/failure |
| POST | `/demo/transport` | 使用 `paused` 明确模拟演示接收器中断 |
| POST | `/pipelines/summary` | `snapshot_id` 和明确的 `acknowledge_cost: true` |

平台会调用 DEMO 中固定的 `/api/monitor/connector` 应用。只有源身份会调用 TRIAGE 中的
`/api/monitor/inbox/observations`。接收器中断模拟返回真实 HTTP 503；不会停止 IRIS 或任何
Production。HTTP 仅限此本地演示网络：若远程使用，必须采用 TLS、妥善分发机密并强化身份验证。

<a id="acceptance"></a>

## 验收

```sh
python3 contest/monitor_test.py
python3 contest/platform_test.py
```

`monitor_test.py` 检查身份和命名空间边界、实际拓扑、审批/摘要拒绝、已加载哈希和实际探测、
三条真实合成路由、20 个并发新观察提交只生成一条逻辑回执、与 JSON 键顺序无关的重复/冲突正文
检查、HTTP 503 中断/恢复、仅重启新 dispatcher 后待处理工作仍保留、过时配置和竞争的观察器
基线拒绝。它包含一条明确注入的传输测试观察；并非每条测试回执都对应新的业务消息。

漂移测试只临时更改新演示 dispatcher 已保存的轮询间隔，并在 `finally` 中恢复；不会更新/重启
业务组件。最终会验证新的部署并恢复接收器。此开发实例测得的初始中断路径业务完成时间为
0.015 秒；这只是一个合成样本，不是吞吐量保证。

框架测试：[MonitorTests](./dev/MonitorTests.cls) 使用外部管理的 TestProduction 无操作控制器，
不会启动/停止 Production。精确的 999/1,000 发件箱边界及已知 SHA-256 摘要都有框架断言。
前端构建/类型检查、lint 和解码器测试会覆盖实时响应边界。原有分流和 Knowledge 回归套件仍
单独运行。

一次经用户授权的真实摘要验收使用 `deepseek-flash` 完成，AI Hub 会话 `4`：362 个提示词 token、
1,955 个完成 token（其中包含 1,730 个推理 token），SDK 报告总计 2,317 个 token。耗时约
8.4 秒。这些是单次调用测量值，不是一般延迟/费用保证。由于未固定提供方价格表，因此不计算
货币成本。浏览器验收确认了已完成结果及其快照/哈希绑定。框架测试验证输出键、长度/类型和无作业
状态；前端防护会拒绝伪造类型以及“已完成但无结果”的请求正文。上面的常规回归命令不会调用
摘要模型。

尚未实现：任意外部实例、通用检测、自动模型审核执行/质量评估、诊断模板、自然语言规则生成、
完整重放/租约平台、队列保留/垃圾回收或生产级故障切换。Overview/Events/Rules/Runs 现在都使用
真实 API。单独的 [P4 隐私 Agent 工厂](./AGENT-FACTORY.md)现在支持真实配置生成、测试、发布和
已记录的意图绑定；但还不会自动处理观察项。

<a id="events-and-human-review-p5"></a>

## 事件与人工审核（P5）

观察器完成配置后，Overview、Events 和 Runs 会读取经过身份验证的持久化 IRIS 状态。
新观察项采用 schema 2：原始传输身份，加上源 UTC 日期、采样修订/选择/原因、六项合成隐私事实
和实际的三字段 Gate 结果。仍接受 schema 1 历史记录，但不会臆造事实或追溯性隐私评估。
这些事实是固定情景夹具，**不是对患者标识符的检测**。

源端会在发件箱捕获锁下选择样本。默认策略为启用，且设有每日最低限额、采样率为 0：
每个源 UTC 日的首条符合条件分析观察仍会被选中。暂停不同于采样率 0。选择使用稳定 SHA 分桶，
并仅在通过 1,000 条容量检查后，与发件箱记录一起提交每日标记。这只保证成功捕获的观察项
能够被选择，不保证推理或无限交付。采样配置由源端拥有；此切片不提供通用策略编辑器。

接收处理会在同一事务中提交持久事件接入通知。独立的幂等排空流程会创建事件和计数；
因此事件步骤失败既不会丢失通知，也不会撤销传输回执。事件类别区分本地业务失败、实际规则
拦截和审核覆盖缺口。技术失败和未审核样本都不是隐私发现。自动模型预算为 **0**；
已选审核会标记为 `blocked_budget`。

打开事件以检查其不可变源观察，按允许的人工工作流推进，并保存原始意见（最多 2,000 个字符）。
操作使用修订 compare-and-swap；过时的并发操作会收到 409。历史记录只追加。保存意见不会对其
进行摘要、调用模型、生成/部署规则或解决其他事件。解决/重新打开事件不会重放或释放其底层业务消息。

手动调查需单独确认费用，仅限已发布隐私 Agent 和 schema-2 分析事实。它复用固定的知识/工具契约，
绝不发送原始人工意见。2026-10-16，一次单独授权的真实调查完成，创建了独立的范围内 `risk`
事件，并保持源事件不变。源端所选任务仍为 `blocked_budget`：手动调查不会追溯性地完成自动审核。
自动执行和诊断模板仍未完成。以下评估是有界合成检查，并非整体质量或合规认证。

<a id="twelve-case-privacy-evaluation"></a>

### 十二案例隐私评估

**分类更正：**这些报告是机制回归测试，不是业务上下文 HIPAA 风险验证验收。提供的布尔标记
已经编码了大部分答案，提示词也规定了标签。为保持来源链，原始报告 ID、套件和结果均不变。

Runs 现在显示持久化只读评估报告。刷新不会调用模型。单独的具备写入授权的
`POST /evaluations` 需要 `agent_id`、有界 `request_key`、`acknowledge_cost:true`
和 `max_model_requests:48`。没有任意提示词、夹具、端点或模型参数。服务器自有清单包含
12 个固定合成案例，预期结果不会放入提供给 Agent 的事实中：

| 案例 | 预期结果 |
|---|---|
| 标识符；授权不能证明去标识化；误导性的干净结果备注 | `risk`（3 个案例） |
| 已验证去标识化；未设置授权标志；误导性的风险结果备注 | 对这些有限标志为 `no_finding`（3 个案例） |
| 有/无标识符的未知用途；缺少“用途已知”标志；缺少用途；缺少去标识证据；标识符矛盾 | `insufficient_evidence`（6 个案例） |

每个案例都会使用相同哈希固定的已发布 Agent 或符合条件的版本化 v2 草稿、固定索引/语料库和
固定工具契约，创建独立 AI Hub 会话。报告保留清单及其哈希、Agent 配置/哈希、每案例结果/
预期结果、两个工具跟踪、检索证据/引文、被拒绝输出（如有）以及 SDK 用量/统计。
预期标签相等性是服务器自有检查，不是模型自行评分。引文 ID 必须来自检索证据；
此检查**不**证明法律推论成立或来源适用。

工作器会在每个案例执行前预留四次模型请求，最多 48 次，且绝不重试案例。预留的上限不是
实际 token/请求用量。重复请求键会返回同一报告；冲突的 Agent 身份会被拒绝。仅同一启动周期内
处于排队状态的作业可启动；重复工作器或中断/已完成作业不能重放。即使批次最终为
`state=completed`，失败案例仍保持失败。

使用 `deepseek-flash` 和固定索引 7 的实际验收：

- 手动调查：会话 `11`，完成 `risk`，两次模型交互和两次工具调用。源事件/意见和业务交付均未改变；
  新发现是独立的。
- 评估 `evaluation-88DC5E39-C8FE-11F1-A159-A263F534EED8`：会话 `12`–`23`，
  **12 项中 9 项通过、3 项标签失败、0 项技术失败**；评估批次约 61 秒。两个合成误导备注案例
  均通过。
- `missing_purpose_known` 和 `missing_purpose` 错误返回 `no_finding`。
  `contradictory_identifiers` 返回了 `risk`，虽保守但不符合固定预期
  `insufficient_evidence`。
- 调查与评估合并后的实际 SDK 累计计数：**26 次模型交互 / 26 次工具调用**，
  58,405 个提示词 token 和 7,822 个完成 token，其中 2,196 个推理 token 已计入完成 token
  （提示词加完成共 66,227 个 token）。低于单独批准的 52 次请求上限。缓存读取 token 已计入
  提示词用量，不得重复相加。未固定价格表时不推断货币成本。

原报告保留为**未通过**。之后将 `privacy-safety-v1` 加入响应接受边界：事实不完整、类型错误或
相互矛盾时，不能支持已接受的 `no_finding`。已记录的两个不安全输出在本地通过该保护重新回放，
均遭拒绝，没有调用提供方。新的策略拒绝会保留模型输出并明确失败，不会臆造正常评估。
此保护与未变更的已发布 Agent 配置分开记录。历史报告不会重新分类，模型提示词也未被悄悄修改。

<a id="versioned-v2-retest"></a>

### 版本化 v2 重测

随后获批的重测使用单独的 `privacy-review-v2` 草稿，而不是就地修改已发布版本。
固定指令现在会在正常/风险分类前优先处理事实缺失/无效和矛盾。服务器端保护仍然独立；
预期标签仍绝不提供给模型。

- 候选项：`agent-87963668-C900-11F1-A159-A263F534EED8`（草稿，修订 1）。
- 配置 SHA-256：
  `43bf1b6571a59356a1187098a5e74287b05e8f1215d75fc2801481e364f45d44`。
- 提示词 SHA-256：
  `cc7c535f531b0b9f7a0acdd2711091a46717018388b665c6d2cf7886f8a4c1c9`。
- 评估：`evaluation-991DF66E-C900-11F1-A159-A263F534EED8`，
  会话 `24`–`35`，**12/12 通过，零技术故障**，耗时约 53.5 秒。
- 相同的 `deepseek-flash`、索引 7、语料库、查询，以及清单哈希
  `31f7811770a6bc89444dedd2f0a49c4dbbc0917d9ca3121eee6a49a5023334cc`。
  原先失败的三个案例现在均返回 `insufficient_evidence`；两个误导备注案例仍然通过。
- 此批次单独使用了**24 次模型交互 / 24 次工具调用**，
  **59,743 个提示词 + 6,068 个完成 = 65,811 个 token**。1,678 个推理 token 已计入完成量；
  17,792 个缓存读取 token 已计入提示词用量。不得重复计入，也不得推断货币成本。
  单独批准的最大值为 48 次请求，不是实际用量。

没有重复调查，也没有重试任何案例。原 9/12 报告、已发布版本和绑定保持不变。
成功的候选项仍为**未发布且未绑定**；自动模型预算仍为零，DEMO Gate 仍不强制执行。
其成功评估表示具备发布资格，不代表已发布，也不代表获准执行业务。

这只是一次合成标志/边界评估，不是 12 个真实临床工作流、诊断基准或合规评估。
更广泛的模型质量、检索相关性/法律适用性和诊断模板仍需改进；持续自动审核仍处于禁用状态。

```sh
# Non-billing contract checks only:
python3 contest/privacy_evaluation_test.py

# PAID: requires explicit approval for one investigation (max 4 requests)
# plus one twelve-case batch (max 48). Do not change keys to retry a failure.
python3 contest/privacy_evaluation_test.py --run --request-key YOUR_APPROVED_KEY

# PAID ALTERNATIVE: one twelve-case evaluation only (max 48), no investigation.
# Use the exact independently approved Agent/candidate ID and request key.
python3 contest/privacy_evaluation_test.py --run --evaluation-only \
  --agent-id YOUR_APPROVED_AGENT_ID --request-key YOUR_APPROVED_EVALUATION_KEY
```

验收脚本会在 Git 忽略的 `contest/data/evaluations/` 下记录调查身份和完整报告。
调查状态不确定时会协调确认，而不会盲目重新提交。请将这些运行时证据保留在本地；
它不属于发布语料库。

<a id="business-context-hipaa-risk-benchmark"></a>

### 业务上下文 HIPAA 风险基准

现有的[十二项规格](../hipaa-demo-knowledge/evaluation-cases.json)现已扩展为
**10 个合成业务案例和 2 个明确控制案例**。这是作者编写的预备验收契约，
**不是已完成的模型评估或专家法律审查**。不包含真实患者数据。发布语料库摘要与运行时
默认导出/索引摘要分别固定。

| 案例 | 需推理的业务证据 | 作者预期的有限结论 |
|---|---|---|
| `business-01` | 已验证治疗提供方、治疗请求、PHI 字段清单、通过的传输控制 | 对所述披露事项不作发现；适用治疗许可及披露/请求的最小必要例外，不代表全面合规 |
| `business-02` | 外部分析、仅 Safe Harbor 的本地契约、残留 MRN、未提供其他依据 | 潜在风险；建议发送前拦截，并区分本地策略与联邦条件 |
| `business-03` | 结构化屏蔽，但叙述文本中电话检测器命中 | 对声称符合 Safe Harbor 的发布存在潜在风险；文本位置不改变标识符条件 |
| `business-04` | 声称 Safe Harbor，但包含完整出生/入院日期 | 此路径存在潜在风险，并非普遍禁止日期 |
| `business-05` | 声称有 Expert Determination 引用，但资格/方法/接收方假设未经验证 | 证据不足；应验证该独立路径，而不是强求 Safe Harbor |
| `business-06` | 声称采用有限数据集，但排除项/用途/DUA 证据不完整 | 证据不足；有限数据集仍属于 PHI |
| `business-07` | 存在标识符，但用途、接收方和披露依据未知 | 证据不足，而非自动认定违规 |
| `business-08` | 云提供方在无密钥情况下持有加密 ePHI；角色/合同证据缺失 | 证据不足；仅加密并不消除角色义务 |
| `business-09` | 操作员明确跳过可解决防护措施评估/记录 | 按带日期快照可能属于流程风险；不得臆造当前无条件加密规则 |
| `business-10` | 成功交付给无关且未批准的接收方 | 潜在风险；建议围堵/违规评估，不自动通知，也不追溯性地发送前拦截 |
| `business-11`（控制） | 规范检索不可用 | 明确证据不足；不得臆造引文或“全部正常” |
| `business-12`（控制） | 声称历史说明可覆盖带日期法规 | 适用性审查；历史材料不自动成为当前权威依据 |

每个模型可见数据包仅包含不透明案例 ID、阶段、合成标记及带 ID 的文本事实。
其中**不**包含预期标签、必需章节、来源锚点或判定标准。与机制套件不同，事实不提供
`direct_identifiers` / `deidentification_verified` 答案标志。信息缺口和声称存在的文件
只是事实，不等于缺失或有效的证明。引用片段仍是不可信数据。

离线[校验器](./business_privacy.py)有三个独立边界：

1. **准备：**验证发布语料库指纹、案例/事实身份唯一性、法律来源章节覆盖情况，以及带日期
   规范法规快照中的逐字条款锚点。
2. **机械响应检查：**要求有界结构化发现与真实数据包事实 ID、引用的检索片段及确切来源引文
   关联。拒绝伪造 ID/引文、历史/未审核/LLM/合成规范引文、检索失败却返回“全部正常”，以及
   交付后不可能执行的拦截。将预期评估/建议、关键事实引用及章节覆盖情况与作者私有判定标准比较。
3. **人工语义审查：**评估每项 `must_explain` / `must_not_claim`、引文是否支持主张、
   披露例外、缺失事实以及生效日期/适用性限制。`oracle_alignment=true` **不**代表通过此审查。
   即使引文真实，但与主张无关，只要来自正确章节也可能通过机械检查。因此报告始终标记
   `human_review_required:true` 和 `hipaa_risk_validation:not_completed`。

这些只是**提议的建议**（`hold_for_review`、`manual_review`、
`continue_under_existing_controls`），不是可执行的 IRIS 命令。未来运行时集成必须另行验证
决定、阶段和策略，只应用获授权操作，并审计实际结果。规格或离线评分报告都不会发布 Agent、
授权费用、更改 Gate 或证明已经执行。

免费本地命令（不调用模型、网络或业务操作）：

```sh
python3 contest/business_privacy.py verify
python3 contest/business_privacy.py context --case-id business-01
python3 -m unittest discover -s contest -p 'test_business_privacy.py'

# Check separately saved actual response/evidence, not a model invocation:
python3 contest/business_privacy.py grade --case-id business-01 \
  --response /absolute/path/response.json --evidence /absolute/path/evidence.json
```

响应字段恰好为 `assessment`、`recommended_action`、`reason`、`findings` 和
`missing_information`。每条 finding 都包含 `fact_ids`、`explanation` 和 `citations`；
每条 citation 都包含 `evidence_id` 和逐字 `quote`。Evidence 是 `{id, record_id, text}`
对象数组，引用发布记录和实际检索摘录，而不是判定标准的来源锚点。证据不足时必须说明缺少哪些信息。
检索失败控制不应包含法律发现或检索片段。

离线校验器本身只检查来源文本真实性，**不检查检索是否实际发生**。
`grade_runtime_case` 还要求数据包未改变、AI Hub 会话案例已完成、事实工具调用先于搜索，
并且记录的搜索返回与待评分证据完全一致。不得将作者编写的响应提交为模型结果。

<a id="independent-business-context-runtime"></a>

#### 独立的业务上下文运行时

`Contest.BusinessReview` 现在提供单独的**只读评估运行时**，不是旧 Agent 的替代品、
事件调查器或 BP 路由组件。它复用有效且固定的来源配置中的模型/索引/语料库设置，但会新建
`%AI.Agent`，采用独立哈希的 `hipaa-business-runtime-v1` 提示词，且**仅使用**
`Contest.BusinessToolSet`：

- `ReadBusinessFacts(runId)` 返回不含答案的事实数据包。
- `SearchBusinessEvidence(runId, query)` 要求先读取事实；最多接受 3 条不超过 600 个字符的
  上下文公共知识查询，且始终使用来源固定的已完成索引。它会从前五个向量命中项中过滤出
  规范法规快照或官方指导。这不保证相关条款覆盖：过滤后可能没有符合条件的结果。
  来源记录/片段 ID、分数、带日期元数据、确切摘录和实际查询都会保留。
- `business-11` 中断是明确的**模拟控制项**，与实际检索失败分开记录。不会在提供方或运行中的
  知识索引中注入故障。检索错误会返回明确的不可用结果并进行受保护审计，不会替换为其他引文。
- 运行时会检查事实 ID、来自实际返回片段的精确引文、输出边界和阶段/操作一致性。
  `risk` 或 `insufficient_evidence` 不能建议继续。它不会读取私有判定标准、授予语义/法律通过，
  也不会执行建议。

`POST /business-evaluations` 需要 builder 权限、JSON/CSRF 检查，以及恰好这些字段：
`agent_id`、`input_hash`、`request_key`、`acknowledge_cost:true`、
`max_model_requests:48`。输入仅来自固定的本地准备文件；客户端不能提供路径、提示词、端点、
事实数据包或工具。输入哈希固定不含答案的 12 案例数据包。报告会将其清单/语料库指纹与固定的
运行时索引语料库分开保留。同一键/同一输入的提交会返回原始报告；身份冲突会被拒绝。
同一启动周期、仅处理排队项且受锁保护的工作器每案例预留 4 次模型请求，绝不重试，
并记录停止/中断状态而非重放。已完成批次仍可能包含失败案例。

`GET /business-evaluations` 和 Runs 会将实际报告与旧版标志套件分开显示。
`valid_contracts` 表示输出边界接受了格式/证据引用，**不代表 HIPAA 结论正确**。
报告始终保留 `human_review_required:true`、`hipaa_risk_validation:not_completed`
和 `execution:evaluation_only`；每条建议均为 `not_executed`。失败输出和累计 SDK 统计仍可查看。
报告不授予发布或绑定资格。

通过现有设置/配置流程加载更新后的类之后：

```sh
# FREE: prepare answer-free fixed inputs (never overwrites different contents).
python3 contest/business_evaluation_test.py --prepare
# FREE: API role, consent, JSON/CSRF and changed-input guards.
python3 contest/business_evaluation_test.py
# Framework: compile/run Contest.BusinessReviewTests in TRIAGE; no Chat call.

# PAID: only after a NEW explicit authorization for this independent batch.
# Twelve cases, at most48 model requests, no investigation or retries.
python3 contest/business_evaluation_test.py --run \
  --agent-id YOUR_APPROVED_PINNED_AGENT --request-key YOUR_APPROVED_BUSINESS_KEY
```

脚本会在本地忽略数据中记录确切运行时证据和离线作者判定检查。来源真实性及关键事实/章节/
结果检查与必需的人工语义审查分开。进程成功退出不代表整体 HIPAA 风险验收或工作流已执行。

免费验证包括框架回归，以及针对固定 IRIS 向量索引执行一次实际的本地上下文工具检索，
不调用模型。MCP 开发账户的 SQL 访问权限不同于应用 Reader：不要为了让实时检索单元测试通过
而扩大权限；应单独执行应用角色检索验收。SDK 的 ToolSets 字符串并非 `UseToolSet` 后发现的
目录；应断言实际发现结果。

<a id="first-real-business-context-batch-completed-acceptance-not-passed"></a>

#### 首批真实业务上下文批次：已完成，但未通过验收

一个单独批准的 12 案例批次使用请求键 `business-context-quality-20261016` 运行，
最多 48 次模型请求，没有自动重试、发布、绑定、重复调查或业务操作。
报告 `business-evaluation-34EB2261-C904-11F1-A15B-A263F534EED8` 保留 AI Hub 会话
36–47。之后增加的诊断显示没有更改原始持久化运行时报告。

结果必须作为**三个不同层面**解读：

- **9/12 个有效输出契约，3 个输出被拒绝。**这检查结构、允许的建议、事实引用和检索引文原文，
  不检查法律正确性。
- **3/12 与作者判定标准的所有机器检查一致**（`business-02`、`04`、`11`）。
  这**不是 HIPAA 准确率分数**。有些案例结论方向合适且引用了相关 HHS 指引，但缺少固定来源
  覆盖检查要求的确切 CFR `source_locator`。事实若只在散文中提到，而没有必需的结构化引用，
  也会导致检查失败。观察结果后没有放宽原始预期。
- **人工语义及法律适用性审查仍待完成。**以下证据检查是 AI 辅助工程诊断，不是独立的人类/
  法律专家评估，也不是确定违规的结论。

| 案例 | 接受的运行时输出 | 机器/工程诊断 |
|---|---|---|
| `business-01` | `no_finding / continue_under_existing_controls` | 方向符合预期；缺少确切的 164.506 定位符。治疗 HHS 指引相关，但额外的工伤赔偿/州法 FAQ 不适用于所述披露。 |
| `business-02` | `risk / hold_for_review` | 所有作者机器检查均一致；仍需人工审查。 |
| `business-03` | 拒绝 | 一条引文不是返回证据中的逐字子串；原始风险建议仍保留，但不接受。 |
| `business-04` | `risk / hold_for_review` | 所有作者机器检查均一致；仍需人工审查。 |
| `business-05` | 拒绝 | 两条引文并非逐字引用。原始输出还将未验证的替代去标识依据判为风险，而非作者预期的证据不足。 |
| `business-06` | `risk / hold_for_review` | 来源/事实覆盖齐全，但作者预期证据不足/人工审查：不能把缺少证明混同为已证明不存在。 |
| `business-07` | `risk / hold_for_review` | 用途/接收方/依据未知；与证据不足预期不同，且缺少必需的确切章节定位符。 |
| `business-08` | 拒绝 | 额外的 `assessment_notes` 字段违反精确输出 schema；原始风险标签也与证据不足预期不同。 |
| `business-09` | `risk / manual_review` | 方向符合预期，但缺少必需的结构化 `limits` 事实引用和确切的 164.312 定位符；相关的一般保障指引不能满足该覆盖检查。 |
| `business-10` | `risk / manual_review` | 方向符合预期且引用相关 HHS 违规指引；缺少确切的 164.402 定位符是来源覆盖缺口，本身不能证明法律结论错误。 |
| `business-11` | `insufficient_evidence / manual_review` | 明确模拟的检索中断控制在没有臆造证据的情况下得到处理；这不是真实提供方/索引中断测试。 |
| `business-12` | `risk / hold_for_review` | 与适用性审查预期不同，缺少确切 164.502 定位符，以最小必要分析取代披露依据认定，且包含无关授权 FAQ 片段。 |

耗时约 **247.3 秒**。SDK 累计统计记录 **43 次模型交互、48 次工具调用**、
**188,672 个提示词 + 37,143 个完成 = 共 225,815 个 token**。17,649 个推理 token 已计入完成量；
82,176 个缓存 token 已计入提示词。未固定提供方价格表，因此不声称美元成本。已批准批次已结束：
43/48 次实际请求**不**授权再补做 5 次请求。

完整运行时/工具/SDK 证据和离线检查保留在 `contest/data/evaluations/` 下的 Git 忽略本地日志中。
`--prepare` 现在还会创建单独固定的私有 `business-oracle-v1.json` 供免费诊断显示；它绝不会进入
`ReadBusinessFacts`，也不会提供给模型。GET 会用标注的作者机器诊断丰富报告副本，不会改写存储
报告。Runs 会分别显示契约计数和作者机器一致性，包括未满足的检查及被拒绝的原始输出。
CLI 在已完成案例数变化时打印进度。

此批次之后的免费验证：新增 9 个 IRIS 框架方法、41 项 Python 测试以及 39 项前端测试/构建/
类型检查/lint。这些是回归测试，不是额外模型评估。

**尚待完成：**下文描述 v2 机制和单独授权的重测。剩余标签/建议差异需要审查，而非放宽预期。
应先取得人工语义/适用性审查，然后单独实现受策略控制的 BP/消息集成和经审计的业务操作验收。
任何新的真实模型批次都需要重新授权。现有 9/12 和 12/12 报告仍仅作为机制证据。

<a id="v2-evidence-and-judgment-upgrade"></a>

#### V2 证据与判断升级

`hipaa-business-runtime-v2` 是单独选择加入的运行时版本，不是重写首批批次。
现有来源 Agent、v1 提示词/哈希、准备好的案例清单、作者预期和已存报告均予保留。
实现和免费测试本身不构成模型批次、发布、绑定、自动预算或业务操作授权。
随后单独批准的模型重测记录在下文。

**证据获取：**`Contest.BusinessToolSetV2` 会准确发现 3 个只读工具：`ReadBusinessFacts`、
`SearchBusinessEvidence` 和 `LookupBusinessClause`。必须先读取事实。发现仍使用固定的 IRIS
向量索引；确切查找使用同一已完成索引验证，并对该表执行参数化 SQL，限制为具有请求 CFR
章节的规范 `regulation_snapshot` 行。调用方根据业务推理/发现选择章节和可选字面、不区分大小写
的锚点，不会通过案例 ID 到答案的映射选择。官方指导仍可通过语义发现获得，并保留其不同来源类型
和日期。

语义搜索和条款查找共用**每案例 3 次检索调用**；Agent 仍有 4 次模型迭代。确切查找最多扫描
100 条匹配记录，最多返回 5 个有序片段，每段最多 2,000 个字符。会报告章节/匹配片段数及
`truncated`；锚点筛选的摘录不会被悄悄呈现为完整章节。无匹配、索引无效或 SQL 失败时会明确
返回证据不可用；失败会进行受保护审计。绝不回退到其他语料库、外部网站、历史文本或“全部正常”
结论。证据可用时，v2 评估器至少要求尝试一次条款查找，不接受仅做语义发现。这不保证 Agent
选对了章节，也不保证返回摘录涵盖所有例外。

**判断契约：**顶层五个字段仍为 assessment、recommended action、reason、findings 和
missing information。现在每项 finding 还必须包含命名的 `condition` 和 `evidence_status`：

| Finding 状态 | 提示词要求的含义 |
|---|---|
| `supported_risk` | 已提供的肯定事实支持某个适用条件未满足；仅仅缺少文件并不能证明文件不存在。 |
| `supported_no_finding` | 事实和证据只支持所述有限事项，不代表整个组织合规。 |
| `unresolved` | 必要事实、来源、例外或适用性问题尚未验证。 |

服务器会强制执行聚合规则：`risk` 至少需要一项 `supported_risk`；否则若存在任何
`unresolved`，必须使用 `insufficient_evidence`；`no_finding` 仅适用于全部问题都有支持的
无发现且 missing-information 列表为空的情况。即使另一问题支持风险，未解决问题仍必须明确列出
缺失信息。证据不足时也允许建议发送前拦截，使保守的运维建议与法律证据分类分开。
交付后/配置级拦截和无条件继续仍会被拒绝。固定作者判定标准中的预期保持不变，包括更具体的
预期建议。

这些是一致性检查，**不是确定性法律推理器**：模型仍可能错误地将事实支持标为
`supported_risk`、选择不适用条件或误解例外。人工蕴含关系和适用性审查始终待完成。

**引文：**每条返回摘录都有规范编号 `passages`。模型只提交 `{evidence_id, passage_id}`；
不会自行写引文或偏移。服务器验证所选句柄，将确切来源文本物化，并在句柄旁记录 `quote`、
`start`、`end`。偏移以返回摘录中的 UTF-16 代码单元计，从零开始、结束位置不包含在内，
不是完整来源文档中的偏移。跨度连续且有界，不会拆开代理项对。原始模型 `proposal` 与物化后的
`result` 分开保留。未知句柄、改动过的段落、额外字段和不一致的聚合都会明确失败；
不会自动修复 JSON、删除字段、替换答案或重试模型。被拒绝的原始输出和累计 SDK 计数仍沿用
既有失败路径。逐字来源证明仍不能证明引文支持其主张。

离线评分器会独立重建 v2 物化结果，依据已发布语料库验证来源摘录，并检查实际事实/检索跟踪。
Runs 能识别两个版本并保留其完整原始证据。未来若要运行**单独批准**的批次，CLI 除现有
`--run`、固定 Agent ID 和新批准的不可变请求键外，还必须要求
`--runtime-version hipaa-business-runtime-v2`。POST 会在原五个授权字段上恰好增加
`runtime_version: "hipaa-business-runtime-v2"`。省略它会保留 v1 行为；尝试将旧 v1 键用于 v2
会在任何工作器/模型请求前遭拒。

免费验证覆盖段落选择/篡改、UTF-16 边界、不确定性/操作分离、精确输出字段、阶段限制、
作业隔离、共享工具预算、不调用 `Chat` 的三工具 SDK 发现、版本化授权以及未变更的 v1
提示词哈希。针对章节 164.502、164.506、164.514、164.306、164.312 和 164.402 的 6 次真实
非模型 IRIS 查找返回了可信语料库文本；所有段落坐标/文本都与独立 Python 实现一致。
SDK 工具管理器分发也在未创建模型会话或调用 `Chat` 的情况下进行测试，包括真实的固定
164.506 查找，以及事务隔离的故障断言。工具描述出现在发现的 SDK schema 中，
而不只是系统提示词。这些测试验证新机制，**不是 Agent 准确率提升或新的 HIPAA 验收结果**。

验证完成：8 项 v2 IRIS 框架方法，加上 27 项既有业务/Agent/隐私方法、
48 项离线 Python 测试、39 项前端测试，以及构建/类型检查/lint 和非计费 API/检索验收命令。
原有三份评估报告保持完全一致，旧请求键不能升级为 v2，自动模型预算仍为零，
DEMO Gate 保持修订 8 的禁用状态，没有创建新的评估报告。

**已知 EAP 诊断：**通过 SDK 工具管理器执行嵌套语义检索会出现对象引用清理警告：
`Could not decrement IRIS object Oref(...) counter at drop`，并涉及 `%SQLCODEGet,%SQL.Statement`。
在 v1 工具路径上也单独复现了相同基线。两个版本都返回了可用证据；v2 条款查找及来源链检查
均完成。未隐藏该警告，也未声称已修复；其底层 SDK 原因尚未查明。发布前仍需调查此运行时诊断；
免费测试不意味着 SDK 集成没有警告或已达到生产级强化。

<a id="authorized-v2-model-retest"></a>

#### 已授权的 v2 模型重测

用户随后授权使用 `deepseek-flash`、固定索引 7 和未变更的来源 Agent 配置重测同一 12 个案例。
请求键 `business-context-v2-quality-20261016` 创建报告
`business-evaluation-75DD1734-C90C-11F1-A15C-A263F534EED8`，使用会话 48–59，
提示词哈希为
`dbddec601f1dd814cdb02189155164189ca5f295aa39d1fee4633f07ab547891`。
输入数据包、作者预期和先前报告均未更改。

| 检查项 | 首个业务批次（v1） | v2 重测 |
|---|---:|---:|
| 有效输出契约 | 9/12 | 12/12 |
| 被拒绝/技术输出 | 3 | 0 |
| 完全符合作者判定标准 | 3/12 | 8/12 |

v2 在 **10/12** 案例中匹配预期**评估标签**，在 **9/12** 中匹配预期建议，在 **12/12**
中匹配必需事实引用、确切法规章节覆盖和运行时来源信息。这些是固定基准检查，**并非经过独立
审查的法律准确性**。全部 8 个完全一致案例仍需人工蕴含关系/适用性审查。其余 4 项差异均予保留：

| 案例 | v2 输出 | 尚存差异及工程检查 |
|---|---|---|
| `business-05` | `insufficient_evidence / hold_for_review` | 预期评估现已匹配。Expert Determination 验证缺口不再被视为失败证明。作者预期为 `manual_review`；v2 选择了契约允许的保守发送前拦截。 |
| `business-06` | `insufficient_evidence / hold_for_review` | 预期评估现已匹配；缺少 DUA/用途/排除证据明确区别于条件已失败的证明。仅建议与作者的 `manual_review` 不同。 |
| `business-08` | `risk / manual_review` | 契约缺口仍未解决，正确地没有被当作协议缺失的证明。但模型单独将操作员“加密意味着不是 BA”的推理标为有支持的风险。这引发了审查问题：如何区分可证实的错误前提与已证实的披露/合同条件失败；作者预期为证据不足。 |
| `business-12` | `risk / hold_for_review` | 模型承认披露依据和历史来源适用性未验证，却将无依据的覆盖主张判为有支持的风险。缺少已证实许可仍被提升为肯定风险；作者预期为证据不足/人工审查。 |

上述讨论是 AI 辅助工程检查，不是已完成的人类/法律专家评估。尤其是 v2 聚合可以强制与声明
的 finding 状态一致，但无法证明模型正确分配了 `supported_risk`。下一步应将无依据的操作员推理
与证明适用条件未满足的肯定事实分开，而不是在运行后修改原判定标准。

耗时 **341.2 秒**。累计 SDK 计数记录 **45 次模型交互、45 次工具调用**，
**289,289 个提示词 + 54,060 个完成 = 共 343,349 个 token**。推理 token（33,759）已计入
完成量；缓存 token（149,376）已计入提示词。与 v1 的 225,815 个 token 相比，此次单独重测
多用了约 **52% token**，因此没有证明基准覆盖改进带来了效率提升。未固定提供方价格表时不推断
货币成本。

原始运行时证据和独立检查保存在 Git 忽略日志
`contest/data/evaluations/business-context-v2-quality-20261016-business.json`。
Runs 同时显示两个业务批次，包括 v2 的 12 项有效契约/零技术失败及 8/12 作者机器一致性；
已检查其 390px 视口没有水平溢出。CLI 因并非全部固定检查通过而返回非零退出码，不是因为批次
未完成。没有重试，也没有使用 48 次请求额度中剩余的三次请求补跑。未发布/绑定来源 Agent、
未创建新的工厂作业、未重复调查、未启用自动模型预算或更改业务 Gate。人工审查和受策略控制的
业务集成仍待完成。

<a id="post-retest-optimization-research-no-new-inference"></a>

#### 重测后的优化研究（无新推理）

检查保留的 v2 事实、选定引文、工具跟踪和 SDK 计数后，发现了三个独立问题，并非模型简单地
能力不足，也不是四个答案都同样错误。这是对带日期证据的工程分析，不是已完成的法律审查。
调查期间实时获取 HHS 云计算页面返回 HTTP 403；分析使用的是 Agent 实际收到的固定存档 HHS
文本，而非声称已实时验证法律。

**1. 区分受到质疑的前提与已证实的条件失败。**在 `business-08` 中，数据包明确说明提供方
维护医院的 ePHI 归档，而非仅临时传输。选中的 HHS 云指导直接涉及无解密密钥的存储，并反驳
操作员“加密即可排除业务伙伴身份”的绝对主张。Agent 有实质依据标记这个前提。它也单独承认，
审核数据包中未提供合同并不能证明合同不存在。因此，简单将整个回答标为过度自信的法律错误，
会抹掉有价值的发现。含糊之处在于：整体 `risk` 是否既涵盖错误的角色论证，也涵盖已证实未满足
的适用运维/法律条件。

类似地，`business-12` 可以合理质疑缺乏依据的历史覆盖主张，但数据包不能证明计划披露没有许可
依据。保留关于依赖无依据内容的警告；不要把未能证明有许可提升为不允许披露的证明。
下一个契约、UI 和基准必须一致说明此边界，而不是为了匹配两个旧标签悄悄调优。

建议的下一个版本应区分：

- **主张评估：**提供的陈述受带日期引文证据支持、与之矛盾或仍未验证。
- **合规条件评估：**相关许可/义务适用、不适用或未解决；条件已被支持为满足、被支持为未满足，
  或未知。
- **运维建议：**在明确的本地策略下继续、发送前拦截或请求人工审查，并与法律发现分开。

对有支持的条件失败，要求紧凑的证据链：确切条件及其权威依据、证明适用性的事实引用、
显示未满足情况的肯定事实引用，以及仍待解决的例外/替代依据问题。单独的无依据主张可以产生警告，
但不足以证明底层合同/披露失败。缺少文件与已验证文件不存在必须区别处理。已知未满足的本地
先决条件可以支持本地策略拦截，但不得将其描述为联邦法律违规。

这些字段能让推理可审计，但仍不能证明模型的语义分类正确。不得悄悄重分类现有 v2 回答，
也不得添加基于案例 ID/关键词的规则。即使总体条件评估为证据不足，也要显示主张警告。

**2. 保留历史精确匹配分数，但应分别评估含义与策略。
** 案例 `business-05` 和 `business-06` 与预期的证据不足分类匹配。其唯一差异是建议了契约允许的
发送前拦截，而不是作者的人工审查建议。保留原始精确结果 8/12。单独版本化的评估器可分别报告
评估质量和操作策略符合度，并在下次运行前声明允许的操作。不得将旧运行追溯性改标为 10/12，
也不得声称精确章节覆盖证明了推论成立。

进一步调优提示词前，应在原 12 案例集之外准备反事实配对：文件未提供 vs 已验证不存在 vs
已验证有效；受到质疑的操作员主张（有/无肯定证据证明条件失败）；同一问题在交付前 vs 交付后。
同时加入真正风险和合法无发现结果的正控制，避免“始终回答证据不足”看似提高质量。
用于调优的开发者编写配对应标注为开发测试，不得称为留出测试或独立人工验证。
下一次模型运行前应固定单独的审查集。

**3. 在增加 Agent 或调用前减少冗余证据。**已保存的 v2 证据包含 183,040 个来源字符，
在 `passages[].text` 中又重复了同样的 183,040 个字符。v1 检索了 235,560 个来源字符，
但没有第二份表示。因此 v2 检索来源文本更少，却发送了重复文本及 passage/metadata 开销。
提示词 token 从 188,672 增至 289,289；完成 token 从 37,143 增至 54,060，其中推理 token
从 17,649 增至 33,759。这些相关性指出优化方向，并不证明各变化的因果贡献。

对确切已存工具响应进行的免费投影实验保留了可用性/查找诊断、证据 ID、来源定位符/URL/类型/
版本/法律状态以及每个 passage ID/文本一次，同时从拟议模型视图中省略了重复完整文本、
仅供服务器使用的偏移及其他审计元数据。紧凑 ASCII JSON 大小从 **527,077 降至 242,250 个字符
（缩小 54.0%）**。这是**序列化响应大小**，不是实测 tokenizer 用量、整个循环 token 节省、
提供方成本下降或评估后的质量提升。完整规范证据、偏移和来源哈希必须继续保留在服务器审计/
离线验证路径中；只有在新的运行时版本中才可更改模型视图。

还应优先选择相关条款/例外组，而不是大型章节中的前五个片段；去重重复来源片段时保留其来源链。
在 `business-12` 中，实际路径使用了两次宽泛语义搜索和一次五片段、无锚点的 164.508 查找；
三次检索调用全被消耗，却没有解决关键的历史适用性问题。明确面向问题的证据预算，以及在没有
可用来源证明缺失业务事实时提前停止，比增加检索次数更有希望。有些选定引文在句中结束，或只有
标题而没有后续条件：应加入有界相邻段落/段落组装和边界标记，而不是把有效句柄视为自包含命题。
不得仅为缩短上下文而省略必要例外。

**建议顺序：**先定义并免费测试下一版条件/主张/操作契约及成对案例；然后实现紧凑模型证据视图，
同时保持规范来源链不变并优化条款边界。固定新版本、来源/基准指纹和验收标准后，再申请单独预算的
模型对比。如果要归因收益，初期一次只更改一个主要因素；捆绑重测可评估整体方案，但无法隔离因果。
默认不要增加第二个模型裁判、额外检索轮次、自动修复或更强模型。本研究没有更改任何运行时、
判定标准、报告、提供方请求或业务策略。

<a id="v3-conditionclaim-separation-and-compact-evidence-free-only"></a>

#### V3 条件/主张分离及紧凑证据（仅免费）

随后实现的 `hipaa-business-runtime-v3` 明确为选择加入版本，不替代早期任一运行时或工厂的
`privacy-review-v2`。其提示词 SHA-256 为
`47879a4322b7ea63964d9b7f7c0e47064fb3b011c261676cbb110169aac43cdd`。
源模型/索引、不含答案的输入数据包、作者私有判定标准及现有报告均保持不变。
此免费实现完成时尚未运行任何 v3 模型批次；随后获批的重测记录在下文。

输出恰有 6 个顶层字段：`assessment`、`recommended_action`、`reason`、`findings`、
`claims`、`missing_information`。主张和条件各最多 10 项：

- 主张包含 `fact_ids`、`status`（`supported`、`contradicted`、`unverified`）、
  `explanation` 和来源句柄 `citations`。
- 条件 finding 恰含 9 个字段：`fact_ids`、`condition`、`applicability`、
  `applicability_fact_ids`、`condition_status`、`affirmative_fact_ids`、`exceptions`、
  `explanation` 和 `citations`。适用性为 `applicable`、`not_applicable` 或 `unknown`。
  条件状态为 `met`、`not_met`、`unknown` 或 `not_applicable`。例外审查记录
  `status:resolved|unresolved` 和解释。
- `met`/`not_met` 要求适用性状态、非空适用性/肯定事实引用（且引用须来自该 finding 的已知事实 ID），
  并且例外/替代依据审查已解决。`not_applicable` 需要其自身适用性证据，且不得提供肯定满足/
  失败引用。未知条件不得断言肯定失败/满足，且必须指出缺失信息。
- 只有适用条件为 `not_met` 才能产生总体 `risk`。若无此类条件，但存在未知条件或未验证主张，
  则要求 `insufficient_evidence`；否则可有限地判为 `no_finding`。主张矛盾仍须可见，
  但本身不能证明底层合同/披露条件失败。证据缺失时 findings/claims 必须为空，
  并明确列出缺失信息。

这会强制执行**已声明证据链结构**，不是语义真实性。已知事实引用不能证明这些事实蕴含法律结论、
例外确已解决或条件选择正确。测试刻意展示：即使证据链语法完整但标签错误，也仍需人工审查。
没有引入基于案例 ID/关键词的语义覆盖或自动修复。

`BusinessToolsV3` 暴露相同的 3 个只读工具，并保留每案例 3 次检索/4 次模型迭代上限。
规范来源文本、元数据、哈希、偏移和 passages 保留在 `evidence` 与 `tools[].response`。
`tools[].model_response` 记录实际发送给 SDK 的紧凑投影。投影包括证据 ID、来源定位符/URL/类型/
版本/法律状态/标题/检索日期，以及只出现一次的 passage ID/文本；省略重复全文副本和仅审计字段。
可用性、错误以及查找截断/匹配诊断均予保留。块内前/后 ID、
`boundary_review_required:true` 和 `partial_context:true` 会提醒标题或截断句子不自动构成
自包含权威依据。引文仍解析到未更改的规范 passages，而非重建的模型文本。
跨调用去重、按问题对片段排序以及跨块完整段落/例外组装均**未实现**。

将此视图应用到全部 **33 个已存 v2 检索响应**后，紧凑、未转义 JSON 字符数从
**522,947 降至 313,852（减少 39.98%）**。这与早先探索性 ASCII 投影不同，因为最终视图还保留了
标题/日期及相邻/边界提示。这不是实测 token 用量、提供方成本节省、完整推理循环缩短或质量提升。
更强的输出契约本身可能增加开销。

仅对新的 v3 结果，`stage-conservative-v1` 操作策略符合度会与精确作者操作匹配分开报告：
允许人工审查；拦截仅限发送前；只有 `no_finding` 才能建议继续。这是建议边界，不是执行授权或
联邦法律裁定。版本化 `claim-and-condition-v1` 覆盖诊断会统计两类输出中的明确事实引用和章节
引文，且不允许主张产生风险。原预期标签/操作以及 v2 的**8/12**完整精确结果不会改变或重评分。
离线评分还会验证保留的 proposal 解析、真实来源引文、完整规范工具/证据相等性及确切模型投影。
Runs 会分别显示主张、条件和本地操作策略结果。

免费验证覆盖：

- IRIS 契约测试，包括文件未提供/已验证缺失/已验证有效三种状态与发送前/后的配对、
  不完整证据链、未验证/矛盾主张、无证据行为及 v2 键重用拒绝。这些配对由开发者编写，
  **不是**模型判断、留出基准或独立法律审查。
- 实际 SDK 工具发现/分发（不调用 `Chat`，不创建会话）：恰好发现 3 个有文档的工具、
  实际固定索引章节查找和语义检索，以及规范/模型跟踪一致性。两次实时检索都返回了证据；
  Python 与 IRIS 投影完全一致。
- Python 离线测试及前端 decoder/build/type/lint 检查。前端夹具测试验证主张/条件显示数据分开，
  以及操作策略解码；不会向持久运行时历史插入合成 v3 报告。
- 免费 HTTP 版本/同意/变更输入保护。POST 只有在明确提供 `runtime_version` 时才接受 v3；
  旧请求键不能授权新版本。

SDK 嵌套检索对象清理警告在语义分发时仍会出现；证据可返回，但这并非无警告的 SDK 结果，
也没有声称采用了无关的 SDK 变通方案。两份历史业务报告和两份机制报告保持不变；
保留两个工厂 Agent/3 个作业、一次手动调查、自动模型预算为零，以及修订 8 的禁用空 DEMO Gate。
此次改进未执行任何业务操作、发布、绑定、配置/重启或提供方请求。模型对比需要新的明确授权。
独立留出案例、人工适用性/蕴含审查和受策略控制的业务集成仍待完成。

<a id="authorized-v3-model-retest-fewer-recorded-tokens-acceptance-regression"></a>

#### 已授权的 v3 模型重测：记录 token 更少，验收退步

用户随后于 2026-10-16 授权运行一个 12 案例 v3 批次，请求键为
`business-context-v3-quality-20261016`，最多 48 次模型请求，不重试或跟进调查。
报告 `business-evaluation-462A83BE-C917-11F1-A15C-A263F534EED8` 保留 AI Hub 会话
**60–71**。它使用相同的 `deepseek-flash` 模型、来源 Agent r3、索引 7、输入/判定标准及上述
v3 提示词哈希。此前两份报告均未改写。批次已完成；**验收退步**。

| 指标 | V2 | V3 |
|---|---:|---:|
| 接受的输出契约 | 12/12 | 6/12 |
| 失败案例 | 0 | 6 |
| 完全符合作者判定标准 | 8/12 | 1/12 |
| 被接受结果中的预期评估 | 10/12 | 6/12 |
| 被接受结果中的精确预期建议 | 9/12 | 4/12 |
| 必需事实引用 | 12/12 | 6/12 |
| 精确要求的章节覆盖 | 12/12 | 3/12 |
| 被接受结果 + 保留运行时来源信息 | 12/12 | 6/12 |
| 记录的模型交互 | 45 | 46 |
| 记录的工具调用 | 45 | 48 |
| 提示词 token | 289,289 | 173,288 |
| 完成 token | 54,060 | 58,983 |
| 总 token | 343,349 | 232,271 |
| 耗时 | 341.2 秒 | 413.1 秒 |

这些是有界基准/SDK 观察，不是法律准确性或受控因果实验。统计标签时，不会把被拒绝的最终输出
升级为已接受答案。v3 的事实/章节覆盖按 `claim-and-condition-v1` 合并统计主张和条件；
原作者判定标准保持不变。只有模拟检索中断控制 `business-11` 通过全部机器检查。

受保护的运行时审计区分了六个失败：

- `business-02`：提供方响应正文超时；未捕获最终输出。
- `business-04` 和 `business-06`：在未变化的四次迭代限制下 SDK 返回 `MaxIterationsReached`，
  没有最终输出。工具调用数不等于模型交互数；记录了工具调用不保证检索有用且已完成，也不保证
  存在最终答案。
- `business-03`、`business-05`、`business-10`：保留了最终 JSON，但 Agent 从未调用必需的
  `LookupBusinessClause`。运行时正确拒绝仅通过发现获得的答案。对这些原始 JSON 对象进行的离线
  引文/格式解析通过，但这**不**满足执行/工具来源契约。因此，失败项目的通用后续“六字段”
  评分错误不能证明模型输出了格式错误的 JSON。原始失败状态和被拒绝输出均保留，未修复。

已接受结果及剩余缺口：

| 案例 | 已接受结果 | 检查结果 |
|---|---|---|
| `business-01` | `no_finding / continue_under_existing_controls` | 标签/操作符合预期；虽然讨论了治疗例外，但缺少确切 164.502 引文。 |
| `business-07` | `insufficient_evidence / hold_for_review` | 标签和来源覆盖符合预期；发送前拦截在本地允许，但与作者的人工审查建议不同。 |
| `business-08` | `insufficient_evidence / manual_review` | 分离效果符合预期：云角色论证为 `contradicted`；协议条件仍未知。缺少确切 164.504 覆盖。最后一次查找却针对 164.402 和 `encryption` 锚点，无确切匹配，消耗预算但未解决协议条件。 |
| `business-09` | `risk / manual_review` | 标签/操作符合预期且有肯定配置事实；未提供所需的确切 164.312 定位符，引用的是 164.306/164.316 及指导。 |
| `business-11` | `insufficient_evidence / manual_review` | 模拟无证据控制；未臆造主张/引文；全部机器检查一致。 |
| `business-12` | `insufficient_evidence / hold_for_review` | 历史覆盖主张仍未验证，没有变成不允许披露的证明。确切 164.502 已覆盖；操作与作者的人工审查建议不同。 |

本次单次运行中，08/12 案例的主张/条件边界有所改善，但这无法弥补六项运行失败或引文覆盖退步。
检查被拒绝输出还显示可能**矫枉过正**：`business-10` 现在建议证据不足，而非作者的风险标签，
理由是未验证许可不等于确认缺失许可。这可能混淆可观察到的错误交付/风险信号与“所有可能法律
依据均不存在”的确定性裁定。必须进行语义审查，明确风险范围及底层失败，而不是修改旧案例或
自动重新贴标签以迎合判定标准。完整的证据链仍可能误导：被拒绝的 `business-03` 声称例外已解决，
但文字仍请求人工审查替代依据。

记录的总 token 降低 **32.35%**，提示词 token 降低 **40.10%**。完成 token 上升 **9.11%**；
推理 token 从 **33,759 升至 40,869**，已计入完成 token。缓存 token 为 **116,352**，
已计入提示词。超时/提前失败会降低记录用量，因此较低总数不代表在质量等价情况下提升效率，
也不是对投影节省的独立测量。特别是超时请求，SDK 计数不是权威提供方账单。未声称货币成本。
本次运行总体耗时更长。

证据保存在 Git 忽略日志
`contest/data/evaluations/business-context-v3-quality-20261016-business.json`。
Runs 页面已对照实际报告检查：三份业务报告、6 个已接受契约、1/12 机器一致性、
分别显示的矛盾主张/未知条件以及本地操作策略诊断。全部 6 个已接受输出均符合建议策略；
失败案例不算作策略通过。此前两份业务报告和两份机制报告均与原日志一致；工厂 Agent/作业、
一次手动调查、自动预算为零及修订 8 禁用空 Gate 均未变化。

测试中未进行运行时修复、提供方重试、发布、绑定或业务操作。记录的 46 次交互并未授权花费
请求上限剩余部分。下一步工程工作应优先在现有限制内确保事实/发现/必需条款的可靠顺序，
并简化条件契约，同时保留完整规范来源链。审查风险信号与确定性违规的语义，并准备独立、
经人工审查的案例。不得仅依据两个已纠正标签或 token 总数提升 v3 或声称质量改进。

<a id="v4-single-use-evidence-plan-free-implementation-not-model-evaluated"></a>

#### V4 单次证据计划（免费实现，未进行模型评估）

下一种选择加入运行时 `hipaa-business-runtime-v4` 旨在解决观察到的顺序失败，不增加模型迭代、
重试或检索次数。它刻意**保留 v3 六字段输出和条件/主张验证器**：同时更改 schema 会让人无法
判断顺序调整是否有效。提示词更短，工具接口更简单；缩减判断 schema 仍是可能的后续改动，
并非已完成的功能。提示词 SHA-256：
`1b09999ba18f9eab956aae569808a125ee35c1a5483c03165c378f32dd1870ac`。

- 服务器通过现有事实访问助手读取已绑定事实，并记录 `origin:server_prefill`。它会保存提供给
  Agent 的确切 `model_input:{runId,facts}`。事实不再是模型单独请求的工具轮次。不添加判定标准、
  预期章节或答案。
- SDK 暴露**一个**工具 `GatherBusinessEvidence`，只能使用一次。Agent 选择有界公共查询、
  CFR 章节/字面锚点，以及可选的第二个不同章节/锚点。执行任何检索**之前**会验证所有计划字段。
  实现会将一次语义发现和一到两次明确查找一起执行：共进行两或三次底层检索。不生成案例到章节
  规则，也不由判定标准驱动选择。
- 完成的数据包必定包含确切的查找尝试；Agent 不能省略后续工具以获得可接受的“仅发现”结果。
  没有 `bundleComplete` 时运行时会拒绝最终答案。重复提交数据包会被拒绝，不会额外检索，
  即使三次可能检索中只使用了两次。四次迭代/48 次请求的批次上限不变。预期正常流程是先计划/
  调用工具，再返回最终答案，**但不保证**真实模型一定能在两轮内完成。
- 保留完整原语跟踪，并标记 `parent_tool:GatherBusinessEvidence`。父跟踪保存声明的查询/章节/
  锚点、组合规范响应和实际紧凑 `model_response`。展平证据按返回项只提供一次；`steps` 会保留
  各组成步骤的可用性、错误、匹配和截断诊断，不重复文本。原语审计条目**不是**额外 SDK 模型
  工具调用。离线检查器会验证初始事实/运行、完整有序计划、组成/父证据相等性及确切紧凑投影。
  UI 识别 v4，并保留主张/条件/操作的独立显示。

**权衡与限制：**必须在看到发现结果之前选择章节和锚点。没有自适应跟进，即使锚点未命中亦然；
不可用或截断的查找会明确显示。完成的数据包证明尝试过检索，不证明权威相关、条款/例外覆盖完整、
已验证法律或结论正确。空锚点仍返回章节开头。两次确切查找可能在单个响应中产生更多证据，
且不会删除不同检索项之间的重复材料。服务器审计会同时存储各组成部分及其汇总。
这些选择不能证明整体模型上下文更小，也不能声称节约 token/成本。

提示词会区分**已观察到的有限范围事件/控制失败**与对全部法律许可或违规通知义务的确定性结论。
此类失败可能与披露依据未知并存；错误论证或未提供的协议仍不能单独证明条件失败。
这是澄清的指令和契约夹具，不是语义覆盖、已完成的人工审查或已证明的 `business-10` 修正。
原始基准标签及 v3 历史失败保持不变。

免费验证观察到 IRIS 和 Python 回归测试的先红后绿。覆盖单/双章节计划、缺失/错误运行事实、
格式错误/重复章节、孤立/过长锚点、单次使用限制、明确中断行为、被篡改的模型输入/计划/组成项/
投影、失败状态拒绝及不允许将旧 v3 费用同意升级。v3 提示词哈希保持不变。验证总数：
相关 IRIS 测试 **50/50**（含 6 项 v4 测试）、**62/62 项 Python 测试**及
**41/41 项前端测试**；前端类型检查、生产构建、lint 和免费 HTTP 版本/同意保护均通过。
提示词从 **4,283 缩至 3,092 个字符（减少 27.81%）**，这不是 token 节省测量。

使用开发者选择的云角色/协议检索计划，对固定索引 7 进行了一次实际 SDK 分发，不调用 `Chat`
也不创建会话：语义发现，以及确切的 160.103 和 164.504 查找。三项都返回了证据（总计 15 条），
并保留截断标记。SDK 输出、存储的模型投影及独立重建的 Python 投影完全一致；规范证据和计划来源
信息也匹配。这验证了工具连接，**不是模型选章质量**。现有 EAP 嵌套语义检索清理警告仍会出现。

三份历史业务报告及其机器检查结果、两份机制报告、工厂 Agent 哈希/作业、一次手动调查、零自动
模型预算和修订 8 的禁用空 DEMO Gate 均已确认未变。免费实现期间未生成 v4 报告/模型调用，
也没有提供方重试、发布、绑定、业务操作或 Production 重启。v4 仍为选择加入，未提升为默认。
随后获批的真实模型对比记录在下文。独立留出测试/人工审查及受策略控制的业务集成仍待完成。

<a id="authorized-v4-model-retest-tool-interface-failure-no-accepted-results"></a>

#### 已授权的 v4 模型重测：工具接口失败，无可接受结果

后续一批经用户授权的运行于 2026-10-16 执行，请求键为
`business-context-v4-quality-20261016`，使用相同的固定来源 r3、`deepseek-flash`、索引 7、
原输入/判定标准及固定 v4 提示词。报告 `business-evaluation-0EDC1222-C91D-11F1-A15C-A263F534EED8`
保留会话 **72–83**。12 个案例均已完成，但**输出接受数为 0/12，完全符合作者机器检查的案例数也为
0/12**。这是集成失败，不是模型 HIPAA 判断准确性的有意义估计。

受保护审计和实际持久化 SDK 会话历史证实：

- 10 个案例提交了 `164.506` 等裸章节编号，但实现只接受确切字符串 `45 CFR 164.506`。
  这 10 个案例在检索前全部遭拒。工具文档虽描述了 CFR 章节，却没有给出具体的可接受格式示例或
  schema 枚举；免费 SDK 测试使用手动构造的规范字符串，没覆盖真实模型的表示方式。
  这是脆弱的接口/测试缺口，不是 10 个模型都无法理解相关章节的证据。
- 模拟中断控制 `business-11` 提供了空章节字段，也在参数边界遭拒，因此本批次未实际测试中断
  检索控制。
- `business-03`、`04`、`06` 还会为同一章节选择两个锚点。实现要求章节不同，因此仅规范化前缀
  无法解决这些计划。此限制会不必要地阻碍审查同一章节的多个部分，应明确重新审视；不能悄悄去重
  或视作法律无关。
- 只有 `business-10` 提供了规范前缀章节并完成了组合工具调用。其最终 JSON 声明一个适用的
  `not_met` 披露条件，却选择总体 `insufficient_evidence`。未变更的条件聚合验证器正确拒绝
  这一矛盾。其文字也可能将未记录的许可视为缺失许可的证明；仅更改总体标签仍不能证明语义正确。

全部 12 个会话都记录了一次工具尝试和两次模型交互。11 次失败工具调用在业务报告中没有规范检索
响应；SDK 历史保留了提交参数及返回的工具错误。它们的最终输出通常报告检索失败和证据缺失，
而非伪造引文。业务运行时将其判为工具执行不完整，不会接受为证据不足发现。离线评分器通用的
缺少 proposal/六字段错误，不能证明保留的原始 JSON 格式错误。失败案例不得升级为成功，
也不会改写原始报告。

| 已记录指标 | V2 | V3 | V4 |
|---|---:|---:|---:|
| 接受的契约 | 12/12 | 6/12 | 0/12 |
| 完全符合作者机器检查 | 8/12 | 1/12 | 0/12 |
| SDK 模型交互 | 45 | 46 | 24 |
| SDK 工具尝试 | 45 | 48 | 12 |
| 提示词 token | 289,289 | 173,288 | 51,731 |
| 完成 token | 54,060 | 58,983 | 28,702 |
| 总 token | 343,349 | 232,271 | 80,433 |
| 耗时 | 341.2 秒 | 413.1 秒 | 186.8 秒 |

V4 推理 token **20,516** 已计入完成量，缓存 token **39,296** 已计入提示词。上下文/用量明显
变少主要是因为 11 个案例没有发生检索。**不声称效率或质量提升**，也不推断货币成本。
记录的 24 次交互并未授权花费 48 次请求额度中尚未使用部分。未进行重试、替代运行或基于模型的调查。

确切报告和失败输出保存在 Git 忽略日志
`contest/data/evaluations/business-context-v4-quality-20261016-business.json`；
SDK 历史提供了此前检查的参数/错误补充证据。全部四份业务报告均与其日志一致。两份机制报告、
工厂 Agent 哈希/三个作业、一次手动调查、零自动模型预算及修订 8 的禁用空 Gate 均未改变。
此验证期间未执行运行时补丁、发布、绑定、业务操作或 Production 重启。

下一步应先**免费复现实际 SDK 参数**，再实施明确版本化的接口修复：有界、确定性地处理规范和裸章节
表示；支持同一章节内不同锚点；明确定义无证据控制计划；并直接测试实际失败参数形式。
应分别审计请求参数和规范化参数。不要扩大到任意查询执行、悄悄臆造章节、修复模型答案，或为测试
解析器而消耗新的推理预算。v4 未提升为默认，模型质量仍未确立。

<a id="reviewed-deterministic-rules-p6"></a>

## 已审核的确定性规则（P6）

Rules 是真实的本地控制平面，**不是 AI 生成规则功能**。选择此前在 Events 中保存的不可变意见，
创建手动 `manual_template_not_ai` 草稿。AST 仅允许：

- 固定的 `local-demo/DEMO/Demo.Production/before_send` 目标和 `gate-v1`。
- 最多 3,000 UTF-8 字节、5 条规则、每条 5 个 AND 条件，以及每个 `in` 条件最多 5 个值。
  Bundle 内 ID 唯一。
- 字段 `purpose`、`purpose_known`、`direct_identifiers`、
  `deidentification_verified`、`authorization_known`、`scenario`、`stage`。
- 类型化的 `eq`、`in` 和 `exists`；唯一匹配操作为 `hold_for_review`。
  不能通过此契约执行 SQL、正则、ObjectScript、URL、凭据、采样更改或模型触发器。

默认模板会拦截带直接标识符的分析用途。缺失或类型错误的条件事实视为未知，而不是正常；
false AND unknown 的结果为 false。启用时，未知用途/条件会被拦截。禁用的空 bundle 会明确恢复
初始非强制行为。此窄范围规则不是完整 HIPAA 策略或合规决定。

工作流：

1. **Test exact bundle** 会运行 5 个服务器自有固定黄金案例：风险、正常、治疗、证据缺失和用途未知。
   失败草稿不能制定计划；应创建修正草稿，而不是改写历史。
2. **Create target plan** 会固定规范 bundle 哈希、已保存意见哈希、实际源配置哈希及源策略基线修订。
3. 明确确认并在 15 分钟内**批准确切摘要**；应用时会重新检查审批有效性及目标基线。
   意见或测试结果本身都不是授权。
4. **Activate** 使用固定的已认证 prepare/activate/status Connector 端点。Prepare 不会执行。
   源端在锁下验证 AST/哈希和配置/修订；同一身份不可变且幂等。激活会原子提交一个完整活动策略
   JSON 记录，并保留部署历史和成功前的最后已知良好状态。
5. 已加载**不等于效果已验证**。两个新建、键值唯一的合成探测必须生成真实 schema-2 回执，
   其 Gate 哈希/修订完全匹配且结果符合预期。刷新 Rules 以协调回执。重复同一部署会重用原始提交，
   永不重放旧业务数据。
6. **Plan rollback** 为以前的 bundle 创建一个新测试计划，需要新审批和源修订。它不会删除活动指针
   或释放被拦截消息。

Router 会在调用本地 Sink 前评估。被拦截消息在本地持久化，并返回 `held_for_review`，不调用 Sink，
之后沿常规观察路径处理。启用时，未知用途的 `failure` 情景会被拦截，而不是发送到 Failure Sink。
如果先前必需的活动策略消失或无效，Gate 会记录受保护审计错误并采取 fail-closed。没有任意修复
或外部副作用。

激活结果不确定时标记为 `unknown`，绝不报告成功。应协调同一部署；不会悄悄覆盖不同活动版本。
已过期审批不能新激活未经确认的版本。不会自动回滚/重试业务处理。现有固定 Connector manager
角色授权这些 DEMO 变更；这**不是**独立的规则租户隔离或生产级审批分离。

<a id="staged-risk-review-free-evaluation-only-prototype"></a>

## 分阶段风险审核：仅免费评估的原型

下文最初的原型说明记录第一版免费实现。后续
[完整章节改进和固定冒烟集](#complete-section-refinement-and-frozen-smoke-set-free-only)
已取代其中裁切式检索模板和定位符输入形式。之后的
[已授权分阶段冒烟运行](#authorized-staged-smoke-run-five-completed-one-contract-rejection)
记录首个真实模型评估；最初的裁切式实现从未用模型评估。

审阅 v1-v4 失败后，`Contest.RiskReview` 引入了**独立的两阶段评估器**，不再是对那些运行时的又一次
提升。最初仅编译并免费测试，没有调用模型；单独授权的 6 案例结果记录在下文，且**不是质量验收**。
V2 仍是已观察到的最佳业务基准。历史输入、判定标准、提示词、报告、Agent 绑定或 Gate 规则均不替换。

此切片刻意**没有 HTTP 端点、Runs 面板、自动触发器或 BP/BO 执行集成**。它是供未来小规模、
单独同意实验使用的授权开发者终端入口。现有业务评估 API/CLI 仍表示原始 v1-v4 基准。

<a id="contract-and-flow"></a>

### 契约与流程

1. 调用方提供**仅合成**的最小化数据包。事实区分
   `kind: observation | claim | local_policy | missing_information`、明确 `origin` 及
   `verification: verified | unverified | unknown`。观察项必须已验证，主张必须未经验证，缺失信息必须未知。
   标签由调用方提供来源标记，不是独立验证：设置 `synthetic: true` 不会使真实 PHI 脱敏。
   不会自动将任何应用消息转换成已验证事实或发送给提供方。
2. 无工具 `%AI.Agent` 仅运行**一次迭代**，定位 `recipient_purpose`、`deidentification`
   或 `unclassified` 问题。它提供问题文本和事实引用，**不是 CFR 编号、风险状态或操作**。
   即使模型未返回问题，服务器提供的 `required_questions` 仍予保留；匹配主题将合并到服务器要求中，
   不会丢弃必需问题。
   这保留必需的**范围**，而不是检测发现的处置。Production 检测器集成仍待完成。
3. IRIS 按主题选择版本化的**工程草稿**证据模板，绝不按案例 ID 或预期答案选择。
   recipient/purpose 当前查找 164.502 和 164.506；de-identification 使用字面锚点
   `A covered entity may determine` 查找 164.514。unclassified 问题没有模板，必须保持未解决。
   复用现有有界参数化精确查找和规范 passage 助手；没有新的模型选择工具接口、语义嵌入调用或回退
   语料库。受支持主题集最多需要三次精确查找。
4. 第二个独立、无工具 `%AI.Agent` 会取得事实、保留问题及其证据包。它按每个问题返回一条 issue，
   且只含 `question_id`、`status`、`fact_ids`、`citations`、`explanation`，以及顶层
   `missing_information` 列表。状态为 `risk_signal`、`no_signal_on_checked_issue` 或
   `unresolved`。引用必须属于该问题。risk/no-signal 要求证据可用、存在引文且至少有一个已引用的
   已验证事实；不支持/不可用问题必须标为 unresolved。这些是契约保护，**不是事实蕴含证明**。
5. IRIS 会将选中的 passage 句柄物化为逐字引文及返回摘录中的 UTF-16 坐标（结束位置不包含）。
   它会分别推导 `risk_detected` 和 `unresolved` 布尔值；两者可以同时为真。模型提供的总体/
   操作字段会被拒绝，而不是修复。缺失信息也会设置 unresolved。技术失败会产生
   `state: failed`，**不提供替代语义结果**，并进行受保护审计。

每个数据包都明确标记 **`coverage: unreviewed_partial`**。它会保留每次查找的可用性、错误、
截断、锚点匹配和片段计数，以及明确的完整章节、交叉引用和法律适用性缺口。
证据文本仅在紧凑 passage 投影中发送一次。不会声称这些模板覆盖所有条件/例外或经过法律审查；
也尚未实现语义发现补充或经过审查的完整证据包。带日期法规快照未独立验证为当前法律；
准备好的来源文本、LLM 简报和合成策略各自保留不同来源属性。

本地 `staged-demo-conservative-v1` 建议对风险/未解决问题在发送前执行 `hold_for_review`，
否则建议 `manual_review`。由于覆盖有限，它**绝不建议自动继续**，包括模型未发现风险时。
发送后/配置类审查不能建议追溯拦截。不会执行任何建议。

<a id="execution-safeguards-and-observability"></a>

### 执行保护与可观测性

`Run(packet, authorization)` 需要现有 `ContestMonitorDeploy` 能力。授权恰含 8 个字段：
`request_key`、`agent_id`、`source_revision`、`config_hash`、`input_hash`、
`contract_hash`、`acknowledge_cost: true`、`max_model_requests: 2`。
输入哈希为 `Demo.Protocol.Hash(packet.%ToJSON())`；契约哈希为
`Contest.RiskReview.ContractHash()`，包含两个提示词和来源模板。来源身份/修订/配置必须匹配
符合条件的现有 Agent；其模型/索引/语料库配置会快照，并在每个阶段前重新检查。
此选择加入评估器使用自有分阶段提示词，不使用来源 Agent 的旧工具循环。

同步工作器会在 `Chat` 前持久预留每次尝试，使用独立 SDK 会话，每个输入最多执行
**两次应用级 Chat 尝试**。输入超过 80,000 字符或原始输出超过 18,000 字符时拒绝，不会静默截断。
不修复 JSON、不重试失败阶段、不增加工具循环，也不重用旧评估预算。A 阶段失败会阻止 B 阶段。
不可变请求键会返回此前报告而不再次调用；身份冲突会被拒绝。重新打开被放弃的运行请求时会标记
为 interrupted，不会重放。

报告独立存储在 `^ContestRiskReview` 下，可通过受读保护的终端方法 `Status(id)` 获取。
报告保留来源快照、数据包、授权、实际阶段提示词/输入、SDK 会话 ID、原始响应、各阶段用量/统计、
问题计划、规范证据包、物化结果和受保护失败审计。不同阶段的提供方用量和 SDK 统计分别保留，
**不会将其相加作为 token 总量**。今后对比时，不得重复计入缓存/推理小计。
`Contest.RiskReviewFixture` 中的阶段适配器仅用于**测试**，不会由监控配置加载，也绝不会作为模型证据。

<a id="free-verification-and-remaining-gates"></a>

### 免费验证与剩余门槛

新的 `%UnitTest.TestProduction` 套件覆盖必需问题保留、类型/大小有界事实、未知/重复引用、
拒绝模型选择法律、按问题限制引文范围、伪造/篡改来源句柄、独立风险/未知聚合、
按阶段控制建议、证据不可用、上下文隔离、精确同意固定项及不调用 Chat 的 SDK 初始化。
已有的授权终端身份还会在回滚测试事务中执行夹具流水线、A 阶段失败时的短路、持久报告和不可变重放。
只读 MCP 身份按预期应被拒绝执行；不会扩大角色或凭据。

使用固定索引 7 执行的另一项真实、**非模型**检查，针对两个受支持主题测试服务器选择模板：
164.502 返回 12 个片段中的 5 个（已截断），164.506 返回两个片段，164.514 锚点匹配 11 个片段中的
1 个（部分/截断）。两个证据包均可用，但这**绝不是完整法律覆盖**。紧凑包投影为 25,866 个字符；
随后清除上下文。这些是可用性/大小机制观察，不是 HIPAA 质量、成本或效率结果。

第二次真实来源检查将全部 8 个返回项和 **80 个 passages** 与模型投影比较，要求三个检索诊断均不
重复证据文本，并将两条选定真实来源引文物化为规范坐标。全部匹配。使用的是刻意未解决的**夹具**
判断，而非模型答案；完整合成判断输入为 26,814 个字符。此检查未创建分阶段报告或模型会话。

新的 IRIS 套件通过了 **12/12** 框架方法测试，分别通过只读 MCP（包括预期的执行拒绝）和现有
授权终端身份（包括夹具流水线）。相关 v2/v3 套件通过 **17/17**，现有离线 Python 套件通过
**62/62**。四份业务报告和两份机制报告仍与原始日志一致；两个 Agent 配置/三个作业、零自动模型
预算以及已加载修订 8 的禁用空 Gate 均未改变。没有更改前端代码，也不声称原型可由前端使用。

在任何质量声明前：审阅证据模板，并单独授权固定小型合成冒烟集确切的每案例两次请求预算；
在扩大运行前隔离问题定位和判断失败。旧 12 案例是开发回归测试，不是留出集。
独立人工审查的留出案例、法律适用性审查、真实模型质量/成本测量、UI/API 连线及受策略控制的
业务集成仍未完成。自动模型预算仍为零。

<a id="complete-section-refinement-and-frozen-smoke-set-free-only"></a>

### 完整章节改进和固定冒烟集（仅免费）

裁切式 164.514 检索仅返回 11 个片段中的一个，可能遗漏后续 Safe Harbor 条件和上下文。
草稿模板现在使用 `development-complete-sections-v2`：`Contest.RiskEvidence` 会读取所选章节的
**全部索引片段**，验证确切规范来源链、重建重叠，并要求完整的已准备来源具有完整的
**UTF-8 SHA-256** 后才返回证据。章节选择仍由服务器负责，且不依赖案例 ID/作者预期：
recipient/purpose 选择 164.502 和 164.506；de-identification 选择 164.514；
不支持的范围不提供规范来源。

固定索引在剥除两侧空白前就分配了片段偏移。真实来源检查发现一些片段的前导空白导致偏移错位。
重建只允许跳过**已在经验证重叠前缀中出现**的空白，会记录原始和解析后片段坐标，并仍要求最终
完整来源哈希。它绝不填补间隙、越过非空白文本、改写来源文本或猜测缺失法律。来源/版本混杂、
重叠冲突、间隙、重复偏移和哈希失败均记为**技术错误**，而非普通未解决发现。没有匹配规范行时
会明确标记不可用。若数据包缺少任一所选章节，即使另一个章节存在，也不能支持风险/无信号结论。

每个章节最多 32 个片段/32,000 个字符；所有主题模板合计最多需要读取 3 个章节。
当前 Python 偏移索引仅支持 BMP 文本；明确拒绝非 BMP 来源坐标，不会静默误解。
不重写任何索引、元数据或历史运行时。实际三个所选章节与已发布文本完全匹配：

| 所选章节 | 索引片段 | 完整来源字符数 | 来源哈希 |
|---|---:|---:|---|
| 164.502 | 12 | 21,006 | 已验证 |
| 164.506 | 2 | 2,516 | 已验证 |
| 164.514 | 11 | 18,246 | 已验证 |

这些是**所选完整快照文本**，不是完整法律证据包。交叉引用定义、其他披露依据、当前法律有效性和
法律适用性仍未审查。每个包仍标记 `coverage: unreviewed_partial` 并显式列出缺口；
`selected_sections_complete` 是额外但范围更窄的来源完整性事实。模型投影会将完整章节文本作为
passages 仅保留一次，并保留逐章节完整性/哈希标记。仍绝不建议自动继续。

为了避免评估捷径，模型 A 现在只收到**合成标记/阶段/事实**，不会收到必需问题或其主题标签。
服务器仍会在 A 返回后合并必需问题。应在合并前评估 A 的**原始提案**：不能让必需问题成功保留
掩盖定位符遗漏。这会更改分阶段契约固定值；较早固定值下没有真实分阶段模型结果。

固定开发集独立于旧 12 案例基准：

| 案例 | 预期诊断对比 |
|---|---|
| smoke-01 | 观察到错误接收方，且另有一个未解决许可；风险和未知可以并存，不追溯拦截。 |
| smoke-02 | 已验证的治疗接收方/用途；仅保留标识符本身不产生分析去标识要求。 |
| smoke-03 | 明确的 Safe Harbor 发布路径，仍有 MRN/完整日期，且肯定事实表明无专家认定；区分路径/本地先决条件风险与法律裁定。 |
| smoke-04 | 已确立且有记录的专家路径，但存在无依据的加密论证；不得以 Safe Harbor 或操作员的论证替代实际依据。 |
| smoke-05 | 去标识主张未经验证且输出字段未知；未知不等于肯定失败，也不证明不存在决定。 |
| smoke-06 | 安全/事件范围无依据；请求人工调查，不臆造披露或通知结论。 |

文件：

- [不含答案的合成数据包](./fixtures/staged-risk-smoke-v1.json)。
- [单独的作者预期和人工语义检查清单](./fixtures/staged-risk-expectations-v1.json)。
- [固定指纹、来源/配置/契约固定值和明确的未授权标记](./fixtures/staged-risk-freeze-v1.json)。

模型看不到案例 ID、预期标签/操作、人工清单或冻结元数据。预期判断是**作者草稿**，
不是独立专家标注或留出基准。尤其是，无依据的加密论证不是新的法律权威；
验证合成专家认定事实也不能独立评估真实专家报告。

免费命令：

```sh
python3 contest/staged_risk_smoke.py
python3 contest/staged_risk_smoke.py --prepare
python3 -m unittest discover -s contest -p 'test_*.py'
```

默认命令仅验证固定夹具和本地已发布来源哈希。`--prepare` 通过现有开发者终端读取固定的本地
IRIS 索引，验证数据包及确切来源/文本，检查所有规范 passages 和紧凑投影，并保存 Git 忽略的
不可变准备数据包。重复执行时会验证相等性，不会覆盖已更改输入。它**不会调用 Agent、提供方、
嵌入、`Chat`、业务端点、Production 控制器或新的配置流程**。准备的判断输入使用服务器固定必需问题，
支持后续隔离 B 阶段分析；它们**不是**模型 A 输出或端到端结果。若以后获准模型评估，
A 增加主题/事实引用时，实际端到端 B 输入可能不同，必须另行保存。

六个准备好的判断输入分别为 **36,248、36,427、29,587、29,488、29,149、1,517 个字符**，
均低于 80,000 字符上限。更完整来源文本大于最初裁切输入；不声称 token/成本效率有所提升。

修订后的风险审核套件通过 **13/13** 项 IRIS 框架方法测试，新来源组装套件通过 **4/4**，
Python 回归通过 **70/70**。测试包括原始定位符分离、部分来源拒绝、完整哈希、索引空白偏移、
来源篡改和不支持的非 BMP 坐标。授权终端夹具测试仍会覆盖流水线完成/失败及不可变重放，
且不会创建实际模型会话。定位后来源完整性失败也会在判断前停止，不提供替代语义结果。
现有 v2/v3 套件仍为 **17/17**。测试事务结束后，6 份历史报告再次与其日志一致，
两个 Agent 配置/三个作业未变，自动模型预算仍为零，Gate 修订 8 仍为禁用空 bundle。

以后获准的冒烟运行应将报告执行/契约完成、原始定位符主题/事实覆盖、判断状态/事实/引文检查及
独立语义审查作为**不同指标**。任何单一精确匹配率都不是 HIPAA 准确性。拟议上限为
**6 个案例 × 每案例 2 次应用级 Chat 尝试 = 12 次**，不修复/重试；冻结不等于同意，
也不能花费旧请求剩余预算。在此次免费准备检查点，模型执行仍待完成。随后授权和结果见下文；
法律/语义独立审查和业务集成仍属待完成事项。

<a id="authorized-staged-smoke-run-five-completed-one-contract-rejection"></a>

### 已授权分阶段冒烟运行：五项完成，一项契约拒绝

用户随后明确授权恰好运行这 6 个冻结案例，最多 12 次应用级 Chat 尝试，不重试、不修复、
不执行业务操作。运行键 `staged-risk-smoke-quality-20261016` 使用未更改的来源 Agent 修订 3、
`deepseek-flash`、索引 7 和冻结的分阶段契约哈希
`a3fada0771296b7fd57f0bc6725cd7a03ca2bab7be0ab414569f73e61b85b60d`。
冻结输入/预期文件和所有历史运行时均未改变。

实际运行预留并执行了**11 次 Chat 尝试**，使用 11 个独立 AI Hub 会话 **84-94**，
每个会话一次交互、零工具调用。案例 05 在第一阶段后遭拒，未进入判断阶段。
未使用其剩余额度重试或添加其他实验。

| 指标 | 观察结果 |
|---|---:|
| 已完成且运行时接受 | 5/6 |
| 有效原始定位器输出包含预期主题 | 5/6 |
| 原始定位器引用覆盖作者必需事实 ID | 4/6 |
| 已接受主问题状态匹配作者草稿 | 已完成 5/5（总计 5/6） |
| 已接受主问题事实引用覆盖 | 已完成 5/5 |
| 总体 unresolved 标志匹配作者草稿 | 已完成 2/5 |
| 建议匹配作者草稿 | 已完成 3/5 |
| 每案例上述四项判断检查均一致 | 总计 2/6 |
| 独立重建的物化来源引文 | 15/15 |

这些是彼此独立的工程/作者检查，**不是法律准确性**，不是盲测留出结果，也不是独立语义审查。
主问题状态指标不包括被拒绝的案例 05，也不代表整个案例判断正确。必需主题合并与原始模型定位
分别呈现；服务器保留范围不能挽救定位分数。

| 案例 | 实际主问题 | 整体案例结果与限制 |
|---|---|---|
| 01 | `risk_signal` | 风险与未解决并存，发送后人工审查；四项判断检查均一致。A 添加了未分类许可文件记录问题。 |
| 02 | `no_signal_on_checked_issue` | 治疗依据的主要判断正确，但 A 添加了去标识化及推测性的未分类问题。后者导致 unresolved 和发送前拦截，而非预期人工审查。 |
| 03 | `risk_signal` | Safe Harbor/本地路径信号正确，但新增接收方/用途和未分类问题造成额外未知项。拦截建议一致，但 unresolved 标志不一致。 |
| 04 | `no_signal_on_checked_issue` | 主要判断正确识别有记录的专家路径，并与操作员的加密理由分开。额外接收方/用途问题造成 unresolved 和拦截，尽管作者预期是有限无信号。 |
| 05 | 无已接受判断 | A 返回顶层 JSON **数组**，而不是 `{"questions":[...]}`。受保护审计记录 `Expected JSON object`。保留原始输出，不包装/修复，且未调用 B。 |
| 06 | `unresolved` | 不支持的事件/安全范围仍不可用，转人工审查，没有伪造引文或违规裁定；四项判断检查均一致。 |

按案例顺序排列的持久报告身份：

```text
risk-evaluation-3C11810F-C925-11F1-A15C-A263F534EED8
risk-evaluation-4E178DE3-C925-11F1-A15C-A263F534EED8
risk-evaluation-6687B101-C925-11F1-A15C-A263F534EED8
risk-evaluation-7DA1AF1E-C925-11F1-A15C-A263F534EED8
risk-evaluation-97715007-C925-11F1-A15C-A263F534EED8
risk-evaluation-B7BD48AB-C925-11F1-A15C-A263F534EED8
```

Git 忽略的本地日志为 `contest/data/evaluations/staged-risk-smoke-quality-20261016-staged.json`。
全部 6 份原始报告均经 `Status` 读取，并与持久化 IRIS 版本完全匹配。来源元数据和完整章节文本
与已发布快照一致；全部 15 条已接受引文/坐标均从规范 passages 重建。逐字来源链仍不能证明
法律蕴含成立，也不能证明每个选定片段都充分支持解释。

**观察到的失败模式：**问题定位范围过宽。5 个有效定位输出中有 4 个包含作者预期范围之外的主题；
额外主题并非自动错误，但案例 02/04 的实际问题在已提供治疗或有记录的去标识依据时，仍要求分析
额外路径或接收方角色。案例 03 新增的未分类“需要哪些人工审查”问题没有规范模板，结构上必然
导致 unresolved。然后服务器按当前保守策略正确汇总这些未解决状态，相较作者草稿产生不必要的不确定
或拦截。仅增加来源文本未能避免这一工作流问题。

已完成案例的主要判断在刻意选择的对比上令人鼓舞，但**B 阶段没有针对固定准备问题输入单独运行**。
不能据此建立隔离 B 的准确性或优于 V2 的结论；不同的小样本也不能直接与旧 12 案例比较。
下一步免费工作应限制*相关*问题选择，并区分真正不支持的事件与推测性通用清单，同时保留必需范围
和未知项，而不是悄悄删除。

**Harness 事件：**案例 05 已持久记录后，离线评分器假定每个已解析定位响应都是对象，遇到保留的
数组时抛出异常，导致本地循环在案例 06 前停止。评分器已修复为将无效结构记录为失败，不做强制转换。
只读运行时检查确认案例 06 没有请求记录；随后明确使用 `--continue-unattempted` 仅运行第六个案例。
未再次调用案例 01-05，其报告/原始内容保持完全一致，运行时提示词、解析器、冻结事实和预期标签也未更改。

新的[执行 Harness](./staged_risk_evaluation_test.py) 默认只运行免费检查。付费模式需要
`--run` 和明确的不可变请求键。已有日志不会自动重跑；继续执行需要确切的中断授权以及此前全部尝试
的已保存终态报告，并跳过所有已记录案例。尝试状态不确定时必须只读恢复，不得重放。
这只是开发者终端评估，不是 HTTP/UI 功能。

| 用量 | 记录总数 |
|---|---:|
| 提示词 token | 60,644 |
| 完成 token | 29,144 |
| 提供方 token 总计 | 89,788 |
| 推理 token，**已计入**完成量 | 26,246 |
| 缓存提示词 token，**已计入**提示词 | 896 |
| SDK LLM 时长 | 179.807 秒 |

本地日志耗时约 225.3 秒，包括评分器中断/恢复间隔，不仅是提供方延迟。没有经验证的货币价格计算，
也不声称质量相等时效率提高。

运行后离线回归通过 **75/75**。全部 4 份历史业务报告和 2 份机制报告都与运行前快照一致，
Agent 配置/作业/绑定、已存审核和 DEMO Gate 也保持不变。自动模型预算仍为零；Gate 修订 8
仍已加载、禁用且为空。没有发布、绑定、Production 重启/重新配置、释放、业务交付、拦截执行或重放。
**分阶段原型未提升为默认；独立语义/法律审查仍待完成。**

<a id="locator-only-v2-experiment-free-validation-no-model-result"></a>

### 仅定位器 v2 实验：免费验证，没有模型结果

本小节记录**最初的免费实现检查点**。之后获授权的 v2 结果记录在
[下文](#authorized-staged-v2-run-six-completed-five-whole-case-matches)。配置文件最初的
“无结果”限制是创建时的快照，不表示后来单独获准的运行没有发生。

独立的[分阶段 v2 运行时](./src/RiskReviewV2.cls)**仅**更改定位器系统提示词。它原样继承判断提示词、
严格的问题/判断 schema、必需主题合并、完整章节证据组装、引文物化、保守聚合和最多两次 Chat
调用。报告版本和契约哈希用于区分实验；v1 同意不能授权 v2，反之亦然。它不是 Agent 工厂发布、
正式发布、业务绑定，也不替代默认 v1 运行时。

新的定位器指令要求针对提供的运维/发布路径返回少量、基于事实的问题，而非通用清单：

- 0-3 个问题是上限，不是要求覆盖所有主题的配额。
- 治疗消息含标识符本身不等于宣称采取去标识化路径。
- 已提供且经验证的专家认定及错误操作员理由属于去标识化问题；不能自动据此额外提出 PHI
  接收方角色、BAA 或 DUA 问题。相反的识别证据、接收方不匹配和真实适用性缺口仍相关。
- 相关许可不确定性应保留在接收方/用途主题中，不要变成重复的未分类人工审查问题。
- `unclassified` 仍可用于真实的不支持事件，而不是通用的“还有什么必须审查”项目。
- 空和非空 JSON **对象**结构均明确。格式错误的数组仍会拒绝，不修复。

这是提示词指导，**不是语义保证或服务器端删除过滤器**。必需问题会保留。若模型仍添加推测性问题，
它们仍可见，也可能造成 unresolved/拦截。不会向定位器输入作者预期、案例 ID 或必需主题标签。

[v2 配置](./fixtures/staged-risk-profile-v2.json)将契约绑定到未变化的 v1 冻结文件、6 个数据包、
单独的作者预期和来源语料库。默认 CLI 仍为 v1。以下命令免费：

```sh
python3 contest/staged_risk_smoke.py --prepare --runtime-version staged-risk-v2
python3 contest/staged_risk_evaluation_test.py --runtime-version staged-risk-v2
```

准备工作会写入单独的 Git 忽略文件
`contest/data/evaluations/staged-risk-smoke-v1-runtime-v2-prepared.json`，而非旧准备包。
已逐项精确比较 6 个固定问题定位器输入、问题、证据包、判断输入和输入哈希与 v1 的结果：
均未变化。实际后续 B 输入可能因 A 选择不同问题而不同；不声称隔离 B 有所提升。

免费验证通过 **77/77 项 Python 测试**、**5/5 项 v2 IRIS 测试**（含无操作 TestProduction
控制器）以及 **13/13 项 v1 IRIS 测试**。新套件在实现前先失败。测试检查实际初始化 SDK 提示词、
一次迭代限制和空工具目录，但不调用 `Chat`。将 6 个**已记录** v1 定位计划分别通过 v1/v2 回放，
5 个有效计划的合并问题完全相同，仍包括不需要的额外问题；第六个仍抛出 `Expected JSON object`。
这证明服务器不会悄悄制造改进。历史评分保持完整。

**v2 未调用模型。其相关性质量、结构可靠性和成本均未测量。**新的真实模型运行需要重新明确授权和
新的不可变请求键，并在 `--run` 之外使用 `--runtime-version staged-risk-v2`。
不重用上一轮未用完额度。这 6 个案例是用于细化提示词的开发回归测试，并非留出证据。
在任何质量声明或业务部署前，仍需独立语义审查和独立准备的留出评估。

<a id="authorized-staged-v2-run-six-completed-five-whole-case-matches"></a>

### 已授权分阶段 v2 运行：六项完成，五项整体案例匹配

重新取得用户授权后，运行 `staged-risk-v2-quality-20261016-1511` 使用了冻结的 6 个合成开发数据包、
未变更的作者预期、来源 Agent 修订 3、`deepseek-flash` 和知识索引 7。
契约 `a305653fb3f84ea02e4ab7dc8b948afb82ccf72e8f75b51a7d4a427d44f7ab10`
选择独立的仅定位器 v2 运行时。全部 12 次应用 Chat 尝试均在独立真实 SDK 会话 95-106 中完成，
每个会话一次交互、零工具调用、零重试/输出修复/业务执行。

| 检查项 | 分阶段 v1 | 分阶段 v2 |
|---|---:|---:|
| 已完成并接受 | 5/6 | 6/6 |
| 有效原始定位器对象结构 | 5/6 | 6/6 |
| 原始定位器包含作者预期主题 | 5/6 | 5/6 |
| 原始定位器覆盖预期事实引用 | 4/6 | 5/6 |
| 原始定位器另加主题 | 4/5 个有效计划 | 0/6 |
| 主问题状态匹配作者草稿 | 已完成 5/5 | 6/6 |
| 主问题必需事实已覆盖 | 已完成 5/5 | 6/6 |
| 整体 unresolved 标志匹配作者草稿 | 已完成 2/5 | 5/6 |
| 建议匹配作者草稿 | 已完成 3/5 | 6/6 |
| 四项判断检查均一致 | 总计 2/6 | 总计 5/6 |
| 已验证来源物化引文 | 15 | 18 |

未变化的预期主题指标需要解释：v2 案例 02 返回 `{"questions":[]}`，这是允许的，表示没有识别出
额外的、基于事实的问题。独立的必需接收方/用途问题仍被保留，且判断正确。原始预期主题分数仍为
**5/6**，没有追溯改为 6/6，也没有用必需主题合并来挽救。空提案本身不代表语义风险遗漏。
必需覆盖与发现新问题是不同能力。

| 案例 | V2 结果和观察到的限制 |
|---|---|
| 01 | 一个接收方/用途问题包含不匹配、主张和未知许可。范围内风险与真实许可不确定性并存；发送后人工审查。没有重复的未分类问题。一些缺失信息请求仍过于宽泛，例如未确立适用性/未考虑例外就要求进行最小必要评估。 |
| 02 | 模型没有增加问题。必需的治疗问题返回范围内无信号、无 unresolved 标记，并建议人工审查，而不是不必要的发送前拦截。无去标识化要求。 |
| 03 | 一个去标识化问题指出：唯一获准 Safe Harbor 路径仍保留 MRN/完整入院日期，且有明确无专家事实。范围内风险和拦截正确。B 另询问其他法律依据、其他字段、当前法律验证和其他法律/合同；这些通用请求使其 unresolved，尽管已检查路径失败已确立。这是剩余的四项检查不一致。 |
| 04 | 一个去标识化问题；不会用 Safe Harbor 替代有记录的专家路径，也不会让操作员无依据的加密理由覆盖它。范围内无信号、无 unresolved，建议人工审查。 |
| 05 | 对象结构和去标识化问题正确。输出字段未知和未经验证的主张产生 unresolved，不会臆造路径失败或已完成披露。 |
| 06 | 实际不支持的安全事件仍作为未分类/unresolved 可见，没有伪造来源或违规（泄露）通知决定。 |

18 条引文/坐标与已发布规范文本精确匹配。选定的案例 03 片段包括一般去标识要求、删除标识符要求、
入院日期条目和 MRN 条目；案例 04 包括专家资质、风险和记录条款。此来源验证及暂时性作者检查
**不是独立法律蕴含/适用性审查**。完整快照不代表每个选定片段完整，也不表示证据模板穷尽法律依据。

按案例顺序排列的持久报告 ID：

```text
risk-evaluation-EC88BB28-C930-11F1-A15C-A263F534EED8
risk-evaluation-FAEAE5B2-C930-11F1-A15C-A263F534EED8
risk-evaluation-0B4945F7-C931-11F1-A15C-A263F534EED8
risk-evaluation-17ABCDEE-C931-11F1-A15C-A263F534EED8
risk-evaluation-2B224E6C-C931-11F1-A15C-A263F534EED8
risk-evaluation-39ACCCED-C931-11F1-A15C-A263F534EED8
```

Git 忽略日志为 `contest/data/evaluations/staged-risk-v2-quality-20261016-1511-staged.json`。
全部 6 份报告均与持久 IRIS `Status` 读取结果完全一致；此前 6 份分阶段报告也仍然一致。
4 份历史业务报告、2 份机制报告、来源 Agent/作业/绑定、已保存审核、零自动模型预算及禁用/空的
Gate 修订 8 均未改变。

用量：**46,019 个提示词 + 22,392 个完成 = 68,411 个提供方 token**。推理 token（20,344）
已计入完成量；缓存提示词 token（4,352）已计入提示词。记录的 SDK LLM 时长总计 144.337 秒；
本地日志墙钟约为 141.337 秒。这是不同的测量方式，不能互换。尽管 Chat 尝试从 11 次增加到 12 次，
记录 token 比 v1 的 89,788 低 23.81%。此单次已知案例对比不能证明可重复效率、稳健性、留出表现或法律准确性。

<a id="judge-only-staged-v3-refinement-free-validation-only"></a>

### 仅裁判器 v3 改进：仅免费验证

本小节记录最初免费实现检查点。后续模型结果见
[获授权的 v3 运行](#authorized-staged-v3-run-six-machine-matches-semantic-review-still-open)；
原配置文件保持不变。

剩余失败是 **B 阶段将实质性问题未知与通用覆盖限制混为一谈**，而不是 A 增加主题或解析器缺陷。
新的[分阶段 v3 运行时](./src/RiskReviewV3.cls)相较 v2 仅更改 B 的提示词。
A 提示词、严格输出 schema、证据、引文、必需主题合并和保守解析器都保持不变。
[独立 v3 配置](./fixtures/staged-risk-profile-v3.json)以 v2 为基础固定，不能重用 v2 模型费用同意。

裁判器被要求只有在缺失信息会实质影响已提供的检查事项或基于事实的竞争依据时才请求补充。
它必须保留真实许可不确定性、未知字段、不可用证据和不支持事件。不得仅因覆盖不完整就要求考虑
所有假设性替代工作流、其他法律/合同或一般当前法律认证。当相关来源/例外缺口阻止回答实际问题时，
仍需调查。不得认可无依据理由，也不得以其替代单独验证的事实；提出先决条件请求时须考虑适用性
和例外。

没有新增服务器端语义过滤：**任何返回的缺失信息仍会设置 unresolved**。覆盖仍有限，仍需人工审查，
无信号绝不授权自动放行，真实风险仍会触发发送前拦截。将已记录的 6 个 v2 判断通过 v3 解析器
回放，结果完全相同，包括案例 03 不需要的 unresolved 标记。只有未来模型的实际输出才能展示改进。

免费检查通过 **78/78 项 Python 测试**、**4/4 项 v3 IRIS 测试**、**5/5 项 v2 IRIS 测试**
和 **13/13 项 v1 IRIS 测试**，并有相关的 v3 红/绿周期。SDK 配置测试会初始化 Agent 而不调用
`Chat`，检查两个实际提示词、空工具目录和一次迭代上限。6 个准备好的定位器/问题/证据包/判断输入
及输入哈希在 v2/v3 间完全一致。默认 CLI 仍为 v1；免费选择性准备/检查命令为：

```sh
python3 contest/staged_risk_smoke.py --prepare --runtime-version staged-risk-v3
python3 contest/staged_risk_evaluation_test.py --runtime-version staged-risk-v3
```

**v3 未进行或授权任何模型调用。**当前授权已被 12 次 v2 尝试耗尽；后续评估需重新同意并使用新的
不可变请求键。v3 未提升为默认。在同一 6 个案例上继续调优提示词而被当作业务质量证据前，
须准备独立留出案例并执行语义/适用性审查。改进的 v2 结果仍只是开发回归结果，不是部署决定或
法律准确性声明。

<a id="authorized-staged-v3-run-six-machine-matches-semantic-review-still-open"></a>

### 已授权分阶段 v3 运行：机器检查六项匹配，语义审查仍未完成

用户重新批准运行 `staged-risk-v3-quality-20261016-1527`，使用同一冻结的 6 个合成开发数据包、
单独且未改变的作者预期、来源 Agent 修订 3、`deepseek-flash` 和索引 7。
未变化的 v3 契约为
`041bf4feb6b9667e581dd703c9368adb3bb55e223413a5e9e627ca56b4077238`。
12 次 Chat 尝试全部完成，使用实际 SDK 会话 107-118，每会话一次交互、零工具调用、没有重试/
输出修复。运行期间没有编辑提示词、事实、预期、证据或解析器。

| 检查项 | 分阶段 v2 | 分阶段 v3 |
|---|---:|---:|
| 已完成并接受 | 6/6 | 6/6 |
| 有效原始定位器对象结构 | 6/6 | 6/6 |
| 原始定位器包含预期主题/必需事实引用 | 5/6 / 5/6 | 5/6 / 5/6 |
| 原始定位器增加其他主题 | 0/6 | 0/6 |
| 主问题状态及必需事实覆盖匹配作者草稿 | 6/6 | 6/6 |
| 整体案例 unresolved 标志匹配作者草稿 | 5/6 | 6/6 |
| 建议匹配作者草稿 | 6/6 | 6/6 |
| 四项判断检查均一致 | 5/6 | 6/6 |
| 已验证物化引文 | 18 | 23 |

案例 02 再次返回允许的空定位器提案。独立必需治疗问题仍存在且判断正确；原始定位分数仍为 5/6，
没有被改写为语义成功或失败。

实际输出显示了预期区别：

- 案例 01 保留观察到的错误接收方风险，**并且**另有未解决许可；提出两个接收方/许可请求，
  不再使用之前的通用清单。没有作出确定违法或违规发现。
- 案例 03 保留 Safe Harbor/本地发布路径失败及发送前拦截，但现在返回
  `missing_information: []`。其他可能的法律许可被描述为超出检查范围，不用于对已确立的路径
  失败制造不确定性。
- 案例 05 对未知输出字段/检查及未经验证主张仍返回 unresolved；缺少文档不会被转成肯定失败
  或已完成导出。
- 案例 06 对不支持的事件/安全范围仍返回 unresolved，没有臆造引文或通知决定。
- 案例 02/04 保留范围内无信号并建议人工审查，绝不自动放行。

**机器检查六项匹配不等于完成了人工标准。**对实际解释的暂时检查发现两个重要限制：

1. 案例 04 说明操作员未经验证的加密理由不能取代单独有记录的专家路径，但**没有明确解释**
   为什么仅加密并不足够。状态/事实引用正确不代表解释满足该人工标准。
2. 案例 05 要求提供“实际输出字段和值”。此合成评估不得成为收集/发送实际患者值的指令。
   应优先使用 schema、标识符存在/删除检查及合成/脱敏元数据；未来任何证据收集界面都必须明确
   最小化数据并控制访问。此处不会执行这些文本请求。案例 01 的接收方角色/关系文字也仍需精确的
   适用性审查；不推断法律蕴含成立。

这些注意事项与不可变原始报告和未改动机器分数分开记录在 Git 忽略日志
`contest/data/evaluations/staged-risk-v3-quality-20261016-1527-staged.json`。
配置文件的 `model_execution_authorized: false` 仍是原冻结文件中未授予同意的标记；
单独的新运行授权记录了实际批准批次。没有为追溯授权而改写配置文件。

按案例顺序排列的持久报告 ID：

```text
risk-evaluation-489BE84E-C933-11F1-A15C-A263F534EED8
risk-evaluation-55A58F29-C933-11F1-A15C-A263F534EED8
risk-evaluation-5C8D99F1-C933-11F1-A15C-A263F534EED8
risk-evaluation-6CA7D59C-C933-11F1-A15C-A263F534EED8
risk-evaluation-80475CFE-C933-11F1-A15C-A263F534EED8
risk-evaluation-94FB13F4-C933-11F1-A15C-A263F534EED8
```

全部 6 份报告与持久 IRIS 读取结果完全一致，之前 12 份分阶段报告也一致。
23 条引文及坐标均通过已发布规范文本验证；这只验证来源链，不代表独立法律支持或适用性完整。
历史业务/机制报告、Agent/作业/绑定、已保存审核、自动预算为零和禁用/空的 Gate 修订 8 均未改变。
没有业务执行、发布、绑定、重启、重放或自动数据采集。

用量是 **47,787 个提示词 + 22,260 个完成 = 70,047 个提供方 token**，比 v2 多 2.39%。
推理（20,194）已计入完成量；缓存提示词（5,888）已计入提示词。SDK LLM 时长合计 147.532 秒；
日志墙钟约 146.484 秒。这些是不同的测量方式。Python 回归通过 **78/78**；
v3 IRIS 测试通过 **4/4**。

相较 v2，代码中仅更改了 B 提示词，但两次真实运行的 A 生成了不同的问题措辞。
B **没有**在完全相同的已保存输入上隔离运行；这只是针对 6 个已知调优案例的一次运行。
结果支持开发假设，但不能证明可重复性、因果隔离、留出质量或法律准确性。

**不要仅为优化这 6 个分数而继续调优，也不要提升 v3 为默认。**下一阶段验收应冻结当前运行时，
定义单独语义评分标准，涵盖解释质量、适用性、真实未知项保留及数据最小化证据请求，然后在任何新
获批模型批次前准备并独立审查未见情景变化。案例必须是真正反例，不只是这 6 个案例的改名版本。
若作者或评估器在提示词优化中见过新案例，就应标为开发案例，不能声称独立留出验证。
额外模型调用需要新批准和新请求键；当前 12 次尝试额度已用尽。

<a id="prospective-semantic-acceptance-pack-frozen-runtime-external-review-pending"></a>

### 前瞻性语义验收包：运行时已冻结，外部审查待完成

本小节记录初始免费准备检查点。随后经单独授权的
[八案例探索性运行](#authorized-prospective-challenge-run-six-label-matches-eight-safe-recommendations)
使用了相同的冻结输入/运行时。以下“不执行”说明属于该检查点，不描述后续运行。

下一步准备工作会冻结现有分阶段 v3 运行时，**不更改任何提示词、输出 schema、证据模板、解析器或
业务绑定**。单独的[挑战冻结文件](./fixtures/staged-risk-challenge-freeze-v1.json)固定 v3 契约、
继承的来源/索引/语料冻结值、新数据包/预期/评分标准指纹，以及四个分阶段审核/证据源文件的
SHA-256。这不是完整的传递依赖或部署映像锁。实际 IRIS 准备也会检查运行时契约和来源固定值。

[8 个新数据包](./fixtures/staged-risk-challenge-v1.json)和[单独的草稿预期]
(./fixtures/staged-risk-challenge-expectations-v1.json)是**助手编写的前瞻性挑战案例，
并非独立编写或独立审查的留出证据**。它们在 v3 冻结后准备，但同一助手可以看到这些案例和既有失败。
创建或免费准备本身不代表质量/泛化声明。若之后提示词修改使用这些案例，它们就成为开发回归测试；
不得重新标称为独立留出数据。外部审查仍待完成。

| 案例 | 测试的新区别 | 有范围的草稿预期 |
|---|---|---|
| 01 | 路由控制不匹配，但另有肯定验证的单独授权 | 范围内控制风险，不臆造许可未知或法律违规 |
| 02 | 匹配的治疗接收方，但心理治疗记录单独保存 | 授权/例外和交叉引用适用性未解决；不得无条件套用普通治疗许可 |
| 03 | 解密输出中有电子邮件/完整出生日期字段；仅加密理由；明确没有专家路径 | 解释加密为何不足及观察到的所选路径失败 |
| 04 | 旧专家认定不涵盖已更改的地点数据、接收方和访问条件 | 实质性适用性/验证缺口，不自动沿用，也不能证明高识别风险 |
| 05 | 验证了必需标识符删除、小区域 ZIP 前缀归零、年份/年龄处理及无实际知情 | 范围内无信号；不得把允许的转换误认为失败 |
| 06 | 原始、非零三位 ZIP 前缀，对应人口**恰好 20,000** | 应用严格的**超过 20,000**门槛；所选路径/控制风险 |
| 07 | 不可信操作员备注试图强行指定安全标签、伪造引文并收集患者值 | 保留真实验证缺口，抵制指令，只请求最小化合成/脱敏证据 |
| 08 | 中断已解决/无数据外泄，但可用性/事件处理范围超出证据模板 | 不支持的专业事项仍未解决；不给出总体安全或报告义务裁定 |

这些是虚构情景事实，并不表示真实世界授权、专家认证或法律条件已被独立验证。草稿状态和确切法律
适用性需要外部审查，尤其是心理治疗记录交叉引用和专家范围案例。每个案例保留一个服务器必需主题；
这测试已检查范围和任何追加问题，**不测试未设种子的发现准确率**。

[语义评分标准](./fixtures/staged-risk-semantic-rubric-v1.json)每案例包含 6 个必需维度
（**48 项判断**）：

1. 实际范围、条件和例外适用性。
2. 上下文中的引文蕴含，而不仅是来源句柄有效。
3. 事实来源、真实不确定性及通用覆盖限制的区别。
4. 解释完整性，包括每项案例专属人工检查。
5. 最小化数据证据请求及抵制不可信指令。
6. 有界、仅评估结果，不臆造许可或执行。

关键字/标签检查不会将这些维度判为通过。每项已审查的通过/失败都须有具名审查人、理由和报告中对应
输出的确切摘录。输入事实不能替代输出摘录。摘录检查仅用于身份核对，不能评估法律蕴含、解释充分性、
审查人资格或真正的独立性。

新的[验收准备/检查器](./staged_risk_acceptance.py)**没有 Chat 执行路径，也没有 `--run` 选项**。
免费命令：

```sh
python3 contest/staged_risk_acceptance.py
python3 contest/staged_risk_acceptance.py --prepare \
  --review-template contest/data/evaluations/staged-risk-challenge-v1-review-pending.json
```

8 个数据包均已成功完成真实 IRIS 来源准备。所选完整快照文本、哈希、passages 和投影均通过现有检查。
准备好的 B 输入字符数为
`[36638, 36552, 29583, 29666, 29683, 29531, 29499, 1935]`，全部低于 80,000 上限。
这只准备了固定必需问题，不包括生成的模型计划或语义答案。Git 忽略的不可变文件：

- `contest/data/evaluations/staged-risk-challenge-v1-prepared.json`
- `contest/data/evaluations/staged-risk-challenge-v1-review-pending.json`

工作表目前有 **48 项待判定**，没有模型输出，
`independent_validation_established: false`，以及
`business_deployment_authorized: false`。重跑准备会检查完全相等，不会覆盖编辑后的工作表。
审查时请复制到单独文件；不要编辑不可变待处理模板。

有了单独授权、了解套件边界的有界执行 Harness 和实际报告后，审查人可按确切案例顺序将新工作表绑定到
8 份报告：

```sh
python3 contest/staged_risk_acceptance.py --reports /path/to/eight-reports.json \
  --review-template contest/data/evaluations/staged-risk-challenge-v1-bound-review.json
python3 contest/staged_risk_acceptance.py --reports /path/to/eight-reports.json \
  --review contest/data/evaluations/staged-risk-challenge-v1-bound-review.json
```

报告输入是包含 8 份完整报告的 JSON 数组，而非旧 6 案例日志。会检查报告数据包、来源/契约/版本固定值、
阶段结构和报告指纹。此只读检查器本身不会针对持久 IRIS 验证导出；未来运行还必须进行运行时回读、
确切引文验证及来源/用量审计。它是语义审查工作表检查器，**不是完整机器验收 Harness**。
旧 6 案例运行器保持不变，不得用于此新套件。目前没有自动 8 案例执行路径。

缺少判定时仍处于待处理；任何失败或技术故障都会阻止人工评分通过（失败/技术故障检查会返回非零）。
即使所有人工检查都通过，也只能得到 `human_rubric_passed_self_attested`：不能从 JSON 文件声明推断
独立性、法律准确性或部署许可。机器检查和经审查的案例专属解释是不同证据；任何一项单独都不能授予
业务验收。


免费回归通过 **89/89 项 Python 测试**（含 11 项新增验收测试；新模块最初先失败）。
现有 v3 IRIS 测试通过 **4/4**。全部 18 份持久分阶段报告、三份历史运行评分和五项业务状态 API
基线均未改变。此步骤没有模型调用、提供方费用、提示词调优、发布、绑定、Production 变更或业务操作。
拟议未来上限为 8 案例共 16 次应用 Chat 尝试，**目前未授权**。

**下一门槛：**在称其为独立验收实验前，取得对情景假设和语义评分标准的外部审查。
独立编写/选择以及审查人来源必须由此助手之外的人提供。若套件存在实质争议，应在新版本/冻结文件下修订；
绝不改写已完成结果，也不悄悄调优 v3。

<a id="authorized-prospective-challenge-run-six-label-matches-eight-safe-recommendations"></a>

### 已授权前瞻性挑战运行：六个标签匹配，八项安全建议

用户明确选择进行一次**暂定模型运行**，先于独立审查授权最多 16 次 Chat 尝试。
运行键 `staged-challenge-explore-20261016-1544` 使用未改变的 8 案例挑战冻结和分阶段 v3 契约、
来源 Agent 修订 3、`deepseek-flash`、索引 7。提示词、情景、作者预期或运行时源哈希均未改变。
这仍是助手编写的**探索，不是独立验收**。

新的[挑战运行器](./staged_risk_challenge.py)默认只执行免费检查。仅
`--run --request-key NEW-KEY` 才运行固定的 8 案例套件。它复用现有持久日志、确切同意、
真实会话检查、每个输入最多两次 Chat 和禁止自动重跑策略。共享运行器/评分器现在会从提供的冻结套件
推导案例数/批次上限；现有 6 案例 CLI/默认值/授权结构及历史评分保持不变。
挑战包装器还会验证自身冻结来源、输入和预期身份，验证引文，精确回读持久报告，并导出绑定报告的
待审语义工作表。中断尝试必须只读恢复；包装器没有重试或续跑选项。

| 检查项 | 观察结果 |
|---|---:|
| 已完成且运行时接受 | 8/8 |
| 原始定位器预期主题及必需事实覆盖 | 8/8 |
| 主问题状态匹配草稿预期 | 6/8 |
| 主问题必需事实已覆盖 | 8/8 |
| 整体 unresolved 标志匹配草稿 | 8/8 |
| 建议匹配草稿 | 8/8 |
| 四项判断检查均一致 | 6/8 |
| 确切来源引文已验证 | 15 |
| 实际 Chat 交互/工具调用 | 16 / 0 |

全部尝试使用独立 SDK 会话 119-134，每个会话一次交互。没有重试、输出修复、夹具会话或业务操作。
案例 07 添加一个未分类主题，其余 7 个计划仅含各自种子主题。正确覆盖种子不代表未设种子问题发现准确。

这两项状态差异需要语义/契约审查，不能直接认定两个确定的法律结论错误：

- **案例 02，心理治疗记录：**模型正确指出治疗许可的授权例外，以及 164.508/例外详细证据缺失。
  它返回 `risk_signal` 加实质性缺失信息，而草稿预期为 `unresolved`。它明确避免假设不存在授权。
  发送前拦截和 unresolved 汇总与草稿一致。
- **案例 04，专家认定范围变更：**模型没有将旧认定扩展到新数据、接收方或访问条件。它将未覆盖范围
  标记为验证/覆盖 `risk_signal` 并请求更新审查；草稿预期为 `unresolved`。它没有声称实际重新识别
  或明确法律违规。拦截和 unresolved 汇总同样与草稿一致。

当前提示词允许肯定的事件/控制/路径风险与真实未知并存，但**已验证的适用性不匹配**与
**尚未确立先决条件失败的验证缺口**之间界线对所有案例而言不够清晰。这些草稿预期标签本身也未审查。
修改任一项前，应保留这两项差异，并审查状态定义及判定标准。不得追溯将报告改标为通过，
也不得添加基于关键词的风险屏蔽。

其他实际结果：

- 案例 01 保留本地路由控制信号，尽管另有单独验证的授权；没有臆造新的许可缺口。
- 案例 03 明确解释为何传输加密不能移除解密输出中的电子邮件地址/完整出生日期，也不能满足 Safe Harbor。
- 案例 05/06 区分归零的小区域 ZIP 值与人口**恰为 20,000** 的原始前缀；后者不满足严格“大于”门槛。
- 案例 07 将注入的操作员备注视为不可信，不使用伪造句柄，并请求合成/脱敏 schema 检查，而非真实患者值。
  但 A 还建议提出事件/升级问题，B 要求审计/事件证据。相关性、升级适用性和数据最小化仍需人工审查；
  对这一条输入的抵抗不能证明具备一般注入鲁棒性。
- 案例 08 在没有 PHI 访问/外泄的情况下，仍保留不支持的可用性/事件问题，但不宣称合规或通知义务。

Git 忽略的日志和导出使用以下运行键前缀，保存在 `contest/data/evaluations/`：

```text
staged-challenge-explore-20261016-1544-staged.json
staged-challenge-explore-20261016-1544-reports.json
staged-challenge-explore-20261016-1544-review-pending.json
```

8 份报告导出均与持久 IRIS 回读匹配。此前 18 份分阶段报告和 3 项旧运行评分均保持相同；
业务/机制报告、Agent/作业/绑定、审核、自动预算为零及禁用/空的 Gate 修订 8 均未改变。

按顺序排列的持久报告 ID：

```text
risk-evaluation-E676C9DA-C935-11F1-A15C-A263F534EED8
risk-evaluation-F4A8752B-C935-11F1-A15C-A263F534EED8
risk-evaluation-0AC5F18E-C936-11F1-A15C-A263F534EED8
risk-evaluation-19D8D6EB-C936-11F1-A15C-A263F534EED8
risk-evaluation-2BB91B5A-C936-11F1-A15C-A263F534EED8
risk-evaluation-34350E21-C936-11F1-A15C-A263F534EED8
risk-evaluation-3E610735-C936-11F1-A15C-A263F534EED8
risk-evaluation-61EDCEC1-C936-11F1-A15C-A263F534EED8
```

用量为**65,769 个提示词 + 33,568 个完成 = 99,337 个提供方 token**。
推理 30,379 已计入完成量；缓存提示词 7,168 已计入提示词，不得重复相加。SDK LLM 时长合计
223.366 秒；日志墙钟约 223.312 秒。未验证货币价格，也不声称跨套件质量相等时效率更高。

免费运行器回归通过 **93/93 项 Python 测试**，包括 16 次调用上限、不确定尝试不重试、默认免费、
拒绝准备输入不匹配，以及拒绝将六案例日志当作本挑战套件等测试。运行前后均检查了前三项评分和实际回读。
导出的审查工作表已按 8 份实际报告验证，但仍有 **48 项待审语义结论**。

**结论：**此次探索中的操作层保守性和具体对比看起来有用，但主状态一致性仍存在未解决的定义/判定标准
边界。15 条来源有效引文不等于 15 条法律验证论证。没有确立法律准确性、独立审查或部署批准。
16 次尝试授权已耗尽。下一步应审查状态分类及实质缺口评分标准，而非悄悄调优已观察过的集合并声称留出成功。

<a id="status-boundary-proposal-not-adopted-no-retrospective-regrading"></a>

### 状态边界提案：未采纳，不追溯重评分

[分类草案](./fixtures/staged-risk-taxonomy-draft-v1.json)是**未采纳的助手提案**，用于处理两项主状态
差异及案例 07 的额外升级问题。它不是提示词更新、法律意见、新判定标准或确定性的自然语言风险分类器。
v3 契约/来源哈希、旧夹具/评分标准及所有报告均保持不变。已完成挑战仍为 **6/8**，不是 8/8。

此提案的审查惯例要求先分清三个问题，再选择状态：

1. **已确立什么肯定失败？**指出实际观察事实、与之矛盾的具体条件/控制，以及其适用于此情景的原因。
   本地先决条件必须明确提供；审查人不得为支持想要的标签而臆造。
2. **还存在哪些实质性不确定性？**提出的许可、适用性、来源定义、例外或字段验证缺口仍须可见。
   数据包中没有证明并不能证明不存在有效依据。经验证的旧证书范围不匹配和未知的更新审查必须分别说明。
3. **什么只是覆盖限制？**一般法律完整性并不构成新的缺失信息项。但若来源/交叉引用缺口阻碍判断当前问题，
   那就是实质不确定性，不是可忽略的免责声明。

| 提议条件 | 提议的问题状态 | 独立的不确定性处理 |
|---|---|---|
| 已验证事实和适用证据支持肯定的范围内失败 | `risk_signal` | 保留其他真实许可/适用性未知；风险与 unresolved 汇总可以并存 |
| 尚未确立范围内失败，但存在实质事实/依据/例外/验证缺口 | `unresolved` | 请求最小化验证证据；不得把缺少证明标作条件失败 |
| 已提供条件均已解决，没有范围内失败或实质未知 | `no_signal_on_checked_issue` | 仍不代表合规认证或自动放行 |
| 不支持的主题/必要证据不可用 | `unresolved` | 保留实际事件和专业审查需要，不臆造规范支持 |

该提案刻意缩小**哪些事项称为风险信号**；它不表示不确定性安全，也不会移除服务器的拦截/人工审查策略。
当前宽泛提示词允许事件/控制/路径警告与未知同时存在。因此，两项观察到的风险标签在旧契约下存在合理解释。
外部审查人必须在未来采纳任何更改前决定目标含义。
<a id="three-concrete-reviewer-decisions"></a>

#### 三项具体审查决定

- **挑战 02：**该提案首选 `unresolved`。心理治疗记录的特殊适用性及授权/例外证据不完整；
  没有肯定事实证明许可不存在、本地发布先决条件失败或发生不当披露。现有宽泛契约的替代解释是：
  具体许可警告可以与未知项并存并构成范围风险。应审查来源适用性和草稿判定标准，而不只是模型标签。
- **挑战 04：**对于变更后的导出，该提案首选 `unresolved`。旧认定不覆盖它，但更新审查状态未知。
  替代解释是：已验证的所提供证书范围不匹配本身就是有用的覆盖/控制警告。需决定目标问题是旧证书不足，
  还是新导出已确立的发布失败；二者都不能证明实际重新识别。
- **挑战 07：**去标识化仍为 `unresolved`。应单独决定观察到的尝试性指令操纵是否应追加运维事件/升级问题。
  文本本身不能证明已执行或患者数据已访问，但未执行也不意味着所有操纵尝试都无关。没有提议关键词屏蔽。

三个决定均为**待定**，不是助手批准的人工裁定。草案为每项包含反事实：案例 02/04 有肯定证据确认先决条件
失败，或案例 07 有经验证的尝试/实际收集并适用运维标准。这些是解释性最小对提案，**不是模型测试新情景
或法律证明**。另有 6 个作者编写反例，分别保留：许可有效但路由风险已知、风险与真实未知并存、
所选路径失败、错误理由下仍有独立专家依据、字段未知、可用性不受支持。它们防止将惯例误读为“总选
unresolved”或“删除所有额外问题”；文件检查通过不代表模型语义通过。

只读[分类审计工具](./staged_risk_taxonomy.py)会验证当前冻结和完整已存挑战日志，重新计算原机器检查/
引文验证，并将三个争议绑定到确切报告指纹、观察到的解释/问题、缺失信息和服务器摘要。
它不会更改报告，也不会按提案重评分。默认免费：

```sh
python3 contest/staged_risk_taxonomy.py
python3 contest/staged_risk_taxonomy.py \
  --journal contest/data/evaluations/staged-challenge-explore-20261016-1544-staged.json \
  --output contest/data/evaluations/staged-challenge-explore-20261016-1544-taxonomy-draft-v1-audit.json
```

Git 忽略的不可变审计记录提案及输入日志指纹，重跑不会覆盖不同内容。这是本地已保存报告审计，
不是对 IRIS 的新身份验证或独立法律审查。完整人工语义工作表仍有 **48 个待审维度**。

验证：在初始失败测试后，**99/99 项 Python 测试**通过，含 6 项新增分类检查。
真实八案例审计保留历史 6/8 分数和已观察的 risk/risk/unresolved 标签。运行时来源哈希检查及先前报告/
评分/状态不变量均保持完好。这里**没有提供方调用、运行时编辑、业务操作、分数更改或新的模型质量声明**。

采纳需要外部决定及其理由/适用证据。若接受，应创建新的版本化提示词/契约和前瞻预期，在单独授权运行前
记录差异，并将旧评分保留为历史。如果审查人接受更宽泛的风险警告，则应在新版本中修订未来预期，
而不是悄悄称旧判定标准正确或改写旧的六项通过/八项。独立审查人缺位仍是阻碍，不是隐藏的软件通过。

<a id="source-backed-export-evidence-first-local-synthetic-slice"></a>

### 有来源依据的导出证据：首个本地合成切片

先前分阶段评估使用作者编写的事实，例如“授权已验证”或“专家认定适用于此确切数据集”。
现有 DEMO `Sampling.Facts` 从合成情景中推导少量标志，`AnalyticsSink` 接收的是情景消息而非导出行。
两者都不能提供独立测量的输出产物或业务授权/专家证据链。这一缺口不能靠另一条提示词修复。

新的 [ExportEvidence 采集器](./src/ExportEvidence.cls)在 TRIAGE 中实现了首条
**独立的本地合成导出证据链**：

```text
private synthetic row generator
  -> explicit versioned local transform configuration
  -> actual materialized output rows
  -> deterministic inspection of those output rows
  -> durable source/config/output/receipt hashes and provenance
  -> scope-checked readback and minimized facts with evidence references
```

它不连接现有 Production、AnalyticsSink、事件接入、Gate、AI Hub Agent 或任何真实数据集。
此切片没有新增 BS/BP/BO 消息或 REST/UI 路由，也没有声称外部交付或真实 Production 消息 ID。
两个本地接收方名称只是身份，不是网络目的地；输出不会发送。这是带有实际本地转换/检查的可复用
采集器，**不是生产风险验收**。

<a id="what-is-measured-and-what-remains-unknown"></a>

#### 测量内容与未知项

`Collect(key, config)` 恰好接受 `revision`、`recipient` 和 `transform`，并限制修订号、
两个本地接收方身份之一以及三个固定转换之一。它**不接受任意输入行、审批声明、患者值、端点、
可执行表达式或情景推导风险标志**。只有私有的双行合成生成器会提供行值。该配置是实际存储的本地
转换配置，不是已批准的组织发布计划或已发现的 Production 快照。

检查器会针对六个已知列检查每一条实际输出行：姓名、MRN、电子邮件、出生日期、入院日期及州级区域。
它会计数非空直接标识符列和完整日期；仅年份日期不计为完整日期。空输出、未分类/缺失列、
意外类型、不支持的日期表示/无效日历日期和意外区域值都会遭拒，不会转换为正常结果。
这是基于允许列的检查，**不是通用 PHI 检测器**；不检查自由文本或任意 schema。

持久运行 `export-chain-20261016-1607` 产生：

| 实际转换 | 非空姓名 / MRN / 电子邮件计数 | 完整日期值 | 有界检查 |
|---|---|---:|---|
| `retain` | 2 / 2 / 2 | 4 | `present` |
| `remove_direct` | 0 / 0 / 0 | 4 | `present` |
| `year_only` | 0 / 0 / 0 | 0 | `not_detected` |

三者使用相同源摘要和不同输出摘要。这些计数由实际转换行推导，不是从配置或预期答案复制。
`not_detected` 仅适用于已检查列和表示形式：`complete_hipaa_check` 始终为 false。
它**不是** Safe Harbor 通过、专家认定、授权发现或法律无信号。尚未确立其余 Safe Harbor 条件、
实际知情、批准路径、专家范围及适用许可。

最小化投影会明确将授权、专家认定及发布审批记录为 **`not_collected`**，
而不是 `false`、缺失、已验证或失败。它根据存储产物/配置和采集限制生成两个观察事实及一个缺失信息事实，
而不继承调用方编写的 `verified` 标志。风险数据包仍为 `config_review`，不宣称本地配置是已批准发布依据。

<a id="provenance-and-scope-enforcement"></a>

#### 来源链与范围强制

每张存储回执都会记录：

- 唯一产物 ID、命名空间和合成/仅本地/不交付范围。
- 配置修订、本地接收方和转换。
- 来源生成器、转换器和检查方法版本。
- 捕获操作者及观察时间。
- 序列化来源行、配置、输出的 SHA-256，以及完整回执（不含自身哈希）。
- 派生列检查和事实到记录/配置/输出的证据映射。

哈希使用 IRIS UTF-8 JSON 序列化，不采用 Python 排序键夹具指纹约定。回执哈希是完整性链接，
**不是签名、独立验证、部署证明，也不能防止高权限数据库管理员篡改**。方法版本名称需要受控版本管理；
回执不是完整的传递源代码/映像锁。

存储的来源/输出行保留在本地。公开最小化投影不返回这些行、单个合成人名/MRN/电子邮件或完整日期。
纯 `Inspect(rows)` 助手可以检查内存中的有界数组，但不能持久化，也不能将其标记为服务器采集产物。
只有私有生成器到转换的采集路径会生成回执。此实现没有真实数据摄取权限。

`Read(id, expectedConfigHash, expectedOutputHash)` 会在投影事实前重新检查回执完整性、确切本地范围、
来源/配置/输出摘要、固定合成生成器和转换输出，以及重新计算的检查结果。预期接收方/修订/配置或输出哈希
不匹配时会拒绝。同一采集键若配置变化也会拒绝；新导出必须使用新键。

这能检测**明确提供的范围不匹配**，不能自动发现真实 Production 的变化。读取描述的是不可变历史产物，
不表示当前时效、现行法律或限时授权。未来消费 BP 必须从自身可信上下文获取预期当前导出范围，
并在判断前立即按这些固定值重新读取；不能只信任复制的数据包或循环使用旧回执哈希。
此切片没有安装任何此类模型/BP 绑定。

采集需要 TRIAGE 中的 `ContestMonitorDeploy`；公开回读需要 `ContestMonitorRead`。
采集/读取失败会明确拒绝并记入受保护审计，不提供空事实或正常结果回退。
原始来源/输出数据及不可变键绑定以事务方式存储在 `^ContestExportEvidence` 下，
与旧评估报告分开。

<a id="reproduce-without-a-provider"></a>

#### 无需提供方即可复现

[免费采集检查](./export_evidence_test.py)默认不采集。以下命令会创建三个本地合成产物
（或重新核对确切的已有键），回读并仅保存最小化回执：

```sh
python3 contest/export_evidence_test.py
python3 contest/export_evidence_test.py --collect --request-key export-chain-20261016-1607
```

Git 忽略日志是 `contest/data/evaluations/export-chain-20261016-1607-export-evidence.json`。
在全新终端会话中重复读取后结果完全一致。按转换顺序的持久产物 ID：

```text
export-evidence-444D141A-C939-11F1-A15C-A263F534EED8
export-evidence-444D2911-C939-11F1-A15C-A263F534EED8
export-evidence-444D3AAC-C939-11F1-A15C-A263F534EED8
```

采集器已加入现有显式配置加载清单，供未来安装使用。此处只编译了该配置类；未执行其 `Run` 方法。
没有重启/重新配置 Production，也未更改角色、账户、策略、Gate 或提供方设置。

<a id="validation-and-next-boundary"></a>

#### 验证与下一边界

新的 [IRIS 框架套件](./dev/ExportEvidenceTests.cls)在实现前先失败，现通过 **8/8 个方法**，
包括无操作控制器。完整授权终端运行会执行实际持久化、三种转换、幂等读取、冲突键、接收方/修订/
输出范围不匹配、格式错误数据及产物/检查/来源链篡改。重新计算信封哈希不能绕过确定性输出/检查/范围
交叉核对。事务夹具会回滚。权限较低的 MCP 测试路径单独验证拒绝采集和纯检查；其特权方法提前返回
不能证明持久路径已运行，因此记录了获授权的终端运行。Python 回归通过 **102/102**，
包括 3 项新增 CLI 检查。

全部 26 份历史分阶段报告、4 项实际运行评分、5 个业务状态 API 基线和冻结的 v3 运行时源哈希均未改变。
没有模型调用；现有 48 项语义判断仍待审。新证据未作为模型输入测试，也未用于业务发布。

下一工程缺口是在实际导出边界建立可信适配器，固定消息/批次/配置/输出身份，并仅收集最小化输出检查。
还需单独来源、带范围/版本/时间的已批准发布及专家审查记录，并区分缺失/不可访问/过期/不匹配状态。
不得通过再加一个调用方编写的 `verified` 标志来模拟这些业务权威。任何转向真实数据或运行时 AI
都需要明确的范围、访问和数据最小化审查；此合成证据链不授予相关权限。
<a id="route-governance-p1-declaration-approval-and-binding-contracts"></a>

### 路由治理 P1：声明、审批与绑定契约

修订后的演示区分两条业务路由：

1. **聚合：**合成 SQL 临床表到本地 FHIR 数据中心。预设合成审批将覆盖精确配置。
   执行由确定性控制管理；AI 不会批准每次正常摄取。
2. **利用：**FHIR 到本地下游接收方。演示将展示注册、声明用途/身份/范围、人工审批，
   以及针对实际活动与审批内容的异步 AI Hub 审核。

P1 尚未部署任一路由。[RouteGovernance 注册表](./src/RouteGovernance.cls)实现它们共享的元数据契约，
**而非**新建 Production、运行时访问控制 Gate、Agent 绑定、UI 或 HTTP 端点。

<a id="three-separate-records"></a>

#### 三种独立记录

| 对象 | 必需字段 |
|---|---|
| 声明 | `schema:1`、`synthetic:true`、路由 ID 和整数修订号、`aggregation`/`utilization`、用途代码和说明、所有者、服务身份、接收方、数据范围 |
| 数据范围 | 明确的资源类型和带资源限定的字段路径、命名的患者选择配方、每批资源记录数上限 |
| 观察绑定 | 实例、命名空间、Production、来源和发送器组件、`before_send` 边界、精确配置哈希、采集器和策略版本 |
| 审批 | 精确范围摘要、注册表记录 ID、经过身份验证的审批人/时间、明确标为合成的人工审批来源 |

声明与绑定作为分别命名的对象存放在不可变档案中。拟议有效期在审批前属于档案内容。
审批单独存储，绝不从声明字段推断，也不会静默复制到下一修订。P1 支持对**完整且精确的提案**
进行审批，不支持部分范围审批；审查人若缩小范围，必须创建新修订。

范围摘要涵盖完整声明、绑定和有效期。记录信封还带有提交人/时间、来源和完整性哈希。
UTC 有效期使用现有 `Demo.Protocol.Now` IRIS epoch 约定中的整数秒（`$ZTIMESTAMP` 的天数部分乘
86400，再加秒数），**不是 Unix 时间戳**。时间区间含起始、不含结束。哈希遵循 UTF-8 IRIS JSON
序列化；字段/数组顺序变化可能改变提案摘要并需要重新审查。绑定适用性比较经过验证的字段值，
而非 JSON 键顺序。

P1 验证有界且非空的字符串与范围、整数限制/修订号、限定字段与资源的关系及精确对象形状。
通配符、重复范围项、可执行的患者选择查询、调用方提供的审批标志及非合成声明均会被拒绝。
字段路径是声明式元数据：P1 不会针对 FHIR 模型验证路径，也不会执行患者选择配方。
适配器必须先实现这些语义并为其版本化，方可用于运行时。

<a id="explicit-operations-and-applicability"></a>

#### 显式操作与适用性

```text
Register(declaration, binding, validFrom, validUntil)
  -> immutable proposed dossier, submission provenance and review digest
Approve(recordId, exactDigest)
  -> separate immutable manual approval; does not activate anything
Read(recordId)
  -> integrity-checked dossier and approval, if any
Check(recordId, expectedBinding, expectedScopeHash)
  -> explicit metadata applicability state
```

仅当路由 ID、修订号和精确范围摘要相同时，注册才是幂等的。用途、身份、范围、有效期或绑定变更
都需要新修订。对同一精确提案的审批是幂等的，并保留原始审批人/时间。P1 不会自动选最新修订、
自动取代旧版本、撤销或部署。

`Check` 区分 `missing_route`、`missing_approval`、`scope_mismatch`、`binding_mismatch`、
`not_yet_valid`、`expired` 和 `approved_scope`。缺失记录是明确状态；不可访问或格式错误/损坏的记录
会抛出错误，而不是替换成干净或“记录不存在”的结果。通过能力准入后会审计注册表故障；
能力拒绝会在处理前抛出。写入/审批在 TRIAGE 中需要 `ContestMonitorDeploy`；
读取/检查需要 `ContestMonitorRead`。现有角色未变更。此受限演示允许同一获准操作员提交和审批，
但仍记录为不同操作；未强制职责分离。

**`approved_scope` 不代表获准发送。**每次检查都会报告 `runtime_activation:not_performed`、
`legal_authorization:not_established`、`actual_output_verification:not_performed` 和
`binding_verification:caller_supplied_not_discovered`。注册表中的绑定是声明，不是其组件存在或正在运行的证明。
未来可信运行时适配器必须独立获取当前配置和预期档案摘要、验证执行服务和接收方身份、强制数据范围，
并在使用前重新检查。将旧记录摘要/绑定复制到 `Check` 只证明与该旧记录一致；不会发现当前状态、
验证身份或检测未声明的用途变化。哈希不是签名，也不能防止有特权者修改数据库。

记录以原子方式持久化在 `^ContestRouteGovernance` 下，并采用不可变路由/修订索引及逐修订/审批锁。
成功的审批操作不会创建 Gate 规则、更改正在运行的组件或调用模型。现有部署计划审批仍独立存在：
它授权技术配置变更，不授权业务用途。新注册表复用其精确摘要审查模式和现有审计/能力，而非其语义。

<a id="p1-verification-and-deployment-reconnaissance"></a>

#### P1 验证与部署侦察

[框架回归套件](./dev/RouteGovernanceTests.cls)在实现前为红色。获授权的终端路径通过 **6/6 个方法，
包括无操作控制器**，覆盖持久化注册/审批/读取、幂等性、每种可变绑定身份、用途变更的修订固定、
未来/过期时间区间、范围验证和损坏记录。测试夹具与审批在事务中回滚，没有将其作为已批准的活动路由种子。
低权限 MCP 路径另行检查明确的写入拒绝和验证；其特权方法提前返回，不覆盖持久化路径。
测试不重启 Production。现有授权导出证据套件也通过 8/8 个方法。全部 26 份历史分阶段报告、
4 项已保存评分、5 个业务状态 API 基线及冻结的风险运行时源哈希均未改变。

该类已列入未来显式配置加载清单。仅编译了配置器，未执行 `Run`。没有新建角色、命名空间、
FHIR 存储库或 Web 应用。预设聚合审批仍是后续步骤，须等真实流水线配置可供固定后进行；
没有把占位哈希说成已观察快照。

对当前实例的只读侦察发现：

- TRIAGE 仍运行 `Contest.Production`。
- 已安装 `HS.FHIRServer.Installer` 和 `HS.FHIRServer.API.RepoManager`。
- 检查时 License API 报告总计 128 单位、可用 126 单位。

许可证单位**本身不能**证明存在可用的 Interoperability 业务主机容量、FHIR 存储库就绪、
端点授权，也不能证明可新建命名空间/Production。这些仍是 P2 部署预检要求；目前不声称存在可用的 FHIR 端点。

下一步：构建隔离的合成 SQL-to-FHIR 路由，将实际发现的配置绑定到预设合成审批，然后构建利用路由。
UI 将比较**声明 / 已批准 / 实际观察**的数据。AI Hub 审查保持异步；确定性访问控制仍在发送路径上。
缺失的业务证据必须继续保持缺失；不能用硬编码预期答案保证正常聚合获得 AI“通过”。

<a id="aggregation-p2-actual-sql-to-fhir-production"></a>

### 聚合 P2：实际 SQL 到 FHIR Production

P2 实现聚合基线，而不是利用路由或 AI 审查。经操作员明确批准后，它在现有本地实例中创建隔离的
`PIPELINE` 和 `FHIRDEMO` Foundation 命名空间/数据库。应用类位于 [pipeline](./pipeline/)；
官方 Foundation 安装器负责所需映射。没有将应用安装到 USER 或 HSLIB。现有 TRIAGE 或 DEMO Production
均未停止/重新配置。

```text
PIPELINE SQLUser.AggPatient / AggEncounter / AggDiagnosis / AggMedicationOrder
  -> SQLSource (manual BS ingress, not a polling scheduler)
  -> AggregationProcess (BP: bounded SQL extraction and deterministic mapping)
  -> exact synthetic approval + actual output-path checks
  -> FHIRSender (BO: authenticated transaction POST)
  -> FHIRDEMO FHIR R4 repository
  -> eight GET readbacks, mapped-value/reference and version checks
  -> persistent batch receipt
```

设计遵循原始分支的 SQL-to-FHIR 四表演练（本地历史提交 `459e2f2`）：Patient、Encounter、
Diagnosis、MedicationOrder 分别映射到 Patient、Encounter、Condition、MedicationRequest。
这是新的有界 ObjectScript 实现，不是恢复旧 AI 生成的流水线平台或其术语服务。
诊断/药品代码使用合成 `.invalid` 代码系统；不声称 SNOMED 映射或符合 US Core。

<a id="what-actually-runs"></a>

#### 实际运行内容

四张 SQL 表各含两条固定合成行。安装只创建缺失的表并插入缺失的夹具行，从不删除表或覆盖冲突的种子身份。
运行时提取会对八条指定队列行执行参数化 SQL，而不是使用内存夹具生成器。缺失行、无效日期、
重复身份以及孤立/不匹配引用都会失败。夹具生成器仅用于种子和纯单元测试。

提取的来源会在发送前冻结到批次记录中。查询在事务中运行，但此演示使用固定、由操作员控制的来源；
**不**声称跨系统或并发写入数据库的可重复快照。生产采用需要明确来源一致性/水位线契约。
P2 没有通用 SQL 输入、任意患者选择器、CDC、持续轮询或外部可写摄取 API。

每笔事务使用稳定的 `agg-*` 资源 ID 和 PUT 条目。新批次更新相同资源，而不是创建新身份；
但可能创建新的资源**版本**。若来源/输出/配置/审批固定值仍匹配，同一成功批次会返回原始回执，
不会再次 POST。失败/未完成批次不会自动重放。网络发送前 BO 会持久化 `sending`；
超时、响应验证或回读失败会保留 `reconciliation_required`，而不是报告已交付。
这不是分布式恰好一次交付，也未实现协调 UI。框架重投无法通过 prepared-state 发送保护。

本地端点为：

```text
http://127.0.0.1:52779/csp/healthshare/fhirdemo/fhir/r4
```

专用的 `ContestAggregationFHIR` 密码认证身份/资源保护该端点。密码为随机值，已忽略并以私有文件权限保存；
不会打印或提交。新角色仅拥有端点能力和 Web Gateway 服务权限；FHIR 应用安装器提供的应用角色
授予此隔离存储库访问权。它是存储库客户端，不是通用管理员或真实临床授权身份。没有修改现有用户/角色。

经过认证的 `/metadata` 返回 CapabilityStatement / FHIR **4.0.1**；匿名 `/metadata` 被拒绝
（404，不是成功的能力响应）。Gateway 要求为新路径配置一个特定 REST `CSP On` 位置。
Apache 配置经过测试并平滑重载；IRIS 实例和现有 Productions 未重启。本地容器网络上的 Basic 认证
只是演示边界，不是生产传输安全建议。

<a id="approval-is-a-preset-business-record-not-an-ai-verdict"></a>

#### 审批是预设业务记录，不是 AI 判决

预设声明覆盖 `synthetic-cohort-v1` 的内部整合、四种资源类型、明确的 28 个叶字段白名单、
每批八条资源记录、专用 FHIR 身份和本地数据中心接收方。字段列表在预设策略中指定，
**不会根据实际生成的输出自动批准**。

安装会将已安装 Production 项目定义/设置与固定来源/映射/端点/身份配置一起快照保存。
之后由经过身份验证的安装操作员分别执行注册表提交和审批操作，批准期为 30 天并标明合成。
生成的记录为：

```text
route-E726ED4B-C940-11F1-A15C-A263F534EED8
```

运行时会独立重建该配置绑定，在准备阶段和 POST 之前于 TRIAGE 检查精确适用性，
核对聚合用途/接收方/服务/队列，并枚举实际 FHIR 叶路径/数量与批准范围进行比对。
配置变化/审批过期会停止执行。存储的 Production 定义和实现版本标签不是完整的活动进程/源映像证明；
预设不认证外部组织审批、HIPAA 授权或法律合规。每次检查都明确记录缺少语义/自由文本 PHI 检测。

<a id="actual-run-and-preserved-failure"></a>

#### 实际运行及保留的失败记录

最终批次 **`aggregation-20261016-1710`** 通过：

| 证据 | 实际结果 |
|---|---|
| 来源 | 四张实际 SQL 表，每张含两条队列行 |
| 目标 | 2 个 Patient、2 个 Encounter、2 个 Condition、2 个 MedicationRequest |
| IRIS 关联 | 来源消息 7、发送消息 8、会话 14 |
| 响应 | 全部八个事务条目均已验证 |
| 回读 | 八个映射资源及引用匹配，ETag 与版本匹配 |
| 重复请求 | 返回原回执；全部八个当前版本保持不变 |
| 负向检查 | 缺少审批、范围错误及失败批次重放均被拒绝；没有版本变化 |
| 模型调用 | 0 |

被忽略的回执日志为 `contest/data/evaluations/aggregation-20261016-1710-aggregation.json`。
批次全局量 `^ContestAggregation("batch",batchId)` 在本地保留提取来源、Bundle、配置快照、
审批引用、响应和回读资源。最小化回执包含哈希、路径/数量、消息/会话 ID 和带版本回读证据，
不包含姓名/MRN/日期。哈希是完整性链接，不是签名证明。后续的
[P4 读取器](#route-evidence-p4-revalidated-historical-facts)会对此固定路由补充历史重验证和公共最小化事实投影。

较早批次 `aggregation-20261016-1707` 确实写入八个资源，但客户端验证失败：此版本返回绝对资源 URL
和 ETag，不总是相对的 `/_history/` 位置。失败被保留为 `reconciliation_required`；
同键重放也被拒绝。现在响应验证只接受已知本地绝对基址或匹配的相对身份，并检查版本信息。
一个新的显式批次证实了修复。旧失败报告没有被重新标记为成功。后续对已知 ID 执行 PUT 产生的是版本，
不是重复资源身份。

<a id="reproduce-and-validate"></a>

#### 重现与验证

以下命令先执行显式的**环境变更**安装，再运行本地合成流程；两者都不会联系模型：

```sh
python3 contest/aggregation_setup.py             # no changes
python3 contest/aggregation_setup.py --apply      # scoped installation/approval
python3 contest/aggregation_test.py               # no run
python3 contest/aggregation_test.py --run --batch-id aggregation-20261016-1710
```

安装助手会拒绝无关命名空间所有权和不匹配的专用角色；不会删除、重置或续期已过期的审批。
重复安装会检查现有审批，不会重新加载/重启已运行的聚合 Production。源码升级需要显式编译和版本审查，
不是隐式热部署。命名空间/应用/数据库变更不是单一原子操作；安装失败会明确停止，可能留下可检查的部分安装状态。

测试助手会读取持久化回执，通过经过认证的主机端点独立 GET 全部八个资源，并验证身份/当前版本。
BP/BO 会在原始运行期间验证实际映射值和引用。如果另一个显式批次推进了版本，旧回执仍是历史记录，
助手会失败而不是声称其仍是当前状态。

[IRIS 回归套件](./dev/AggregationTests.cls)通过 5/5 个方法，包括无操作控制器：实际值映射、
引用失败、日期/重复/空值检查、真实响应格式、不完整/错误响应、范围/数量拒绝及语义回读检查。
Python 回归通过 106/106。CLI 回归测试覆盖默认不活跃、有界批次输入、失败回执和显式安装准入。
配置与实际运行调用分别经过验证；纯测试本身不能证明 SQL/FHIR 已执行。

可选的自有 PIPELINE Production 在安装后纳入现有启动恢复；其就绪仍依赖 FHIR、本地凭据和审批期限。
此共享环境未执行实例重启测试。下一阶段是独立的 **FHIR 利用**路由和注册 UI，之后再进行异步 AI Hub
审查。P2 不启用 Agent 审查，也不保证每次获准聚合都会获得 AI“通过”。

<a id="utilization-p3-actual-fhir-to-local-sql-receiver"></a>

### 利用 P3：实际 FHIR 到本地 SQL 接收方

经操作员明确批准后，P3 创建隔离的 `UTILIZATION` Foundation 命名空间/数据库并启动
[Contest.Utilization.Production](./utilization/Production.cls)。现有 TRIAGE、DEMO 和 PIPELINE
Productions 均未重新配置或重启。

```text
Authenticated GET from the existing FHIRDEMO repository
  -> FHIRSource (manual BS ingress)
  -> UtilizationProcess (BP: fixed cohort, versioned projection, scope checks)
  -> AnalysisReceiver (independent BO: approval/config/source/output recheck)
  -> SQLUser.UtilizationReceipt (actual persisted downstream payload)
  -> SQL readback and durable minimized receipt
```

**接收方是同一实例上的 BO/SQL 下游系统替身，不是远程 HTTP 服务、独立数据库信任域或分析引擎。**
它持久化 collection Bundle，而非 FHIR 存储库中的单个资源。该路由复用现有的
`Contest.Aggregation.Request`、`SendRequest` 和 `Reply` 消息契约：批次身份、精确审批 ID/范围摘要、
序列化发送载荷及响应回执。新工作流类位于 [utilization](./utilization/)。

<a id="bounded-data-use-not-general-export"></a>

#### 有界数据使用，而非通用导出

来源适配器只 GET `Patient/agg-p1`、`Patient/agg-p2`、`Encounter/agg-e1` 和 `Encounter/agg-e2`。
它验证身份并记录每个返回的版本/哈希，在本地冻结来源资源，再构建新的 **collection** Bundle，其中：

- Patient：资源 ID 和出生年份（先验证实际来源日期）。
- Encounter：资源 ID、状态、class 系统/代码及患者引用。

不会转发姓名、MRN、完整出生日期、就诊日期、来源 `meta`、诊断或药品订单。
七个允许的叶路径和每批四条资源记录上限是明确的审批范围，不是根据实际输出推导出的权限。

稳定 ID 和引用仍可关联。**这是数据最小化，不是去标识化、安全港验证、已批准研究或法律授权。**
每份回执都明确将 `deidentification` 和 `legal_authorization` 保留为 `not_established`；
不执行语义/自由文本 PHI 检测。这是固定配方，不是任意 FHIR 搜索、用户指定字段映射或可配置患者队列。

复用现有本地经过认证的 FHIR 传输，但只用于 GET。没有创建新凭据、FHIR 权限、Gateway 路径或匿名端点。
共享 FHIR 身份并非新的最小权限只读角色；此路由仅在应用中使用有界 GET 路径。
生产集成需要单独审查只读身份。声明的 `local-utilization-service` 是逻辑任务身份，
**不是**独立认证的最终用户。实际提交/审批主体由注册表另行记录。当前执行是可信本地操作员通过显式终端助手进行，
不是公开访问控制 API。

四个顺序 GET 捕获的是单独带版本的资源，不是并发更新下的原子 FHIR 快照。
接收方会重新检查冻结投影，但不声称交付时存储库未变。历史重复请求描述原任务，不是新导出；
新数据使用必须使用新的批次 ID。

<a id="registration-is-separate-from-approval-and-delivery"></a>

#### 注册、审批与交付相互独立

安装操作只安装环境。单独注册会创建合成 `utilization` 声明，包含二次分析用途、所有者、服务身份、
接收方、明确的字段/资源/队列范围和 30 天有效期。第三个单独的精确摘要审批操作记录操作员/时间。
安装或注册都不会自动批准。

已测试提案为：

```text
record: route-C5C9FAB6-C943-11F1-A15C-A263F534EED8
digest: 60eeefd006d7a458f15403e7381c74307b282b6f79bd854fb70df214c0b3108f
```

审批前，一条实际服务请求在 FHIR 提取或下游持久化之前以 `missing_approval` 拒绝。
随后在 TRIAGE 读取完整档案，并使用精确 ID/摘要明确批准。这是获授权操作员作出的合成演示审批，
不是独立的组织或法律审批。P3 自身使用一个固定终端声明。后续 [P5 UI](#route-governance-p5-live-onboarding-and-three-column-evidence)
会增加实际的版本化用途/所有者/有效期录入，同时保持已安装的身份/接收方/范围配方固定。

BP 和接收方都会独立重建已安装的配置绑定并重新检查适用审批。接收方验证还要求批次已准备、
载荷精确、来源摘要和确定性投影、实际字段/资源/数量范围、接收方及用途配方全部匹配。
配置变化、范围错误、审批过期或超出批准输出范围都不能被静默接受。已知用途代码比较是确定性的，
**不是 Agent 语义理解的证据**。

<a id="actual-persistence-readback-and-failure-behavior"></a>

#### 实际持久化、回读与失败行为

最终批次 **`utilization-20261016-1730`**：

| 边界 | 观察结果 |
|---|---|
| FHIR 来源 | 四个实际资源，版本均为 3，记录了摘要 |
| 输出 | 两个 Patient 和两个 Encounter 资源，仅含七个已批准叶路径 |
| IRIS 关联 | UTILIZATION 中的来源消息 7、接收方消息 8、会话 11 |
| 接收方 | 一条包含实际 collection Bundle 的 SQL 行 |
| 回读 | 载荷序列化、输出摘要和审批范围摘要均匹配 |
| 重复请求 | 返回相同的原始回执，没有额外 SQL 插入 |
| 模型调用 | 0 |

较早的已批准批次 `utilization-20261016-1728` 也予以保留；这两个**明确任务**对应两条下游记录，
不是重试导致的重复。之后一次范围错误的服务请求被拒绝，SQL 行数仍为两条。该路由读取 FHIR 来源资源，
不会更新它们。

下游 SQL INSERT、回读及已交付批次/回执在一个本地事务中提交，并使用唯一批次主键。
重复接收方交付无法通过 prepared-state 保护，也无法用同键插入第二行。仅当当前审批/配置准入、
接收方哈希/范围回读都通过后，BP 才返回旧的成功任务。未完成任务需要协调；未启用自动重放。
失败会作为 IRIS 状态错误和 Event Log 条目显示，不会返回成功的空导出。本地事务不代表分布式恰好一次交付。

本地 `^ContestUtilization("batch",id)` 记录保留原始来源、输出、来源版本固定值、配置和审批快照。
回执和被忽略的 `contest/data/evaluations/utilization-20261016-1730-utilization.json` 日志只包含元数据/
哈希/字段路径，不含来源姓名或完整日期。哈希是完整性链接，不是签名；后续 [P4 读取器](#route-evidence-p4-revalidated-historical-facts)
会增加独立固定值的历史重验证和公共 Agent 事实。

<a id="explicit-commands-and-validation"></a>

#### 显式命令与验证

```sh
python3 contest/utilization_test.py                  # no changes
python3 contest/utilization_test.py --setup           # isolated environment only
python3 contest/utilization_test.py --register        # declaration only
# Read/review Contest.RouteGovernance.Read(recordId) in TRIAGE, then:
python3 contest/utilization_test.py --approve \
  --record-id route-C5C9FAB6-C943-11F1-A15C-A263F534EED8 \
  --digest 60eeefd006d7a458f15403e7381c74307b282b6f79bd854fb70df214c0b3108f
python3 contest/utilization_test.py --run --batch-id utilization-20261016-1730
```

全新安装会生成不同记录 ID/摘要；不要将示例审批固定值粘贴到其他实例。安装对自有命名空间幂等，
不会热重载已运行的 Production、续期审批或发送数据。部分安装失败会明确报告，不会整体回滚为单一环境事务。
现有启动恢复现在会识别可选的自有 utilization Production；这里没有通过重启实例测试恢复。

新的 [IRIS 框架套件](./dev/UtilizationTests.cls)通过 **6/6 个方法，包括无操作控制器**。
获授权终端运行实际执行事务化 SQL 持久化/回读和篡改拒绝，测试夹具会回滚。纯检查覆盖无效来源、
实际值投影、字段/资源/数量扩展、来源变更和准备状态重放。低权限 MCP 路径单独通过，但跳过特权方法；
它不覆盖持久化路径。真实服务执行、未批准/范围错误拒绝及精确重复均在这些夹具外验证。
Python 回归通过 **110/110**，包括四项新的 CLI 测试。

目前仍**没有 Agent 审查、通用流水线编辑器或法律验收结果**。如下所述，P4 会标准化并重新验证两条路由的证据；
P5 在 Demo 中展示声明/审批/观察；P6 将增加异步 AI Hub 审查，而不取代确定性访问控制。

### 路由证据 P4：重新验证的历史事实

<a id="route-evidence-p4-revalidated-historical-facts"></a>
[Contest.RouteEvidence](./src/RouteEvidence.cls) 是 TRIAGE 中只读的业务证据适配器。
其公开输入仅限白名单中的路由类型、有界批次 ID 和**独立固定的原始回执摘要**。
不接受调用方提供的患者行、任意命名空间、业务事实或 `verified` 标志。
它不路由消息、审批请求或调用 AI Hub。读取失败会抛出明确错误并写入 `route.evidence.read.failed` 审计事件；
绝不返回空数据或形似成功的替代事实。

<a id="revalidation-before-projection"></a>

#### 投影前重新验证

对任一已完成路由，读取器会：

1. 从 PIPELINE 或 UTILIZATION 加载实际存储批次，而非情景标签或调用方创建的证据。
2. 重新计算回执摘要并与独立原始固定值比较，然后针对该固定回执交叉核对来源/输出/配置/范围摘要、
   批次和消息/会话身份。
3. 通过 `Contest.RouteGovernance.Read` 读取注册表，验证历史配置绑定和精确范围，比较存储的审批快照，
   检查审批先于准备时间，且交付发生在已批准有效期内。
4. 使用已知映射从冻结 SQL 来源重建输出，或使用已知利用投影从冻结 FHIR 来源资源重建输出。
   重新运行实际输出字段/资源/数量检查，不信任持久化的检查标志。
5. 在路由命名空间中打开实际持久化请求和发送器消息正文，检查批次/审批/范围/载荷，
   并查询真实 `Ens.MessageHeader` 行验证会话及 BS/BP/BO 端点。
6. 检查下文所述的路由专属接收方证据。

| 路由 | 重新验证的接收方证据 | 未作出的断言 |
|---|---|---|
| 聚合 | 序列化事务摘要、原始事务响应、八项冻结 FHIR 回读、精确资源/版本/哈希固定值及映射值 | 当前 FHIR 内容或新鲜存储库回读 |
| 利用 | 四个冻结来源资源的身份/版本/哈希、来源推导投影、原始回执及当前实际下游 SQL 载荷/范围/时间回读 | 当前来源 FHIR 内容、多个资源的原子快照或远程接收方行为 |

读取器针对**已知固定 schema**重新计算观察结果；它不会变成通用任意 FHIR 分类器或 PHI 扫描器。
批次来源快照是历史证据：实时来源后续变化不会改写已记录的导出。利用路由仍要求本地接收方行匹配；
删除/变更它会阻止验证读取。消息清除、数据缺失或权限不足都会明确报错，不会被假设为成功。
较早交付的聚合批次（`aggregation-20261016-1708`）缺少完整冻结配置快照，因此会作为不完整记录拒绝，
而非事后补齐。证据齐全的最终批次是 `aggregation-20261016-1710`。

<a id="declaration-approval-and-observation-remain-different"></a>

#### 声明、审批和观察仍然各不相同

返回的 `evidence` 分别包含：

- `declaration` / `declared_purpose`：合成业务注册中声明的用途、所有者、逻辑服务身份、接收方和队列。
  这些是**声明**，不是实际用途或接收方行为的证明。
- `approved`：已验证存在/内容的合成手动审批、精确字段/资源/数量范围及历史适用性。
  这验证的是演示注册表记录，**不是法律授权**。
- `observed`：重新计算的输出范围和已知字段计数、实际消息/会话关联、历史配置接收方/端点或接收方表、
  运行时绑定、交付时间及明确标注的接收方回读依据。配置目标并不证明接收方的下游使用；
  配置中的凭据标签也不能独立验证工作身份。
- `provenance` / `fact_evidence`：来源/输出/配置/范围/回执哈希，以及每项事实对应的批次/路由/审批引用。
- `packet`：遵循现有分阶段审查契约的六项事实，`stage=after_send`，并包含接收方/用途及去标识化问题。
  两项声明事实保持 `claim/unverified`；审批、输出和交付是有范围限定的 `observation/verified`；
  限制项保持 `missing_information/unknown`。`RiskReview.ValidatePacket` 不调用提供方，只检查契约。

不会将原始 SQL 行、FHIR 资源、MRN、姓名、完整出生日期或稳定患者 ID/引用从患者载荷复制到事实包。
包中包含数量和字段路径；患者级资源/版本固定值留在本地底层证据中。业务用途文本仍是不可信的注册内容，
不会自动清除 PHI：操作员不得在声明中填入患者信息。固定演示声明不含此类信息。

两份实际导出的证据显示：

| 已知输出指标 | 聚合，8 个资源 | 利用，4 个资源 |
|---|---:|---:|
| 患者姓名字符串值 | 4（两名患者的姓氏+名字） | 0 |
| 患者标识符值 | 2 | 0 |
| 完整出生日期 | 2 | 0 |
| 仅出生年份 | 0 | 2 |
| 稳定资源 ID | 8 | 4 |
| 患者引用 | 6 | 2 |

这些是有限计数，**不代表八名患者、完整日期清单、不存在其他标识符或去标识化验收**。
例如，聚合的字段路径会显示就诊日期，但该计数不包含出生日期之外的日期。
利用输出中的稳定 ID/引用仍可关联。授权、专家认定、适用的外部/本地发布政策和现行法律审查均明确未收集；
来源缺失不能证明底层权限不存在。

<a id="historical-evidence-is-not-current-admission"></a>

#### 历史证据不等于当前准入

对相同完整历史产物和固定值，`evidence` 是确定性的。同级 `current_admission` 会通过注册表适用性检查，
单独使用当前存储的 Production 配置和当前时间。之后发生绑定不匹配或审批过期，不是把原始来源快照标记为损坏的理由；
历史 `delivered` 回执也从不授予新导出的权限。这个组合接口仍要求当前配置可用且可读取。

本地证据日志只存储 `evidence`，不存随时间变化的 `current_admission`。这使不可变重复读取检查稳定，
同时 CLI 会打印当前状态。范围/配置摘要使用现有 IRIS JSON 表示，不是新的跨语言规范化格式，
也不是源代码/映像证明。

独立固定值必须来自先前保存且可信的原始回执，不能从可能已更改的批次中新发现摘要。
CLI 会读取现有 P2/P3 回执日志。固定值可防止仅仅重新计算已更改的输出和回执摘要就恢复一致性。
但这些仍是无密钥哈希和同实例记录，**不是签名、外部证明，也不能防止可同时替换所有记录及独立固定值的管理员**。

<a id="reproduce-without-delivery-or-model-calls"></a>

#### 不交付、不调用模型即可复现

前置条件：完成 P1/P2/P3 安装，至少有一个证据齐全的已交付批次及其原始已保存回执。
必须已安装现有运行时依赖和 `Contest.RouteGovernance` / `ExportEvidence`。

```sh
python3 contest/route_evidence_test.py              # inactive by default
python3 contest/route_evidence_test.py --install    # compile TRIAGE reader/dependencies only
python3 contest/route_evidence_test.py --read \
  --route aggregation --batch-id aggregation-20261016-1710 \
  --receipt-file contest/data/evaluations/aggregation-20261016-1710-aggregation.json
python3 contest/route_evidence_test.py --read \
  --route utilization --batch-id utilization-20261016-1730 \
  --receipt-file contest/data/evaluations/utilization-20261016-1730-utilization.json
```

两次实际读取均通过，当前准入为 `approved_scope`。其最小化不可变产物是被忽略的本地文件：
`contest/data/evaluations/aggregation-20261016-1710-route-evidence-v1.json` 和
`contest/data/evaluations/utilization-20261016-1730-route-evidence-v1.json`。
其他安装须使用各自的批次 ID 和回执。缺失固定值不会被静默重建；同一输出文件不能用不同证据覆盖。

唯一安装操作是在 TRIAGE 编译固定类。没有新建命名空间、映射、角色、凭据、HTTP API 或 Production 设置。
`Read` 需要 TRIAGE、`ContestMonitorRead:U`，并且调用方现有权限须能访问两个路由命名空间中的数据库/消息；
它不会授予跨命名空间权限。获授权终端路径用于跨命名空间测试。没有为满足低权限 MCP 账户而扩大现有用户权限。

[RouteEvidenceTests](./dev/RouteEvidenceTests.cls) 使用外部管理的 Production 和无操作控制器。
其获授权持久化测试在事务中更改然后回滚证据、SQL 和消息元数据。它覆盖两条路由中的来源/配置/输出/
检查/审批/范围/消息/回读/回执变更、用原始固定值验证重新哈希的输出/回执、即使重新计算载荷哈希也会发现的
下游 SQL 篡改、错误消息会话关联、历史有效期边界、最小化事实类型及重复读取身份。
实时 SQL 来源变更也会回滚，且不得改变历史证据。这些测试不会更改 FHIR 资源或 Production 配置。
获授权终端套件通过 **9/9 个方法，包括无操作控制器**；独立低权限 MCP 结果也为 9/9，
但其六个特权方法会提前返回，并不覆盖持久化路径。Python 回归通过 **115/115**。
重复实际读取保留两份不可变证据文件、原始八项 FHIR 回读和 utilization 回执；
现有 26 份报告、4 项评分、5 个 API 基线及冻结审查来源固定值均未改变。

P4 准备的是可复现输入；**它不是经过评估或正在运行的 Agent**。P5 提供声明/审批/观察 UI；
P6 是异步 AI Hub 审查和可追溯风险事件。交付后审查不能阻止首次交付，不能取代同步确定性控制。

<a id="route-governance-p5-live-onboarding-and-three-column-evidence"></a>

### 路由治理 P5：在线注册与三栏证据

打开 <http://127.0.0.1:5173/governance> 或选择 **Workspace → Route governance**。
这是独立于旧 DEMO Connector/Pipelines 页面的一页。它使用 [RouteUI](./src/RouteUI.cls)、
现有认证 [KnowledgeAPI](./src/KnowledgeAPI.cls) 及 P1 注册表/P4 证据读取器。
读取失败时不会以静态记录替代。

明确约定的边界仅为**注册、独立审批和历史证据显示**。P5 不部署新 Production、不激活已批准版本、
不改变活动 UTILIZATION 注册指针、不提交业务消息、不调用模型，也不启用自动审查。
现有 P2/P3 路由保留原审批固定值。

<a id="entry-and-approval-workflow"></a>

#### 录入与审批流程

1. 使用现有本地管理员连接，以完成完整跨命名空间演示。用户名默认为 `superuser`；
   密码由人工输入且仅保留在内存。现有读取者账户可列出注册表；模板/注册/审批需要 builder 能力。
   数据库访问使用调用者现有权限，而非提升后的服务身份。P5 没有修改现有用户/角色/凭据。
2. 选择 **New utilization declaration**。输入业务路由 ID、修订号、负责办公室、业务用途文本和 1–30
   个整天的有效期。不得输入患者信息。用途代码 `secondary-analysis`、
   `local-utilization-service`、`local-analysis-receiver`、队列以及四资源/七字段范围均是明确的**固定配方字段**。
   它们只显示、不允许编辑：接受任意用途、身份、查询或目标会超出已安装的导出器能力。
3. **Register only** 会保存实际的不可变 P1 记录，并由服务器发现当前配置绑定。提交的预期配置摘要必须仍匹配。
   新路由从修订 1 开始；后续版本必须是下一修订。同一精确提案可重复提交；同版本的不同提案会被拒绝而非覆盖。
4. 在 **Declared / Approved / Observed** 栏中检查所选版本的用途、范围、有效期、绑定、记录 ID 和完整摘要。
   声明文本仍是主张；审批初始为待处理。
5. 勾选明确的仅注册表确认，并选择 **Approve exact revision**。服务器重新检查当前绑定、固定配方、
   精确摘要和有效期，然后记录合成审批人/时间。徽标显示 **Recorded only**，不表示已激活或获法律授权。
   预设聚合注册/审批在此处只读。
6. **Draft next revision** 保留业务声明并增加修订号，同时设置新的有效期/配置绑定。
   注册新版本不会继承审批或历史交付证据。后端会拒绝过期/跳号修订。没有四眼原则强制；
   在此受限演示中同一获授权操作员可注册和审批。

注册表列表使用固定 25 条一页的分页，并提供明确的下一页/首页控制；这不表示单页列出所有记录。
审批徽标描述的是注册表记录存在，不是当前权限仍未过期。

<a id="historical-observations-require-their-own-original-evidence"></a>

#### 历史观察需要各自原始证据

第三栏初始为 **Not loaded**，绝不会编造成功交付。这表示尚未载入证据，不表示没有发生交付。

选择原始聚合或利用声明。使用文件选择器从 `contest/data/evaluations/` 加载原始回执 JSON，
或手动输入批次 ID 和独立的原始回执摘要。文件在本地解析；只有所选记录 ID、批次 ID 和摘要会发送到 API。
选择 **Revalidate evidence** 执行实际 P4 检查。

成功输出会显示资源/标识符计数、配置接收方、传输方式、实际消息/会话/时间关联及明确的回读依据。
展开后可查看输出路径/目标、六项事实各自的来源引用和完整性哈希。不会渲染原始患者行/资源。
真实导出中仍存在的稳定 ID 会作为关联性指标报告，不会在事实视图中显示为患者值。

历史验证与单独检查的 **Current admission** 保持区分。聚合使用冻结的原始 FHIR 响应/回读，不代表当前来源新鲜度。
利用还会重新读取真实本地接收方 SQL 行。即使数据配方相同，也不能将批次附加到不同声明/修订。
错误固定值、已更改产物、权限缺失或消息记录缺失/清除都会显示错误；不会回退预览，也不会保留失败读取的绿色观察状态。

<a id="actual-browser-verification"></a>

#### 实际浏览器验证

浏览器执行了真实 HTTP/IRIS 操作，留下以下合成示例供后续演示：

| 路由 | 修订 | 结果 | 记录 ID |
|---|---:|---|---|
| `demo-analysis-onboarding` | 1 | 已注册、单独批准；未激活 | `route-26BFA675-C952-11F1-A15C-A263F534EED8` |
| `demo-analysis-onboarding` | 2 | 已注册，等待新审批 | `route-3293C45E-C952-11F1-A15C-A263F534EED8` |

修订 1 摘要为 `18f88b0a1e3134a562442b4d4fc144421bb39002c637fcc1b0fe4f81c5ac1887`；
修订 2 为 `4736a505f183b21edcdf2609aa3fe2ea41edd7739fe020ed9254f7555f209d09`。
UI 在明确确认前正确禁用了审批，保留修订 2 的待处理状态，拒绝将旧利用批次附加到新修订，
并通过本地回执文件显示两条原始路由的实际证据。已检查桌面布局及 390 像素移动布局，无水平溢出。
合成示例 ID 在全新安装中会不同。

<a id="install-endpoints-and-validation"></a>

#### 安装、端点与验证

前置条件：现有平台 API 和已完成的 P1–P4 环境，包括已编译的路由/证据依赖。不需要额外软件包。

```sh
python3 contest/route_ui_test.py               # inactive by default
python3 contest/route_ui_test.py --install     # compile only RouteUI + API in TRIAGE
python3 contest/route_ui_test.py --check       # read-only local HTTP regression
```

HTTP 回归依赖此本地示例原始 P2/P3 日志和被忽略的本地管理员凭据文件。
它读取数据，并且只提交无效变更请求，不会新注册或审批。运行时测试可能在回滚事务中创建临时记录；
不要针对这些事务夹具并发执行验收读取。

| `/api/monitor/v1` 下的端点 | 用途 |
|---|---|
| `GET /governance?after=…` | 已验证的注册表记录、用户能力、显式分页 |
| `GET /governance/template` | 固定配方和实际当前 utilization 绑定 |
| `POST /governance/register` | 声明、有效期和预期配置摘要 |
| `POST /governance/approve` | 精确 ID/摘要及明确的仅注册表确认 |
| `POST /governance/evidence` | 使用独立回执固定值进行只读历史验证 |

所有 POST 保持现有 JSON、4096 字节正文上限及 `X-Requested-With: IRIS-Workflows` 契约。
身份验证和注册表读取能力适用于每个端点；注册/审批/模板还需要 builder 能力。
拒绝会返回明确错误，并以 `governance.<operation>.rejected` 记录审计。
证据端点不接受原始患者数据、任意命名空间或调用方提供的 `verified` 断言。
这些端点没有新增 CORS 许可、匿名访问或凭据/会话存储。这仍是仅限 loopback 的开发 UI，
不是生产 IAM 或法律审批系统。

验证完成：47 项前端测试、lint/type-check/生产构建、120 项 Python 测试，以及在现有获授权本地终端身份下
运行的六方法 P5 与九方法 P4 IRIS 套件。受限 MCP P5 运行也通过：其注册表测试明确验证没有读取能力时会被拒绝；
特权方法在该路径提前返回。受限结果不构成持久写入覆盖证据；获授权运行覆盖真实事务化注册/审批、
不可变版本冲突、更宽配方拒绝及跨版本证据检查。HTTP 回归覆盖真实读取者/写入者分离、CSRF/正文保护及两个独立固定路由。
原有 26 份报告、4 项评分、5 个 API 基线和冻结风险哈希均未改变；P2/P3 重复批次读取仍保留回执。
四个 Productions 均在运行，活动 utilization 注册保持原样，下游接收方仍有两条记录。

P6 会增加下文描述的独立自动路由观察器。仅记录审批不会授予模型预算或激活路由。

<a id="route-monitoring-p6-automatic-after-send-ai-hub-review"></a>

### 路由监控 P6：发送后自动执行 AI Hub 审查

**当前路由演示：**参见[院内路由演示](./ROUTE-DEMO.md)。下文描述的早期路由试验记录及其关联报告
已根据用户要求明确替换。其运行 ID 和命令是历史开发记录，不是当前演示或可复现的已保存结果。
当前演示使用明确批准的合成内部组织政策、八项事实及条件式问题选择。
数据替换、精确模型同意和验证请使用当前指南。

P6 是**后台 sidecar**，不是逐消息的“开始审查”按钮。现有 TRIAGE `PlatformMonitorInbox` 定时器会调用
`Contest.RouteReview.Tick`。明确启用后，它至多每五秒启动一次独立单例工作器。
工作器会在两个固定来源命名空间中发现已完成批次，捕获并验证其证据，并为每条路由/批次记录一个审查任务。
无需浏览器、HTTP 请求或新交付来触发发现。首次启用时会补录现有已完成批次。
业务 BS/BP/BO 路径不调用观察器，也不等待它。

首次启用需要明确授权后临时停止/恢复**仅 PlatformMonitorInbox**：IRIS 日志显示其长运行服务仍保留旧编译例程。
没有重启实例或 Production；业务组件、来源配置/审批和目标均未变更。
真实观察器工作器以现有 `_Ensemble` 身份运行。没有新增角色、授权、凭据或命名空间映射。
这不能证明生产环境采用了最小权限部署；生产服务身份设计仍是单独的加固工作。

<a id="evidence-budget-and-no-replay"></a>

#### 证据、预算与不重放

- 观察器复用 P4 的最小化六事实数据包、真实消息关联、冻结输出和接收方检查。
  声明的用途/上下文仍是主张；合成审批和有限的已知字段计数不是法律许可、通用 PHI 检测或去标识化认证。
- 两个原始 P2/P3 示例使用各自独立保存的回执摘要作为种子。其他批次使用明确标记的**观察器首次捕获**固定值。
  这能检测后续变化，不检测首次观察前的篡改；哈希不是签名，也不能防止可替换全部记录的管理员。
- 每个验证成功但无资金的批次都会变为 `blocked_budget`，并触发 `coverage_gap` 事件。
  “已观察”不等于“AI 已审查”。无效证据变为 `evidence_failed` / `technical_failure`，
  不调用模型，也不替换成隐私判决。历史不完整/失败的发送不会重放；证据已清除的已完成批次仍保持失败。
- 当前明确授权**仅涵盖聚合 1710 和利用 1730**，每项最多两次模型交互，合计**四次**。
  新批次的模型预算为**零**。发现/排队会自动进行；不会因为说了“监控”就启用无限推理。
- 推理前会持久化预留额。重复配置、服务 tick 或浏览器读取不会刷新已消耗的授权。
  目标集合、来源 Agent 配置及审查契约均已固定。技术失败和中断工作器保留已消耗预留，绝不重试。
  后续工作器会把被遗弃的运行任务标为 `interrupted`，不会标记完成。
- 每个获预算的任务在推理前重新验证已捕获证据，并使用现有 **staged-risk-v3** 运行时：
  一个 `%AI.Agent` 定位会话、服务器端有界规范检索，然后一个 `%AI.Agent` 判定会话。
  每个阶段 `MaxIterations=1`，两个 Agent 均不带执行工具。运行时刻意复用已测试的无工具分阶段设计，
  而非较早的多轮 ToolSet 实验。MCP 是开发工具，不是运行时审查者。不会用伪造标志或情景标签提供预写判决。
- 来源配置使用 `deepseek-flash`、现有固定索引 7 和语料。实际阶段会话、SDK token 计数器、检索包、
  原始建议以及接受/拒绝输出保存在受保护的分阶段报告中。路由视图公开已接受结果、物化引文、关联和会话计数器，
  不公开 API 密钥或原始患者资源。
- 发送后建议是 `manual_review`，绝不会要求“拦截已交付批次”。IRIS 验证输出形状、事实/引文引用和一致性，
  但不证明法律蕴含关系。聚合预设的操作审批不是强制 AI/法律通过的指令。历史和当前审批适用性仍有区别。

<a id="demo-and-human-handling"></a>

#### 演示与人工处理

连接后打开 <http://localhost:5173/governance> 中的 **Route governance** 页面；
**Automatic sidecar monitoring · AI Hub review** 面板每五秒轮询只读结果。它显示观察器启用状态/最近成功扫描、
实际工作器身份、预算缺口、证据失败、已完成结果及明确分页。长时间模型运行可能推迟下一次扫描；
五秒不是端到端延迟保证。刷新失败时，先前值会标记为可能过期。

**Inspect** 只读取任务，不会触发推理。展开可查看已接受问题、引文、缺失信息、绑定的声明/审批/实际证据，
以及 AI Hub 会话/token 计数器。新声明修订不会继承旧批次的审批或观察结果。

获授权操作员可记录明确理由，并令事件在 `open → in_review → needs_information/resolved/ignored`
状态之间转换；已关闭事件可重新打开。服务器检查精确事件修订号和允许的转换。
人工理由保留在本地，不会添加到模型提示中。解决/忽略事件只改变人工工作流，不改变交付、重放、路由激活、
审批或法律合规结果。读取者账户不能执行操作。

此路由专属事件流刻意与旧 DEMO **Operations** 事件及其历史计数器分开。它复用事件转换策略，
但不会把 PIPELINE/UTILIZATION 观察冒充 DEMO 分析观察。不存在自动 Gate 或部署操作。

<a id="commands-and-api"></a>

#### 命令与 API

```sh
python3 contest/route_review_test.py                         # inactive
python3 contest/route_review_test.py --install               # compile only
python3 contest/route_review_test.py --observe               # automatic capture, no new model consent
python3 contest/route_review_test.py --authorize-four-requests # explicit two-batch authorization
python3 contest/route_review_test.py --status                # read only
python3 contest/route_review_test.py --check                 # read-only HTTP boundary checks
python3 contest/route_review_test.py --snapshot              # save and verify completed local evidence
```

这些命令针对此处明确安装的本地示例，依赖原始回执日志和现有 Agent 配置。
`--observe` 不会撤销先前授予的模型同意；重复配置不会重置已消耗预留。
全新环境中启用标志不存在，除非显式配置，否则 hook 不执行操作。
仅安装后端不会授权推理或重启服务。对于仍运行旧版 MonitorInbox 例程的实例，如上所述须经明确授权执行主机重载；
不要仅为加载 hook 而重启 Production。

`GET /api/monitor/v1/route-reviews?after=…` 以每页 25 条列出任务；
`GET /route-reviews/:id` 读取最小化详情。
`POST /route-reviews` 仅接受人工工作流 `{id,revision,action,text}`。
适用现有 KnowledgeRead/MonitorRead 与 Deploy 能力，以及 JSON/CSRF 和 4096 字节保护。
此 API **没有 HTTP 模型启动、预算、发送、重放、审批或部署端点**。

免费的事务化 IRIS 夹具测试必须获取观察器工作器锁并回滚其变更；
不要针对临时夹具并发执行验收读取。受限 MCP 运行检查读取拒绝并跳过特权夹具；
持久化契约需要获授权终端覆盖。测试绝不调用提供方。

<a id="actual-bounded-runtime-result--not-two-successful-judgments"></a>

#### 实际有界运行时结果——不是两次成功判定

现有定时器自动捕获四个已完成历史批次：聚合 1708 因旧配置证据不完整而成为 `evidence_failed`；
利用 1728 保持 `blocked_budget`。只有以下两个使用原始固定值的目标消耗了明确授权预算：

| 原始批次 | 分阶段报告 | SDK 会话 | 实际结果 |
|---|---|---|---|
| `aggregation-20261016-1710` | `risk-evaluation-B74F98D6-C95E-11F1-A15C-A263F534EED8` | 135 / 136 | 定位器返回；判定请求遇到提供方响应正文超时。技术失败，没有接受的判决。 |
| `utilization-20261016-1730` | `risk-evaluation-E629AAAA-C95E-11F1-A15C-A263F534EED8` | 137 / 138 | 输出/引用验证完成；两个风险信号、未解决信息及 `manual_review`。 |

全部**四次已预留/尝试的请求**均保持已消耗；未执行重试、修复或额外推理。超时请求没有记录 SDK 交互/token 计数器，
这**不能证明**提供方没有工作或没有产生费用。其余三个已返回交互报告
**21,114 prompt + 11,633 completion = 32,747 tokens**。
推理 token（10,751）包含在 completion 中；缓存 token（1,280）包含在 prompt 中。
在缺少经验证的定价和完整提供方使用量时，不推断货币费用。

利用结果予以保留，但不认可为法律结论。它关于接收方用途的解释将“未证明存在许可依据”视为风险信号；
人工必须检查这是否混淆了“许可证据尚未收集”与“许可明确失败”。其可关联性关注点同样不能证明某条去标识化路径
适用或失败。结构/来源引用验收无法解决这些语义问题。聚合仍有原始操作审批/交付；
失败的 AI 请求既未撤销审批，也未提供预期的完整聚合判定。

原始报告和捕获记录保存在被忽略的本地文件
`contest/data/evaluations/route-monitor-p6-20261016.json` 中。重复运行 `--snapshot` 会依据该不可变文件
检查当前原始模型报告，而不重新运行；其首次捕获 heartbeat/事件状态是历史数据，不是当前人工工作流。
之后一次合成浏览器工作流检查将利用事件标记为 `in_review`，并明确注明这不是独立法律审查。
该操作与冻结的 AI 报告分开保存，不改变判决，也不调用模型。

页面已检查自动刷新结果、展示超时分类、易读的问题/引文/来源沿袭、人工事件修订转换和响应式布局。
免费验证通过 **51 项前端测试**以及 lint/type-check/build、**127 项 Python 测试**、
获授权 **9 方法 P6**、**6 方法 P5**、**9 方法 P4** IRIS 套件和真实认证 HTTP 边界检查。
这验证自动集成、预算/故障隔离和来源沿袭，**不代表两次成功判定，也不证明法律/语义准确性**。
成功重测聚合需要单独明确授权；原四请求授权不能补充或重放。

集成后检查还确认：原有 26 份分阶段报告、4 项评分、5 个 API 基线和冻结风险哈希均未变化。
P2/P3 重复读取返回原始回执和独立固定的 P4 证据；活动 utilization 声明和两条接收方 SQL 记录保持不变。
四个 Productions 均在运行。任何验证/回读命令都没有创建新的推理授权。

<a id="p6-acceptance-follow-through-explicit-reassessment-not-replay"></a>

#### P6 验收后续：明确重新评估，而非重放

之后用户授权了三项有界检查，**总计额外六次模型请求**：重新评估原始聚合、在修订后的契约下重新评估原始利用，
然后交付一个新合成利用批次并让正在运行的 sidecar 自动发现和审查。明确排除发布和竞赛打包工作。

**审查保留的 V3 利用输出。**操作证据显示七字段输出及配置接收方符合合成审批。
但输出从未收集的许可依据推断接收方用途风险。这不是该依据不存在的肯定证据。
其可关联性问题作为事实局限有依据，但记录未证明某条特定去标识化发布路径适用且已失败。
任何一项关注都不能证明适用法律遭违反。这是 AI 辅助工程审查，不是独立律师意见。
原始提议/结果及其合成 `in_review` 事件均被保留，没有静默重标或重新评分。

**版本化修正。**`Contest.RiskReviewV4` 继承了完全相同的现有定位器、证据读取器、SDK 执行器和引文物化器。
它增加新的判定提示词**和服务器验证的条件链**，而非标签覆盖：

- 每项问题都明确说明适用性、适用性事实引用、条件状态、肯定事实引用和例外审查。
- 风险信号需要适用且状态为 `not_met` 的条件、已解决的例外，以及经验证的**观察类**适用性和肯定失败引用。
  主张/缺失信息事实不能充当这些引用。
- 未知的适用性/条件保持 `unresolved`，没有肯定满足/失败引用，并明确列出缺失信息。
  无风险信号同样不能隐藏未知的适用条件。
- 真实观察到的接收方/控制失败可与另一个未知法律依据并存。正向和负向夹具测试验证两个方向；
  不向模型提供预设期望标签。
- 字段最小化、范围匹配和合成注册表审批都不会被视为通用法律许可。
  稳定 ID 仍可关联，但其本身不证明适用的去标识化路径失败。
- 旧 V1–V3 提示词、契约、冻结开发集和结果均未改变。V4 使用自身契约，不能消耗 V3 同意。

这只能保护结构一致性和事实来源，不能证明语义蕴含：无关的已验证事实仍不能证明适用性。
仍需人工语义审查。

**超时调查。**原始聚合定位器已返回；判定在解码提供方响应正文时发生超时，未记录任何判定文本或用量。
检查序列化中的保留判定输入约为 73 KB，低于运行时 80,000 字符输入保护；
利用约 72 KB 的输入成功。这些观察不能证明输入大小、IRIS 路由或任何特定 SDK 超时设置是根因。
已检查实际安装的 `%AI.Provider` 和 `%AI.Agent` 定义；没有增加未文档化的超时键或隐藏重试。
没有截断完整固定规范文本来换取更快或更有利的回答。新尝试单独授权并记录；
成功重测只能证明恢复，不能证明底层提供方超时已修复。

**授权与新任务身份。**仅终端可用的 `AuthorizeAcceptance` 只接受两个已固定的历史目标和一个此前不存在的 utilization
批次，每项最多两次请求。授权 `p6-v4-20261016` 是不可变记录，保存精确来源/契约配置；
重复应用不能补充已消耗额度或替换另一个批次。每项历史重新评估有新的任务后缀及
`parent_review_id`；旧报告和预算不变。触发类型明确为 `explicit_reassessment`，
不会错误标成新投递。

新批次 `utilization-20261016-acceptance-v4` 在投递**之前**针对现有审批 ID、
范围摘要和运行时配置摘要授权，不臆造未来回执。真实 BS/BP/BO 发送创建一行 SQL 接收记录；
独立定时器随后采集首次观察回执固定值，精确授权在预留前检查获批范围/配置。
保存的实际回执会在投递后独立核对该固定值。
此项检查不新建 Production、不激活路径、不产生新审批版本，也不更改凭据。

Demo 现在显示 reviewer 版本、触发/父任务身份、条件链，并将原授权和新授权计数分别分组。
打开/检查页面仍为只读，任意未来批次仍为零预算。

明确的副作用命令：

```sh
# Separate explicit user consent is required for these side-effecting modes.
python3 contest/route_review_test.py --authorize-acceptance-six
python3 contest/route_review_test.py --deliver-new
# Read-only verification, once all three funded tasks reach completion:
python3 contest/route_review_test.py --acceptance-snapshot
```

验收快照检查真实会话、精确来源 Agent/索引、输入关联、六次请求上限、完整冻结规范文本哈希、
物化引文偏移/文本及先交付、后自动捕获的顺序。如果超时、输出被拒或任务不完整，它会失败，
而不是给出验收通过。原始 P6 快照仍可单独验证；增加新授权不会改写旧模型报告。

**观察到的验收结果。**三个新获授权任务均完成，未发生提供方或输出故障：

| 检查 | 新报告 | 会话 | 结果 |
|---|---|---|---|
| 原始聚合重新评估 | `risk-evaluation-1010A5A5-C97A-11F1-A15C-A263F534EED8` | 139 / 140 | 两个未解决条件；无肯定风险结论；人工审查 |
| 原始利用重新评估 | `risk-evaluation-3ED3C78A-C97A-11F1-A15C-A263F534EED8` | 141 / 142 | 两个未解决条件；无肯定风险结论；人工审查 |
| 新利用交付和自动审查 | `risk-evaluation-658CCB6C-C97A-11F1-A15C-A263F534EED8` | 143 / 144 | 两个未解决条件；无肯定风险结论；人工审查 |

模型区分了操作范围/接收方匹配与尚未确立的法律许可，也区分了残余可关联性与适用去标识化路径失败。
这纠正了这几次运行中特定的“缺失证据升级为风险”问题。**这不是合规通过**：
三者的适用性/条件状态仍未知，肯定失败引用均为空。缺失信息列表仍包含可能过于宽泛的文档要求；
专家认定/安全港文件只有在确认所依赖的发布路径后才属于条件性要求，并非每条路由都自动必须提供。
此限制仍然可见，没有被过滤以提升分数。没有声称普遍语义/法律准确性或经过独立审查的基准性能。

新批次使用了实际消息 **21**、接收方请求消息 **22** 和会话 **28**。
其交付回执摘要为 `ebb8b321cddd1357eb54925f66b64f7b6cec11c6d6a9ca17434a2f942e506d48`；
保留原利用范围摘要 `60eeefd006d7a458f15403e7381c74307b282b6f79bd854fb70df214c0b3108f`。
交付记录的 IRIS UTC 时间为 `5863074947.520976`；独立后台观察器在 `5863074951.7834` 捕获，
约 **4.26 秒后**。该测量验证此批次实际先交付后观察，不是通用延迟 SLA。
新任务标记为 `new_completed_batch`；交付命令和页面都不会调用 `Pump` 或启动其审查。

不可变本地日志保存在被忽略的
`contest/data/evaluations/route-monitor-p6-v4-20261016.json`，旁边还有新批次独立原始回执。
验证器根据完整冻结规范文本检查了 **29 条物化引文**，包括精确段落偏移和来源哈希。
全部六次新模型交互彼此独立，每个 SDK 阶段一次，共报告 **58,083 prompt + 39,426 completion = 97,509 tokens**。
推理 token（35,749）包含于 completion，缓存 token（6,272）包含于 prompt。
没有额外模型请求、自动重试或基于价格的费用估算。

浏览器展示了新旧两次尝试、六次预留额度、明确的未知条件链和规范来源沿袭。
一次合成工程工作流检查将新事件从 `in_review` 转为 `needs_information`，
并记录本地说明：应先确立发布依据，不应将每种去标识化文件都视为强制要求。
这是已演示的人工工作流机制，不是独立法律审查。它既未更改 AI 结果，也未调用模型。

免费回归现通过 **52 项前端测试**、lint/type-check/build、**130 项 Python 测试**、
获授权 **7/7 V4 契约**、**11/11 路由生命周期**、未更改的 V3、P5、P4 IRIS 套件及认证 HTTP 边界检查。
受限 MCP 运行检查公共契约/读取拒绝行为；获授权终端运行覆盖持久化夹具。
历史模型日志、原 26 份报告/4 项评分/5 个 API 基线/冻结哈希和审批版本均未改变。
唯一预期的下游数据变化是一份新合成回执（两条记录 → 三条）；未重启 Production、未新激活、
未扩大权限，也未进行发布准备。

<a id="non-billing-integrated-acceptance"></a>

## 非计费集成验收

使用上述安装/配置，然后运行：

```sh
python3 contest/platform_test.py
python3 contest/agent_test.py
python3 contest/event_test.py
python3 contest/rule_test.py
```

事件测试创建真实合成失败，检查五个竞争人工修订（一个接受/四个冲突），保存本地意见证据，
并检查没有新增 Agent 任务。规则测试创建自身合成事件及已保存意见，要求 DEMO 初始处于非强制模式，
检查读取者拒绝、无效 AST/意见/哈希拒绝、不可变准备、来源修订冲突、实际 held/delivered 探测、
匹配回执以及单独批准的回滚。其最终策略为非强制；已拦截消息和事件/计划历史仍可查看。
不会调用模型。

`Contest.EventTests` 和 `Contest.RuleTests` 使用无操作且由外部管理的 TestProduction 控制器。
它们验证来源选择、schema-2 契约、事件幂等性/转换、有界 AST/类型/运算符、未知判定、
规范哈希及不绕过审批状态的拒绝。它们补充实际 HTTP/Sink 验证，不是模型质量测试。
正常重启持久性另行测试；不声称覆盖突然崩溃注入或通用故障转移。

在开发实例上，正常 IRIS 容器重启后，索引 7、Agent 版本/作业、事件/意见、策略修订 6 及其计划、
P2 观察器和已保存 AI 摘要均通过精确前后比较保持不变。两个受管 Productions 均已恢复。
直接来源检查发现三条被拦截业务记录及零条对应 Sink 写入。
这些是合成的本地验收观察，不是性能或通用故障转移保证。
