# Local IRIS license key

[English](README.md) | [简体中文](README.zh-CN.md)

Place your locally obtained InterSystems license key here as `iris.key`:

```text
iris/license/iris.key
```

License keys in this directory are excluded from Git. Do not commit or share the key.

The contest Compose setup mounts this file read-only at
`/usr/irissys/mgr/iris.key`. Alternatively, set `IRIS_LICENSE_PATH` to an absolute
local file path. A missing file causes startup to fail rather than creating a
directory in its place. EAP images and licenses must be obtained by each
developer from InterSystems. The old Community deployment has been removed.
