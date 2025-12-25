# Tasks: 仓库内目录与笔记管理

**Input**: Design documents from `/specs/003-repo-folder-notes/`  
**Prerequisites**: `plan.md` (required), `spec.md` (required), `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: 遵循宪法要求：对共享核心（业务规则/文件 I/O/元数据语义）的变更必须包含至少单元或集成测试任务；对 UI 行为变更必须有可回归验证任务。

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 为目录/笔记管理补齐共享核心的“文件系统写入 + 元数据迁移 + 事件/缓存失效”基础设施骨架

- [x] T001 明确实现落点与新增文件清单（共享核心优先）：在 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/` 增加 Folder 用例文件，在 `Storage/` 增加元数据迁移辅助（如需）
- [x] T002 [P] 为目录/笔记管理补齐错误语义（如新增）：更新 `QingJianApp/QingJianCore/Sources/QingJianCore/Contracts/CoreError.swift`
- [x] T003 [P] 为目录/笔记管理补齐事件语义（如需新增更细事件则谨慎）：更新 `QingJianApp/QingJianCore/Sources/QingJianCore/Contracts/CoreEvent.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 任何用户故事实现前都必须具备的共享核心能力（文件系统操作封装、重名/非法移动校验、元数据迁移、缓存失效与性能测量）

**⚠️ CRITICAL**: 本阶段完成前，不应开始平台 UI 集成工作

- [x] T004 实现通用路径校验与冲突检测（重名/非法移动/越界）：新增 `QingJianApp/QingJianCore/Sources/QingJianCore/Storage/RepoPathValidator.swift`
- [x] T005 实现元数据路径迁移与清理（folderOrders + recentNotes）：新增 `QingJianApp/QingJianCore/Sources/QingJianCore/Storage/RepoMetadataMigration.swift`
- [x] T006 在 `RepoMetadataStore` 增加"清理不存在路径/批量迁移路径"的 API：更新 `QingJianApp/QingJianCore/Sources/QingJianCore/Storage/RepoMetadataStore.swift`（被 T005 调用）
- [x] T007 [P] 为 T004/T005 增加核心单元测试：新增 `QingJianApp/QingJianCore/Tests/QingJianCoreTests/RepoPathValidatorTests.swift` 与 `.../RepoMetadataMigrationTests.swift`
- [x] T008 为目录操作新增性能测量点（必要时新增 metric）：更新 `QingJianApp/QingJianCore/Sources/QingJianCore/Telemetry/PerfMetrics.swift`
- [x] T009 统一"写入后刷新"策略：在合适的用例层调用 `BrowseUseCases.invalidateTreeCache` 并（按需要）发出 `CoreEvent.repoChanged`：更新 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/BrowseUseCases.swift`

**Checkpoint**: Foundation ready（可以开始按用户故事实现，并可在共享核心层独立测试）

---

## Phase 3: User Story 1 - 在选中仓库中创建与使用笔记（Priority: P1）🎯 MVP

**Goal**: 在选中仓库范围内创建笔记并可打开（最小闭环），且打开/保存具备冲突保护与可观测指标

**Independent Test**: 使用 `QingJianApp/Tests/Fixtures/SampleRepo/` 或临时目录：创建笔记 → 打开读取 → 保存 → 再次打开；并验证 `PerfMetrics` 至少覆盖 `note.open`/`note.save`

### Tests for User Story 1 (Required by constitution: Core behavior) ⚠️

- [x] T010 [P] [US1] 新建笔记的核心集成测试：新增 `QingJianApp/QingJianCore/Tests/QingJianCoreTests/NoteCreateOpenSaveTests.swift`
- [x] T011 [P] [US1] 冲突保护测试（expectedHash 不匹配时报错）：更新 `QingJianApp/QingJianCore/Tests/QingJianCoreTests/NoteCreateOpenSaveTests.swift`

### Implementation for User Story 1

