# Research: 打开已有仓库（添加已有仓库）

**Branch**: `002-open-existing-repo`  
**Date**: 2025-12-25  
**Spec**: [spec.md](./spec.md)  
**Plan**: [plan.md](./plan.md)

本文件用于在实现前收敛关键技术决策与风险，确保：跨端一致性、性能预算、零回归与离线可移植（符合 Constitution）。

---

## 1) Decision: “已有仓库”的判定规则（元信息即凭证）

**Decision**: 以 Repo 根目录内存在并可解析的 `.qingjian_metadata.json` 作为“这是一个可打开的青简仓库”的唯一判定规则。

**Rationale**:
- 共享核心已存在 `RepoMetadataStore`，其元信息文件名固定为 `.qingjian_metadata.json`，与当前扫描/排序能力天然一致
- 以单一文件作为“仓库 marker”可测试、可迁移、跨端一致，且不依赖外部工具（如 git）

**Alternatives considered**:
- 以“目录中存在某些内容（如 assets/、docs/）”判断：脆弱且不可控
- 以“.git”判断：与产品定位不一致（Repo 并非 git 仓库）

---

## 2) Decision: “新建仓库”与“打开仓库”的语义与幂等

**Decision**:
- **新建仓库**：在用户选择的目录上“初始化青简仓库”——写入（或确认存在）`.qingjian_metadata.json`，并将其加入仓库列表。
- **打开仓库**：仅允许选择“已存在且元信息可解析”的仓库目录；不写入/修复元信息；加入仓库列表后可打开。
- **幂等**：对同一路径/同一仓库标识重复操作，不产生重复列表项；应定位并打开已有条目。

**Rationale**:
- 满足 spec 的入口区分，同时不破坏用户对“新建仓库”的期待（原能力保留）
- 允许“新建仓库”在误选到已初始化目录时仍能安全工作（可直接视为“已初始化，可加入列表”）

**Alternatives considered**:
- “打开仓库”也自动创建元信息：会把错误输入静默变成“新建”，破坏入口语义

---

## 3) Decision: 仓库列表持久化（跨重启仍可打开）

**Decision**: 将“已添加仓库列表”持久化到 App Support 目录的单一 JSON 文件中（跨端一致），包含：
- 仓库显示名称、最近打开时间、iCloud 开关等
- 访问凭据（见下一节的 bookmark）

**Rationale**:
- spec 的 FR-007/FR-008 隐含“后续仍可打开/失效可恢复”，需要跨会话持久化
- JSON 文件易于调试与迁移，且不绑定具体数据库技术

**Alternatives considered**:
- 仅内存：重启即丢失，不符合“仓库列表”的基本预期
- UserDefaults：可行但不利于结构化迁移与调试（仍可作为实现细节备选）

---

## 4) Decision: 沙盒持续访问（Security-Scoped Bookmark）

**Decision**: 对用户选择的仓库目录，保存可恢复的访问凭据（bookmark data），并在需要访问时显式开启/关闭访问：
- **iOS**：使用 security-scoped bookmark；每次访问时 `startAccessing.../stopAccessing...`
- **macOS（App Sandbox）**：同样保存 bookmark，并在访问时开启；避免依赖“仅当前会话有效”的临时授权

**Rationale**:
- macOS target 启用了 App Sandbox（entitlements 包含 user-selected read-write）；iOS 本身也受沙盒约束
- 仅保存路径无法保证重启后可访问；bookmark 是系统推荐方式

**Alternatives considered**:
- 关闭沙盒/扩大权限：不符合上架与安全边界
- 每次打开都重新让用户选择目录：体验差且不符合“仓库列表”

---

## 5) Decision: 错误语义映射（不新增跨端概念）

**Decision**: 复用 `CoreError` 的现有分类表达“打开已有仓库”的失败原因：
- 缺失元信息：视为 `invalidRepo(path: "... - 缺少仓库元信息")`
- 元信息损坏：视为 `invalidRepo(path: "... - 仓库信息损坏")`
- 权限/不存在/不是目录：复用现有 `invalidRepo` 或 `permissionDenied/pathNotFound`

**Rationale**:
- 保持跨端错误语义统一（宪法要求），且减少错误类型扩散

---

## 6) Performance Gates: 打开/新建的可测指标

**Decision**: 将以下指标作为 Debug 环境的门禁采样点（阈值见 plan.md）：
- `repo.create`：新建/初始化仓库（写入元信息 + 加入列表）
- `repo.open`：打开已有仓库（校验元信息 + 加入列表）
- `repo.list.load`：加载已添加仓库列表

**Rationale**:
- “打开仓库”属于关键路径，必须可度量以支撑零回归


