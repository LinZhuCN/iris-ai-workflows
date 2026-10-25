# Production HIPAA 审核演示与录制脚本

当前**现场“首次纳管 → 新消息 → 新审计”**演示，请使用[固定 M5 入门演示](./M5-ONBOARDING-DEMO.md)。
下方编号记录是历史验收参考。范围受限的 M5 重置会归档旧监控视图，因此不要要求这些编号出现在当前 Production 审核列表中，也不要重放旧的付费测试脚本来恢复它们。

**语言：**[English](./DEMO-WALKTHROUGH.md) · 简体中文

[另见：含系统地址和分步要点的中文运维指南](./DEMO-GUIDE.zh-CN.md)

## 本演示展示什么

IRIS Interoperability Production 处理合成消息。独立观测器记录实际消息边和最小化的结构化事实。用户在批准审核时提供并确认业务背景。IRIS 将该批准绑定到一个消息 session，调用真实 AI Hub Agent，验证结构化结果和准确的来源引文，并保存建议性发现。

**演示输入是模拟中的可用事实。**无需连接真实医院、合同仓库或授权系统。UI 会将这些输入与采集到的消息证据区分开。未知答案会继续保持未知，审批者不会选择 AI 结论。

演示流程如下：

```text
实际合成 BS -> BP -> BO 消息
                |
        独立观测
                |
用户确认的、绑定 session 的业务前提 + 付费审核同意
                |
  AI Hub locator -> IRIS 准备规范性证据 -> AI Hub judge
                |
   IRIS grounding／引文检查 -> 已保存的发现 -> 人工检查
```

该 Production 级审核器是**发送后的建议性监控**。它不会阻断传送、隔离消息或重放消息。仓库中的独立原始分诊 BP 展示了有界 AI 路由与执行；参见[安装与分诊指南](./README.md)。不要将发送后的发现描述成阻止了已经完成的披露。

## 选择演示模式

| 模式 | 适用场景 | 副作用 |
|---|---|---|
| 检查已保存的真实结果 | 下方固定流程和视频 | 读取现有记录；不会发起新的模型请求或业务发送 |
| 预览新的审批 | 说明用户如何提供演示事实 | 仅为未保存的表单／预览，除非点击最终付费确认 |
| 执行新案例 | 单独授权的开发验收 | 新的合成消息发送和付费模型调用；不属于本录制流程 |

已保存记录是本地验收数据，不是干净 clone 自带的固定数据。启动基础 mock stack **不会**重新生成这些记录。缺少记录说明设置尚未完成，而不是允许用截图或虚构的成功数据替代。

## 录制前准备

