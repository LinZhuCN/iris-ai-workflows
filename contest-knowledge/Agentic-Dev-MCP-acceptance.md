# Agentic Dev MCP / Interop Skills 接入验收

## 范围与版本

- 官方 IRIS Agentic Dev `v1.5.0`，macOS ARM64 本地独立二进制。
- SHA-256：`cfae461e715945bdc0d3f6462ec1795c88f31a161573cca2c5872cda08c050d9`。
- IRIS for Health EAP `2026.3.0AI.154.0`，固定
  `127.0.0.1:52779 / TRIAGE`，专用开发账号。
- Interop Skills 上游参考版本：
  `00faab5be2915357dd20941f4b7990a65e73523c`。
  采用三项项目级 Copilot 精简适配，不是完整 Claude 插件安装。
- 开发工具与运行时 `%AI.Agent` 明确分离，未向业务 Agent 开放开发 MCP。

## 已验证

在仓库根目录执行：

```sh
python3 contest/dev/install.py
python3 contest/dev/prepare.py
python3 contest/dev/verify.py --tests
```

验收客户端真实启动 stdio MCP，执行 JSON-RPC initialize / tools/list /
tools/call：

1. `serverInfo` 返回 `iris-agentic-dev / 1.5.0`。
2. `check_config` 返回 `connection_source=config_file`，
   `config_file` 为本仓库配置；host、port、namespace 匹配目标，
   `write_tools_enabled=true`，`destructive_tools_enabled=false`。
3. 公布工具只包含指定九项，不包含通用执行、管理、全局删除工具。
   允许的编译/测试工具仍有代码执行能力，不能称为只读沙箱。
4. `iris_doc get` 读取真实 `Contest.Request.cls`。
5. `iris_doc put` 上传 `Contest.DevTests.cls`，
   `iris_compile` 返回无错误、成功编译。
6. `iris_test` 通过真实 `%UnitTest.TestProduction` 返回：
   `total=4, passed=4, failed=0, errors=0`。
7. `iris_get_log` 取得框架日志，确认三项业务测试共 **7 条断言**：
   完整消息的两项事实和两个脱敏属性检查、缺失字段/未知代码检查、
   无请求上下文时的事实工具访问拒绝。
   第四个测试方法为 no-op `TestControl`，避免改变既有 Production 生命周期。
8. 测试客户端退出时停止 MCP 子进程；本地真实演示实例继续运行。

回归：

```sh
COMPOSE_PROJECT_NAME=iris-triage-real python3 contest/test.py --real --persistence-only
```

真实三路业务记录、目标和审计重启前后相同，重复消息仍返回原 case，
不新增模型调用；门户 HTTP 200。未操作其他本地项目或上游仓库。

## 排障所得

- Apache 的 `/api/atelier/` 必须配置 `CSP On`：
  只有 `SetHandler` 时，带 `.cls` 的读取可能成功，但无扩展名的
  `/action/compile` 返回 Apache 404，导致 SCM probe/编译失败。
- CLI `tool check_config` 与真正 MCP 的配置报告行为不同；
  不能用 CLI 的 `connected=true` 代替真实 MCP 配置来源和读写验证。
- 数据库安全资源通过物理 `SYS.Database.ResourceName` 配置，
  不是 `Config.Databases` 的属性。
- IRIS 用户和角色不能同名：账号 `ContestDeveloper`，
  角色 `ContestDevelopment`。
- `%UnitTest.TestProduction.Run()` 要求 `^UnitTestRoot` 指向现存目录。
  未设置时可能被工具概括成 `NO_TESTS_FOUND`；应查看框架真实错误，
  不能把零测试当作通过。

## 保留边界

- 尚未证明当前 VS Code 会话已发现或自动调用新增 Skills。需要
  `MCP: List Servers` 启动/信任 `iris-triage-dev`，必要时重载窗口或新建对话。
- 密码、二进制、数据库和 `.env` 都在忽略路径内；不提交 Git。
- 开发角色并非 `%All`，也未使用宽泛 `%Developer`；但允许在 TRIAGE
  编译和执行可信开发代码，不是安全隔离执行环境。
- 本次没有新增真实模型推理、外部投递、生产变更或自动重放能力。
- 安装和操作方式见[开发工具指南](../contest/dev/README.md)。
