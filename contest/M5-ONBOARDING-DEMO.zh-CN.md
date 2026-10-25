# M5 Production 从纳管到审计：现场演示指引

[English](./M5-ONBOARDING-DEMO.md) · [简体中文](./M5-ONBOARDING-DEMO.zh-CN.md)

## 固定对象与演示主线

入口：<http://localhost:5173/demo/m5>

固定使用 **`M5OBSERVATION / Contest.M5.Production`**。业务 Production 和
SQL 接收端提前部署好，不另建副本，也不在现场讲解基础设施搭建。

演示主线是：

**录入机构说明 → 纳管 → 授权字段检查 → 触发数据流 → 生成监控证据 → AI 审计 → 讲解结果。**

固定链路为 `M5Source → ProcessB → ReceiverB → SQLUser.M5Receipt`。
在这个合成场景里，前两个 Host 代表源医院，`ReceiverB` 代表外部研究机构。
该对应关系和机构档案里的 Business Partner 标识随运行冻结保存；
保存档案不会自动修改 Host 的原生配置。

风险来自实际消息与约定的矛盾：消息声明采用 Safe Harbor 去标识化，
但实际仍有合成姓名、MRN 和完整出生日期；示例研究机构只允许接收出生年份和状态。
不是简单把“没有个人授权”预先写成答案。

## 演示前准备

使用已配置好的真实 AI Hub/EAP、M5 基础设施、后台采集器、已发布审核 Agent
和知识索引。安装本轮新增代码：

```sh
python3 contest/m5_demo.py --install
```

此命令不发送业务消息，也不调用模型。完整环境要求见
[英文安装说明](./README.md)和[监控说明](./MONITORING.md)。
本地工作区认证也必须可用。若本项目拥有的 M5 基础流程尚未配置，
使用 [M5 验证程序](./production_acceptance_test.py) 中明确的 `setup()` 实现；
不要仅为安装新 UI 而运行其付费验收。

开发时做一次完整验收，然后重置为现场演示起点：

```sh
# Archives M5 logical state, sends ONE synthetic message, funds at most TWO
# model requests. Refuses an existing acceptance journal.
python3 contest/m5_demo.py --run

# Read-only: verify the saved real report, even after logical reset.
python3 contest/m5_demo.py --check

# Archive/reset only the fixed M5 demonstration to a clean logical start.
python3 contest/m5_demo.py --reset
```

本轮已实际验证一个新发送和一次两请求审核，AI Hub sessions 为 **226、227**，
结果是选定 Safe Harbor 路径的风险信号。测试中在付费调用前修复了草稿 Agent
筛选和 JSON 布尔类型问题，继续使用同一条消息和同一份授权，没有另买一次重试。
SDK 共记录 43,626 tokens，并非已核实的供应商账单。
其中 prompt 为 28,912，completion 为 14,714。
验收明细保存在不入 Git 的本地数据目录。
`--resume` 仅对保留的同一次已投递尝试及其精确授权进行核对，
不会分配另一条消息或替代预算。开发验收不是每次启动演示的前提。

## 现场操作

### 1. 从干净起点开始

打开页面并登录。确认固定 Namespace/Production，状态未纳管，暂无 M5
机构档案和运行记录。

再次排练时，在重置区域输入 `RESET M5 DEMO`，再点击
**Archive and reset M5 demo**。这一步有明确后果，所以保留精确确认。

### 2. 录入源医院和研究机构

在 **Source hospital** 和 **Research recipient** 中分别：

1. 点击 **Fill example**。
2. 展示机构职责、用途、允许和禁止字段、接收要求；这些内容可以编辑。
3. 点击 **Save for demo**。

“填入示例”只填表，保存才产生版本。这些档案属于本次 M5 演示，
不覆盖另一个多机构场景的共享档案。

讲解：“这些是 Demo 内成立的机构背景，不是官方法规，也不是模型的预设结论。”

