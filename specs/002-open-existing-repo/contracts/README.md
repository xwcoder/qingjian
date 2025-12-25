# Contracts: 打开已有仓库（添加已有仓库）

本目录用于描述“共享核心（QingJianCore）”与“平台 UI（macOS/iOS）”之间围绕本功能的契约：新增/调整的用例接口、错误语义与事件。

说明：
- 这是原生应用，不提供 Web API；因此这里的 contracts 不是 OpenAPI。
- 契约目标：跨端一致、可测试、零回归（不得影响“新建仓库”既有能力）。

文件列表：
- `use-cases.md`: Repo 新建/打开/校验/列表持久化相关用例
- `errors.md`: 与“打开已有仓库”相关的错误语义补充（基于 CoreError 分类）
- `events.md`: 与 Repo 列表/可用性相关的事件补充


