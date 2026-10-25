# Production HIPAA 风险审核演示指南

**语言：** [English](./DEMO-GUIDE.md) · 简体中文

**当前现场完整演示请使用：[M5 从纳管到审计操作指引](./M5-ONBOARDING-DEMO.zh-CN.md)。**
固定对象为 `M5OBSERVATION / Contest.M5.Production`，从录入机构到现场触发和审核，
不以历史报告回放替代。本页后续多机构和编号案例保留为历史参考；
M5 专用重置会归档旧监控视图，不能再要求旧编号出现在当前清单里。

## 新主演示：FHIR 向三个机构分发

新场景的完整安装、协议边界与验收命令见[多机构演示说明](./MULTI-ORGANIZATION-DEMO.md)。
下文原有 M5 编号案例仍保留为历史演示，不要与新场景的消息编号混用。

| 入口 | 地址 | 主要看点 |
|---|---|---|
| 机构档案 | [Organizations](http://localhost:5173/organizations) | 填入示例后可编辑；确认机构职责、业务关系和接收范围；保留版本 |
| 新主演示 | [Synthetic demo](http://localhost:5173/demo) | FHIR 来源、三个真实协议分支、接收回执和逐机构 AI 审计 |
| Production 观测 | [Productions](http://localhost:5173/pipelines) | 选择 `DEMODISTRIBUTION / Contest.Multi.Production`，查看实际路径、Business Partner 和人工事件处理 |
| 原 Connector 演示 | [Legacy demo](http://localhost:5173/demo/legacy) | 原来的演示仍可访问，不与新场景混用 |

建议按六步展示：

1. **机构档案**：源医院加三个接收机构，共四份档案。“填入示例”只填表；点击 **Save for demo** 保存为场景前提并生成版本，无需另勾确认。
2. **观测授权**：在 Productions 发现 Production，点击 **Enable read-only monitoring** 开启监控。已纳管的对象直接显示状态。通用 Production 的消息字段检查仍有独立操作按钮，但不再要求先勾选。
3. **准备与分发**：回到新主演示，点击 **Prepare demo data** 准备合成 FHIR 数据；选择案例后点击 **Run distribution**。这两步不再要求勾选。三个机构分别位于 `DEMOQUALITY`、`DEMORESEARCH`、`DEMOCLINIC`。
4. **实际接收证据**：SQL 看真实列和入库回读，REST 看实际 JSON 和回执，HL7 看 PID 字段、MLLP ACK 与保存的报文。对照“允许接收”与“实际发送”。
5. **AI 审计**：只保留一个模型费用确认框，再点击 **Run AI audit**；每次运行最多三份审核、六次模型请求，无自动付费重试。不重复确认“这是合成数据”。AI Hub 在 `AdvisoryAudit` BP 内执行，旁路审核不拦截发送。
6. **读结果**：先看 Result / Why / Next step；需要追问依据时再展开法规引文、AI Hub sessions、用量和原始输出。技术失败不是无风险，尚未审核也不是无风险。

风险主线是：**研究中心的接收约定及消息声明都要求 Safe Harbor 去标识化，但实际 REST 输出仍有姓名、MRN 和完整出生日期。**
治疗诊所则作对照：同类身份字段不应脱离实际治疗背景一概判违规。
修正研究输出只证明移除了这些选定字段，不等于完整 Safe Harbor 合规。

查看已有运行或打开 `/demo?run=<已保存编号>` 不会重新发送或调用模型。
没有真实医院、合同系统或真实患者；确认的机构档案是 Demo 内成立的业务前提。

**直接展示已验证的结果：**
[打开本轮主演示](http://localhost:5173/demo?run=multi-fe23cf92-73ec-45dc-91cc-77b0828e27dd)。
研究分支实际发现 Safe Harbor 条件风险；其他研究许可是否成立仍单独标为待补充。
质控和治疗分支仅在所检查的问题上未发现风险。
真实审计 BP session 是 `59`，AI Hub sessions 是 `219–224`；查看这些记录不产生新费用。
首次模型超时的失败记录仍保留，没有被“修正”为成功。

## 1. 演示目标与路线

本指南用于当前本地 Demo 环境，按以下顺序演示：

**选择 Production → 查看实际消息 → 说明用户审批背景 → 展示三类评估结果 → 查看依据与审计记录。**

演示要讲清楚的核心能力：

> 用户选择要监管的 Production；系统采集实际消息，结合用户审批时提供的业务背景，由真实 AI Hub Agent 判断 HIPAA 条件，并展示评估结果、法规依据和需要补充的信息。

本指南默认**查看已经实际执行并保存的结果**，不新增消息、不调用模型。
这不是静态假数据页面；但查看历史报告也不能说成“现场正在进行推理”。

### 适用范围

- 用户填写并确认的业务背景，是 **Demo 内成立的场景前提**，不要求接入真实医院、合同或授权系统。
- 用户提供事实，不是选择或指定模型答案；不明确的内容可以填写未知。
- 监管对象是整个 Production，不需要逐条业务流登记。
- 本次展示的是**消息发送后的风险审核和提示**，不是发送前拦截。
- “所检查问题未发现风险”不代表整个机构通过 HIPAA 合规认证。
- 接收方后续真实使用行为不在当前观测范围内。

## 2. 系统地址与入口

以下地址对应目前的**本机部署**。在另一台电脑打开 `localhost`，访问的是那台电脑自身，而不是此演示环境。当前 HTTP 服务仅适用于本地演示，不应直接暴露到公网。

### 2.1 主演示必用地址

| 系统 / 页面 | 地址 | 用途 |
|---|---|---|
| Production 监管主页面 | [http://localhost:5173/pipelines](http://localhost:5173/pipelines) | 本次演示主入口；发现、选择 Production，查看消息和审核结果 |
| IRIS Management Portal，真实 AI Hub 环境 | [http://127.0.0.1:52779/csp/sys/UtilHome.csp](http://127.0.0.1:52779/csp/sys/UtilHome.csp) | 可选辅助展示，检查 namespace、Production 和实际互操作消息；需单独登录 |

主演示通常只需要第一个地址，**不必在多个页面之间反复切换**。
前端通过本地代理访问当前 `52779` IRIS 环境。

### 2.2 可选补充页面

| 页面 | 地址 | 什么时候用 |
|---|---|---|
| 工作区概览 | [http://localhost:5173/overview](http://localhost:5173/overview) | 简短介绍平台导航，不作为本次审核结果的主要证据 |
| 数据使用申请与审批 | [http://localhost:5173/declarations](http://localhost:5173/declarations) | 补充介绍独立的申请、版本、AI 审核和人工审批工作流；不是本次 Production 案例的必经步骤 |
| Agents | [http://localhost:5173/agents](http://localhost:5173/agents) | 可选介绍 Agent 配置与版本；本次具体模型调用记录以消息报告内部为准 |
| Knowledge | [http://localhost:5173/knowledge](http://localhost:5173/knowledge) | 可选介绍知识检索与来源；不要为演示随意重建索引 |
| Runs | [http://localhost:5173/runs](http://localhost:5173/runs) | 查看其他独立评估任务；本次四份 Production 报告请在 Productions 内查看 |

### 2.3 避免混淆的地址

| 地址 | 说明 |
|---|---|
| [http://127.0.0.1:52777/csp/sys/UtilHome.csp](http://127.0.0.1:52777/csp/sys/UtilHome.csp) | 基础 mock 部署使用的 Portal 地址，只有相应服务已启动才可访问；不是本次真实模型验收所用的 `52779` 环境 |
| [http://localhost:5173/governance](http://localhost:5173/governance) | Legacy routes 页面，属于另一条固定路由治理演示，不要误当作本次 Production 主入口 |
| [http://localhost:5173/demo](http://localhost:5173/demo) | 原有 Synthetic demo 页面，不是本指南的三类 HIPAA 审核结果页面 |

### 登录说明

- 在工作区登录页使用现有的本地授权账号；本指南不记录密码、API Key 或授权头。
- 如果本地登录页已预填演示账号，仍需点击 **Sign in**，不会自动登录。
- 工作区各页面共用当前登录身份；整页刷新、打开新标签页后可能需要重新登录。
- IRIS Portal 与前端工作区不是同一登录会话。
- 普通只读账号可查看其有权访问的记录；发现、审批等管理操作需要相应权限。

## 3. 固定演示对象与案例速查

### 演示对象

| 项目 | 值 |
|---|---|
| 前端页面 | Productions，路径 `/pipelines` |
| 业务 namespace | `M5OBSERVATION` |
| 业务 Production | `Contest.M5.Production` |
| 控制平面、审核与审计 namespace | `TRIAGE` |
| 选中对象的按钮 | **Inspect M5OBSERVATION / Contest.M5.Production** |

### 四份实际报告

| 演示顺序 | 案例 | Session | 代表性消息 Header | 点击按钮 | 预期显示 |
|---|---|---|---|---|---|
| 1 | 普通治疗披露，已补齐消息与业务的对应关系 | 30 | 30 | **Review detail 30** | `no signal on checked issues` |
| 2 | 付费营销，明确缺少所需个人授权 | 22 | 22 | **Review detail 22** | `risk identified` |
| 3 | 接收方、用途或许可条件未知 | 26 | 26 | **Review detail 26** | `information required` |
| 4，可简短对照 | 首轮治疗案例，对应关系未说明充分 | 18 | 18 | **Review detail 18** | `information required`，保留的首轮结果 |

这里的 Header 和 Session 是**当前本地验收环境的历史编号**，不是所有部署通用的固定编号。
每份报告需要先在 Productions 页面选中对应 Production，再点击详情按钮；
当前没有按这些编号直接定位报告的前端独立页面 URL，不要自行拼接查询参数。

新克隆的仓库不携带完整本地验收数据库和被 Git 忽略的运行记录，启动基础环境不会自动生成上述四份报告。

## 4. 演示前检查

1. 打开 [Production 页面](http://localhost:5173/pipelines)，完成登录。
2. 确认 inventory 中存在 **M5OBSERVATION / Contest.M5.Production**。
3. 点击其 **Inspect** 按钮，确认页面没有错误提示。
4. 确认四份报告可在 **Sampled review records** 中找到；必要时使用
   **Older review records** 翻页。消息证据列表与审核列表各自独立分页。
5. 确认相关 `m5-premises-*` 模型授权显示 **Revoked**。
6. 如需终端核验，在仓库根目录运行：

   ```sh
   python3 contest/production_premises_test.py --check-complete
   ```

   这是只读检查，不发送消息、不调用模型。需要现有本地服务、凭据文件和持久化报告。
   最后应看到：

   - `status: passed_after_explicit_input_mapping_repair`
   - `first_pass: 2/3`
   - `all_grants_revoked: true`
   - `new_model_calls: 0`
   - `new_business_sends: 0`

如果没有数据或检查失败，先排查环境，不要清理历史数据、重置 journal 或直接重新执行付费验收。
本指南中的端口和结果来自既有配置与验收记录，不表示这些服务在任意时刻都自动在线。

## 5. 分步演示与主要看点

### 第一步：发现并选择 Production

**入口：**[Productions](http://localhost:5173/pipelines)。

**操作：**

1. 点击 **Discover active Productions**。
2. 展示发现的 namespace / Production 列表。
3. 回到 inventory，点击 **Inspect M5OBSERVATION / Contest.M5.Production**。
4. 本对象已纳管，无需再次点击 **Enroll selected Production**。

**主要看点：**

- 系统扫描可访问的 IRIS namespaces，发现正在运行的 Productions。
- 用户选择监管对象，不是让系统不加区分地接管所有业务。
- 纳管单位是 Production，内部多条业务路径都属于观测范围，不需要逐流登记。
- 纳管不会重启、修改业务 Production，也不会自动授予消息内容读取和模型付费权限。

**建议讲法：**

> 先决定监管哪个 Production。选中后，监控覆盖其组件活动，而不是只监控手工挑出来的一条路由。

### 第二步：查看实际消息与业务路径证据

**位置：**所选 Production 的实际消息边、**Message evidence and session correlation** 等区域。

**操作：**

1. 展示实际组件间消息边。
2. 找到一条消息，指出 Header、Session、Source、Target 和 capture 状态。
3. 点击 **Correlate session 30**（如果对应消息在当前页）；也可在
   **Exact source session (optional)** 输入 `30`，点击 **Filter evidence by session**。
4. 查看同一 session 的相关消息；必要时展开最小化事实和 provenance。

点击 **Inspect evidence / review …** 或 **Review detail …** 会加载对应详情，
并自动将页面定位到 **Sampled review records** 下方的详情区域。
可重复点击同一条重新读取；读取失败会在该区域显示错误，不会调用模型。
若显示 `unsupported`，说明该消息类型没有适用的结构化采集适配器，
不是按钮失效，也不是“无风险”结论。下文三个主要案例请查看 Header `30`、`22`、`26`。

**主要看点：**

- 这是实际发生过的消息记录，不只是静态配置图。
- Session 将相关消息关联起来；Header 对应具体一条消息记录，两者概念不同。
- 采集范围、格式不支持、未授权或采集失败均有明确状态。
- **技术处理成功不等于 HIPAA 合规，技术处理失败也不自动等于 HIPAA 风险。**

**注意：**观测有采样和结构化字段边界，不要说成所有内容、所有接收方后续行为都已被完整掌握。

### 第三步：说明业务背景如何由用户提供

**位置：**消息上的 **Use session … for demo approval**，
以及 **AI review approval, demo business premises and bounded funding**。

**操作：**

1. 在已采集消息上点击 **Use session … for demo approval**。
2. 展示自动带入的 source session。
3. 按顺序介绍表单，不必提交：

   | 输入内容 | 要讲清楚的问题 |
   |---|---|
   | Recipient / relationship | 数据给谁？内部团队、治疗提供者、业务伙伴还是其他外部组织？ |
   | Actual intended use | 数据实际用于什么活动？ |
   | Permission basis | 本次希望依据哪类许可？这不是用户提前决定法律结论 |
   | Individual authorization | 明确存在、明确不存在、不依赖该授权，还是尚不清楚？ |
   | Permission details | 涉及什么数据、授权范围、有效性及特殊条件？ |
   | Safeguards / exceptions | 有哪些访问限制、必要性说明和适用例外？ |
   | Technical-host / recipient mapping | `ProcessB`、`ReceiverB` 等技术组件怎样代表业务接收方？ |
   | Message data scope | 本 session 的数据是否属于所述患者、业务活动和范围？ |

4. 指出业务前提确认、数据导出确认、费用确认以及最终付费批准是明确步骤。
5. 本次只展示表单：保持确认项未勾选，不点击最终付费批准。

**主要看点：**

- 演示业务事实由用户填写确认，不需要接真实医院系统。
- 背景被绑定到本 Production/configuration 的指定 session，不能泛化到其他消息。
- 用户不能填入预期评估结果；系统仍需判断条款适用性、条件与例外。
- 未知不是违规证据，也不是默认许可。
- 用户输入与采集事实在报告中分开展示，记录确认人和时间。

**建议讲法：**

> 系统能看到消息如何传递，但业务用途需要由用户说明。这里让审批人把演示前提说清楚，再由 AI 判断，而不是让 AI 猜组织关系，也不是让用户直接选评估答案。

### 第四步：正常治疗披露

**操作：**在 **Sampled review records** 点击 **Review detail 30**。

依次展示：

1. **No risk found in this check**：本次检查未发现风险。先看 **Why** 和 **Next**。
2. 展开 **Business background supplied by the user**，查看确认人、确认时间、session。
3. 外部治疗提供者、治疗用途、不依赖个人授权的场景条件。
4. 技术组件与接收方的对应关系，以及患者／活动／数据范围。
5. 判断解释与原文引用：
   - `164.506(c)(2)`：治疗披露许可；
   - `164.502(b)(2)(i)`：治疗提供者披露的 minimum-necessary 例外。

**主要看点：**

> 不是看到完整出生日期或没有个人授权就机械报警。系统能结合治疗用途、适用条件与例外，判断本次检查是否存在风险。

**预期结果：**本次所检查问题未发现风险；不能讲成“医院整体完全合规”。

### 第五步：付费营销缺少所需授权

**操作：**点击 **Review detail 22**。

依次展示：

1. **Potential risk found**：发现潜在风险。先看 **Why** 和 **Next**；完整分析及引文在 **Full reasoning and legal references**。
2. 用户明确说明付费营销用途及个人授权缺失。
3. 场景中明确排除相关例外。
4. 解释及 `164.508` 营销授权条件引用。

**主要看点：**

> 系统识别的是明确失败的适用条件，而不是因为缺少一份上传文件就说违规。业务用途和授权情况改变，结论也随之改变。

本场景中的处理方协议不替代所需个人营销授权；不要泛化成“所有业务伙伴都需要个人授权”。

### 第六步：信息不足，不猜测风险

**操作：**点击 **Review detail 26**。

依次展示：

1. **More information needed**：信息不足。直接查看 **Missing information** 中需要补充的内容。
2. 用户明确填写未知的接收方关系和许可条件。
3. **Material information required** 中列出的具体补充问题。

**主要看点：**

> “尚不清楚有没有授权”和“确认没有授权”不同。系统在证据不足时提出问题，而不是编造许可或编造违规。

### 第七步：追溯判断依据与模型调用

**操作：**选择一份报告，例如 **Review detail 30**，展开：

- **AI Hub sessions, usage, prompts and preserved output**
- **Dated normative sources and provenance**
- **Frozen observation and optional context**（必要时）

再查看 **Durable AI authorization history**。

**主要看点：**

- 使用了真实 AI Hub locator / judge 会话，不是把静态规则结果换个 AI 名字。
- 可以追到业务输入、消息证据、模型输出和法规原文。
- 引用有问题对应关系、内容哈希与精确文本范围检查。
- 授权是独立且有预算限制的，不会因为打开或刷新页面持续调用模型。

**本轮历史用量：**

| 项目 | 数量 |
|---|---|
| 新发送的合成消息 | 4 条，包含首次治疗尝试与追加验证 |
| 模型请求 | 8 次 |
| 模型报告 tokens | 116,871 |
| 核验引用 | 15 条 |
| 当前授权 | 四个相关 grant 均为 `Revoked` |

这些是已发生的历史用量，查看报告不新增调用。Token 数不是实际金额账单，不要据此虚构成本金额。

### 第八步：展示首轮问题与修复，保留历史

**操作：**

1. 打开 **Review detail 18**。
2. 展示其仍为 **information required**。
3. 指出缺的是技术组件、业务接收方和消息数据范围之间的对应说明。
4. 返回 **Review detail 30**，展示补充明确输入后的结果。

**主要看点：**

- 首轮三例通过了两例，治疗案例需要补齐对应信息。
- 修改的是表单和输入契约，不是把预期答案改成匹配输出。
- 追加了一条经单独授权的新消息进行验证，旧报告没有覆盖、旧消息没有重放。
- 不要把这段过程讲成“首次三例全部通过”，也不要说成独立盲测。

如果展示时间较短，这一步可以作为最后的简短补充，不必先展开开发过程。

## 6. 推荐的简洁演示顺序

| 顺序 | 操作 | 一句话看点 |
|---|---|---|
| 1 | 发现 Production，选中 M5 | 整个 Production 纳管，不逐流登记 |
| 2 | 看消息边与 session 证据 | 技术事件来自实际消息，不是静态图 |
| 3 | 展示审批背景表单 | 用户提供 Demo 前提，AI 不猜业务背景 |
| 4 | 看报告 30 | 理解许可和例外，不机械报警 |
| 5 | 看报告 22 | 对明确失败的授权条件识别风险 |
| 6 | 看报告 26 | 信息不足就提问，不混淆未知与不存在 |
| 7 | 看来源、SDK 会话、撤销授权 | 有依据、可追溯、调用有边界 |
| 8 | 对比 18 与 30 | 问题与修复保留历史，不覆盖结果 |

**结束时的总结：**

> 这个 Demo 把实际互操作消息、用户审批背景和 HIPAA 条款连接起来，展示三种可解释结果：发现风险、所检查问题未发现风险、需要补充信息。它是发送后的受控审核，不是自动法律认证。

## 7. 可选：到 IRIS Portal 辅助展示

如果观众希望确认业务 Production 确实在 IRIS 中运行：

1. 打开 [真实环境 IRIS Portal](http://127.0.0.1:52779/csp/sys/UtilHome.csp)，单独登录。
2. 切换 namespace 到 **M5OBSERVATION**。
3. 在 Interoperability 相关菜单中打开 Production 配置／状态页面，查看
   **Contest.M5.Production**；菜单文字可能随 IRIS 版本有所差异。
4. 如需进一步查看消息，在对应 namespace 的消息查看功能中按 session
   `30`、`22`、`26` 或 `18` 定位。
5. 查看后返回前端，不点击启动、停止、更新、重发或清理操作。

主要看点是实际 BS/BP/BO 与消息运行记录。`TRIAGE` 是控制平面和审核所在
namespace，不要在 `TRIAGE` 中寻找 `M5OBSERVATION` 的业务消息。

## 8. 操作边界与常见问题

### 本次可以操作

- 登录、发现、选择和刷新。
- Session 筛选、翻页和查看详情。
- 展开来源、审计、会话和历史授权。
- 打开审批表单，填写但不提交。

### 不属于这条只读演示路线

- **Confirm paid review authorization**：可能立即启动后台付费推理。
- **Authorize local synthetic inspection**：改变未来消息内容采集授权。
- 新增消息发送、重新执行 `--run`、重启或重配 Production。
- 删除 journal、旧报告或历史授权记录。

### 找不到报告

先确认选中了 **M5OBSERVATION / Contest.M5.Production**，再检查
**Sampled review records** 的分页。若是新环境没有历史数据，需要先按安装与验收
流程准备；本指南不把重新付费执行作为“查看结果”的隐含步骤。

### 页面显示登录界面或权限错误

整页刷新后重新登录。权限不足应使用现有有权账号，不要为演示随意修改账号权限或凭据。

### 页面无法连接

先检查本地 UI、IRIS 及 Web Gateway 是否运行，以及 UI 是否指向 `52779`；
不要误连 `52777` 的 mock 环境。安装与启动说明见
[IRIS 环境指南](./README.md) 和 [前端指南](../web/README.md)。

### “无风险”是否意味着合规认证

不是。这里只能说明当前 Demo 前提及观测范围内，所检查条件未发现风险。
法规来源是带日期的准备语料；精确引用验证不等于法律时效、语义或整体合规的独立认证。

### 为什么不要求接真实业务系统

这是 Demo。用户在审批中确认的合成背景可作为演示前提。
真实系统接入属于未来部署扩展，不是当前演示的前置条件。

## 9. 相关说明

- [另一份英文演示脚本（保留历史编号案例）](./DEMO-WALKTHROUGH.md)
- [实现状态、证据边界及 M5 验收记录](./MONITORING.md#m5-approval-input-live-acceptance-and-explicit-repair)
- [安装与运行指南](./README.md)
- [前端运行与登录说明](../web/README.md)
- [原始 DataPipelineDemo 项目](https://github.com/zlnick/DataPipelineDemo)

本指南新增于 2026-10-21，案例编号与用量对应 2026-10-20 已保存的本地验收结果。
