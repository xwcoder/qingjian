# Errors Contract（跨端一致）

本文件定义错误语义分类与用户可见信息要求，确保 macOS+iOS “错误语义一致”（宪法要求）。

原则：
- 错误分为“可恢复/不可恢复/需要用户决策”
- UI 文案可不同，但必须表达同一含义与下一步操作

---

## Error Types

### PermissionDenied

**Meaning**: 用户未授权访问 Repo/文件，或系统限制访问

**User action**:
- 重新授权（或重新选择 Repo 目录）
- 查看帮助说明

### RepoUnavailable

**Meaning**: Repo 目录不存在、被移动/重命名、或临时不可访问

**User action**:
- 重新关联 Repo
- 从最近列表移除

### NotFound

**Meaning**: 指定的 Note/Asset 不存在

**User action**:
- 返回目录
- 刷新 Repo

### CorruptedFile

**Meaning**: 文件无法解析为有效文本/编码异常等

**User action**:
- 只读打开（尽力展示原文）
- 复制导出交由外部工具修复

### RenderFailed

**Meaning**: 渲染失败（语法/资源/主题等导致）

**User action**:
- 回退到纯文本查看
- 展示错误并允许报告（可选）

### SyncError

**Meaning**: iCloud 同步出现错误（账号/网络/权限）

**User action**:
- 重试
- 关闭 iCloud 同步
- 查看错误详情

### ConflictDetected (NeedsDecision)

**Meaning**: 同一路径文件在多端并发修改或出现系统报告的冲突，需要用户决策

**User action**:
- 选择保留本地/远端
- 合并后保存

### LockedAfterTrial

**Meaning**: 试用期结束且未购买，应用进入锁定状态

**User action**:
- 购买解锁
- 继续导出/迁移 Repo（必须可用）


