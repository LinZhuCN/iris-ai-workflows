# 文档目录

[English](./DOCUMENTATION.md) · [简体中文](./DOCUMENTATION.zh-CN.md)

英文是默认展示语言。下列每份项目文档都有完整简体中文对应版，并提供双向语言链接。
命令、标识符和历史测试结果保留原含义；翻译不代表新增运行时验收。

## 从这里开始

| 文档 | English（主版本） | 简体中文 |
|---|---|---|
| 项目概览 | [README](./README.md) | [项目概览](./README.zh-CN.md) |
| 安装与演示入口 | [Setup](./INSTALL.md) | [安装与入口](./INSTALL.zh-CN.md) |
| IRIS 运行时 | [Runtime](./contest/README.md) | [运行时](./contest/README.zh-CN.md) |
| Web UI | [Frontend](./web/README.md) | [前端](./web/README.zh-CN.md) |
| 本地许可放置 | [License setup](./iris/license/README.md) | [许可配置](./iris/license/README.zh-CN.md) |

`README.md` 是项目概览。详细安装指南为 `INSTALL.md`，
其中文对应版为 `INSTALL.zh-CN.md`。

## 演示与参赛材料

| 文档 | English（主版本） | 简体中文 |
|---|---|---|
| M5 现场纳管 | [Live steps](./contest/M5-ONBOARDING-DEMO.md) | [现场步骤](./contest/M5-ONBOARDING-DEMO.zh-CN.md) |
| 三接收方分发 | [Multi-organization demo](./contest/MULTI-ORGANIZATION-DEMO.md) | [多机构演示](./contest/MULTI-ORGANIZATION-DEMO.zh-CN.md) |
| 多机构开发计划 | [Plan](./contest/MULTI-ORGANIZATION-DEMO-PLAN.md) | [计划](./contest/MULTI-ORGANIZATION-DEMO-PLAN.zh-CN.md) |
| 历史录制讲解 | [Walkthrough](./contest/DEMO-WALKTHROUGH.md) | [讲解脚本](./contest/DEMO-WALKTHROUGH.zh-CN.md) |
| 历史详细演示指南 | [Demo guide](./contest/DEMO-GUIDE.md) | [详细指引](./contest/DEMO-GUIDE.zh-CN.md) |
| 院内路径 | [Route demo](./contest/ROUTE-DEMO.md) | [院内路径](./contest/ROUTE-DEMO.zh-CN.md) |
| 参赛文章 | [Article](./contest/CONTEST-ARTICLE.md) | [参赛文章](./contest/CONTEST-ARTICLE.zh-CN.md) |
| 提交文案与核对表 | [Submission](./contest/CONTEST-SUBMISSION.md) | [提交说明](./contest/CONTEST-SUBMISSION.zh-CN.md) |

M5 现场步骤是主演示。历史指引是独立参考，不用于替代新观测的生成。

## 架构、操作和开发

| 文档 | English（主版本） | 简体中文 |
|---|---|---|
| Production 监测与历史实验 | [Monitoring](./contest/MONITORING.md) | [监测](./contest/MONITORING.zh-CN.md) |
| Agent 工厂 | [Factory](./contest/AGENT-FACTORY.md) | [Agent 工厂](./contest/AGENT-FACTORY.zh-CN.md) |
| 知识 API 和嵌入 | [Knowledge setup](./contest/KNOWLEDGE.md) | [知识配置](./contest/KNOWLEDGE.zh-CN.md) |
| 声明工作流 | [Workflow](./contest/DECLARATION-WORKFLOW-PLAN.md) | [声明工作流](./contest/DECLARATION-WORKFLOW-PLAN.zh-CN.md) |
| 模拟接收端配置 | [Receivers](./contest/multiorg/receiver/README.md) | [模拟接收端](./contest/multiorg/receiver/README.zh-CN.md) |
| Agentic Dev 与 Skills 来源 | [Development tools](./contest/dev/README.md) | [开发工具](./contest/dev/README.zh-CN.md) |
| 发布知识包用法和来源 | [Package guide](./hipaa-demo-knowledge/README.md) | [知识包说明](./hipaa-demo-knowledge/README.zh-CN.md) |

## 本地调研笔记

`contest-knowledge/` 中的研发调研与验收笔记仅保存在本地，不纳入 Git。
公开指南不依赖这些本地文件。

## 翻译边界与维护

- 无语言后缀的 Markdown 默认英文，中文对应使用 `.zh-CN.md`。
- 修改要求、命令或证据时同时更新两版。英文是展示默认；
  事实差异应明确修正，不能静默当成不同产品声明。
- 双语化覆盖项目说明；本地研发笔记单独维护，不公开发布。
  不包含作为知识输入的法律/证据语料和 LLM 导读、
  原始许可/NOTICE 文本、Agent 指令/Skills 或运行数据。
  知识包 README 与许可放置 README 属于项目指引，因此包含在内。
- 翻译是项目说明，不是法律官方译文。不要将翻译指南加入检索语料，
  也不要仅为翻译文档而修改来源/知识摘要。
- 除非另有经过验证的修改，代码块应保持原样且可执行。
  代码注释和引用的 UI 标签可保留原语言，便于识别示例。
