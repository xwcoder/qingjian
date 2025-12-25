# Use Cases Contract: 仓库内目录与笔记管理

本文件定义共享核心对外提供的用例接口（不包含 UI 实现），供 macOS/iOS 平台层调用。命名与语义必须跨端一致。

---

## Browse

### UC-Browse-01: Load Repo Tree

- **Input**: `repoId`, `rootURL`, `forceRefresh?`
- **Output**: `RepoTreeSnapshot`
- **Errors**: `RepoUnavailable`, `PermissionDenied`
- **Notes**: 树由文件系统扫描得到；排序可叠加 `RepoMetadata.folderOrders`

### UC-Browse-02: Open Note

- **Input**: `repoId`, `rootURL`, `notePath`
- **Output**: `NoteDocument`
- **Errors**: `NoteNotFound`, `PermissionDenied`, `NoteReadFailed`
- **Notes**: 打开后应更新 `recentNotes`

---

## Note Management

### UC-Note-01: Create Note

- **Input**: `rootURL`, `path`, `initialContent?`
- **Output**: `NoteDocument`
- **Errors**: `IOError`, `PermissionDenied`
- **Notes**: 默认创建空内容；若目标已存在必须失败（由 UI 决定是否自动改名）

### UC-Note-02: Save Note

- **Input**: `rootURL`, `document`, `expectedHash?`
- **Output**: `Void`
- **Errors**: `NoteConflict`, `PermissionDenied`, `NoteSaveFailed`
- **Notes**: 必须支持冲突保护（expectedHash）

### UC-Note-03: Rename Note

- **Input**: `rootURL`, `oldPath`, `newPath`
- **Output**: `Void`
- **Errors**: `NoteNotFound`, `IOError`, `PermissionDenied`

### UC-Note-04: Move Note

- **Input**: `rootURL`, `oldPath`, `newPath`
- **Output**: `Void`
- **Errors**: `NoteNotFound`, `IOError`, `PermissionDenied`
- **Notes**: 语义等同“重命名到不同目录”

### UC-Note-05: Delete Note

- **Input**: `rootURL`, `path`
- **Output**: `Void`
- **Errors**: `NoteNotFound`, `IOError`, `PermissionDenied`

---

## Folder Management

### UC-Folder-01: Create Folder

- **Input**: `rootURL`, `path`
- **Output**: `Void`
- **Errors**: `IOError`, `PermissionDenied`
- **Notes**: 支持多级目录创建

### UC-Folder-02: Rename Folder

- **Input**: `rootURL`, `oldPath`, `newPath`
- **Output**: `Void`
- **Errors**: `PathNotFound`, `IOError`, `PermissionDenied`
- **Notes**: 必须阻止移动到其自身/子目录（平台层与核心层都应校验）

### UC-Folder-03: Move Folder

- **Input**: `rootURL`, `oldPath`, `newParentPath`
- **Output**: `Void`
- **Errors**: `PathNotFound`, `IOError`, `PermissionDenied`
- **Notes**: 移动后需迁移 `RepoMetadata.folderOrders` 与 `recentNotes`（见 research 决策）

### UC-Folder-04: Delete Folder

- **Input**: `rootURL`, `path`, `recursive=true`
- **Output**: `Void`
- **Errors**: `PathNotFound`, `IOError`, `PermissionDenied`
- **Notes**: 非空目录必须由 UI 先确认；核心层执行递归删除


