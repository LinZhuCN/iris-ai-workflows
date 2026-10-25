# 本地 IRIS 许可证密钥

[English](README.md) | [简体中文](README.zh-CN.md)

将本地获取的 InterSystems 许可证密钥以 `iris.key` 名称放在此处：

```text
iris/license/iris.key
```

此目录中的许可证密钥已从 Git 中排除。不要提交或分享该密钥。

竞赛 Compose 配置会将此文件以只读方式挂载到
`/usr/irissys/mgr/iris.key`。也可以将 `IRIS_LICENSE_PATH` 设置为一个绝对本地文件路径。
若文件缺失，启动会失败，而不是在原位置创建目录。EAP 镜像和许可证必须由每位开发者从
InterSystems 获取。旧的 Community 部署已移除。
