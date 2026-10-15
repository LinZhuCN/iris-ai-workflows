# 最小业务闭环验收记录

日期：2026-10-15。范围：独立 EAP、终端驱动的最小互操作分诊演示，
不是完整参赛发布或生产环境认证。

## 环境与隔离

- IRIS for Health AI Hub EAP `2026.3.0AI.154.0`，ARM64。
- Web Gateway `2026.2`，通过独立无管理角色的服务账号进行密码认证。
- 新建 `TRIAGE` 数据库及命名空间，通过
  `%EnsembleMgr.EnableNamespace("TRIAGE")` 启用互操作。
- 12 个应用类编译成功。BP、AI Hub、ToolSet 和数据均在 TRIAGE 运行，
  不手工补系统库映射，不在业务代码中切换 USER/HSLIB。
- 在全新数据目录完成安装和验收，不依赖早期探针容器中的手工配置。
- 原应用默认 Compose、镜像、数据目录未替换。许可、本地配置及生成的
  Gateway 密码均不提交 Git。

## 已通过的验收

| 验收项 | 实际结果 |
| --- | --- |
| 正常合成消息 | Agent 选择 deliver；BO 持久化唯一目标记录，状态 delivered |
| 缺必填字段 | Agent 选择 quarantine；持久化隔离记录，状态 quarantined |
| 未知代码 | Agent 选择 human_review；持久化待审核记录，状态 pending_review |
| 工具闭环 | Agent 实际调用注册 ToolSet 的 GetTriageFacts，留下 tool_facts 审计 |
| 受限事实 | 工具只允许当前 BP job 绑定的 case ID；不返回原始业务内容 |
| 成功消息重复提交 | 返回同一 case，不重新调用工具或写入目标 |
| 同 ID 不同内容 | 显式失败，不覆盖原结果 |
| 无效输入 JSON | 显式失败，有持久化错误记录 |
| 不安全 deliver | IRIS 策略拒绝缺字段消息的投递，目标写入数为 0 |
| 未知动作 | delete_production 被拒绝，目标写入数为 0 |
| 空理由、错误类型、无效模型 JSON | 均明确失败，不执行分流 |
| 跨 case 工具访问 | 工具拒绝，失败落库，不执行分流 |
| 跳过事实工具 | BP 检查失败，不因模型声称成功而投递 |
| provider HTTP 503 | SDK 错误传播，失败落库，无目标写入 |
| 失败消息再次提交 | 拒绝自动重放，不自动重新推理 |
| IRIS 重启 | case、目标内容和有序审计历史快照逐项相同 |
| 重启后重复提交 | 三个成功分流 case 仍各有一个目标及一次事实工具调用 |
| Portal | 全新环境及重启后登录页 HTTP 200 |
| Gateway 管理路径 | HTTP 403，未对宿主开放管理功能 |

八类模型/工具/provider 故障通过独立 mock 注入，不声称这些错误输出来自真实模型。
mock 也通过真实 AI Hub SDK 和 IRIS Production，不是直接调用 BP 方法的替代测试。

## 真实模型结果

使用用户授权的本地 `.env` 中的 `LLM_BASE_URL`、`LLM_MODEL`、
`LLM_API_KEY`，独立运行 `iris-triage-real`；未启动 mock provider。
实际模型标识为 `deepseek-flash`。未把服务地址或密钥复制到文档。
发送内容仅为合成 case ID、布尔事实及固定分诊指令。

| Case ID | Agent 决策 | 最终结果 | AI Hub session | BP 耗时 |
| --- | --- | --- | --- | --- |
| 1 | deliver | delivered | 1 | 2011 ms |
| 2 | quarantine | quarantined | 2 | 1994 ms |
| 3 | human_review | pending_review | 3 | 1805 ms |

每个 case 均有 received、tool_facts、agent_decision、policy、
executed 审计路径，并通过重启后重复提交验证。

保存的 provider usage 如下，**只对应 SDK 最终返回的 response，
不是整个 Agent 工具循环的累计 token 或账单统计**：

| Case ID | prompt_tokens | completion_tokens | total_tokens |
| --- | --- | --- | --- |
| 1 | 481 | 84 | 565 |
| 2 | 487 | 51 | 538 |
| 3 | 470 | 80 | 550 |

另有 provider 返回的缓存及 reasoning 计数保存在 case 的 Usage JSON 中。
尚未取得全工具循环 usage 和实际账单，因此不报告估算费用。
这三个合成样本证明运行时路径可用，不是模型质量评测。

## 可复现入口

- [英文安装和操作说明](../contest/README.md)
- [独立 Compose](../contest/compose.yaml)
- [真实 provider override](../contest/real.yaml)
- [自动化验收入口](../contest/test.py)
- [IRIS 端断言和重启快照](../contest/src/Tests.cls)

最后一轮 mock 全套故障和重启测试通过；真实实例再执行仅重启和去重检查，
没有额外发起模型调用。相关脚本以完整行标记和进程返回码检查结果，
不把 IRIS 终端正常退出或日志中出现某个单词视为业务成功。

## 明确未覆盖的部分

- deliver 为本地持久化 demo sink，尚不是实际外部业务系统。
- human_review 为持久化待审核队列，尚无人工审核/处置界面。
- 未开放自动重放；未验证负载、并发、进程崩溃或外部副作用的 exactly-once。
- Gateway 使用私有 Docker 网络内的密码认证，未配置 TLS；不是生产安全部署。
- AI Hub EAP API 可能变化；此验收不证明默认 Community 2026.1 包含 AI Hub，
  也不代表主办方已确认参赛资格。
- 全 Agent 循环的 token/成本聚合、超时/长时故障和更广泛的模型评测仍待完善。
