# IRIS AI Hub Interoperability Workflows

[English overview](./README.md) · [English setup guide](./README.en.md)

**在不改动现有业务流程的情况下，旁路监测机构间的数据交换，
识别潜在的隐私与合规风险。**

本项目面向 InterSystems AI Agents in Interoperability Workflows 竞赛。
通过独立观察器采集 IRIS Production 的消息证据，结合来源和接收机构、
使用目的及 HIPAA 参考材料，由真正的 **IRIS AI Hub Agent** 辅助审查，
为业务人员提供可核查的风险报告。

这是使用合成数据的演示程序，不是生产级合规服务、法律意见或 HIPAA 认证。

## 业务用途与能力

医院向内部质量部门、研究机构和诊所发送数据时，接收方需要的数据范围不同。
系统将实际消息中的字段事实与机构档案、用途声明和参考依据关联起来，
帮助人员识别潜在风险或缺失信息，而不是只依据是否含标识符判断违规。

- **Production 纳管**：发现并显式选择本机 Production，采集消息路径、会话、
  事件和覆盖情况，不改写业务 Host。
- **受限本地检查**：单独授权后检查已注册的结构化消息属性；
  模型输入使用字段存在性、日期精度等事实，不需要患者标识符原值。
- **两阶段 AI 审查**：定位问题、准备证据、生成判断；IRIS 校验结构和引用，
  保存结果及不确定项。
- **可查看 AI log**：执行按钮旁展示保存的输入、原始响应、会话、用量与错误；
  查看日志不调用模型。
- **显式费用授权**：纳管、刷新页面和重试不会自动购买额外推理。

“非侵入式”指观察器不插入原业务 BS/BP/BO 投递链，不改消息、不阻断正常投递。
采集与审查分离；当前主线是发送后的旁路辅助审查，不保证实时检测，
也不能撤回已经完成的数据披露。“非侵入式”不意味着零资源开销。

另有独立的执行型 triage BP：Agent 调用只读事实工具，建议投递、隔离或人工审核，
IRIS 经确定性策略校验后执行。它与旁路监测不同，纳管不会将它插入被观察的流程。

## 主演示：从机构录入到新审计结果

基础设施预先部署后，访问 <http://localhost:5173/demo/m5>：

1. 录入并保存来源医院、研究接收机构；“自动填入”只填充可编辑的模拟数据。
2. 将固定的 `M5OBSERVATION / Contest.M5.Production` 纳管。
3. 单独授权本地合成字段检查。
4. 触发一条新的研究数据消息，经实际 BS/BP/BO 投递并读取 SQL 接收回执。
5. 查看后台新采集的消息、会话和字段证据。
6. 显式授权一次有界 AI 审查，讲解结果并打开旁边的 **AI log**。

示例声明使用 Safe Harbor 去标识化，但保留合成姓名、MRN 和完整出生日期，
用于展示声明、接收要求与实际字段之间的矛盾，不代表所有研究披露都违法。
档案版本在发送时冻结，后续修改不会改写该消息的审查前提。

完整步骤：[中文现场指引](./contest/M5-ONBOARDING-DEMO.zh-CN.md) ·
[English walkthrough](./contest/M5-ONBOARDING-DEMO.md)。
限定重置归档 M5 的逻辑状态，保留原消息、SQL 回执和模型报告，不影响其他演示。

### 可选三机构场景

[多机构演示](./contest/MULTI-ORGANIZATION-DEMO.md)从 FHIR Repo 读取版本化 Patient，
转换后通过不同协议投递：

| 模拟机构 | 接口 | 独立命名空间 |
|---|---|---|
| 内部质量部门 | SQL | `DEMOQUALITY` |
| 外部研究中心 | REST | `DEMORESEARCH` |
| 接诊诊所 | HL7 V2 / MLLP | `DEMOCLINIC` |

接收方均在同一本地 IRIS 实例内。每路有实际接收证据；
`AdvisoryAudit` BP 在分发后调用 AI Hub 审查，不阻断分发。

## 安装

需要 Docker Compose 2.24.4+、Python 3、自行取得的 AI Hub EAP 镜像与适当许可。
已验证 ARM64 IRIS for Health `2026.3.0AI.154.0`；当前竞赛公告指定
AI Hub Community build 154，不能用普通非 AI Hub 镜像替代。
UI 使用 Node 22.12+，也可使用 Docker。

### 最小 mock triage