- [x] T012 [US1] 在 `EditUseCases` 暴露"创建笔记"用例（封装 `NoteStore.create`）：更新 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/EditUseCases.swift`
- [x] T013 [US1] 创建笔记后更新最近列表（recentNotes）并触发 repoChanged：更新 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/EditUseCases.swift`
- [x] T014 [US1] 打开笔记路径加入事件（noteOpened）与缓存策略校验：更新 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/BrowseUseCases.swift`
- [x] T015 [P] [US1] 平台层最小 UI 接线（macOS）：在 `QingJianApp/QingJianMac/` 中接入"新建笔记 → 打开"入口（具体文件按现有 UI 结构落点）
- [x] T016 [P] [US1] 平台层最小 UI 接线（iOS）：在 `QingJianApp/QingJianIOS/` 中接入"新建笔记 → 打开"入口（具体文件按现有 UI 结构落点）
- [x] T017 [US1] 为"未保存更改切换"提供核心层可用的状态/回调契约（或在平台层实现保护流程）：更新 `QingJianApp/QingJianCore/Sources/QingJianCore/Domain/NoteDocument.swift`（如需）与平台层对应文件

**Checkpoint**: US1 可独立演示：选中仓库 → 新建笔记 → 打开/保存 → 返回仍可打开；核心测试通过

---

## Phase 4: User Story 2 - 管理仓库内目录结构（Priority: P2）

**Goal**: 在选中仓库内完成目录创建/重命名/移动/删除（含非空删除确认语义），并确保元数据迁移与扫描/缓存刷新正确

**Independent Test**: 临时目录创建多级目录与笔记，执行目录操作后重新扫描，验证树结构、排序元数据迁移、recentNotes 迁移/清理

### Tests for User Story 2 (Required by constitution: Core behavior) ⚠️

- [x] T018 [P] [US2] 目录 CRUD + 扫描回归测试：新增 `QingJianApp/QingJianCore/Tests/QingJianCoreTests/FolderManagementTests.swift`
- [x] T019 [P] [US2] 非法移动（移动到自身/子目录）测试：更新 `.../FolderManagementTests.swift`
- [x] T020 [P] [US2] 元数据迁移（folderOrders/recentNotes）在目录移动/重命名后保持一致：更新 `.../FolderManagementTests.swift`

### Implementation for User Story 2

- [x] T021 [US2] 新增 Folder 用例入口（Create/Rename/Move/Delete）：新增 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/FolderUseCases.swift`
- [x] T022 [US2] Create Folder：调用 `FileManager.createDirectory` 并处理权限/重名：实现于 `.../UseCases/FolderUseCases.swift`
- [x] T023 [US2] Rename/Move Folder：调用 `FileManager.moveItem`，并调用 T005 元数据迁移：实现于 `.../UseCases/FolderUseCases.swift`
- [x] T024 [US2] Delete Folder（recursive）：调用 `FileManager.removeItem`，并清理元数据相关路径：实现于 `.../UseCases/FolderUseCases.swift`
- [x] T025 [US2] 操作完成后触发刷新（invalidateTreeCache + repoChanged affectedPaths）：更新 `.../UseCases/FolderUseCases.swift`
- [x] T026 [P] [US2] 平台层 UI 接线（macOS）：提供目录创建/重命名/移动/删除入口与"非空删除确认"对话框（文件按现有 UI 结构落点）
- [x] T027 [P] [US2] 平台层 UI 接线（iOS）：提供目录创建/重命名/移动/删除入口与"非空删除确认"流程（文件按现有 UI 结构落点）

**Checkpoint**: US2 可独立演示：目录 CRUD + 非法移动拦截 + 非空删除确认；核心测试通过

---

## Phase 5: User Story 3 - 整理与维护笔记（重命名/移动/删除）（Priority: P3）

**Goal**: 对笔记执行重命名/移动/删除，保持内容不变，且列表/扫描/元数据与事件语义一致

**Independent Test**: 临时目录创建 A/B 目录与 N.md；执行重命名/移动/删除后重新扫描，验证树结构与 recentNotes 清理；并验证错误语义一致

### Tests for User Story 3 (Required by constitution: Core behavior) ⚠️

- [x] T028 [P] [US3] 笔记 rename/move/delete 核心测试：新增 `QingJianApp/QingJianCore/Tests/QingJianCoreTests/NoteManagementTests.swift`
- [x] T029 [P] [US3] 重名冲突与权限/不存在路径错误语义测试：更新 `.../NoteManagementTests.swift`

### Implementation for User Story 3

- [x] T030 [US3] 统一 rename/move 的实现路径（移动 = rename 到新路径），并在成功后迁移 recentNotes：更新 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/EditUseCases.swift`
- [x] T031 [US3] 删除笔记后清理 recentNotes，并触发 repoChanged：更新 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/EditUseCases.swift`
- [x] T032 [P] [US3] 平台层 UI 接线（macOS）：笔记重命名/移动/删除入口 + 未保存更改保护流程回归（文件按现有 UI 结构落点）
- [x] T033 [P] [US3] 平台层 UI 接线（iOS）：笔记重命名/移动/删除入口 + 未保存更改保护流程回归（文件按现有 UI 结构落点）

**Checkpoint**: US3 可独立演示：笔记重命名/移动/删除 + 重名冲突提示；核心测试通过

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 跨故事一致性、性能门禁与回归清单

- [x] T034 统一两端术语与交互语义（目录/笔记/删除确认/错误提示）：更新 `QingJianApp/QingJianIOS/` 与 `QingJianApp/QingJianMac/` 对应 UI 文案与交互
- [x] T035 [P] 性能预算回归：对 `repo.scan` / `note.open` / `note.save` / `editor.key_latency` 做 Debug 观测并记录阈值与测量方式（补充到 `specs/003-repo-folder-notes/plan.md` 如需）
- [x] T036 [P] 按 `specs/003-repo-folder-notes/quickstart.md` 完成双端手工验收并记录结果

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)** → **Phase 2 (Foundational)** → **Phase 3/4/5（US1/US2/US3）** → **Phase 6（Polish）**

### User Story Dependencies

- **US1 (P1)**：依赖 Phase 2（基础校验/元数据/刷新策略），不依赖 US2/US3
- **US2 (P2)**：依赖 Phase 2；与 US1 可并行开发（完成后通过“重新扫描”验证）
- **US3 (P3)**：依赖 Phase 2；与 US1/US2 可并行开发，但平台 UI 层可能共享组件（注意冲突）

### Parallel Opportunities

- 带 `[P]` 的测试与平台 UI 任务可并行
- US2 的核心实现与 US1 的平台接线可并行（前提：Phase 2 完成）

---

## Parallel Example: US2（核心 + 平台并行）

```bash
# Core（共享核心）
Task: "T021 新增 FolderUseCases.swift 并落地 Create/Rename/Move/Delete"
Task: "T018 FolderManagementTests.swift 覆盖 CRUD/非法移动/元数据迁移"

# Platform（两端 UI）
Task: "T026 macOS 目录管理入口与删除确认"
Task: "T027 iOS 目录管理入口与删除确认"
```


