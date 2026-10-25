# HIPAA 演示知识库

[English](README.md) | [简体中文](README.zh-CN.md)

发布包包含完整的已准备文本语料，约 **23 MB UTF-8 文本**，而不是先前的 2 MB 精选子集。
原始 PDF、HTML 快照、提取中间文件和其他二进制来源仍位于 Git 忽略的
`hipaa-documents/` 目录下。验证器不需要这些文件。

## 准备工作和限制

编码助手选择了准备规则，并撰写了五篇
[LLM 导读简报](./briefs/)和一份合成组织政策。官方来源文本通过确定性方式提取，
并在同一文档类型内合并完全相同的文本重复项。**语料并非全部由 LLM 重写或压缩。**
摘要不是官方法律依据。

发布包包含已成功归档的 HHS 指引、常见问题、案例、历史说明、其他归档文件、
Parts 160/162/164、原始法案和年度 CFR PDF 文本，以及两份选定的 NIST 技术指南。
纳入历史材料是为了上下文查询，不是为了扩充语料，也不代表现行法律。
它们不得悄然进入默认规范性检索。

本项目不声称收集或审阅了所有 HIPAA 出版物。清单记录了五十个归档 URL 失败、
无法提取文本的页面、导航回退说明以及来源/版本限制。不包含 OCR。
来源日期并不能证明生效日期；适用性和司法状态仍需审查。PDF 表格已线性化。
未进行法律审查或 Agent 准确性基准测试。

## 文件

- [documents.jsonl](./documents.jsonl)：包含来源信息的自包含文本。
- [manifest.json](./manifest.json)：确切计数、文本/文件字节数、语料 SHA-256、
  检索范围计数、失败来源和提取说明。
- [catalogue.json](./catalogue.json)：标题、ID、来源位置和范围。
- [briefs/](./briefs/)：LLM 撰写的导读和合成组织政策。
- [evaluation-cases.json](./evaluation-cases.json)：合成评估规格，不是检索内容或已完成的
  评估结果。十个业务案例和两个控制案例现包含模型可见的事实包、单独由作者撰写的预期结果、
  精确带日期的来源锚点和人工审查量规。参见[离线验证与限制](../contest/MONITORING.md#business-context-hipaa-risk-benchmark)。
- [supplemental-sources.json](./supplemental-sources.json)：固定的官方 NIST 来源 URL、
  校验和及纳入理由。

每条记录均保留来源 URL、来源校验和、文档类型、来源版本、章节/页码定位符、
内容校验和、法律状态标签和 `retrieval_scope`。来源校验和可用于比较；
验证已分发语料的校验和不需要原始来源文件。

## 受范围控制的检索输入

| Scope | 用途 | 默认导出 |
|---|---|---|
| `normative` | 法规快照及选定的 HHS 指引/常见问题 | 是 |
| `technical` | 明确选定的 HHS/NIST 实施指南 | 是 |
| `orientation` | 非权威 LLM 简报 | 是 |
| `organization_policy` | 合成演示政策 | 是 |
| `historical` | 历史最终规则说明 | **否** |
| `unreviewed` | 案例、提案、未逐项分类的其他归档文件 | **否** |

`normative` 是检索角色，并不表示每个段落当前都属于有约束力的法律。
对案例/提案/历史材料的分类有意采取保守做法：未经审阅的材料必须明确进行上下文检索，
未经进一步来源审查不得用于支持当前法律结论。不要将整个文件的索引说成仅包含现行法律的索引。

从仓库根目录使用 Python 3.9+：

```sh
python3 contest/knowledge.py verify
python3 contest/knowledge.py select --profile demo
python3 contest/knowledge.py release-check

# New file only; refuses to overwrite existing exports.
python3 contest/knowledge.py export \
  --output contest/data/knowledge/default.jsonl

# Explicit background-only export, kept separate.
python3 contest/knowledge.py export --scope historical \
  --output contest/data/knowledge/historical.jsonl
```

按范围导出仅会筛选输入记录，不是 AI Hub 搜索端点。独立的
[本地 Knowledge API](../contest/KNOWLEDGE.md)会强制默认范围，并保留元数据和引用。
每次审查都应只检索相关文本块，而不是将 23 MB 内容全部发送到提示词中。

## 发布包和本地配置

`demo` 现在表示**发布的完整已准备文本语料**，不是小型精选集。`full` 仍是可选的本地重建副本，
供开发对比。若从相同来源重建，两者包含相同文本。发布包独立于原始归档。
选择配置会在被忽略的本地状态中固定语料摘要和特定配置的索引键。
来源缺失或摘要更改会报错，不会静默回退。

选择和导出**不会**构建向量索引、调用嵌入模型，也不会让当前分诊 Agent 使用这些知识。
独立的本地 AI Hub RAG 实现已对 715 条默认范围记录建立索引，共 1,785 个文本块
（384 维），并完成离线验证和经过身份验证的检索。选择 CLI 中的
`index_status=not_imported` 描述的是准备状态，不是独立运行时 API 的就绪状态。
隐私工厂单独固定 Agent 知识，并运行了标志分类机制测试；业务上下文规格现已通过单独的
只读 AI Hub 运行时运行，复用固定的模型/索引，且未更改源 Agent。第一批未通过验收：
12 份输出约定中 9 份有效，12 个案例中 3 个符合所有作者 oracle 机器检查
（这不是法律准确性）。专家适用性审查仍待完成。选择语料或运行离线基准不会改变任何
Production 行为。

重建需要原始的带日期本地归档和 macOS PDFKit：

```sh
python3 contest/knowledge.py fetch-supplemental
swift hipaa-demo-knowledge/extract_pdfs.swift
python3 contest/knowledge.py build --profile demo
python3 contest/knowledge.py build --profile full
python3 -m unittest discover -s contest -p test_knowledge.py -v
```

验证和导出已发布的软件包无需 Swift、网络访问或原始 PDF 下载。
这些命令不会产生推理或嵌入费用。承诺一键式 AI Hub 设置前，必须单独测量导入延迟、
索引大小、嵌入依赖项和审查质量。

## 来源归属和使用

官方证据归属于 HHS、eCFR 和 NIST。它们并非本项目撰写，也不会整体依 Apache-2.0
重新许可。原始声明和适用的第三方权利仍然有效。项目的 LLM 简报不是 HHS 出版物、
法律意见或合规认证。
演示中请使用合成消息；切勿将原始患者消息混入此规范性/背景文档语料。
