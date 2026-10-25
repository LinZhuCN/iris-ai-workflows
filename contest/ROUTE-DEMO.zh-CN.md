# Internal hospital route demo

[English](./ROUTE-DEMO.md) | [简体中文](./ROUTE-DEMO.zh-CN.md)

当前路由演示遵循**组织政策 → 项目审批 → 已观察行为**。它取代了早期 P5/P6 试验记录，不会将多个历史尝试伪装成当前演示。

## Explicit synthetic organization policy

`Contest.RouteScenario` 实现 **DEMO-INTERNAL-USE-1，版本 1**。DEMO-HOSPITAL 是模拟的受保护实体。其源 SQL 系统、FHIR 中心和技术隔离的分析接收方均属于同一组织。所有患者数据均为合成数据。命名空间隔离不代表法律或组织边界。

| 路由 | 已批准场景 | 已登记接收方 / 已配置身份 |
|---|---|---|
| 内部聚合 | 汇总八个合成资源以支持已批准的医院照护和运营；不向外部导出 | `local-fhir-center` / `ContestAggregationFHIR` |
| 内部质量改进 | 按出生年份队列比较就诊类别以改进医院服务；不是旨在产生可普遍推广知识的研究、营销或外部商业再利用 | `local-analysis-receiver` / `local-utilization-service` |

两条路径都在受控的内部访问下处理模拟的可识别数据。两者都不依赖去标识化或患者个人授权。在获批项目范围内允许使用稳定 ID/引用；仅凭其存在不构成政策判断。BAA、DUA、Safe Harbor 和 Expert Determination 并非每个 HIPAA 工作流都必须具备的一套通用前置条件。

每个项目都需要针对确切用途、接收方、已配置服务身份、资源/字段范围、记录上限、配置和有效期进行审批。用途变更、外部接收方或更广的数据集都需要单独审核。用途代码不能证明与之矛盾的自由文本用途是恰当的：审批者和 Agent 必须比较两者。

