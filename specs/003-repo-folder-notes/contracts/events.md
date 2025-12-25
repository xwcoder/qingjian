# Events Contract: 仓库内目录与笔记管理

本文件定义与目录/笔记管理相关的事件语义，主要映射到 `QingJianCore/Contracts/CoreEvent.swift`。

## Repo Content

- **RepoChanged** → `CoreEvent.repoChanged(repoId, affectedPaths)`
  - 场景：目录/笔记创建、重命名、移动、删除后；或外部同步/文件系统变更导致内容变化
  - 期望：平台层按 `affectedPaths` 做最小刷新（必要时触发 `Load Repo Tree` 或 `refreshPath`）

- **RepoContentChanged** → `CoreEvent.repoContentChanged(repoId, changedPaths)`
  - 场景：由 `RepoWatchService` 监听到的外部变更

## Note

- **NoteOpened** → `CoreEvent.noteOpened(repoId, path)`
- **NoteSaved** → `CoreEvent.noteSaved(repoId, path)`
- **NoteExternallyModified** → `CoreEvent.noteExternallyModified(repoId, path)`

说明：本期不新增 `folderCreated/folderDeleted` 等细粒度事件，避免事件面扩大导致跨端行为分叉；平台层可基于 repoChanged 的受影响路径做一致处理。


