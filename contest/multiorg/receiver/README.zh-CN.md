# M2 local recipients

[English](./README.md) | [简体中文](./README.zh-CN.md)

这是三个在逻辑上隔离的合成数据接收方，并非相互独立的组织，也不是合规决策引擎。不会调用提供方/模型。

## Deployment

```sh
python3 -m unittest contest/test_multiorg_receivers.py -q
python3 contest/multiorg_receivers_setup.py --apply
python3 contest/multiorg_receivers_setup.py --verify
```

`--apply` 仅创建本项目拥有的数据库/命名空间、专用用户/角色、REST 应用和环回 MLLP 监听器。若数据库路径、命名空间映射、所有权标记、凭据、Web 应用或端口存在冲突，则拒绝执行。不会重置现有命名空间。重复应用会保留收据。默认容器为 `iris-triage-real-iris-1`；源文件挂载在 `/contest/multiorg/receiver`。

受保护的生成凭据仅保存在被 Git 忽略的持久卷中：`/dur/multiorg-receiver/credentials.json` 和 `quality.properties`，文件模式为 `0600`；其目录模式为 `0700`。SQL 凭据使用专用角色，仅可访问相应数据库和 SQL 服务，并且在收据表上仅有 `SELECT, INSERT` 权限。REST 凭据仅可访问其接收方数据库、Web 应用资源、嵌入式 Python 服务以及收据表的 `SELECT, INSERT`。不会分配 `%All` 角色。管理设置通过明确授权的本地容器控制台执行，而不是通过 API。

诊所工作进程在进入接收循环之前，会使用专用的 `MultiOrgClinic` 账户登录，从而放弃设置身份。其角色仅限于自己的数据库、嵌入式 Python 服务以及收据表的 `SELECT, INSERT`。

| 接收方 | 端点 | 实际存储 |
| --- | --- | --- |
| `DEMOQUALITY` | JDBC TCP `127.0.0.1:1972/DEMOQUALITY` | `MultiOrg_Receiver.Receipt`，包含 `patient_id`、`birthYear`、`status`、`RawPayload`、`PayloadHash` 和投递主键 |
| `DEMORESEARCH` | 经过身份验证的 `http://gateway:80/csp/multiresearch/receipts` | 命名空间本地收据表 |
| `DEMOCLINIC` | UTF-8 HL7 v2 MLLP `127.0.0.1:25751` | 命名空间本地收据表，之后返回相关联的 `MSA|AA` 或拒绝的 `MSA|AE` |

数据库目录为 `/dur/multiorg-receiver/<NAMESPACE>/`。接收方数据全局变量不会跨命名空间映射。各命名空间中的标记为 `^MultiOrgReceiverInstall("owner")="multi-organization-receivers-v1"`。

网关要求：将 `/csp/multiresearch` 和 `/csp/multiresearch/`（包括无扩展名 REST 路径）路由到 IRIS 实例。由于此实例在端口 52773 上没有专用 HTTP 监听器，因此使用固定主机 `gateway:80`。本包不会更改 compose 或网关配置。

诊所使用小型嵌入式 Python MLLP 监听器，而不是原生 HL7 Production，以便收据摘要绑定实际收到的 UTF-8 线上负载（包括 CR 段终止符）。持久存储完成后才返回 ACK。每个 TCP 连接只接受一条有界消息；缺失/无效分帧、否定 ACK 或无法关联的 ACK 都不会成为肯定投递证据。ACK 仅确认本地收件，不表示已用于临床。

容器重启后，明确归本项目所有的启动钩子必须切换到 `DEMOCLINIC`、验证标记，然后调用 `##class(MultiOrg.Receiver.API).StartIfNeeded()`。该方法也会验证所有权，并在启动 IRIS 后台作业前探测监听器身份。无需启动接收方 Production，因为这里没有接收方 Production。

## Client contract

从嵌入式 Python（包括 `DEMODISTRIBUTION`）调用：

```python
import sys
sys.path.insert(0, "/contest/multiorg/receiver")
import transport
receipt = transport.send("sql", delivery_id, payload)
stored = transport.read("sql", delivery_id)
health = transport.readiness()
```

