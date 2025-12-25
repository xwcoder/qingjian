# Errors Contract: 仓库内目录与笔记管理

本文件定义该功能相关的错误语义，主要映射到 `QingJianCore/Contracts/CoreError.swift`，以保证跨端一致的错误处理与提示。

## Repo

- **RepoUnavailable** → `CoreError.repoUnavailable`
  - 场景：仓库根目录不可达/被移除/权限变化
  - 期望：平台层提供“返回仓库选择/重新授权/重试”的恢复路径

## Permission / IO

- **PermissionDenied** → `CoreError.permissionDenied`
- **PathNotFound** → `CoreError.pathNotFound`
- **IOError** → `CoreError.ioError`

## Note

- **NoteNotFound** → `CoreError.noteNotFound`
- **NoteReadFailed** → `CoreError.noteReadFailed`
- **NoteSaveFailed** → `CoreError.noteSaveFailed`
- **NoteConflict** → `CoreError.noteConflict`