将许可放入 `iris/license/iris.key`，或设置绝对路径 `IRIS_LICENSE_PATH`。
在仓库根目录执行：

```sh
python3 contest/prepare.py
docker compose --profile mock up -d --wait
python3 contest/test.py --restart
```

本地 mock 不调用外部模型，但实际经过 AI Hub SDK、BP、ToolSet、BO 和审计。
访问 <http://127.0.0.1:52777/csp/sys/UtilHome.csp>，登录后选择 `TRIAGE`。
**这不是完整 M5 监测系统的一键安装。**

### 完整监测演示

按[英文安装指南](./README.en.md)配置真实运行时，再依次完成：

1. [本地知识 API 与向量索引](./contest/KNOWLEDGE.md)。
2. [Production 监测基础设施](./contest/MONITORING.md)。
3. [M5 基础流程、已发布 reviewer 及新源码安装](./contest/M5-ONBOARDING-DEMO.md#before-presenting)。
4. [UI 安装及共享登录](./web/README.md)。

完整 M5 的干净环境发布复验仍待完成；现有验收日志不是新克隆的启动数据。
真实模型需在忽略的 `.env` 中配置，可能产生费用。不得提交密钥、使用真实患者数据，
或输出包含凭据的 Compose 配置。HTTP 开发环境仅限 localhost，不应原样暴露到公网。

## 验证与实测

不调用模型的知识包验证：

```sh
python3 contest/knowledge.py verify --profile demo
python3 contest/knowledge.py release-check
```

前端在安装依赖的相同环境内执行 `npm test`、`npm run lint`、`npm run build`；
详见[前端验证](./web/README.md#validation)。

| 已记录的本地验收 | 结果 |
|---|---|
| M5 新消息审查 | 2 次模型请求，43,626 SDK tokens，输出限定风险结果 |
| 三机构成功审查 | 6 次请求，97,069 SDK tokens；研究风险，质量与治疗路径为限定范围无信号 |
| M5 完成时前端验证 | 250 项测试通过，类型检查、lint、构建通过 |

更早的多机构超时及未推广实验保留在[研发记录](./contest/MONITORING.md)中。
以上不是法律准确率、账单金额或新环境可复现相同编号的保证。
本次发布前 Python 自动发现运行了 242 项测试：226 项通过，
16 项历史 staged acceptance/taxonomy 检查因运行时源码已变化而拒绝旧哈希。
未为获得通过而重写历史冻结记录，也不将其描述为当前验收通过。
`python3 contest/m5_demo.py --check`只读验证已存在的本地验收记录；
`--run`会发送数据并授权模型费用，不是免费检查。

## HIPAA 知识来源和边界

[发布知识包](./hipaa-demo-knowledge/README.md)包含约 23 MB 完整整理文本，
并明确区分官方提取文本、LLM 导读和合成组织策略。不能把整个包称为 LLM 改写，
也不能把导读当成官方法律文本。历史和未审查内容不进入默认检索导出。

发布验证使用 `demo`；`full` 为可选本地重建，完整原始归档与本地完整语料不进 Git。
输入选择不代表已完成 AI Hub 导入或 Agent 质量评估。
字段检查不是全面自由文本 PHI 检测；机构档案是用户提供的情景前提，
不是已核实的法律权限；引用匹配也不能证明法律适用判断或接收方后续行为。

## 文档与来源

- [英文参赛文章](./contest/CONTEST-ARTICLE.md) · [提交文案与发布核对表](./contest/CONTEST-SUBMISSION.md)。
- [Agent factory](./contest/AGENT-FACTORY.md) · [声明与审批工作流](./contest/DECLARATION-WORKFLOW-PLAN.md)。
- [Agentic Dev 与 Skills](./contest/dev/README.md)：开发期工具，不是运行时业务 Agent。
- [研发知识与调研](./contest-knowledge/README.md)。

本项目 fork 自 [zlnick/DataPipelineDemo](https://github.com/zlnick/DataPipelineDemo)。
新增 AI Hub 运行时决策、独立监测、机构上下文审查与证据界面；
当前目录不再包含原管道生成应用，但保留历史与署名，不修改上游仓库。

项目代码采用 [Apache-2.0](./LICENSE)。UI、Skills 和知识材料来源见 [NOTICE](./NOTICE)。
不分发 InterSystems 镜像、许可、模型凭据或完整本地归档。
文章发表、视频、干净环境复验和正式参赛提交仍为独立发布步骤。