公开的 `send`/`read` 分别接受机构 ID `quality`、`research`、`clinic`，以及协议 ID `sql`、`rest`、`hl7`。`readiness()` 的 `name` 字段保留协议 ID。投递 ID 必须为 1–64 个 ASCII 字母数字或连字符。负载最多为 16,000 个 UTF-8 字节。收据包含 `delivery_id`、`payload_hash`（精确 UTF-8 内容的 SHA-256）、`payload`/`stored_payload`、`readback_match`、`namespace` 和 `protocol`。SQL 发送使用实际捆绑的 JDBC 连接以及预编译插入和查询。REST 发送使用真实的身份验证 HTTP POST，并通过独立 GET 回读。诊所发送使用实际 MLLP 和 ACK 关联，以及只读管理回读；即使发生错误，也会恢复调用方命名空间。管理回读调用方需要有权读取诊所数据库/表。IRIS `Process.NameSpace()` 是读取器（其参数为进程 ID）；客户端改为在 `try/finally` 中使用 `Process.SetNamespace()`。

SQL JSON 必须且只能包含 `patient_id`（字符串，≤64）、`birthYear`（整数，1800–2100）和 `status`（字符串，≤64）。REST POST 信封格式为 `{"delivery_id":"...","payload":"<exact raw JSON object text>"}`。GET 使用 `/receipts/<delivery_id>`。HL7 必须具有 `MSH|^~\&`、匹配的 MSH-10、一个包含 MRN、姓名和 YYYYMMDD DOB 的 PID，以及末尾 CR。

SQL 收据中的 `columns` 包含独立回读的实际持久化 SQL 列 `patient_id`、`birthYear`、`status`；`column_inventory` 列出 `MultiOrg_Receiver.Receipt` 中这些确切 SQL 标识符。其他持久化列为 `DeliveryId`（主键）、`RawPayload`、`PayloadHash`。`PatientId` 仅是 ObjectScript 属性名；其 SQL 字段名为 `patient_id`。

相同 ID/相同正文会返回现有收据。不同正文会被拒绝，绝不覆盖。客户端不会自动重试发送。ACK 或 HTTP/JDBC 响应丢失时结果不确定；必须先按 ID 对账，再显式重试。原始合成数据留在本地；不要将这些原始收据交给模型。

`--verify` 会为每条分支追加一条合成收据，检查独立回读、重复计数、不同正文拒绝和命名空间保留。不会删除现有数据。框架契约测试为 `Contest.MultiReceiverTests`，从 `ReceiverTests.cls` 加载到 `TRIAGE`；其 `TestControl` 绝不会重启现有 Production。

## Class/source loading

`--apply` 会将 `Provision.cls` 作为 `MultiOrg.Receiver.Provision` 加载到 `%SYS` 并调用 `Apply()`。它会将 `Receipt.cls` 和 `API.cls` 加载到每个接收方；`REST.cls` 仅加载到 `DEMORESEARCH`。`--verify` 会将 `Acceptance.cls` 加载到 `DEMOCLINIC`。除 `ReceiverTests.cls`（其在 `TRIAGE` 中定义 `Contest.MultiReceiverTests`）之外，这些文件都定义 `MultiOrg.Receiver.<FileName>` 类。

框架套件可使用固定的 `iris_compile` 编译，并通过 `iris_test(pattern="Contest.MultiReceiverTests", namespace="TRIAGE", test_type="testproduction")` 运行。该执行身份必须具有 `%Service_EmbeddedPython:U`。如果开发 MCP 身份缺少该权限，不要扩大该现有账户权限；应改为通过获授权的本地 IRIS 控制台运行同一组已编译测试：

```objectscript
set manager=##class(%UnitTest.Manager).%New()
do manager.RunTest(":Contest.MultiReceiverTests","/nodelete/noload")
```

协议验收还会测试 UTF-8 非 ASCII JSON、拒绝 SQL UPDATE/DELETE、拒绝匿名 REST，以及线上格式错误的 HL7 消息不会收到肯定 ACK 且不会产生持久化行。
