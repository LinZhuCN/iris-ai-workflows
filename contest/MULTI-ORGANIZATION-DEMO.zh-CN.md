# Multi-organization FHIR distribution demo

[English](./MULTI-ORGANIZATION-DEMO.md) | [简体中文](./MULTI-ORGANIZATION-DEMO.zh-CN.md)

此本地合成演示从 IRIS FHIR R4 Patient 读取数据，将其转换为三种不同表示，并投递至同一 IRIS 实例中分别存储的三个模拟机构。

| 命名空间 | 角色 | 实际边界 |
|---|---|---|
| `FHIRDEMO` | 来源受保护医院场景 | 经过身份验证的 FHIR HTTP 读取 |
| `DEMODISTRIBUTION` | `Contest.Multi.Production` | 来源 BS、分发 BP、三个出站 BO 和咨询审核 BP |
| `DEMOQUALITY` | 内部质量部门 | JDBC SQL 连接、参数化列插入及回读 |
| `DEMORESEARCH` | 外部研究中心 | 经身份验证的 REST 请求和持久化 JSON 回读 |
| `DEMOCLINIC` | 外部治疗诊所 | HL7 V2 TCP/MLLP 接收器、关联 ACK 和持久收据 |
| `TRIAGE` | 控制平面 | 版本化档案、知识、AI Hub 报告和人工审核事件 |

这些是逻辑隔离的系统，不是三台独立服务器。接收方应用数据使用独立数据库。诊所接收器是 IRIS 管理的监听器作业，不是独立接收器 Production。

若要检查实际模型工作，请点击 **Run AI audit** 旁边的 **AI log**。它会显示所选运行的三个接收方已保存报告，包括原始定位/判断响应、AI Hub 会话 ID、用量和错误。打开或关闭日志不会启动审核或购买重试。对于未经审核的运行，或没有阶段输出的失败阶段，不会声称存在已保存响应。

## Installation into the existing local platform

前提条件：真实 AI Hub 部署、经过身份验证的平台 API、知识索引和已发布隐私审核者，见[安装指南](./README.md)和[监控指南](./MONITORING.md)。没有 AI Hub 的普通 Community 镜像无法替代已测试的 EAP 构建。不需要真实患者数据、外部接收方或新的 Python 包。SQL 客户端使用此镜像捆绑的 JDBC 驱动和 Java 运行时。

```sh
# 现有自有 FHIR 仓库/客户端基础设施；不会发送批次。
python3 contest/aggregation_setup.py --apply
python3 contest/multiorg_receivers_setup.py --apply --verify
python3 contest/multi_setup.py --apply
docker compose -f web/compose.yaml up -d
```

已提交的 Gateway 配置包含对 `/csp/multiresearch` 的无扩展名路由。更新配置后，已运行的 Gateway 必须重新加载；仅配置接收方不能改变 Apache 路由。确切凭据、所有权检查、SQL 架构和协议测试见[接收方设置](./multiorg/receiver/README.zh-CN.md)。凭据保存在被忽略的本地文件中，绝不会填入组织档案。

配置会拒绝不属于本项目的命名空间所有权。容器启动只会恢复自有接收方监听器和自有分发 Production；不会播种患者数据、发送消息或购买模型调用。

## Browser walkthrough

| 入口 | 本地 URL |
|---|---|
| 组织表单 | <http://localhost:5173/organizations> |
| 主分发和审核页面 | <http://localhost:5173/demo> |
| Production 观察和人工事件操作 | <http://localhost:5173/pipelines> |
| 早期合成连接器演示 | <http://localhost:5173/demo/legacy> |
| IRIS Portal | <http://127.0.0.1:52779/csp/sys/UtilHome.csp> |
| FHIR 端点，单独身份验证 | <http://127.0.0.1:52779/csp/healthshare/fhirdemo/fhir/r4> |

1. **保存组织。** 填写来源医院和三个接收方的可编辑预设，检查职责及允许/禁止的字段，然后点击 **Save for demo**。保存会建立版本化场景前提；无需额外复选框。填写表单不会保存、发送数据或调用模型。
2. **登记观察。** 在 Productions 页面发现 `DEMODISTRIBUTION / Contest.Multi.Production`，登记只读监控，并单独授权本地合成检查。这会添加通用消息观察；它不是模型费用授权或法律许可。
3. **准备来源数据。** 点击 **Prepare demo data**，只在自有仓库中创建 `Patient/agg-multi-p1`。重复执行会验证现有数据是否相同，而不会悄然替换其他资源。
4. **运行分发。** 选择变体并点击 **Run distribution**。按钮会提交该变体和稳定运行 ID；没有额外确认复选框。BP 会读取版本化 FHIR 来源，并发送 SQL、REST 和 HL7 输出。检查三份实际收据、输出字段和冻结的档案修订。
5. **可选地运行 AI 审核。** 一次成本确认后点击 **Run AI audit**，可为该运行最多三个审核、六次模型请求提供额度。不重复要求合成数据确认：此工作流限制为使用自有合成夹具和本地接收方。预留单次授权前，会先执行免费的 Business Process 预检，以验证证据和规范性来源。
6. **读取结果。** 每个分支以 Result / Why / Next step 为主。接收方政策不匹配与 AI HIPAA 结论分开。仅在检查来源信息时展开收据和 AI 审核详情。Production 事件支持确认和人工备注，不支持自动更改投递。

