# AI Hub message triage（隔离的 EAP 演示）

[English](README.md) | [简体中文](README.zh-CN.md)

此 fork 在 IRIS Interoperability Production 中加入运行时 AI Hub 决策。
当前分支已移除继承而来的应用程序栈；根目录 Compose 入口现包含此隔离部署。
不会修改上游仓库或其他本地项目。

**现场入门演示：**使用固定的 [M5 入门说明](./M5-ONBOARDING-DEMO.md)
或[中文版本](./M5-ONBOARDING-DEMO.zh-CN.md)，从
<http://localhost:5173/demo/m5> 开始。输入机构资料、登记现有 M5 Production、
触发新消息并授权真实审计。限定范围的重置会归档 M5 逻辑状态，不会清除原始消息/
模型报告，也不会更改其他演示。

**历史已保存结果演练：**遵循[固定 Production 演练和五分钟英文录制脚本](./DEMO-WALKTHROUGH.md)。
中文分步操作、系统 URL 和演示重点见[中文演示指南](./DEMO-GUIDE.zh-CN.md)。
该演练检查已保存的真实治疗/风险/未知结果，不会发起新的模型调用；它说明用户输入的演示
前提，并保留首次修复历史。这不代表视频已经录制或发布。

新的一切从声明开始的工作流请参见[设计、D1 实现和开发顺序](./DECLARATION-WORKFLOW-PLAN.md)。
D1 提供有版本的提案持久化及审查/决定约定。D2 增加真实异步 AI Hub 提案审查。
三个验收场景现在都有经过验证的真实结果：内部质量改进/未发现风险、外部营销/发现风险，
以及未指明的二次用途/需要信息。常规用途案例在保留两次失败后，于版本 3 通过。
[D3 浏览器工作区](http://localhost:5173/declarations)现在支持新建提案、明确授权 AI 审查
费用、查看结果/证据、版本历史，以及人工退回/拒绝/批准决定。D4 增加确切批次执行计划、
批准/配置检查、接收方重新验证和关联的 SQL 回读回执。经授权在本地双主机重新加载后，
浏览器确认的新批次完成了真实 BS/BP/BO 投递和 SQL 回读。重复运行同一命令两次会返回
同一回执，不会增加行或消息。首个失败批次仍保留，SQL 行数为零。
D5 现在会自动采集已投递的声明批次，并在单独取得有界模型同意后，将实际使用情况与其
确切获批版本进行比较。真实 D4 批次通过发送后比较和浏览器人工事件审查；之后接收方行为
仍不在观测覆盖范围内。旧版固定路由页面仍然独立存在。

**D1-D6 声明工作流验收已完成。**重新检查已保存的真实常规/风险/缺少输入结果、
修正版批准、实际投递、自动比较、人工处理和历史 SDK 用量；无需新的模型请求或投递：

```sh
python3 contest/declaration_acceptance_test.py --check
```

在仓库根目录针对现有本地演示运行。它需要已配置的本地 API 和 admin 凭据文件；
若演练证据缺失或已更改，命令会以 fail-closed 方式拒绝通过。
参见[浏览器演练和负例矩阵](./DECLARATION-WORKFLOW-PLAN.md#d6-unified-end-to-end-acceptance)。
这完成的是范围受限的应用工作流，不是对任意接收方或管道的支持；竞赛发布准备工作另行进行。

**[Productions 工作区](http://localhost:5173/pipelines)**还会发现活动的本地 IRIS
Productions，并允许用户明确将每个 Production 登记为独立观测对象。它提供各 Production
的运行事件、审查备注、暂停/恢复操作，以及关联的既有业务风险历史。通用观测默认为元数据，
并明确展示覆盖缺口；M2 还支持单独授权的本地检查，读取已登记的 FHIR/JSON 消息属性。
这两种路径都不会自行推断 HIPAA 结论。参阅[设置、来源归属、API 和两个 Production
实际验收](./MONITORING.md#managed-active-productions)。对新管道可复用的业务风险监控
是单独的 M1-M5 扩展，并非运行监控登记所隐含的能力。
**Production 是唯一登记单位**：用户发现正在运行的 Productions 并选择要管理的对象，
无需登记单个业务流程。早期 M1 手动流程目录仅作为可选的、有版本的审查上下文保留；
不得用它筛选或限制采集。M2 现在无需逐路由登记，即可记录真实消息边、与会话关联的不可变
观测，以及经同意的本地结构化属性事实。独立的三路由合成 Production 已通过真实五批次证据验收。
M3 现在增加单独付费、限定在 Production 范围内的抽样，以及分两阶段的 AI Hub 审查；
包含规范来源、经过验证的引用、持久请求预算，以及明确的信息缺口/失败。
三个已保存的 A/B/C 观测已完成真实审查，无需人工上下文或新业务发送：六个请求、
报告 token 数 68,373，验证引用十一条。它们都正确要求补充缺失的业务上下文，
没有声称存在违规或合规。该验收授权已撤销。已保存结果也会显示在现有 Production
风险信息流中。M4 现在在 Production 工作区展示真实消息边、按会话筛选的证据、
采集/审查覆盖、确切来源的审查详情，以及相互独立的检查/模型授权控件。
可选语义上下文仅用于补充信息，不是流程登记的前提。M4 验证未使用新的模型预算或业务投递。
M5 的技术/本地规则测试已在单独登记的合成接入适配器上通过：实际接入 A/B/C/D 四批，
自动发现 D 的首个活动；两个范围受限的无偏差结果、一个明确的本地最小化风险，
以及一个缺少业务信息的结果。消息/会话/配置和 SQL 回执哈希共同绑定证据；
不需要手动流程上下文。四次真实审查共用了八个请求、98,219 个报告 token 和十一条已验证引用，
模型授权已撤销。这只验证了受支持的接入约定。**在明确记录输入映射修复后，M5 的范围受限
演示验收现已完成**，但这不是现实世界的合规认证。
仅仅检查了本地规则和精确引文，并不能证明 HIPAA 评估可靠。单独的前瞻性八案例 Privacy
Rule 条件基准已通过所有预先声明的自动检查（16 个请求、158,476 个报告 token、31 条精确引用），
涵盖治疗例外、心理治疗记录授权、付费营销、自身质量运营和 Safe Harbor ZIP 阈值。
它基于规定事实测试，使用助手编写且未经过独立专家验证的 oracle，也不证明现实世界事实覆盖。
**此演示不要求集成真实系统**：Production 批准 UI 现在接受按会话范围、由用户确认的接收方、
目的、许可/授权、保障措施和例外。这些可作为模拟前提使用，并与服务器端批准者/时间一起冻结，
同时与采集到的消息证据分开显示；明确的未知项仍保持未知。不需要逐流程登记，也不需要连接
真实医院/合同系统。
实时 Production 验收现在覆盖治疗披露（无范围内信号）、明确缺少授权的付费营销（风险），
以及接收方/许可未知（需要信息）。首次通过率为 **2/3**：治疗场景正确询问技术主机和消息数据
如何映射到业务场景。现在有两个明确表单输入可捕获该映射和数据范围。经单独授权后，
发送的一条新治疗消息通过了未更改的 oracle；原未解决报告仍予保留。包括首次尝试在内总计：
**4 次合成发送、8 个请求、116,871 个报告 token、15 条精确引用**。四项模型授权均已撤销。
无需推理即可读取原始和后续报告：

```sh
python3 contest/production_premises_test.py --check-complete
```

参阅[实现状态和约定边界](./MONITORING.md#business-flow-risk-monitoring-m1-m5)。
竞赛控制平面、AI 审查器、治理和审计记录位于独立数据库支持的 **TRIAGE** 命名空间。
独立管理的业务演示保留各自命名空间；隔离的 M2 和 M5 验收 Productions 分别使用
**OBSERVATION** 和 **M5OBSERVATION**。

安装程序会创建此命名空间并调用 `%EnsembleMgr.EnableNamespace("TRIAGE")`。
Interoperability 会自行配置系统库映射。安装程序不会将 `Ens`、`EnsLib`、`%AI` 或应用程序
包手动映射到 `USER` 或 `HSLIB`。BP 和 AI Hub 工具在 TRIAGE 中执行，不需要切换命名空间。

## 前置要求

下一阶段监控/安全审查使用独立的
[HIPAA 知识输入](../hipaa-demo-knowledge/README.md)。
`knowledge.py` 可准备/选择 `demo` 或 `full` 输入；当前分诊运行时尚未导入这些内容，
也不会执行 HIPAA 审查。完整来源归档及本地 full 配置不纳入 Git。

可选的开发时 MCP 和 Copilot Interop Skills 请参阅[开发指南](./dev/README.md)。
这些工具与下文所述的运行时 AI Hub SDK 不同。

- Docker Compose 2.24.4+，并且有足够资源再运行一个 IRIS 实例
  （真实服务提供方 override 使用 `!override`）。
- 由本地获取的 AI Hub EAP 镜像；已在 ARM64 IRIS for Health `2026.3.0AI.154.0` 上测试。
  EAP 是预发布软件；请通过官方分发流程获取镜像和适当许可证。继承而来的 Community
  2026.1 部署不再使用，也不能替代 AI Hub。
- 将自己的许可证放在仓库根目录的 `iris/license/iris.key`，或设置 `IRIS_LICENSE_PATH`
  为绝对本地路径。不会分发许可证。
- 测试运行器需要 Python 3。不需要额外 Python 软件包。

## 启动和测试

从仓库根目录运行：

```sh
python3 contest/prepare.py
docker compose -p iris-triage -f contest/compose.yaml --profile mock up -d --wait
python3 contest/test.py --restart
```

默认使用**本地合成 mock 服务提供方**，不执行真实模型推理。它仍会运行真实的 AI Hub SDK、
已注册 ToolSet、Business Process、Business Operation、持久化目标和审计记录。
`gpt-4o-mini` 只是 mock 配置中的、支持工具的模型标识；这些测试不会调用该外部模型。

Gateway 发布地址为 <http://127.0.0.1:52777/csp/sys/UtilHome.csp>。
`prepare.py` 会生成被 Git 忽略的本地密码文件。安装程序配置专用 `ContestGateway`
服务用户（没有应用或管理角色），Gateway 使用该用户通过私有 Docker 网络进行带密码的
IRIS 连接。已验证 Portal 登录页返回 HTTP 200；请使用 IRIS 管理员凭据登录并选择 TRIAGE。
此服务账户不是 Portal 管理员。不要仅凭容器健康状态判断 Portal 已验证。
如需**仅限本地演示**的管理员，可运行 `python3 contest/prepare.py --portal-admin`，
并输入/确认密码。被忽略、权限为 mode-600 的 `contest/data/portal-admin-password`
文件会在启动时读取，用来将 `superuser` 配置为具有 `%All`、账户启用、密码永不过期、
首次登录不要求更改密码。没有此文件时，安装程序不会更改管理员账户。
只要文件存在，本地密码会在每次启动时重新应用；删除该文件并轮换账户密码即可停止此行为。
这不会更改独立的 Gateway 服务用户、实例级密码策略或其他用户。切勿在公共/生产实例上使用
弱密码/共享密码或永不过期的管理员凭据。随附 Apache 配置会拒绝 Gateway 管理路径。
mock 和 IRIS Superserver 都不会通过宿主机端口暴露。

数据持久化在被忽略的 `contest/data/dur/`。若要创建独立的干净实例，请使用另一个 Compose
项目名、不同且未占用的 `TRIAGE_WEB_PORT`，以及指向新建可写空目录的绝对路径
`TRIAGE_DATA_PATH`。不要将其指向原应用程序的数据目录。实例会自行创建 `irissys` 子目录。

停止但保留数据：

```sh
docker compose -p iris-triage -f contest/compose.yaml --profile mock down
```

## 工作流和证据

当前 SQL/FHIR 聚合和内部质量改进 sidecar 请参阅[内部医院路由演示](./ROUTE-DEMO.md)。
它使用明确的合成组织策略、确切的项目批准和真实投递观测，并提供彼此分开的破坏性演示替换
和付费推理命令。以下工作流描述的是原始消息分诊切片。

1. `Contest.Setup.Submit` 通过测试 Business Service 向 `Contest.Process` 发送 `Ens.Request`。
2. IRIS 从合成 JSON（`reference`、`code`、`value`）导出事实。只有完整性和已知代码标志会
   提供给 Agent，不会提供原始消息内容。
3. AI Hub Agent 调用只读 `GetTriageFacts` 工具。该工具只允许访问绑定到当前 BP 作业的案例。
4. BP 验证 JSON 操作和理由。对于不完整消息或不属于 `OBS`、`LAB` 的代码，禁止投递。
5. 同步的 Business Operation 会原子地持久化一个目标和最终状态：`delivered`、
   `quarantined` 或 `pending_review`。
6. `Contest.Event` 记录接收、工具访问、决定、策略和执行。`Contest.Case` 包含 IRIS
   消息/会话 ID、AI Hub 会话 ID、模型、模式、耗时、事实、服务提供方报告用量和错误。
   当前用量描述最终 SDK 响应，而不是每个工具循环请求的总和。不会根据这些不完整计数推算
   已计费费用。

投递目标是本地持久化演示接收端，不是外部系统。隔离和人工审查是持久化工作队列；
尚未实现操作员审查/处理 UI，也没有自动重放。成功的重复请求会返回原结果，不会再次调用
模型或写入目标。冲突 ID 和失败/不完整的重试会被拒绝，不会静默重放。

查看证据：

```sh
docker compose -p iris-triage -f contest/compose.yaml exec iris iris session IRIS -U TRIAGE
```

在 IRIS 终端中：

```objectscript
Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT ID,ExternalId,Decision,Policy,Outcome FROM Contest.""Case""") Do rs.%Display()
Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT CaseId,Stage,Detail FROM Contest.Event ORDER BY ID") Do rs.%Display()
Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT CaseId,Queue FROM Contest.Destination") Do rs.%Display()
```

## 真实服务提供方验证

此演示中不要使用真实患者数据。将经授权的服务提供方配置放入仓库根目录、被 Git 忽略的
`.env` 文件：

```dotenv
LLM_BASE_URL=https://your-provider.example/v1
LLM_MODEL=your-tool-capable-model
LLM_API_KEY=your-local-key
```

不要将实际凭据复制到文档或 Git。使用独立数据库启动单独的真实服务提供方实例
（不启动 mock 服务）：

```sh
python3 contest/prepare.py
docker compose --env-file .env -p iris-triage-real \
  -f contest/compose.yaml -f contest/real.yaml up -d --wait
COMPOSE_PROJECT_NAME=iris-triage-real python3 contest/test.py --real --restart
```

这会发出真实外部请求，可能产生服务提供方费用。发送的只有合成案例 ID 和布尔事实，
不会发送原始输入消息。真实服务提供方 override 会将 API key 作为容器环境变量注入；
Docker 管理员可以检查到它。使用真实凭据时不要打印 `compose config` 或环境转储。
请限制 Docker 访问。真实 Portal 位于
<http://127.0.0.1:52779/csp/sys/UtilHome.csp>。

若要在不发起任何新推理调用的情况下重新检查持久化：

```sh
COMPOSE_PROJECT_NAME=iris-triage-real python3 contest/test.py --real --persistence-only
```

服务提供方必须支持此 EAP SDK 使用的 OpenAI 兼容 Chat Completions 工具调用协议。
mock 回归套件不是模型质量基准。切勿对真实服务提供方实例运行 mock 故障注入；
基础测试会在发送请求前验证所请求的模式。

## 验证状态（2026-10-15）

已使用全新的数据目录完成验证，没有沿用原探测环境的 `USER` 或 `HSLIB` 配置：

- 创建独立数据库和命名空间；启用 Interoperability。
- 12 个应用类全部编译通过，无需手动映射包或例程。
- 使用合成服务提供方，完成真实 BP → AI Hub → 只读 ToolSet → 策略 → BO 执行，
  覆盖三个持久化目标。
- 重复投递抑制、冲突 ID 拒绝、无效 JSON 失败和持久化失败证据。
- 八种 mock 故障场景：不安全投递、未知操作、理由为空、字段类型无效、JSON 格式错误、
  跨案例工具访问、跳过事实工具以及服务提供方 HTTP 503。每种场景都会检查明确失败、
  持久化证据、目标写入数为零，并拒绝自动重试。
- IRIS 重启期间，案例、目标内容和有序审计历史保持不变；重启后重复提交不会重复推理，
  也不会增加目标写入。
- 经过身份验证的 Gateway 连接、Portal HTTP 200、Gateway 管理页面 HTTP 403。
- 通过本地配置的兼容服务提供方进行了真实 `deepseek-flash` 推理：三条路由、真实事实工具、
  AI Hub 会话、用量和重启持久性检查均已通过。

验收结果和限制参阅上文。
这完成的是最小化终端驱动演示验收，不是生产或竞赛发布认证。操作员处理 UI、外部投递、
负载/并发/崩溃恢复测试、完整循环 token/费用核算和广泛模型质量评估仍在此里程碑范围之外。