1. 使用已经配置好的本地环境。若是新安装，请先阅读 [IRIS／EAP 要求与设置](./README.md#requirements)和 [UI 设置](../web/README.md#run-without-host-node)。已测试运行时为 IRIS for Health `2026.3.0AI.154.0`；需要获授权的 EAP 镜像和自有许可证。AI Hub EAP API 可能会变化。
2. 打开 <http://localhost:5173/pipelines>。使用已有的本地授权账号登录，并在登录后才开始屏幕录制。不要录入／录下凭据、环境文件、提供方密钥或授权头。完整刷新浏览器后需要重新登录。
3. 确认 inventory 中显示 **M5OBSERVATION / Contest.M5.Production**。它已经纳管。不要重新纳管、重启或重新配置。
4. 在仓库根目录运行只读的已保存结果检查：

   ```sh
   python3 contest/production_premises_test.py --check-complete
   ```

   此命令需要已配置的本地 API、现存的本地凭据文件和持久化 IRIS 报告。最终摘要必须包含：

   ```json
   {
     "status": "passed_after_explicit_input_mapping_repair",
     "first_pass": "2/3",
     "usage_including_failed_first_case": {
       "requests": 8,
       "tokens": 116871,
       "citations": 15
     },
     "business_sends_in_saved_runs": 4,
     "all_grants_revoked": true,
     "new_model_calls": 0,
     "new_business_sends": 0
   }
   ```

   实际命令还会打印逐案例检查和后续摘要。若失败则停止。不要删除 journals，也不要重跑付费命令来掩盖失败。
5. 使用易读的浏览器缩放比例，并关闭无关标签页、通知和开发者工具。需要时再展开原始 JSON 面板。

## 固定浏览器演示流程

### 1. 发现并选择 Production

在 **Managed Productions** 中点击 **Discover active Productions**，显示当前可访问的活动 namespace／Productions。这是读取操作，不是纳管或付费推理。说明用户可以选择要监控的 Production。

在 inventory 中点击 **Inspect M5OBSERVATION / Contest.M5.Production**。展示 Production 级范围以及实际消息边／证据面板。无需逐条业务流作为纳管前提。证据范围有限且经过抽样，并不能证明所有下游行为。

### 2. 普通治疗披露：header 30

在 **Sampled review records** 中点击 **Review detail 30**。
如有需要，请使用审核分页控件；不要将证据页的分页与审核列表分页混淆。

依次展示：

- **Scoped assessment: no signal on checked issues**。
- **User-approved demo premises**：确认用户／时间、session 30、外部治疗诊所、治疗用途、不依赖授权。
- 明确的技术主机／接收方映射和消息数据范围：内部传输主机不是独立业务接收方；在本模拟中，接收器代表所命名的诊所。
- 支持治疗许可 164.506(c)(2) 及治疗披露例外 164.502(b)(2)(i) 的推理和准确引文。

说明：仅凭完整出生日期和缺少个人授权，并不能认定此约定治疗披露存在失败。这是有范围的结果，并非笼统宣称该机构符合 HIPAA。

### 3. 缺少所需授权的付费营销：header 22

点击 **Review detail 22**。展示 **risk identified**、付费且无关产品的营销目的、明确缺少授权，以及明确排除的适用例外。展示 164.508 营销条件引文。

解释此发现基于一项明确未满足的条件，而不只是因为没有提供某份文件。在此场景中，处理方协议不能替代所需的个人授权。

### 4. 未知的业务条件：header 26

点击 **Review detail 26**。展示 **information required**、明确标记未知的接收方／许可输入，以及 **Material information required**。

解释系统会要求补充缺失事实，而不是臆造许可、臆造违规，或把未知等同于没有授权。

### 5. 展示保留的失败结果及修复

点击 **Review detail 18**。由于审批没有说明技术主机、业务接收方与患者／活动范围之间的关系，原始治疗结果仍为 **information required**。

返回 **Review detail 30**，展示单独批准的映射修复。首轮通过率为 2/3；修复表单／输入契约后，治疗后续测试通过，且预期法律条件未变。原始报告未被覆盖。不要说成首轮 3/3 通过，也不要说成留出测试。

### 6. 展示可审计性与费用边界

在一份报告中展开 **AI Hub sessions, usage, prompts and preserved output**，展示真实 locator／judge sessions 和记录的用量。如需更仔细地查看来源，再展开 **Dated normative sources and provenance**。

在 **Durable AI authorization history** 中展示四个 `m5-premises-*` grants：每个都已撤销，并各自预留了一次审核／两次请求。累计运行使用了四条新的合成消息、八次请求、116,871 个报告 token 和 15 条准确引文，其中包括首次治疗尝试。Token 数不是货币成本估算；尚未计算价格和账单。

### 7. 可选：不发起新调用的表单预览

在已采集的消息上，点击 **Use session ... for demo approval**。
**AI review approval, demo business premises and bounded funding** 面板会打开。说明接收方、用途、许可／授权、保障措施、特殊条件、主机映射和数据范围输入。

录制时保持业务前提确认和费用／导出确认均未勾选。说明最终付费确认是独立步骤。**不要**点击 **Confirm paid review authorization**，也不要授权新的检查。已有的终态审核不会自动重新评估。选择 session 或在表单中输入文字本身不会调用模型。

## 五分钟英文讲解稿（中文译文）

| 时间 | 画面 | 建议讲解 |
|---|---|---|
| 0:00-0:25 | Production inventory | “这个演示结合了 IRIS Interoperability 事件、经用户批准的业务背景和真实 AI Hub Agent。我们选择的是 Production，而不是逐条选择业务流。今天我检查的是本地真实执行后保存的结果；回放不会发起新的模型调用。” |
| 0:25-0:55 | 实际消息边与消息证据 | “IRIS 记录实际消息边以及范围有限、经过最小化的字段证据。接收方关系和预期用途等业务事实由审批者作为明确的演示前提提供。无需连接真实医院。” |
| 0:55-1:45 | Review 30 | “对于向治疗诊所进行的一般披露，结果是所检查问题未发现信号。审批说明了技术主机如何代表诊所，以及消息涉及哪项患者活动。审核者引用治疗许可和治疗场景的最小必要例外，而不会把完整出生日期一概视为禁止。” |
| 1:45-2:25 | Review 22 | “第二个案例是没有所需授权的付费营销，并明确排除了相关例外。Agent 识别出具体的授权风险，并提供精确、绑定来源的引文。笼统的批准标签或处理方协议都不会被当作法律许可。” |
| 2:25-3:00 | Review 26 | “在这里，接收方和许可明确为未知。正确结果是需要补充信息。缺失事实不会自动变成违规，未知授权也不会变成不存在授权。” |
| 3:00-3:35 | 先看 Review 18，再看 30 | “我们会保留未成功的尝试。首次治疗测试没有清楚说明技术主机与业务背景之间的联系。我们增加明确的映射字段，并在单独授权后使用相同的预期法律条件进行了后续测试。旧报告仍然保留。” |
| 3:35-4:15 | SDK 用量、来源、已撤销的 grants | “这些是真实 AI Hub locator 和 judge sessions。IRIS 会验证结构化依据和准确的来源段落。四项 grants 均已撤销。包含首次尝试在内，本轮使用八次请求和 116,871 个报告 token。这些计数不是货币成本估算。” |
| 4:15-5:00 | 审批表单，然后查看最终报告 | “用户在审批过程中提供场景，报告会将这些输入与消息证据分开展示。未知信息仍明确保持未知。这是发送后的建议性监控：它不声称能阻止已经完成的披露、执行任意动作或认证现实中的合规性。” |

## 录制与发布清单

- 录制连续的浏览器演示，或明确标注剪辑／时间跳转。已保存结果必须介绍为真实执行后保存的结果，而非现场推理。
- 英文讲解和字幕须与脚本一致；展示范围化结果、审批输入和引文，而不只是绿色状态标记。
- 不要显示凭据、本地机密文件、真实 PHI 或无关数据。
- 标明测试过的 EAP build，以及这些报告所用、已发布的 `deepseek-flash` Agent。保留已存的版本／契约来源信息。
- 来源证据使用已发布的、注明日期的规范快照，不是经过独立核验的实时法律。更广泛的八案例基准由助手撰写，并非独立专家验证，也不是总体准确率估算。
- 开发用 MCP／IRIS Agentic Dev 工具用于实现和测试，不是运行时业务 Agent。
- 致谢[原始 DataPipelineDemo](https://github.com/zlnick/DataPipelineDemo)及继承的 UI notices。说明 fork 增加的工作流和证据控制，不要暗示整个项目都从零创建。
- 只有在录制完成、审核并获准上传后，才能添加公开视频 URL。本指南是录制脚本，**不是已录制或已发布的视频**。竞赛提交和组织方接受与此技术演示是两回事。

完整结果、限制和修复历史参见
[M5 现场验收](./MONITORING.md#m5-approval-input-live-acceptance-and-explicit-repair)。