选择已保存运行，或打开 `/demo?run=<saved-run-id>`，即可重新查看证据，不会再次发送或付费。加载历史报告不是实时推理。刷新可能需要重新登录；不会重放执行。

### Verified saved demonstration

打开[已接受运行](http://localhost:5173/demo?run=multi-fe23cf92-73ec-45dc-91cc-77b0828e27dd)即可查看真实结果，不产生模型费用：

| 分支 | 已保存结果 |
|---|---|
| 质量 / SQL | 对已检查的内部运营/最小化问题未发现信号 |
| 研究 / REST | 已识别风险：实际标识符与所声称的 Safe Harbor 路径冲突；替代研究许可仍未解决 |
| 诊所 / HL7 | 对规定的同一患者治疗披露未发现信号，并考虑了治疗情境例外 |

审核在 BP 会话 59 中运行，并保留 AI Hub 会话 219–224，包括实际提示、输出、token 用量和确切来源片段。该已接受运行的 SDK 报告提示 token 70,768 个、完成 token 26,301 个（总计 97,069）。其中 24,775 个推理 token 已计入完成 token；10,624 个缓存读取 token 已计入提示 token，不可重复相加。这些计数不是提供方账单，也不是经核实的货币成本。早先一次研究提供方超时仍显示在此前运行中；已接受运行使用另行授权的第二笔六请求预算。没有重新标记或替换任何失败报告。

一次真实 IRIS 容器重启保留了四个完整的已保存运行/报告哈希、十二次独立回读的接收方收据和所有 AI 报告预算。唯一新增消息标头属于 IRIS 调度器启动流量，不是业务重发或 AI 请求。研究事件的人工审核记录为 `in_review`，随后为 `needs_information`，未更改投递，也未额外推理。

## What the three branches demonstrate

- **SQL / 内部质量：**本地患者代码、数字出生年份和限定状态。SQL 回读会独立检查实际列值。这展示已配置的本地最小化政策，不代表完整 HIPAA 合规。
- **REST / 研究：**`identifier-leak` 变体声明 Safe Harbor 去标识化，实际却发送合成姓名、MRN 和完整出生日期。`corrected` 变体删除这些被选定标识符；这并不能证明完全符合 Safe Harbor。
- **HL7 / 治疗：**PID 为规定的、实际治疗同一转诊患者的场景携带身份和出生日期。审核者必须考虑治疗许可和相关例外，而不能将每个标识符都视为自动违规。

出站主机具有原生 Business Partner 关联。档案使用稳定组织 ID，并保留修订、确认者、时间和内容哈希。编辑当前档案不会改写先前运行中的档案快照。更改 partner key 需要与主机配置显式对账；保存档案绝不会悄然重新配置 Production。

## Evidence and execution boundaries

Sidecar 会在投递后读取持久化的出站消息正文和实际标头边，并检查接收方回读，记录最小化字段事实。它不会仅凭原始 FHIR 资源推断接收方内容。原始合成接收方负载留在本地；模型数据包包含字段存在性、日期精度、机构上下文和来源信息，不包含患者身份值。

`AdvisoryAudit` Business Process 会执行真实 `%AI.Agent` 阶段，使用 `TRIAGE` 保护知识和报告存储。报告会保留该 Business Process 会话、AI Hub 会话 ID、输入、系统提示、输出、用量、引用和契约验证情况。

投递确认并不证明之后发生了临床使用。AI 审核是发送后的咨询意见，不是拦截、法律认证或业务审批。契约/模型执行失败会标为 `not_assessed`，而不是无风险结果。未解决的重要事实会明确保留。

相同 run ID 的重复提交会返回已保存运行，不会重发。部分成功、失败和结果不确定的尝试都会保留可见。之后的不同导出需要新的明确确认运行 ID。重启时，执行中的工作会标记为中断，而不是自动重放。

常规保存、准备合成数据、启用只读监控和撤销授权均使用直接操作按钮，不使用额外确认复选框。通用 Production 页面上的检查仍是单独的直接操作，因为启用标头观察并不等于允许检查任意消息正文。已经监控的对象会显示其状态，而不是显示禁用的确认控件。模型费用仍需明确同意；用户仍可选择范围，例如是否纳入未审核的历史捕获。服务器权限、修订、预算和重复执行检查保持不变。

## Verification commands

```sh
python3 -m unittest discover -s contest -p test_multi_runtime.py
python3 -m unittest discover -s contest -p test_multiorg_receivers.py
python3 contest/multiorg_receivers_setup.py --apply --verify

# 显式发送两个本地合成变体；绝不调用模型。
python3 contest/multi_acceptance.py --run

# 只读取已保存的验收记录；不发送、不调用模型。
python3 contest/multi_acceptance.py --check
```

验收运行器拒绝替换现有尝试。显式使用 `--new-attempt` 会分配新的免费合成运行 ID，并保留之前的开发尝试。`--audit` 会单独产生费用，并拒绝已经存在的审核记录。不要仅为检查已保存结果而运行此命令。

前端验证使用[网页项目](../web/package.json)中的现有 Vitest、TypeScript、ESLint 和 Vite 命令。分阶段验收门槛见[开发计划](./MULTI-ORGANIZATION-DEMO-PLAN.zh-CN.md)。
