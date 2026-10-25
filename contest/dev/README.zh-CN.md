# Agentic Dev MCP and Copilot Interop Skills

[English](README.md) | [简体中文](README.zh-CN.md)

这些是**开发工具**，不是运行时 AI Hub Agent。运行时推理仍在 BP 内使用
`%AI.Agent`、`%AI.ToolSet` 和 `%AI.Tool`。

## 安装和连接

前置条件：Python 3.9+、curl、Docker/Colima，以及[工作流指南](../README.md)
所述的真实演示部署正在运行。此工作区配置有意仅指向 `127.0.0.1:52779`、
命名空间 `TRIAGE`。它不会连接其他容器、继承而来的应用程序或生产环境。

从仓库根目录运行：

```sh
python3 contest/dev/install.py
python3 contest/dev/prepare.py
python3 contest/dev/verify.py --tests
```

安装程序会下载官方 **iris-agentic-dev v1.5.0** macOS/Linux ARM64 或 x86_64
制品，并依据 GitHub 发布制品元数据中的固定 SHA-256 校验。可执行文件和生成的密码均留在
被忽略的 `contest/data/agentic-dev/` 下；不需要全局安装。

配置需要 Docker 管理权限，并会明确在 `iris-triage-real-iris-1` 中执行。
它为物理 TRIAGE 数据库分配专用 `%DB_TRIAGE` 资源，创建 `ContestDevelopment` 角色和
`ContestDeveloper` 账户，并在 TRIAGE 中设置 `^UnitTestRoot="/contest/dev"`。
重新运行会保留本地密码。重建数据库后应重新运行；此步骤有意不属于运行时安装流程。

在 VS Code 中，将此仓库作为工作区打开。使用 **MCP: List Servers** 启动/信任
**iris-triage-dev**。已提交的[工作区 MCP 配置](../../.vscode/mcp.json)会启动
[mcp.py](./mcp.py)，它提供被忽略的密码并固定工作区配置。它会移除继承而来的
`IRIS_*` 环境覆盖项。如果 MCP 服务器已经运行，请重启。

调用 `check_config`，并要求其满足 `connection_source="config_file"`、
主机 `127.0.0.1`、端口 `52779`、命名空间 `TRIAGE`，且禁用破坏性工具。
若连接是自动发现的，不要继续操作。VS Code 可能需要重新加载窗口/新建聊天才能发现技能；
独立测试并不能证明编辑器已发现技能或会自动调用技能。

## 实际权限和限制

[.iris-agentic-dev.toml](../../.iris-agentic-dev.toml) 仅发布以下工具：

`check_config`、`iris_doc`、`iris_compile`、`iris_query`、`iris_search`、
`iris_symbols`、`iris_test`、`iris_debug`、`iris_get_log`。

已启用写入权限，以便开发时编译和测试；已禁用破坏性工具。角色授予
`%Development:U`、`%DB_TRIAGE:RW`、`%DB_IRISLIB:R`、`%DB_ENSLIB:R`、
`%DB_IRISTEMP:RW`；它不是 `%All`，也不是权限广泛的 `%Developer`。
Gateway 路由启用扩展名可省略的 `/api/atelier/` REST 端点并设置 `CSP On`；
IRIS 身份验证仍保持启用。

**这不是只读接口，也不是 ObjectScript 沙箱。**编译和运行测试会执行代码；
`iris_doc` 可以写入/删除文档，`iris_query` 也有写入模式。工具门控设置并不会让获准工具
变得无害。仅用于可信的本地开发。不要默认授权生产环境变更、重放、凭据访问或真实服务提供方调用。
上游服务器可能会尝试 USER 遥测辅助操作；此角色并未获准写入 USER 数据库。
不要为了遥测扩展权限。

## 验收脚本的验证内容

[verify.py](./verify.py) 使用真实的 stdio JSON-RPC `initialize`、`tools/list` 和
`tools/call`，而不是模拟 MCP 响应：

- 加载项目配置并选择预期目标。
- 公布的工具不超出项目允许列表。
- `iris_doc` 读取已部署的 `Contest.Request` 类。
- 使用 `--tests` 时，`iris_doc` 上传 [DevTests.cls](./DevTests.cls)，
  `iris_compile` 编译它，`iris_test` 运行真实的 `%UnitTest.TestProduction` 框架。
  嵌套失败和空测试套件都会导致验证失败；`iris_get_log` 会检索详细证据。

三个包含断言的方法会检查完整安全事实、不完整/未知代码事实，以及未绑定事实工具时的拒绝行为。
第四个方法是无操作的 `TestControl`，特意避免更改 Production 生命周期。
没有单元测试会调用服务提供方或重放业务消息。测试会写入框架结果和临时辅助类；
因此这不是只读检查。验证结束时客户端进程会停止。

## Skills 来源

上游 [IRIS Interop Skills](https://github.com/intersystems-ib/iris-interop-skills)
已在提交
[`00faab5be2915357dd20941f4b7990a65e73523c`](https://github.com/intersystems-ib/iris-interop-skills/tree/00faab5be2915357dd20941f4b7990a65e73523c)
进行审查。本项目将 messages-first 路由器和 TDD/单元测试指导改编为三个独立的 Copilot
Agent Skills，并补充项目专属调试指导：

- [iris-interop](../../.github/skills/iris-interop/SKILL.md)
- [iris-interop-tdd](../../.github/skills/iris-interop-tdd/SKILL.md)
- [iris-message-debug](../../.github/skills/iris-message-debug/SKILL.md)

这些是经过整理的**改编内容**，不是安装完整的上游 Claude Code 插件或全部 21 个技能。
未安装 Claude hooks、子代理、CCR/BASE 工作流或不可用的同级技能依赖项。
名称、路径、MCP schema、命名空间及外部管理的 Production 行为均为本仓库作了适配。
来源致谢：Pierre-Yves Duquesnoy，MIT 许可证，保留在
[interop-skills-LICENSE](./interop-skills-LICENSE) 中。

MCP 二进制文件单独从官方
[IRIS Agentic Dev release](https://github.com/intersystems-community/iris-agentic-dev/releases/tag/v1.5.0)
获取。其上游许可条款仍然适用；此 Git 树不重新分发该二进制文件。
