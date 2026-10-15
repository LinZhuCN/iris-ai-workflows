# IRIS AI Hub Interoperability Workflows

[English README](./README.md)

面向 InterSystems AI Agents in Interoperability Workflows 竞赛的消息异常分诊应用。
AI Hub Agent 在 IRIS Interoperability BP 中调用受限事实工具，建议投递、
隔离或人工审核；IRIS 校验策略并执行动作，保存完整路径的审计记录。

```text
合成消息 -> IRIS 事实检查 -> AI Hub Agent + 只读 ToolSet
                                    |
                              BP 策略校验
                                    |
                    BO -> 投递 / 隔离 / 人工审核队列
                                    |
                       持久化决策、结果与审计
```

## 安装与运行

需要 Docker Compose 2.24.4+、Python 3、自行取得的 AI Hub EAP 镜像与有效许可。
已验证 ARM64 IRIS for Health `2026.3.0AI.154.0`；不能用不含 AI Hub 的
默认 Community 镜像替代。EAP 是预发布软件，不用于生产。

1. 将本地许可放入 `iris/license/iris.key`，或设置绝对路径 `IRIS_LICENSE_PATH`。
   许可不会随仓库分发。
2. 在仓库根目录执行：

```sh
python3 contest/prepare.py
docker compose --profile mock up -d --wait
python3 contest/test.py --restart
```

默认使用本地 mock，不调用外部模型，但经过真实 AI Hub SDK、BP、ToolSet 和 BO。
访问 <http://127.0.0.1:52777/csp/sys/UtilHome.csp>，登录后选择 `TRIAGE`。
此命名空间由安装程序新建并启用 Interoperability，不手工补系统类库映射。

真实模型需要本机 `.env` 中配置的 `LLM_BASE_URL`、`LLM_API_KEY` 和 `LLM_MODEL`：

```sh
docker compose --env-file .env -p iris-triage-real \
  -f contest/compose.yaml -f contest/real.yaml up -d --wait
COMPOSE_PROJECT_NAME=iris-triage-real python3 contest/test.py --real --restart
```

真实实例门户为 <http://127.0.0.1:52779/csp/sys/UtilHome.csp>。
真实调用可能产生费用；不使用真实患者数据。不要输出包含密钥的 Compose 配置。

详见[英文操作说明](./contest/README.md)和[验收记录](./contest-knowledge/Minimal-workflow-acceptance-2026-10-15.md)。
已验证三路真实模型分流、8 类 mock 故障、去重、重启持久化和门户连接。
投递目前为本地持久化目标，人工审核为待处理队列；尚无处置界面、
外部投递或全工具循环的费用统计，不代表生产就绪。

## 开发工具与 Skills

已接入官方 IRIS Agentic Dev v1.5.0 的项目级 MCP 配置，并提供基于
[IRIS Interop Skills](https://github.com/intersystems-ib/iris-interop-skills)
精简适配的 3 个 Copilot Skills（互操作开发、TDD、消息调试）。
它们是开发期辅助，不替代业务 BP 内真正的 AI Hub Agent。
安装、权限和真实 MCP 编译/单元测试方法见[开发工具指南](./contest/dev/README.md)。

## HIPAA 演示知识

发布版采用约 23 MB 正文的完整整理文本包，而不再使用原来的 2 MB 精选子集。
带来源元数据的 JSONL 约 25 MB；原始 PDF 和网页归档仍留在本地，不上传 Git。
LLM 编写的摘要与官方原文有明确区分，不能将整个包描述为经 LLM 改写的法规。

法规与指南、技术参考、LLM 导读、模拟组织策略、历史资料和未审查资料分层保存。
历史与未审查资料不会进入默认导出，可按上下文显式导出。资料类别并不代表
法律效力已经全面核定；案例、提案或历史解释不能替代适用的现行法规。

```sh
python3 contest/knowledge.py verify
python3 contest/knowledge.py select --profile demo
python3 contest/knowledge.py release-check
python3 contest/knowledge.py export --output contest/data/knowledge/default.jsonl
```

验证与导出不依赖本地原始归档，不调用模型。当前尚未导入 AI Hub 或接入审核 Agent；
切换输入不代表运行时知识已经更新。详见[知识包说明](./hipaa-demo-knowledge/README.md)。

## 目录结构

- `contest/`：工作流源码、独立 Compose、Gateway 配置与验收脚本。
- `contest/data/`：忽略的本地数据库和 Gateway 凭据，不提交 Git。
- `contest-knowledge/`：项目专用知识与验收资料；早期探针笔记仅为历史记录。
- `iris/license/`：许可目录约定；实际 key 不提交 Git。

## 上游与新增内容

本仓库 fork 自 [zlnick/DataPipelineDemo](https://github.com/zlnick/DataPipelineDemo)。
原项目通过 AI 推荐映射并生成数据管道；本 fork 聚焦运行时的受控消息决策。
新增 AI Hub Agent/ToolSet、专用 TRIAGE 命名空间、BP 策略验证、
持久化三路分流、审计、真实模型验证及可复现测试。

旧前后端、管道生成、术语服务器子模块、embedding、JDBC 辅助流程和素材已退出
当前版本；可以通过 Git 历史查看，不再是安装依赖。原项目及其他本地项目未被修改。
不需要初始化 Git 子模块。

参赛是否获批由主办方决定，EAP 版本接受情况仍需确认。

## 许可证

Apache-2.0，参见 [LICENSE](./LICENSE) 和 [NOTICE](./NOTICE)。
保留原项目归属，不随仓库分发 InterSystems 镜像、许可或模型凭据。
