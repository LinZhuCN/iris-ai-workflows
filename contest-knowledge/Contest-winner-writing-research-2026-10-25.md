# 往届获奖项目调研与本项目参赛写作取舍

调研日期：2026-10-25（北京时间）。

## 结论

用户指定的三个项目均可从官方结果页核实获奖，且都获得过各自竞赛的专家组第一。
但它们参加的是不同届竞赛，不能把它们当作同一评分条件下的对照实验。
**获奖结果可核实，“因为某种文章写法而获奖”不可由这些资料证明。**

值得借鉴的共同点不是功能数量，而是：

1. 从一个具体业务问题开篇。
2. 让读者看见 InterSystems 在核心路径里做了什么。
3. 用一条完整可操作的主线连接输入、执行和结果。
4. 把文章、Open Exchange 和可执行 README 连起来。
5. 展示系统内部证据，而不是只展示漂亮的最终页面。

本次产出：

- [英文 Developer Community 文章草稿](../contest/CONTEST-ARTICLE.md)
- [英文 Open Exchange 文案及发布核对表](../contest/CONTEST-SUBMISSION.md)
- [英文现场演示指引](../contest/M5-ONBOARDING-DEMO.md)
- [中文现场演示指引](../contest/M5-ONBOARDING-DEMO.zh-CN.md)

## 调研方法与边界

阅读三篇文章，顺着原文链接查看 Open Exchange 页面、公开 GitHub README，
并抽查实现文件；同时核对官方获奖公告。未运行他人的容器、管理操作或付费服务，
也未验证他们托管演示今天是否仍能正常运行。

仓库代码指向调研时可访问的当前分支，不等同于当年参赛提交的精确版本。
下列功能差异是文档与当前实现的对照，不是对历史参赛版本的判定。
未复制原文大段内容或将其代码移植进本项目。

## 一、promjet-stats：从“统计结果为什么不一致”切入

