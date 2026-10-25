# Local embeddings and the Knowledge API

[English](./KNOWLEDGE.md) | [简体中文](./KNOWLEDGE.zh-CN.md)

此可选平台切片使用 AI Hub EAP RAG SDK 和本地 CPU 推理，不使用托管嵌入 API。消息分诊 Agent 未更改，尚未使用此语料。独立的[隐私 Agent 工厂](./AGENT-FACTORY.zh-CN.md)现已在真实合成测试中使用固定版本的知识检索。

## Verified scope

- 固定版本的 `Qdrant/all-MiniLM-L6-v2-onnx`，版本
  `d13954661f83248295ba75c1ed411eef3b7b936e`，Apache-2.0 模型。
- 384 维向量；ONNX 权重约 90 MB。
- 默认范围包含 715 条记录、1,785 个向量块，原始 UTF-8 记录文本约 2.52 MB。这**并非全部 23 MB** 已发布文本。
- 范围：682 条规范性资料、27 条技术资料、五份非权威导读简报和一项合成组织政策。排除历史/未审核记录。
- 真实 top-five 检索包含来源 URL、来源定位符和范围。给定的具体 Safe Harbor 问题会返回 45 CFR 164.514 的证据。此冒烟测试不是全面的检索质量基准。

仅在获授权的 ARM64 AI Hub EAP `2026.3.0AI.154.0` 上测试。SDK API 处于实验阶段。镜像需要获授权访问和有效本地许可证；本仓库不分发其中任何一项。MiniLM 主要面向英文检索；不要假设中文问题也有同等质量。

## Prepare a verified model cache

在仓库根目录执行：

```sh
python3 contest/embedding.py
# 官方主机无法访问时，显式指定备用下载端点：
python3 contest/embedding.py --endpoint https://hf-mirror.com
```

仅下载公开模型资源。端点不会用于推理，也不会接收项目/患者数据。会验证文件大小、ONNX SHA-256 和固定仓库 Blob 哈希；检查失败即报错，不会回退到远程推理。现有缓存文件也会验证。

为竞赛容器准备持久缓存：

```sh
docker exec iris-triage-real-iris-1 mkdir -p /dur/models/fastembed
docker cp contest/data/models/fastembed/. iris-triage-real-iris-1:/dur/models/fastembed/
```

新容器会从竞赛 Compose 文件获得 `FASTEMBED_CACHE_DIR=/dur/models/fastembed`。对于未设置该环境变量的已运行容器，已验证的本地开发实例会在 TRIAGE 工作目录中使用 `.fastembed_cache` 符号链接，指向该持久缓存。不要仅为更改嵌入环境设置而重启业务 Production。请为自己的部署明确调整容器名称。

权重只下载一次。使用带 `--network none` 的**全新临时 IRIS 容器**验证真正的离线运行，而不只是测试缓存命中的 HTTP 请求：

```sh
python3 contest/offline_embedding.py --license /absolute/path/to/iris.key
```

此辅助工具会验证已发布语料/缓存，创建自身隔离的 TRIAGE 命名空间，导入全部 715 条默认记录并运行框架嵌入/存储测试。两个套件中必须有八个测试方法通过（包括空操作的 Production 控制方法），不得有失败。证明保存在被忽略的 `contest/data/embedding-offline-proof.json`；随后会移除辅助容器。不使用业务 Production 或提供方密钥。

## Enable the local Knowledge API

先按竞赛常规方式完成设置，以准备专用 TRIAGE 命名空间、数据库资源和 AI Hub SDK。然后执行：

```sh
python3 contest/platform_prepare.py --container iris-triage-real-iris-1
```

该命令验证发布语料，准备固定的 715 条记录导出，编译四个 Knowledge 类，并配置 REST 应用和两个本地账户。不会停止、启动或重新配置 Production。仅在密码不存在时生成密码，不会重置现有账户密码。

必须加载更新后的 Gateway 配置。升级已经运行的本地演示时，只重启其 Gateway，而不是 IRIS 或其他项目：

```sh
docker restart iris-triage-real-gateway-1
```

启动[前端](../web/README.md)，打开 <http://127.0.0.1:5173/knowledge>。Vite 开发代理目标为 `http://host.docker.internal:52779`；使用主机 Node 时设置 `PLATFORM_API_TARGET=http://127.0.0.1:52779`。该代理中不嵌入服务器凭据。

| 账户 | 权限 | 本地密码文件 |
|---|---|---|
| `ContestViewer` | 状态、作业状态和检索 | `contest/data/platform/ContestViewer.password` |
| `ContestKnowledgeAdmin` | 读取者权限以及固定语料的影子重建 | `contest/data/platform/ContestKnowledgeAdmin.password` |

打开相应的本地忽略密码文件，并粘贴到登录表单。凭据仅保存在 React 内存中，不会写入本地/会话存储或 URL。退出登录、刷新或离开 Knowledge 页面都会清除凭据。空部署会显示**尚未就绪**，直至构建者首次完成经过验证的构建；如有现有本地基线，则会识别该基线。

