# Documentation

[English](./DOCUMENTATION.md) · [简体中文](./DOCUMENTATION.zh-CN.md)

English is the default presentation language. Each project-authored document
below has a complete Simplified Chinese counterpart with a reciprocal language
link. Commands, identifiers and historical test results retain their original
meaning; translations do not constitute new runtime acceptance.

## Start here

| Document | English (primary) | 简体中文 |
|---|---|---|
| Project overview | [README](./README.md) | [项目概览](./README.zh-CN.md) |
| Installation and demo entry points | [Setup](./INSTALL.md) | [安装与入口](./INSTALL.zh-CN.md) |
| IRIS runtime | [Runtime](./contest/README.md) | [运行时](./contest/README.zh-CN.md) |
| Web UI | [Frontend](./web/README.md) | [前端](./web/README.zh-CN.md) |
| Local license placement | [License setup](./iris/license/README.md) | [许可配置](./iris/license/README.zh-CN.md) |

`README.md` is the project overview. Detailed installation instructions are
in `INSTALL.md`, with the matching translation in `INSTALL.zh-CN.md`.

## Demonstrations and contest materials

| Document | English (primary) | 简体中文 |
|---|---|---|
| Live M5 onboarding | [Live steps](./contest/M5-ONBOARDING-DEMO.md) | [现场步骤](./contest/M5-ONBOARDING-DEMO.zh-CN.md) |
| Three-recipient distribution | [Multi-organization demo](./contest/MULTI-ORGANIZATION-DEMO.md) | [多机构演示](./contest/MULTI-ORGANIZATION-DEMO.zh-CN.md) |
| Multi-organization development plan | [Plan](./contest/MULTI-ORGANIZATION-DEMO-PLAN.md) | [计划](./contest/MULTI-ORGANIZATION-DEMO-PLAN.zh-CN.md) |
| Historical recording walkthrough | [Walkthrough](./contest/DEMO-WALKTHROUGH.md) | [讲解脚本](./contest/DEMO-WALKTHROUGH.zh-CN.md) |
| Detailed historical demo guide | [Demo guide](./contest/DEMO-GUIDE.md) | [详细指引](./contest/DEMO-GUIDE.zh-CN.md) |
| Internal hospital routes | [Route demo](./contest/ROUTE-DEMO.md) | [院内路径](./contest/ROUTE-DEMO.zh-CN.md) |
| Contest article | [Article](./contest/CONTEST-ARTICLE.md) | [参赛文章](./contest/CONTEST-ARTICLE.zh-CN.md) |
| Submission copy and checklist | [Submission](./contest/CONTEST-SUBMISSION.md) | [提交说明](./contest/CONTEST-SUBMISSION.zh-CN.md) |

The live M5 sequence is the main presentation. Historical walkthroughs remain
distinct references, not substitutes for generating a new observation.

## Architecture, operations and development

| Document | English (primary) | 简体中文 |
|---|---|---|
| Production monitoring and historical experiments | [Monitoring](./contest/MONITORING.md) | [监测](./contest/MONITORING.zh-CN.md) |
| Agent factory | [Factory](./contest/AGENT-FACTORY.md) | [Agent 工厂](./contest/AGENT-FACTORY.zh-CN.md) |
| Knowledge API and embeddings | [Knowledge setup](./contest/KNOWLEDGE.md) | [知识配置](./contest/KNOWLEDGE.zh-CN.md) |
| Declaration workflow | [Workflow](./contest/DECLARATION-WORKFLOW-PLAN.md) | [声明工作流](./contest/DECLARATION-WORKFLOW-PLAN.zh-CN.md) |
| Simulated receiver setup | [Receivers](./contest/multiorg/receiver/README.md) | [模拟接收端](./contest/multiorg/receiver/README.zh-CN.md) |
| Agentic Dev and Skills provenance | [Development tools](./contest/dev/README.md) | [开发工具](./contest/dev/README.zh-CN.md) |
| Released knowledge package usage and provenance | [Package guide](./hipaa-demo-knowledge/README.md) | [知识包说明](./hipaa-demo-knowledge/README.zh-CN.md) |

## Local research notes

Development research and acceptance notes under `contest-knowledge/` are kept
locally and excluded from Git. They are not dependencies of the published guides.

## Translation boundaries and maintenance

- Use unsuffixed Markdown files for default English pages; use `.zh-CN.md`
  counterparts for Chinese.
- Update both versions when changing requirements, commands or evidence.
  English is the presentation default; any factual discrepancy must be resolved,
  not silently treated as a different product claim.
- This bilingualization covers project explanations; local research notes are
  maintained separately and are not published. It
  excludes legal/evidence corpus text and LLM briefs used as knowledge inputs,
  original license/NOTICE texts, Agent instructions/Skills and runtime data.
  The knowledge-package README and license-placement README are project
  instructions and are included.
- Translations are project documentation, not official translations of law.
  Do not add translated guide files to the retrieval corpus or change a
  source/knowledge digest merely to translate documentation.
- Keep code blocks executable and unchanged unless a separately tested change
  is intended. Code comments and quoted UI labels may retain their original
  language to keep examples identifiable.
