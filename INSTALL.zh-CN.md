# 安装与演示入口

[English](./INSTALL.md) · [简体中文](./INSTALL.zh-CN.md) ·
[项目概览](./README.zh-CN.md) · [全部文档](./DOCUMENTATION.zh-CN.md)

本项目在不改变被观察 Production 业务流程的前提下，监测机构间数据交换中的潜在隐私
与合规风险。IRIS AI Hub 辅助发送后审查，发现供人工调查，不是自动法律认证。

配置分两层：小型 mock triage 工作流和扩展监测演示。
启动前者不会自动配置后者。

## 平台前提

- Docker Compose 2.24.4+ 和 Python 3。
- 单独取得的授权 AI Hub EAP 镜像和适当许可。
- 实测 ARM64 IRIS for Health `2026.3.0AI.154.0`；
  普通 Community 镜像缺少所需 AI Hub 运行时。
- 本机前端使用 Node 22.12+，也可采用
  [Docker UI 配置](./web/README.zh-CN.md)。

当前竞赛公告指定 AI Hub Community build 154。EAP 环境不是生产就绪部署，
不能根据本仓库的开源许可再分发其镜像或许可。

## Mock triage 快速启动

将许可放在 `iris/license/iris.key`，或将 `IRIS_LICENSE_PATH` 设为绝对本地路径。
在仓库根目录执行：

```sh
python3 contest/prepare.py
docker compose --profile mock up -d --wait
python3 contest/test.py --restart
```

Provider 是本地合成 mock；AI Hub SDK、事实 ToolSet、BP 策略检查、BO 和持久化审计
是真实组件。测试包含合成流量和重启检查。
打开 <http://127.0.0.1:52777/csp/sys/UtilHome.csp>，
使用 IRIS 管理员身份登录，选择 **TRIAGE**。

[运行时指南](./contest/README.zh-CN.md)解释镜像配置、初始凭据、
预期行为和排障，不需要患者数据。

## 真实模型运行时

参考 [.env.example](./.env.example) 填写被忽略的根目录 `.env`。
在本地配置 `LLM_BASE_URL`、`LLM_API_KEY` 和 `LLM_MODEL`：

```sh
python3 contest/prepare.py
docker compose --env-file .env -p iris-triage-real \
  -f contest/compose.yaml -f contest/real.yaml up -d --wait
```

独立的真实实例使用 <http://127.0.0.1:52779/csp/sys/UtilHome.csp>。
不要打印含凭据的解析后 Compose 配置。

以下是可选的**付费 triage 测试**，不是安装监测功能的步骤：

```sh
COMPOSE_PROJECT_NAME=iris-triage-real python3 contest/test.py --real --restart
```

它向真实 provider 发送合成案例，可能产生费用。
Triage Agent 只看到受限案例事实，而不是任意患者记录。

## 扩展监测演示

演示前配置：

1. [知识 API 和离线本地嵌入](./contest/KNOWLEDGE.zh-CN.md)。
2. [监测基础设施和 Production 观察](./contest/MONITORING.zh-CN.md)。
3. [M5 前提](./contest/M5-ONBOARDING-DEMO.zh-CN.md)中的固定 M5 基础流程、
   已发布 reviewer 及源码安装。
4. [前端配置与共享认证](./web/README.zh-CN.md)。

完整 M5 干净机器部署仍需发布复验；现有本地验收日志不是随项目分发的启动 fixture。

本机 Node 下，恢复 UI 并连接真实本地运行时：

```sh
cd web
npm ci --legacy-peer-deps
PLATFORM_API_TARGET=http://127.0.0.1:52779 npm run dev -- --host 127.0.0.1
```

打开 <http://localhost:5173/demo/m5>。登录、录入机构档案、
纳管 `M5OBSERVATION / Contest.M5.Production`、授权本地检查、
发送合成研究流、检查采集证据，再单独授权有界审查。
阅读结果和旁边的 **AI log**。

纳管不修改业务 BP、不授权正文检查、不购买推理。Reviewer 位于独立观察 worker。
[可选三接收方演示](./contest/MULTI-ORGANIZATION-DEMO.zh-CN.md)
增加独立本地命名空间中的实际 SQL、REST、HL7 V2 接收方。

HTTP 开发部署仅限 localhost。凭据保留在浏览器内存中，
安全的公开部署仍需额外工作。

## 验证与排练

免费语料检查：

```sh
python3 contest/knowledge.py verify --profile demo
python3 contest/knowledge.py release-check
```

在安装依赖的环境内执行前端检查：

```sh
cd web
npm test
npm run lint
npm run build
```

已有完整本地 M5 验收时：

```sh
python3 contest/m5_demo.py --check
```

此命令只读且需要已保存的日志，不会为新克隆生成验收证据。
`--run` 发送新消息并授权模型请求，`--reset` 归档固定 M5 逻辑状态。
操作前阅读[范围和保护措施](./contest/M5-ONBOARDING-DEMO.zh-CN.md)。

## 更多资料

- [项目能力、实测证据及限制](./README.zh-CN.md)
- [中文现场演示](./contest/M5-ONBOARDING-DEMO.zh-CN.md)
- [HIPAA 语料来源](./hipaa-demo-knowledge/README.zh-CN.md)
- [历史实验与保留的失败](./contest/MONITORING.zh-CN.md)
- [参赛文章](./contest/CONTEST-ARTICLE.zh-CN.md)及[发布核对表](./contest/CONTEST-SUBMISSION.zh-CN.md)
- [开发 MCP 与 Skills](./contest/dev/README.zh-CN.md)，与运行时 AI 区分

Fork 自 [DataPipelineDemo](https://github.com/zlnick/DataPipelineDemo)，上游不变。
项目代码采用 [Apache-2.0](./LICENSE)；附加署名和材料专属说明见 [NOTICE](./NOTICE)。
