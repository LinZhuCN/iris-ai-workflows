# IRIS AI Hub Interoperability Workflows

[English](./README.md) · [简体中文](./README.zh-CN.md) ·
[安装指南](./INSTALL.zh-CN.md) · [全部文档](./DOCUMENTATION.zh-CN.md)

**以非侵入式方式监测机构间的数据交换，识别潜在的隐私与合规风险。**

观察现有的 InterSystems IRIS Interoperability Production，不改动其业务流程，
不阻断投递。将消息证据、来源/接收机构档案和 HIPAA 参考材料结合起来，
由 **IRIS AI Hub Agent** 辅助人工调查。

这是为 [AI Agents in Interoperability Workflows](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows)
竞赛开发的合成数据演示，不是生产合规服务或法律认证。

## 应用做什么

医疗数据交换的要求取决于接收方和预期用途。研究导出、内部质量报告和治疗消息，
不应使用同一组假设进行评估。

应用在运行中的 Production 旁路采集受支持的消息证据，与版本化的机构背景绑定，
再使用 AI Hub 识别潜在问题或缺失信息。报告将每个发现关联到观测事实、
来源原文和保存的模型输出。

| 能力 | 已实现行为 |
|---|---|
| Production 观察 | 发现并显式纳管本机 Production；采集消息边、会话、事件和覆盖情况，不修改业务 Host |
| 有界本地检查 | 单独授权后检查已注册的结构化属性；审查输入采用最小化字段事实，而不是患者标识符原值 |
| 上下文审查 | 冻结的机构档案和用途声明、两阶段 AI Hub、报告结构及来源引用校验 |
| 可检查的推理 | 模型执行操作旁提供 **AI log**：保存的输入、响应、会话、用量和错误；查看不调用模型 |
| 费用控制 | 显式有界授权；纳管、刷新和重试不会静默购买推理 |
| 额外工作流决策 | 独立 triage BP 使用只读事实 ToolSet 和确定性策略门，再持久化投递、隔离或人工审核结果 |

监测是**发送后的建议性审查**。它不能阻止已完成的披露，不会自动修改 Production，
也不保证实时检测。非侵入式描述投递架构，不代表零资源开销。

## 主演示

使用 [M5 现场指引](./contest/M5-ONBOARDING-DEMO.zh-CN.md)
（[English](./contest/M5-ONBOARDING-DEMO.md)）。
配置完成后打开 <http://localhost:5173/demo/m5>。

1. 录入并保存来源医院与研究接收机构档案。**Fill example** 填充可编辑测试数据。
2. 纳管固定的 `M5OBSERVATION / Contest.M5.Production`。
3. 单独授权本地合成字段检查。
4. 通过实际 BS/BP/BO 流程和 SQL 接收端发送一条新的合成研究消息。
5. 检查新采集的字段证据与消息/会话关联。
6. 授权一次有界 AI 审查，查看结果并打开 **AI log**。

示例声明使用 Safe Harbor 去标识化，但仍保留合成标识符和完整出生日期。
报告指出实际字段与所选发布路径之间的矛盾，不表示所有研究披露都违法。

```text
Existing business Production: BS -> BP -> BO -> receiver
                                      |
                               observed evidence
                                      |
                  minimized facts + frozen institution context
                                      |
                 AI Hub locator -> source evidence -> AI Hub judge
                                      |
                    IRIS validation -> report -> human review
```

上图依次为业务投递、旁路证据、最小化事实与冻结机构背景、两阶段模型审查、
IRIS 校验及人工审核。M5 reviewer 位于独立观察 worker，不在被观察的业务 BP 中。
重置仅归档固定演示的逻辑状态；原始 IRIS 消息、SQL 回执和模型报告继续保留。

### 三个接收方、三种协议

[可选多机构场景](./contest/MULTI-ORGANIZATION-DEMO.zh-CN.md)读取版本化 FHIR Patient，
转换并投递实际输出：

| 模拟接收方 | 接口 | 独立命名空间 |
|---|---|---|
| 内部质量部门 | SQL | `DEMOQUALITY` |
| 外部研究中心 | REST | `DEMORESEARCH` |
| 接诊诊所 | HL7 V2 / MLLP | `DEMOCLINIC` |

所有接收方均位于同一本地 IRIS 实例。接收端回读支持分支级审查。
该场景还通过 `AdvisoryAudit` BP 演示分发后调用 AI Hub 审查。

## 安装

### 前提

- Docker Compose **2.24.4+** 和 Python 3。
- 单独取得的、获得授权的 **AI Hub EAP 镜像**和适当的本地 InterSystems 许可，
  两者均不随仓库分发。
- 实测运行时为 **ARM64 IRIS for Health `2026.3.0AI.154.0`**；
  普通非 AI Hub Community 镜像不能替代。当前竞赛公告指定 AI Hub Community build 154。
- UI 使用 Node **22.12+**，也可采用文档中的 Docker 方案。
- 真实审查需要模型凭据、已配置的 reviewer 和知识索引；供应商调用可能产生费用。

### 从有界 mock triage 工作流开始

此方式使用本地 mock provider，验证真实 IRIS BP、AI Hub SDK、ToolSet、策略门和 BO。
**它不会配置完整 M5 监测演示。**

将许可放在 `iris/license/iris.key`，或将 `IRIS_LICENSE_PATH` 设为绝对路径。
在仓库根目录执行：

```sh
python3 contest/prepare.py
docker compose --profile mock up -d --wait
python3 contest/test.py --restart
```

