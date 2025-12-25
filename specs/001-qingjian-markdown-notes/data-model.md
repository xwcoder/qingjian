# Data Model: 青简（qingjian）Markdown 笔记应用（macOS/iOS）

**Branch**: `001-qingjian-markdown-notes`  
**Date**: 2025-12-25  
**Spec**: [spec.md](./spec.md)  
**Research**: [research.md](./research.md)

本数据模型描述“文件即真相”的 Repo 结构、应用元数据、跨端一致性约束，以及同步/冲突的状态机。避免绑定具体存储实现（例如数据库类型），但要让实体与规则可测试。

---

## Core Entities

### Repository (Repo)

**Represents**: 一组笔记与目录的集合；物理上对应用户选择的一个文件夹。

**Key fields**:
- `id`: 应用内部标识（用于持久化“已添加的 Repo 列表”）
- `displayName`: 用户可编辑的显示名称
- `rootURL`: Repo 根目录路径（文件系统位置）
- `isICloudEnabled`: 是否启用 iCloud 同步（按 Repo 维度）
- `lastOpenedAt`: 最近打开时间（用于最近列表）

**Invariants**:
- `rootURL` 必须指向用户可访问的目录；访问失效时 Repo 进入 `Unavailable` 状态并提示恢复

### FolderNode

**Represents**: Repo 中的一个目录节点（无限层级）。

**Key fields**:
- `path`: 相对于 Repo 根目录的路径（例如 `tech/ios/`）
- `childrenOrder`: 该目录下子节点的有序列表（路径列表或条目列表）

**Rules**:
- `childrenOrder` 是“UI 顺序”的来源；文件系统的默认排序只作为兜底
- 当目录下出现新文件/新目录且不在 `childrenOrder` 中：追加到末尾，并标记为 `unsortedNewItems`

### Note

**Represents**: 一个 Markdown 文本文件。

**Key fields**:
- `path`: 相对于 Repo 根目录的路径（例如 `tech/ios/swiftui.md`）
- `title`: 标题（默认从内容推断；可选保存用户覆盖值）
- `lastModifiedAt`: 文件系统最后修改时间
- `sizeBytes`: 用于大文件降级策略
- `renderCacheKey`: 与渲染缓存关联的键（由内容 hash/mtime 等生成）

**Rules**:
- 编辑（macOS）写回同一文本文件；外部修改检测到后必须提示“重新加载/对比”，避免静默覆盖

### Asset (Image)

**Represents**: 图片等资源（本地文件或在线链接）。

**Key fields**:
- `kind`: `localFile` | `remoteURL`
- `reference`: Markdown 引用（相对路径或 URL）
- `storedPath`（仅本地）：在 Repo 内的存储相对路径（例如 `assets/2025/12/img.png`）

**Rules**:
- 本地插图必须保证在 Repo 内可移植：引用优先使用 Repo 相对路径

### RepoMetadata

**Represents**: 为支持“拖拽排序/多 Repo 状态/打开历史”等而保存的元数据（与 Markdown 内容解耦）。

**Key fields**（建议最小集）:
- `version`: 元数据版本号（便于未来迁移）
- `folderOrders`: `path -> childrenOrder`
- `pinnedNotes`（可选）：置顶笔记列表
- `recentNotes`: 最近打开笔记列表（按 path）
- `uiState`（可选）：分栏宽度、最后选中项等（平台可分离但语义一致）

**Rules**:
- 元数据必须保存在 Repo 内（随文件同步/迁移），且不破坏用户对 Repo 的“可读性/可控性”

---

## State Machines

### Repo Availability State

States:
- `Available`: 路径可访问、可扫描
- `Unavailable`: 路径不存在或权限被撤销
- `Recovering`: 用户正在重新关联/选择新路径

Transitions:
- `Available -> Unavailable`: 检测到目录缺失/权限失败
- `Unavailable -> Recovering`: 用户点击“重新关联 Repo”
- `Recovering -> Available`: 重新选择目录并校验通过

### Sync State (iCloud)

States（按 Repo 维度）:
- `Off`: 未启用 iCloud
- `On`: 启用 iCloud，正常同步
- `ConflictDetected`: 检测到冲突，需要用户处理

Transitions:
- `Off -> On`: 用户开启 iCloud 同步
- `On -> ConflictDetected`: 检测到同一路径的并发修改或系统报告冲突
- `ConflictDetected -> On`: 用户完成“保留版本/合并后保存”

**Conflict entity**:
- `SyncConflict`:
  - `path`: 冲突文件相对路径
  - `localVersionRef`: 本地版本引用（时间戳/内容快照）
  - `remoteVersionRef`: 远端版本引用
  - `detectedAt`
  - `resolution`: `keepLocal` | `keepRemote` | `merged`

**Rules**:
- 默认不允许静默覆盖（符合 research 决策）
- iOS 只读也必须可见冲突状态；合并操作可引导在 macOS 完成

---

## Cross-Platform Consistency Rules (Constitution)

- 术语与结构：Repo/Folder/Note/Asset/Conflict 在 macOS+iOS 命名与语义一致
- 同步语义：iCloud 开/关、冲突提示、导出/迁移路径一致（UI 表现可不同）
- 只读差异：iOS 不编辑，但必须保证“查看结果/渲染结果/错误语义”与 macOS 一致