### 3. 纳管固定 Production

点击 **Enroll M5 Production**，确认状态变为已纳管。
如需展示总清单，可通过页面链接进入 Productions 查看该对象。

讲解：“监管单位是整个 Production，不需要逐条登记业务流，不会重启业务。”

### 4. 授权本地字段检查

点击 **Authorize local inspection**，必须在本次发送之前完成。

讲解：“消息头观测和消息正文检查分开授权。这一步不调用 AI，不回填旧正文。”

### 5. 触发真实数据流

点击一次 **Send fixed synthetic research data**。

展示消息 ID、Session、接收 Header 及 SQL 回读匹配。
这是本次现场执行的 BS/BP/BO 链路，不是预生成报告。

注意：消息 Header 和回执不等于已经完成监控字段采集，更不等于合规结论。

### 6. 展示新生成的监控证据

等待后台采集，必要时点击 **Refresh status**。
展示实际采集状态、消息来源与目标、字段清单和完整日期精度。

如需追溯，在 Productions 查看 Observed message edges、会话关联和事件。
刷新不会再次发送消息。未采集、未审核或失败，都不能说成“没有风险”。
确认采集状态实际为 `captured`，不能只凭接收 Header 判定。

### 7. 授权 AI 审计

选择已发布的审核 Agent，勾选模型费用确认，然后点击
**Authorize bounded AI audit**。

本次授权固定限制为：

- 一条符合条件的会话/消息体审核；
- 最多两次模型请求；
- 30 分钟有效期；
- 仅适用于当前运行的源会话，不为其他会话提供额度。

失败或已预留的请求不会自动获得补偿额度。
审核使用本次发送时冻结的机构档案，不需要重新填写一遍业务背景。
发送后修改表单不会改写本次运行的机构版本。

### 8. 讲解本次审计结果

先展示 **Result / Why / Next**，再展开引用或技术细节。

保持示例档案不变时，预期发现：
**实际标识符和完整日期与所声明的 Safe Harbor 路径不一致。**

这只是本次可观测矛盾的判断，不是完整 HIPAA 合规认证，也不是说所有研究披露都违法。
若同一消息体的接收 Header 被去重，页面会同时标明代表性审核 Header，
它们仍绑定同一个消息体和源会话。

### 9. 用 AI log 展示真实模型工作

点击审计按钮旁的 **AI log**，展示：

- 两阶段原始响应；
- 本次 AI Hub Session；
- 模型与 token 使用量；
- 保存的输入、系统提示词和错误。

完整报告同时保留实际送入模型的机构档案事实与精确法规引用。
查看日志不会重新调用模型，缺少响应不能被包装为成功。

### 10. 收尾

说明这是**发送后的旁路建议性审核**，没有拦截已经完成的发送，
不会自动修改 Production 或重放消息。需要时在 Productions 添加人工事件备注。

## 重置到底会做什么

重置将固定 M5 对象的纳管、观测证据/事件、检查授权、审核记录/预算，
以及 M5 专用机构档案和运行记录归档到 `^ContestM5DemoArchive`，
再从当前界面移除，下一次纳管从当前消息游标开始采集。

**不物理删除**原始 IRIS 消息、SQL 回执和已保存的 RiskReview 报告；
不清理 Agent、模型配置、知识索引或全局审计日志；
不修改其他 Production、共享机构档案或多机构演示结果。
正在审核或留有未解决在途记录时会拒绝重置。

因此，“干净起点”是演示工作区的逻辑起点，不是销毁测试证据。
每次重置后使用新的运行 ID，界面自动生成，不手工复用旧消息编号。
原验收报告在重置后仍可只读验证；下次纳管从当前 Header/日志游标开始。
相同 ID 的重复发送返回已保存的尝试，不会重放业务。
不确定的审查提交可使用保存的精确授权显式核对，
不能通过新建身份静默购买重试。
