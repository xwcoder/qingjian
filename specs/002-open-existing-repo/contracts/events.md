# Events Contract: 打开已有仓库（添加已有仓库）

本文件补充与“仓库列表变更/可用性变化”相关的事件语义，供 UI 层订阅并刷新。

---

## Events（复用 CoreEvent，强调语义与使用场景）

### EV-Repo-Added

**When**: 新建仓库/打开仓库成功加入列表

**Payload**:
- `repoId`

**UI expectation**:
- 列表新增一项并可被选中/打开

### EV-Repo-Removed

**When**: 仓库从列表移除

**Payload**:
- `repoId`

**UI expectation**:
- 列表移除对应项；若当前选中项被移除，需要选择合理的下一个项或回到空态

### EV-Repo-AvailabilityChanged

**When**: 仓库路径/授权状态发生变化（例如重启后 bookmark 恢复失败、仓库被移动/删除）

**Payload**:
- `repoId`
- `state`（available/unavailable/recovering）

**UI expectation**:
- 列表以一致语义展示“不可用”并提供恢复入口（重新定位/移除）


