# Contracts: QingJianCore ↔ Platform UI

本目录用于描述“共享核心（QingJianCore）”与“平台 UI（macOS/iOS）”之间的契约：用例接口、事件流、错误语义与数据边界。

说明：
- 这是原生应用，不提供 Web API；因此这里的 contracts 不是 OpenAPI。
- 契约的目标是：跨端一致、可测试、可替换（UI 可变，核心语义不变）。

文件列表：
- `use-cases.md`: 核心用例接口（Repo 管理/浏览/打开笔记/渲染/搜索/导出/冲突处理）
- `events.md`: 事件与状态通知（文件变更/同步状态/冲突/进度）
- `errors.md`: 统一错误语义与用户可见信息分类（跨端一致）