打开 <http://127.0.0.1:52777/csp/sys/UtilHome.csp>，登录并选择 **TRIAGE**。
镜像选择、凭据、真实 provider 配置和排障见[运行时安装指南](./contest/README.zh-CN.md)。

### 配置监测演示和 UI

按以下顺序阅读；不要将已有验收日志当作新安装 fixture：

1. [真实运行时配置](./INSTALL.zh-CN.md#真实模型运行时)。
2. [知识 API 和本地嵌入配置](./contest/KNOWLEDGE.zh-CN.md)。
3. [Production 监测基础设施](./contest/MONITORING.zh-CN.md)。
4. [M5 前提、源码安装和现场步骤](./contest/M5-ONBOARDING-DEMO.zh-CN.md)。
5. [前端安装和共享登录](./web/README.zh-CN.md)。

UI 使用现有 IRIS API 身份，凭据仅保存在浏览器内存中；模型授权独立于登录。
HTTP 演示应仅限 localhost，不要将当前开发部署原样暴露到公网。

## 验证与已记录证据

不产生新模型调用的免费检查：

```sh
python3 contest/knowledge.py verify --profile demo
python3 contest/knowledge.py release-check

cd web
npm test
npm run lint
npm run build
```

在运行 UI 的环境中使用 `npm ci --legacy-peer-deps` 恢复前端依赖。
Docker 用法见[前端验证](./web/README.zh-CN.md)。

以下是已记录的本地验收，不是新安装保证：

| 范围 | 已记录结果 |
|---|---|
| M5 纳管审查 | 一条合成消息；两次模型请求；限定风险发现；43,626 SDK tokens |
| 三接收方成功审查 | 六次请求；研究路径风险、质量和治疗路径限定无信号；97,069 SDK tokens |
| M5 完成时前端 | 250 项测试通过；类型检查、lint、构建通过 |

更早的多机构尝试出现 provider 超时，并单独保留记录。SDK 计数不是核对后的账单，
也不是法律准确率。历史实验，包括失败和未推广变体，保留在
[MONITORING](./contest/MONITORING.zh-CN.md)。

发布时 Python 自动发现运行 242 项测试：226 项通过，16 项历史 staged acceptance/
taxonomy 检查因运行时源码哈希变化而拒绝执行。未重新绑定这些历史冻结，
也未将其描述为当前验收通过。

`python3 contest/m5_demo.py --check` 读取已保存的本地验收日志。
`--run` 会发送数据并授权付费推理，不是常规免费检查。
使用安装、验收或重置命令前先阅读 [M5 指南](./contest/M5-ONBOARDING-DEMO.zh-CN.md)。

## 知识来源与边界

[演示知识包](./hipaa-demo-knowledge/README.zh-CN.md)包含约 **23 MB 完整整理文本**，
另有明确标识的 LLM 导读与合成组织策略。官方提取文本不被描述为 LLM 改写，
导读不是官方法律文本。历史/未审查材料不进入默认检索导出。

发布检查使用公开的 `demo` profile；`full` 是可选本地重建。
完整来源归档和本地完整整理语料留在 Git 之外。
输入选择不代表已完成 AI Hub 导入或审查质量评估。

受支持的结构化检查不是全面自由文本 PHI 检测。
机构档案是用户提供的情景前提，不是核实后的法律权限。
精确引用校验不能证明法律解释正确或接收方后续行为。

## 文档

默认英文入口及全部中文对应版见[双语文档目录](./DOCUMENTATION.zh-CN.md)。

| 主题 | 指南 |
|---|---|
| 主演示 | [English live demo](./contest/M5-ONBOARDING-DEMO.md) · [中文](./contest/M5-ONBOARDING-DEMO.zh-CN.md) |
| 扩展场景 | [FHIR 到 SQL/REST/HL7 分发](./contest/MULTI-ORGANIZATION-DEMO.zh-CN.md) |
| 运行时与 UI | [IRIS 安装](./contest/README.zh-CN.md) · [前端](./web/README.zh-CN.md) |
| 审查与证据 | [Production 监测](./contest/MONITORING.zh-CN.md) · [知识 API](./contest/KNOWLEDGE.zh-CN.md) |
| 其他工作流 | [Agent factory](./contest/AGENT-FACTORY.zh-CN.md) · [声明工作流](./contest/DECLARATION-WORKFLOW-PLAN.zh-CN.md) |
| 参赛材料 | [文章草稿](./contest/CONTEST-ARTICLE.zh-CN.md) · [提交核对表](./contest/CONTEST-SUBMISSION.zh-CN.md) |
| 开发 | [Agentic Dev 与 Skills](./contest/dev/README.zh-CN.md) |

Agentic Dev MCP 和 Interop Skills 是开发辅助，不是运行时业务 Agent。
文章发表、视频、干净机器完整演示复验和正式参赛提交是独立发布任务。

## 仓库与署名

- [contest/](./contest/)：ObjectScript 组件、部署、Python 验证程序和工作流文档。
- [web/](./web/)：React/TypeScript 演示 UI。
- [hipaa-demo-knowledge/](./hipaa-demo-knowledge/)：公开的整理语料。

Fork 自 [zlnick/DataPipelineDemo](https://github.com/zlnick/DataPipelineDemo)。
本 fork 新增 AI Hub 运行时决策、独立 Production 观察、机构上下文审查和证据检查。
当前目录不再包含原管道生成应用，但保留其历史和署名；本仓库开发不会修改上游。

项目代码采用 [Apache-2.0](./LICENSE)；上游、UI、Skills 和知识材料署名见 [NOTICE](./NOTICE)。
不分发许可密钥、模型凭据、InterSystems 镜像或完整本地来源归档。
