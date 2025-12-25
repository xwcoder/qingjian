# Events Contract

本文件定义核心对外发布的事件与状态变化，供 UI 层订阅，以实现：
- 文件系统变化的增量刷新
- 同步/冲突状态的跨端一致提示
- 性能友好的批处理更新

---

## Event Stream (概念)

核心提供一个事件流（或等价机制），事件必须具备：
- `timestamp`
- `repoId`
- `kind`
- `payload`

事件必须可在 macOS 与 iOS 以相同语义消费；UI 表现可以不同，但含义一致。

---

## Events

### EV-Repo-Changed

**When**: Repo 结构变化（新增/删除/重命名/移动文件或目录；或元数据排序变化）

**Payload**:
- `pathsChanged`: `[String]`（相对路径）
- `changeType`: `filesystem` | `metadata`

**UI expectation**:
- 目录树增量刷新；若当前打开笔记受影响则触发“外部变更提示”

### EV-Note-ExternallyModified

**When**: 当前打开的 Note 被外部修改

**Payload**:
- `notePath`
- `newVersionRef`

**UI expectation**:
- 弹出提示：重新加载/对比/保留当前（macOS 编辑场景必须避免静默覆盖）

### EV-Sync-StatusChanged

**When**: iCloud 同步状态变化（开始/进行中/完成/失败）

**Payload**:
- `status`: `off` | `syncing` | `idle` | `error`
- `message?`

### EV-Sync-ConflictDetected

**When**: 检测到冲突

**Payload**:
- `conflictId`
- `notePath`

**UI expectation**:
- 进入可操作的冲突处理入口（iOS 只读也需要可见与可引导）

### EV-Performance-Milestone (debug only)

**When**: 关键路径埋点（用于性能门禁）

**Payload**:
- `metricName`
- `durationMs`
- `context`（例如 repoSize/noteSize）