### Security boundary

这是一个**仅供 localhost 使用的演示**，不是生产身份架构。每个请求都需要原生 IRIS 密码身份验证；禁用 Cookie 和 CORS。POST 需要 JSON 和显式应用标头；服务器强制执行读取者/构建者权限和输入上限。若要在共享/网络环境部署，必须使用 TLS、适当的身份提供方/会话生命周期、请求限流和专用平台数据库。

专用角色具有 TRIAGE 数据库的审计和平台状态读写权限、IRIS 库读取权限，并且没有 `%All`、开发、终端或通用 SQL API 角色。构建者还在此隔离命名空间中拥有 SQL `%CREATE_TABLE` 权限。这只是应用/API 权限分离，**不是按表或多租户的数据库隔离**；绝不要在真实业务命名空间中复用这些角色。开发者 MCP 账户权限没有扩展。

## API contract and index lifecycle

所有路径均位于 `/api/monitor/v1` 下：

| 方法 | 路径 | 用途 |
|---|---|---|
| GET | `/knowledge` | 真实就绪状态、计数、活动版本和调用者权限 |
| POST | `/knowledge/search` | 仅允许 `{"query":"..."}`；最多 1,000 字符 |
| POST | `/knowledge/builds` | 空 JSON 对象；仅构建者可用；返回 `202` 和持久化作业 ID |
| GET | `/knowledge/builds/:id` | 持久化阶段、记录进度、完成状态或明确失败 |

POST 标头包含 `Content-Type: application/json` 和 `X-Requested-With: IRIS-Workflows`。请求正文上限为 4,096 字节。无效输入会被拒绝；不存在夹具回退。搜索返回证据，不会生成法律答案。不要在查询框输入患者信息。

每次异步构建都会：

1. 根据本地已配置状态验证准备好的导出文件 SHA-256。
2. 创建全新的、通过允许列表控制的 `Contest.HIPAAIndex<number>` 表。
3. 保留来源元数据，并在 SDK 分块前将长段落预先切成最多 2,000 字符、重叠 200 字符的窗口。
4. 验证 715 条记录、1,785 个块和非空的真实检索结果。
5. 在一个事务中授予读取者 SELECT 权限并切换活动指针/作业状态。现有请求可以继续使用旧版本完成。

旧索引在整个过程中仍可检索；构建失败不会切换活动索引。调度器拒绝并发活动构建，工作进程锁则避免写入者重叠。五分钟没有心跳的作业会报告为 `interrupted`；不会被悄然标记成功或自动重放。此轻量 JOB 实现不是通用分布式作业运行器。旧/失败版本表会保留供诊断，尚未实现保留策略/垃圾回收。重复构建前应预留磁盘空间。

持久状态使用 `^ContestPlatform`、`^ContestKnowledgeJobs` 和 `^ContestPlatformAudit`。审计条目会记录操作者、操作、版本和失败详情；会有意省略查询文本。不会向浏览器调用者公开内部错误详情。请由获授权的本地 IRIS 管理员检查，而不是通过允许任意全局变量访问的端点查看。

此前的 `Contest.LocalKnowledge.ImportFile` 是只用于隔离测试的破坏性单表原型。UI **不会**调用它。只读存储适配器会验证现有表配置，而不是调用 SDK 的 DDL 路径，因此检索不需要 `%CREATE_TABLE`。

## Verification

```sh
# 通过实际 UI 代理执行只读 HTTP 检查：
python3 contest/platform_test.py
# 显式构建并激活新的本地版本：
python3 contest/platform_test.py --build
# 显式故障隔离检查：只临时更改已准备的公开导出文件，
# 并在 finally 中恢复；请勿与其他构建者同时运行。
python3 contest/platform_test.py --failure
python3 -m unittest discover -s contest -p 'test_*.py'
```

HTTP 检查涵盖身份验证、读取者/构建者权限隔离、严格输入、来源信息、特定法规检索、并发构建拒绝，以及重建期间对旧索引的检索。故障注入证明无效来源不会影响当前活动版本。浏览器检查另外涵盖登录、错误密码提示、五条真实引用、读取者限制、退出登录和移动端溢出。构建者浏览器验收还会验证显式确认复选框、运行进度、完成作业、自动刷新活动版本、激活后的真实检索和退出登录。之后会删除临时浏览器验证账户。框架测试位于 [KnowledgeTests.cls](./dev/KnowledgeTests.cls)、[EmbeddingTests.cls](./dev/EmbeddingTests.cls) 和 [EmbeddingStoreTests.cls](./dev/EmbeddingStoreTests.cls)。

仍未实现：通用上传/导入 Agent、任意模型选择、对观察结果进行自动 Agent 审核、实时事件以及动态 Production 规则激活。实例发现和合成观察传输已在独立的 [P2 Connector 切片](./MONITORING.md)中提供。
