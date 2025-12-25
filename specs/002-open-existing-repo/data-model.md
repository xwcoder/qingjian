# Data Model: 打开已有仓库（添加已有仓库）

**Branch**: `002-open-existing-repo`  
**Date**: 2025-12-25  
**Spec**: [spec.md](./spec.md)  
**Research**: [research.md](./research.md)

本数据模型聚焦“仓库打开/新建/列表持久化/访问授权”的新增与约束，避免绑定具体实现细节，但要求规则可测试、跨端语义一致。

---

## Core Entities

### Repository

**Represents**: 用户在 App 中管理的一组笔记集合；物理上是一个文件夹。

**Key fields**（与现有 `QingJianCore/Domain/Repository.swift` 对齐）:
- `id`: 由 `rootURL` 标准化路径生成的稳定标识（用于列表与引用）
- `displayName`: 用户可见名称
- `rootURL`: 仓库根目录
- `lastOpenedAt`: 最近打开时间（用于排序）
- `iCloudEnabled`: 是否启用 iCloud（本功能不改变该语义）

**Invariants**:
- `rootURL` 必须是“存在且可读写”的目录；否则仓库状态为 Unavailable
- 同一仓库不得在列表中重复出现（以 `id` 或标准化路径去重）

---

### RepoMetadata (仓库元信息)

**Represents**: 存放在 Repo 根目录的元信息文件，用于自定义排序/最近笔记等。

**Physical location**: `rootURL/.qingjian_metadata.json`

**Key fields**（与现有 `RepoMetadataStore` 对齐）:
- `version`
- `folderOrders`
- `recentNotes`
- `lastScannedAt`

**Invariants**:
- “打开已有仓库”必须要求该文件存在且可解析（否则视为 InvalidRepo）
- “新建仓库”必须确保该文件存在（不存在则写入默认值）

---

### RepoRegistryEntry (已添加仓库列表项)

**Represents**: App 的“仓库列表”中持久化的一条记录。

**Key fields**:
- `repoId`
- `displayName`
- `rootURLBookmark`（可选但推荐）：用于跨重启恢复对 `rootURL` 的访问授权
- `rootPathHint`（可选）：用于展示/调试（不能作为唯一访问依据）
- `lastOpenedAt`
- `iCloudEnabled`

**Rules**:
- 从 `rootURLBookmark` 恢复失败时：该 Repo 在列表中应展示为不可用，并提供恢复路径（移除或重新定位）
- `repoId` 与恢复后的 `rootURL` 必须一致，否则视为数据损坏并触发恢复流程

---

### RepoAccessGrant (访问授权)

**Represents**: 沙盒下对用户选取目录的持续访问授权。

**Key fields**:
- `bookmarkData`
- `createdAt`
- `lastResolvedAt?`
- `lastResolveError?`

**Rules**:
- 每次实际访问 repo 文件内容前，需要开启 security-scoped access（平台实现不同，但语义一致）
- 授权失效时必须可恢复：提示用户重新选择同一仓库目录以更新授权

---

## State & Lifecycle

### Repo Availability State

（与现有 `RepoAvailabilityState` 对齐）
- `available`
- `unavailable(reason?)`
- `recovering`

**Transitions**:
- `available → unavailable`: 目录被删除/移动/权限变化/授权失效
- `unavailable → recovering`: 用户触发“重新定位/重新授权”
- `recovering → available`: 授权与路径恢复成功并通过校验


