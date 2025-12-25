# Data Model: 仓库内目录与笔记管理

本文件从“共享核心（QingJianCore）”角度描述数据实体、字段、关系与关键约束，供 macOS/iOS 平台层与测试对齐。

## Repository（仓库）

来源：`QingJianCore/Domain/Repository.swift`

- **id**: `String`（由 `rootURL` 标准化路径的 SHA256 前缀生成；稳定、可复现）
- **displayName**: `String`
- **rootURL**: `URL`（文件系统根目录）
- **lastOpenedAt**: `Date?`
- **iCloudEnabled**: `Bool`

约束：
- `id` 必须与 `rootURL` 一一对应；同一路径不应产生多个 repoId

## RepoRegistry / RepoRegistryEntry（仓库注册表）

来源：`QingJianCore/Domain/RepoRegistryEntry.swift`

- **RepoRegistry**
  - **version**: `String`
  - **entries**: `[RepoRegistryEntry]`
- **RepoRegistryEntry**
  - **repoId**: `String`
  - **displayName**: `String`
  - **rootURLBookmark**: `Data?`（用于恢复访问授权）
  - **rootPathHint**: `String`（仅展示/调试，不作为访问依据）
  - **lastOpenedAt**: `Date?`
  - **iCloudEnabled**: `Bool`

## RepoMetadata（仓库元数据）

来源：`QingJianCore/Storage/RepoMetadataStore.swift`

- **version**: `String`
- **folderOrders**: `[String: [String]]`
  - key：目录相对路径（根目录用空字符串 `""`）
  - value：该目录下子项的相对路径列表（文件或目录）
- **recentNotes**: `[String]`（笔记相对路径，按最近打开排序）
- **lastScannedAt**: `Date?`

约束：
- 元数据为“可恢复的辅助信息”，不得作为源数据
- `folderOrders` 与 `recentNotes` 中不存在的路径应被清理（避免幽灵条目）

## TreeNode / FolderInfo / NoteInfo（目录树节点）

来源：`QingJianCore/Domain/TreeNode.swift`

- **TreeNode**
  - `folder(FolderInfo)` 或 `note(NoteInfo)`
  - **id**: `String`（`folder:<path>` / `note:<path>`）
  - **path**: `String`（相对路径）
  - **name**: `String`（展示名）
- **FolderInfo**
  - **path**: `String`（相对路径；根目录不作为 FolderInfo 表达）
  - **name**: `String`
  - **children**: `[TreeNode]`
  - **isExpanded**: `Bool`（UI 展开态快照，可由平台层覆盖）
- **NoteInfo**
  - **path**: `String`
  - **name**: `String`（文件名）
  - **displayTitle**: `String`（从内容提取标题或 fallback）
  - **modifiedAt**: `Date`
  - **sizeBytes**: `Int`

## NoteDocument（笔记文档）

来源：`QingJianCore/Domain/NoteDocument.swift`

- **note**: `NoteInfo`
- **content**: `String`（Markdown 原文）
- **contentHash**: `Int`（用于外部修改/冲突检测）
- **loadedAt**: `Date`
- **isDirty**: `Bool`（未保存修改标记，通常由平台层驱动）

约束：
- 打开笔记后，平台层在保存/切换等操作时应使用 `contentHash` 做冲突保护（避免静默覆盖）


