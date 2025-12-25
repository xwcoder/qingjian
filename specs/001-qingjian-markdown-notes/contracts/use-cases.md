# Use Cases Contract

本文件定义共享核心对外提供的“用例接口”（不包含 UI 实现），供 macOS/iOS 平台层调用。接口命名与语义必须跨端一致。

---

## Repo Management

### UC-Repo-01: Add Repo

- **Input**: `rootURL`, `displayName?`
- **Output**: `RepoSummary`
- **Errors**: `PermissionDenied`, `InvalidRepo`, `AlreadyAdded`
- **Notes**: 添加后应可被“最近 Repo”访问；若 rootURL 不可访问必须失败并给出可恢复提示

### UC-Repo-02: Remove Repo

- **Input**: `repoId`
- **Output**: `Void`
- **Errors**: `RepoNotFound`
- **Notes**: 仅移除“引用”，不删除磁盘文件（符合可移植）

### UC-Repo-03: List Repos

- **Input**: `Void`
- **Output**: `[RepoSummary]`（含最近打开时间）

---

## Browse & Open

### UC-Browse-01: Load Repo Tree

- **Input**: `repoId`
- **Output**: `RepoTreeSnapshot`
- **Errors**: `RepoUnavailable`, `PermissionDenied`
- **Notes**: 支持增量更新与分页（大 Repo），但对 UI 表现保持一致语义

### UC-Browse-02: Open Note

- **Input**: `repoId`, `notePath`
- **Output**: `NoteDocument`（原文 + 元信息）
- **Errors**: `NotFound`, `PermissionDenied`, `CorruptedFile`

---

## Render (View / Preview)

### UC-Render-01: Render Markdown

- **Input**: `NoteDocument`, `RenderTheme`（暗色/字体等）
- **Output**: `RenderedDocument`
- **Errors**: `RenderFailed`
- **Notes**: 必须可缓存；主题变化会导致缓存失效或重渲染

---

## Edit (macOS only)

### UC-Edit-01: Save Note

- **Input**: `repoId`, `notePath`, `newMarkdownText`, `expectedBaseVersion?`
- **Output**: `SaveResult`（成功/需要冲突处理）
- **Errors**: `PermissionDenied`, `RepoUnavailable`
- **Notes**: 若检测到外部修改导致版本不匹配，应返回“需要冲突处理”，禁止静默覆盖

### UC-Edit-02: Import Local Image

- **Input**: `repoId`, `sourceImageURL`, `targetDirPolicy`（例如 assets/ 分桶规则）
- **Output**: `ImportedAsset`（repoRelativePath + 推荐 markdown 引用）
- **Errors**: `PermissionDenied`, `UnsupportedFormat`, `IOFailed`

---

## Sync (iCloud)

### UC-Sync-01: Enable iCloud for Repo

- **Input**: `repoId`, `enabled`
- **Output**: `SyncStatus`
- **Errors**: `NotSupported`, `AccountNotAvailable`, `PermissionDenied`

### UC-Sync-02: Get Sync Status

- **Input**: `repoId`
- **Output**: `SyncStatus`（含是否冲突、是否正在同步）

### UC-Sync-03: Resolve Conflict

- **Input**: `repoId`, `conflictId`, `resolution`（keepLocal/keepRemote/merged + mergedText?）
- **Output**: `Void`
- **Errors**: `ConflictNotFound`, `ResolutionInvalid`, `IOFailed`

---

## Export / Share

### UC-Export-01: Export Repo

- **Input**: `repoId`, `mode`（folderReference / archive / shareSheet）
- **Output**: `ExportArtifact`
- **Errors**: `PermissionDenied`, `IOFailed`
- **Notes**: 用于试用到期锁定时的“必须允许导出/迁移”通道