| 项目 | 核实资料 |
|---|---|
| 文章 | [Compare Apache Logs to Yandex Metrika (Google Analytics analogue)](https://community.intersystems.com/post/compare-apache-logs-yandex-metrika-google-analytics-analogue) |
| 作者、日期 | Evgeniy Potapov，2021-09-12 |
| Open Exchange | [promjet-stats](https://openexchange.intersystems.com/package/promjet-stats) |
| GitHub | [jakcpto/promjet-stats](https://github.com/jakcpto/promjet-stats) |
| 获奖 | 专家组第一、社区组第三：[官方结果](https://community.intersystems.com/post/analytics-programming-contest-and-winners-are) |

### 文章和实现实际展示了什么

从客户 WordPress 网站的统计疑问开始：浏览器统计可能漏数据，而 Apache/AWStats
又包含机器人、监控等请求。随后解释为什么要比较两种来源，再展示 IRIS BI、
AtScale、Power BI/Tableau 的分析结果。

代码提供了实质性的数据处理，而不仅是展示层：

- [Apache 日志转换](https://github.com/jakcpto/promjet-stats/blob/main/api/get_csv/index.php)
  读取压缩日志，输出时间、请求、状态、设备和 User-Agent 等字段。
- [Yandex CSV 获取](https://github.com/jakcpto/promjet-stats/blob/main/api/get_csv_YaMetrika/index.php)
  提取浏览器、设备、广告拦截和流量来源等维度。
- [PromjetCube](https://github.com/jakcpto/promjet-stats/blob/main/src/dc/irisbi/PromjetCube.cls)
  使用 `%DeepSee.CubeDefinition`；
  [module.xml](https://github.com/jakcpto/promjet-stats/blob/main/module.xml)
  配置依赖与 Cube 构建。
- [README](https://github.com/jakcpto/promjet-stats/blob/main/README.md)
  交代日志、OAuth、PHP、导入和可视化入口。

### 应用到我们项目

不要从“我们实现了一个 AI 平台”开篇，而从：

> 在不改动现有业务流程的情况下，旁路监测机构间的数据交换，
> 识别潜在的隐私与合规风险。

再以研究机构导出的去标识化声明与实际字段不一致为具体案例，
引出消息证据、机构职责、AI 辅助判断与人工核查，而不是用口号代替业务说明。

### 不照搬什么

日志请求数并不等于真实人数，文章也没有提供受控准确率实验。同理，
我们不能把“模型返回了结果”当作正确率，更不能把接收成功当作合规成功。
站点 ID、日期范围、行数上限和访问配置等示例也不能原样视为通用部署方案。

## 二、fhir-integratedml-example：模型之前的数据准备就是技术贡献

| 项目 | 核实资料 |
|---|---|
| 文章 | [fhir-integratedml-example overview](https://community.intersystems.com/post/fhir-integratedml-example-overview) |
| 作者、日期 | Henrique Dias，2021-07-22 |
| Open Exchange | [fhir-integratedml-example](https://openexchange.intersystems.com/package/fhir-integratedml-example) |
| GitHub | [jrpereirajr/fhir-integratedml-example](https://github.com/jrpereirajr/fhir-integratedml-example) |
| 获奖 | 专家组第一、社区组第一：[官方结果](https://community.intersystems.com/post/ai-programming-contest-meet-winners) |
| 官方获奖署名 | José Pereira、Henrique Dias，不应只列文章作者 |

### 文章和实现实际展示了什么

文章抓住 ML 落地中的数据准备问题，把 FHIR 和可复用 DTL 作为桥梁。
其 README 的技术证据比概述文章更丰富：架构、DTL、动画、预测接口、
`CREATE MODEL`、`TRAIN MODEL`、`PREDICT`、`VALIDATE MODEL` 命令与结果。

- [NoShowDTL](https://github.com/jrpereirajr/fhir-integratedml-example/blob/main/src/PackageSample/NoShowDTL.cls)
  继承 `Ens.DataTransformDTL`，关联 Appointment、Condition、Communication 等资源并映射模型特征。
- [Dispatch](https://github.com/jrpereirajr/fhir-integratedml-example/blob/main/src/PackageSample/Dispatch.cls)
  和 [Service](https://github.com/jrpereirajr/fhir-integratedml-example/blob/main/src/PackageSample/Service.cls)
  连接 FHIR 输入、DTL 和预测调用。
- [README](https://github.com/jrpereirajr/fhir-integratedml-example/blob/main/README.md)
  明确说明将数据集转换为合成 FHIR 资源；并非独立临床验证。
- [MLModelHelper](https://github.com/jrpereirajr/fhir-integratedml-example/blob/main/src/PackageSample/MLModelHelper.cls)
  可用于核对实际训练和验证流程，而不能只看展示结果。

### 应用到我们项目

技术贡献不应写成“用了某个 LLM”。真正可解释的是：

**实际消息 → 有界字段事实 → 冻结的机构档案 → 适用问题 → 来源证据 → 判断 → IRIS 校验。**

其中字段最小化、版本绑定、后台采集、引用验证和失败留存是实质工程。
文章讲清楚主线，README/操作指南承载命令、前提和预期输出。

### 不照搬什么

合成 FHIR 数据不能包装成临床有效性。该项目文章中的潜在云服务扩展也不能
视作已部署成果。README 的固定划分示例与当前安装辅助代码的实验流程存在差别，
提醒我们必须让文案、命令和实际初始化一致，不能拿旧验收编号当成新安装自带数据。

## 三、bg-iris-agent：对话之外展示 Production 和调用证据

| 项目 | 核实资料 |
|---|---|
| 文章 | [AI-Powered System Management with IRIS Agent](https://community.intersystems.com/post/ai-powered-system-management-iris-agent) |
| 作者、日期 | Georgii Tatevosian，2025-03-30 |
| Open Exchange | [bg-iris-agent](https://openexchange.intersystems.com/package/bg-iris-agent) |
| GitHub | [banksiaglobal/bg-iris-agent](https://github.com/banksiaglobal/bg-iris-agent) |
| 获奖 | 专家组第一、社区组第二：[官方结果](https://community.intersystems.com/post/winners-intersystems-ai-programming-contest) |
| 官方获奖署名 | Georgii Tatevosian、Elena Karpova、Alena Krasinskiene |

### 文章和实现实际展示了什么

自然语言管理 IRIS/查询外部数据，接入 Custom GPT 与 Claude/MCP。
文章把用户操作与内部 Production、请求/响应 Trace、生成 OpenAPI、
操作后的检查和外部查询穿插展示，而不只是放聊天截图。

- [RestService](https://github.com/banksiaglobal/bg-iris-agent/blob/master/src/Banksia/IrisAgent/RestService.cls)
  验证目标、导入消息并通过 `SendRequestSync` 分派；根据 Operation 和消息元数据生成 OpenAPI。
- [MCP bridge](https://github.com/banksiaglobal/bg-iris-agent/blob/master/mcp-nodejs-server/index.ts)
  将 OpenAPI 路径转换成 MCP tools，转发带 API Key 的请求。
- [README](https://github.com/banksiaglobal/bg-iris-agent/blob/master/README.md)
  包含 Compose、Production、客户端配置、HTTPS 场景和视频。

这比“给 API 加一个聊天界面”更有解释力：它展示了元数据驱动的可复用连接。

### 应用到我们项目

每个关键结论配两层画面：

1. 用户能理解的 Result / Why / Next。
2. 可检查的消息/会话证据、两阶段原始响应、模型及预算。

我们已经实现的按钮旁 **AI log** 正好承担第二层；视频还应短暂展示实际 BP
Trace 或策略审计，避免观众误以为这只是一个脱离 Interoperability 的网页审核器。

### 不照搬什么

其 README 功能列表与当前代码并非完全一致：
例如 [Users Operation](https://github.com/banksiaglobal/bg-iris-agent/blob/master/src/Production/Operation/Users.cls)
的删除操作返回不允许；[FindMeds](https://github.com/banksiaglobal/bg-iris-agent/blob/master/src/Production/Operation/FindMeds.cls)
展示的是 OpenFDA NDC 品牌查询，不能放大成全面药物安全服务。
密钥配置说明也应与当前实现逐项核对。

因此我们不使用“自主监管所有 Production”“自动修复违规”“HIPAA 合规认证”等
超出实现的说法，也不把 AI Hub 的业务运行时与 Agentic Dev 开发 MCP 混在一起。

## 四、本届公告和评审建议带来的约束

[本届官方公告](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows)
在调研时明确：

- 核心是 **IRIS Interoperability workflow 中使用 AI Hub Agent 处理决策任务**。
- 要求完整可用、开源，已有项目必须有重大改进；主办方保留批准权。
- 英文 README 需要安装步骤及视频或工作原理说明。
- 使用 **AI Hub Community build 154**；公告提示使用 162 的项目切换回 154。
- 公告明确说明相关 EAP 开发及参赛提交在其许可条款下获准，
  不能据此推导镜像或许可文件可以随项目再分发。
- 建议文章写 AI Hub 经验、模型与费用、可观测性和 Agentic Dev 使用。

[What experts look for in contest entries](https://community.intersystems.com/post/what-experts-look-contest-entries)
建议突出技术想法、首次运行成功、工作演示、README 顶部重点以及问题解决经历，
并强调个人工程投入。该文自己说明这不是正式评分表，不应虚构分数权重。

我们当前 ARM64 `2026.3.0AI.154.0` 实测与公告 build 号一致，
但提交前仍应核对具体镜像和许可方式，不只看版本字符串。

## 五、已经应用到本次稿件的取舍

| 借鉴经验 | 本次实际写法 |
|---|---|
| 具体问题开篇 | 非侵入式旁路监测机构间数据交换，以研究导出的声明/字段矛盾说明业务用途 |
| 一条完整用户故事 | M5 从机构录入、纳管到新消息、新审计，不先展示历史成绩表 |
| InterSystems 在关键路径 | 明确 `%AI.Agent`、事实 ToolSet、BP 策略门、BO 落库及独立观察器 |
| 结果与内部证据成对 | 接收回执、采集证据、AI 结论分别展示，再打开 AI log |
| 文案与实现一致 | M5 是后台旁路审核，不虚构它插入原 BP；另列 triage BP 和多机构 audit BP |
| 诚实展示实测 | M5 2 requests/43,626 tokens；多机构成功运行 6 requests/97,069 tokens |
| 不隐去失败 | 说明之前多机构超时和单独授权重试；不把成功运行用量说成全部开发成本 |
| 报告边界 | SDK usage 不等于供应商账单；合成机制验收不等于法律准确率 |
| 可复现配套 | 链接安装、现场步骤、验收和限定重置，说明旧报告不是新安装自带 fixture |
| 开源和继承 | 明确 DataPipelineDemo 来源、实质新增与 NOTICE，不把 fork 包装成从零原创 |

## 六、发布前还需要完成的事

1. **发布代码。** 本调研初次起草时，关键 M5/UI/说明文件仍有本地未跟踪内容；
   不能把“本地测试通过”说成评委已经能从 GitHub 获取。发布后应核对远端提交，
   以实际 GitHub 版本为准。
2. **干净机器复现。** 基础 mock triage 启动不等于完整 M5 安装，
   应验证额外基础设施、Agent 发布、知识导入等步骤，而不是只验证现有容器。
3. **录制短视频。** 一条主线优先，补一个 BP/策略证据镜头；不游览所有页面。
4. **真实媒体。** 现有稿件只给镜头计划，没有伪造截图、视频或托管地址。
5. **正确成本口径。** 若没有供应商账单，继续明确“不报告已核实金额”。
6. **公开链接验证。** DC 发布时把相对链接换成公开版本链接，并在未登录状态检查。
7. **团队与身份。** 不虚构团队名单、DC 个人主页、Freshmen 资格或主办方批准。

我们借鉴的是“让评委迅速理解、操作和检查贡献”的方法，
不是复制功能或声称找到了必胜公式。