这些是虚构场景前提，不是真实医院凭据、法律授权或合规证书。相关概念见 [HHS TPO 指南](https://www.hhs.gov/hipaa/for-professionals/privacy/guidance/disclosures-treatment-payment-health-care-operations/index.html) 和 [HHS 最低必要性指南](https://www.hhs.gov/hipaa/for-professionals/privacy/guidance/minimum-necessary-requirement/index.html)。这两个来源都没有批准本演示，也没有规定所有分析项目都属于医疗保健运营。

政策以有界应用事实的形式提供。它不会悄然取代已准备知识语料中的独立 treatment/Safe Harbor/expert 示例，也不声称已将更新后的语料导入 AI Hub。

## Approval and evidence

仅登记不授予任何权限。明确审批会将合成场景绑定到声明/配置/有效期摘要以及审批者记录。回读会验证该绑定和已登记的场景定义。自由文本用途仍然是一个**主张**，不会被提升为观察事实。

`route-evidence-v2` 包含八项最小化事实：

- 已提交用途和上下文：未经验证的主张。
- 确切获批范围、重新计算的输出和持久化投递：观察事实。
- 监控覆盖范围：明确的边界，不是笼统的法律文件清单。
- 组织政策：本地合成政策。
- 已批准场景：经过验证的合成审批绑定之观察事实，不是真实机构的证据。

服务器会强制执行政策、用途、接收方、服务配置和数据范围之间的有范围比较。不再要求每个批次都进行去标识化调查。矛盾的去标识化主张仍可能引出实际相关问题。

IRIS 负责确切范围/配置/有效性检查。AI Hub Agent 根据所提供事实和注明日期的规范性来源，检查用途一致性、数据恰当性和相关条件。它可以返回限定范围的未发现问题、潜在偏差或重要信息缺口。服务器会检查条件、事实引用和物化引用，但这不能证明语义蕴含关系。

后续接收方行为、超出快照的新鲜度以及总体法律合规性仍属于覆盖边界。对于其他方面可验证的批次，这些因素不会自动成为缺失的前置条件。发送后的审核不能拦截、重放或撤销已完成的投递。

## Run on the existing local installation

这些命令针对已拥有的现有本地实例和正在运行的 PIPELINE/UTILIZATION/TRIAGE Productions。不会配置环境、更改凭据或重启 Productions。

```sh
# 免费：仅编译确切更新的类。
python3 contest/route_demo.py --install

# 破坏性操作：需要明确同意。仅替换路由演示记录、
# 审批、批次快照、关联 AI 报告、指定结果文件和 SQL 接收方行。
# 登记/批准两个场景并执行两次全新发送。
python3 contest/route_demo.py --reset-demo

# 付费：单独明确同意，最多四次 deepseek-flash 请求。
# 现有后台定时器会发现并审核这两个确切批次。
python3 contest/route_demo.py --authorize-four-requests

# 只读；两个任务都到达终态后运行；若结果缺失/失败则报错。
python3 contest/route_demo.py --check
```

重置会在观察器锁内验证已检查的计划，并拒绝未知登记、非本项目实例、执行中批次或正在运行的审核。不会删除不相关的工作流数据、引擎消息日志、HIPAA 来源、FHIR 仓库历史或其他 Agent 评估。全新聚合会更新同一组八个合成 FHIR 资源。下游 SQL 表包含一条全新的演示收据。

当前两个批次为 `aggregation-internal-demo` 和 `utilization-quality-demo`。打开 `/governance` 不会触发推理。任意未来批次的模型额度为零。重复授权不会补充预留额度；失败会明确显示且不会重试。若提供方或输出契约失败，不会伪造结果。

可选的 `--replace-failed-utilization-two-requests` 命令是单独明确授权的一次性输出重测，不是自动重试。它要求两阶段质量改进审核已终止失败；只替换显示的失败报告，不重发数据，并保留已消耗额度和 SDK 计数器。额外的两请求额度会单独显示。第二次替换或证据/来源 Agent 已更改时均会拒绝。

## Free regression coverage

使用项目互操作测试工作流运行 `Contest.RouteScenarioTests`、`Contest.RouteGovernanceTests`、`Contest.RouteEvidenceTests`、`Contest.RouteUITests`、`Contest.RouteReviewTests` 和 `Contest.RiskReviewV4Tests`。特权持久化测试还必须通过获授权的本地会话运行；权限较低的开发 MCP 会有意跳过这些分支。

测试涵盖场景绑定/篡改、未知用途和接收方、主张来源不变、条件性问题范围、确切投递证据、超量字段/配置拒绝、过期重置计划、不可变请求预算以及独立的重置/成本同意命令。测试夹具不会将范围外数据发送至真实接收方，也不会调用提供方。

## Verified local outcome

两个全新批次均完成了真实 BS/BP/BO 投递和自动 AI Hub 审核：

| 批次 | AI Hub 会话 | 已接受的限定范围结果 |
|---|---|---|
| `aggregation-internal-demo` | 145 / 146 | 对检查的问题未发现信号；适用条件已满足；无重要信息请求 |
| `utilization-quality-demo` | 149 / 150 | 对检查的问题未发现信号；适用条件已满足；无重要信息请求 |

首个 utilization 响应的依据引用无效且超出解释长度限制。系统拒绝了该响应，没有截断或重新标记。另行明确同意后，一次两请求输出重测通过了未更改的验证器。显示的失败报告已替换；其已消耗额度和 SDK 计数仍计入成本，而不是作为另一条演示记录。总计发生**六次交互**，41,292 个提示 token 和 41,635 个完成 token（总计 82,927），包含被拒绝的尝试。未运行自动重试。

五条物化引用已根据完整冻结源文本及确切偏移量核验。两个结果均保留覆盖限制以及分阶段评估器的保守 `manual_review` / `human_review_required` 标记；这些标记不是流水线拦截，也不代表缺少前置条件。运行事件为 `no_signal_on_checked_issues`，而不是 `unresolved`。这验证了两个正常合成场景，不代表一般法律准确性。

当前注册表有两条已批准路由、两个批次快照和一条 SQL 接收方收据。所有四个现有 Productions 仍在运行；没有任何一个被重启。已准备的 HIPAA 语料、来源 Agent/索引均未更改。验证通过：135 项 Python 测试、54 项前端测试以及 lint/type-check/build，还有八个经过授权且共含 345 个断言的 IRIS 套件。
