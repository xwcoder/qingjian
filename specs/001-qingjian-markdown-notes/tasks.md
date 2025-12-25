---

description: "Tasks for implementing 青简（qingjian）Markdown 笔记应用（macOS/iOS）"
---

# Tasks: 青简（qingjian）Markdown 笔记应用（macOS/iOS）

**Input**: Design documents from `/specs/001-qingjian-markdown-notes/`  
**Prerequisites**: `plan.md` (required), `spec.md` (required), `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests（按宪法门禁）**：
- 对**共享核心/数据/同步语义**的变更：**MUST** 至少包含 XCTest 单元或集成测试任务
- 对**UI 行为**的变更：**MUST** 提供可回归验证任务（UI 测试/快照/或明确的手工检查清单）

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 初始化工程与目录结构（Swift 6+ 原生 macOS+iOS，多 target，共享核心）

- [ ] T001 创建 Xcode 工程与两个 App target（macOS+iOS）在 `QingJianApp/QingJianApp.xcodeproj`
- [ ] T002 创建共享核心模块骨架（Swift Package 或 Xcode framework）在 `QingJianApp/QingJianCore/`
- [ ] T003 [P] 初始化目录结构与占位文件（Core/UI/Mac/iOS/Tests）在 `QingJianApp/`（按 `specs/001-qingjian-markdown-notes/plan.md`）
- [ ] T004 [P] 添加基础 CI/格式化占位说明（后续实现阶段细化）在 `.github/workflows/ci.yml`
- [ ] T005 [P] 新增开发说明入口并链接 quickstart 在 `README.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 共享核心的基础设施（Repo/文件 I/O/元数据/事件/错误/性能埋点），完成后才能开始任何用户故事

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 定义跨端一致的错误枚举与映射（对齐 contracts）在 `QingJianApp/QingJianCore/Sources/QingJianCore/Contracts/CoreError.swift`
- [ ] T007 定义事件流协议与事件类型（对齐 contracts/events.md）在 `QingJianApp/QingJianCore/Sources/QingJianCore/Contracts/CoreEvent.swift`
- [ ] T008 [P] 定义核心实体（Repo/FolderNode/Note/Asset/SyncConflict）在 `QingJianApp/QingJianCore/Sources/QingJianCore/Domain/`
- [ ] T009 实现 Repo 路径可用性状态机（Available/Unavailable/Recovering）在 `QingJianApp/QingJianCore/Sources/QingJianCore/Domain/RepoAvailability.swift`
- [ ] T010 实现 Repo 元数据读写（folderOrders/recentNotes/version）在 `QingJianApp/QingJianCore/Sources/QingJianCore/Storage/RepoMetadataStore.swift`
- [ ] T011 实现文件系统扫描（构建 RepoTreeSnapshot，支持增量/分页接口预留）在 `QingJianApp/QingJianCore/Sources/QingJianCore/Storage/RepoScanner.swift`
- [ ] T012 实现打开笔记与基础文本读取（含编码/损坏降级）在 `QingJianApp/QingJianCore/Sources/QingJianCore/Storage/NoteStore.swift`
- [ ] T013 实现外部变更监听与去抖批处理（发出 EV-Repo-Changed/EV-Note-ExternallyModified）在 `QingJianApp/QingJianCore/Sources/QingJianCore/Storage/RepoWatchService.swift`
- [ ] T014 实现性能埋点基础设施（关键路径计时、debug 输出）在 `QingJianApp/QingJianCore/Sources/QingJianCore/Telemetry/PerfMetrics.swift`
- [ ] T015 [P] 添加共享核心 XCTest 单测：RepoMetadata roundtrip + 排序合并规则在 `QingJianApp/Tests/QingJianCoreTests/RepoMetadataStoreTests.swift`
- [ ] T016 [P] 添加共享核心 XCTest 单测：RepoScanner 生成目录树快照在 `QingJianApp/Tests/QingJianCoreTests/RepoScannerTests.swift`
- [ ] T017 [P] 添加共享核心 XCTest 单测：NoteStore 读取/损坏文件降级在 `QingJianApp/Tests/QingJianCoreTests/NoteStoreTests.swift`
- [ ] T018 创建 UI 回归手工检查清单（暗色/键盘/VoiceOver/错误语义一致）在 `specs/001-qingjian-markdown-notes/checklists/ui-regression.md`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - 打开仓库并优雅查看笔记（View 模式）(Priority: P1) 🎯 MVP

**Goal**: 用户可添加/打开一个 Repo，浏览目录树，打开笔记进入 View 渲染；图片（本地/在线）可展示并有错误降级

**Independent Test**: 用一个本地文件夹作为 Repo（含多级目录、Markdown、图片），完成“添加 Repo→浏览→打开笔记→View 渲染→图片展示/错误提示”

### Tests for User Story 1

- [ ] T019 [P] [US1] 添加集成测试样例 Repo 夹具（目录/笔记/图片）在 `QingJianApp/Tests/Fixtures/SampleRepo/`（用于可重复回归）
- [ ] T020 [P] [US1] XCTest 集成测试：Add Repo + Load Repo Tree + Open Note 在 `QingJianApp/Tests/QingJianCoreTests/UseCaseBrowseTests.swift`

### Implementation for User Story 1

- [ ] T021 [US1] 实现用例：Add/Remove/List Repos（对齐 UC-Repo-*）在 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/RepoUseCases.swift`
- [ ] T022 [US1] 实现用例：Load Repo Tree / Open Note（对齐 UC-Browse-*）在 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/BrowseUseCases.swift`
- [ ] T023 [US1] 确定并接入 Markdown 渲染实现（满足标题/列表/代码块/引用/链接/图片；支持主题）在 `QingJianApp/QingJianCore/Sources/QingJianCore/Rendering/MarkdownRenderer.swift`
- [ ] T024 [US1] 实现渲染缓存与失效策略（按内容版本/主题）在 `QingJianApp/QingJianCore/Sources/QingJianCore/Rendering/RenderCache.swift`
- [ ] T025 [P] [US1] macOS UI：Repo 列表 + 目录树 + View 渲染页面骨架在 `QingJianApp/QingJianMac/UI/RepoBrowserView.swift`
- [ ] T026 [P] [US1] iOS UI：Repo 列表 + 目录树 + View 渲染页面骨架在 `QingJianApp/QingJianIOS/UI/RepoBrowserView.swift`
- [ ] T027 [US1] 跨端统一主题（暗色/字体）接入渲染器在 `QingJianApp/QingJianCore/Sources/QingJianCore/Rendering/RenderTheme.swift`
- [ ] T028 [US1] 图片加载与错误降级（本地路径/在线 URL 不可用提示）在 `QingJianApp/QingJianCore/Sources/QingJianCore/Rendering/ImageResolver.swift`
- [ ] T029 [US1] UI 回归项补齐：US1 手工验证步骤写入 `specs/001-qingjian-markdown-notes/checklists/ui-regression.md`
- [ ] T030 [US1] 性能门禁埋点落地：打开 Repo、打开 Note、渲染耗时写入 debug 指标在 `QingJianApp/QingJianCore/Sources/QingJianCore/Telemetry/PerfMetrics.swift`

**Checkpoint**: User Story 1 可独立演示与回归（MVP）

---

## Phase 4: User Story 2 - macOS 高效编辑：Vim 模式 + 边写边预览 + 快速插图 (Priority: P2)

**Goal**: macOS 支持编辑 Markdown（保存回文件），提供 Vim 模式与边写边预览；支持导入本地图片到 Repo 并插入引用

**Independent Test**: 在 macOS 对同一笔记完成“编辑→预览更新→保存→重新打开验证”；插入本地图片后 Repo 内出现资产且引用可渲染

### Tests for User Story 2

- [ ] T031 [P] [US2] XCTest 集成测试：Save Note（含 expectedBaseVersion 冲突分支）在 `QingJianApp/Tests/QingJianCoreTests/UseCaseEditSaveTests.swift`
- [ ] T032 [P] [US2] XCTest 集成测试：Import Local Image 生成 repo 相对路径与引用在 `QingJianApp/Tests/QingJianCoreTests/UseCaseImportImageTests.swift`

### Implementation for User Story 2

- [ ] T033 [US2] 实现用例：Save Note（对齐 UC-Edit-01，禁止静默覆盖）在 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/EditUseCases.swift`
- [ ] T034 [US2] 实现用例：Import Local Image（导入到 assets/ 并返回推荐引用）在 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/AssetUseCases.swift`
- [ ] T035 [US2] 设计并实现 macOS 编辑器视图（Markdown 输入 + 分栏预览容器）在 `QingJianApp/QingJianMac/UI/EditorSplitView.swift`
- [ ] T036 [US2] 实现预览更新策略（debounce、滚动定位基本可用）在 `QingJianApp/QingJianMac/UI/PreviewCoordinator.swift`
- [ ] T037 [US2] 实现 Vim 模式核心键位与状态机（覆盖移动/选择/删除/撤销重做/查找；与输入法共存）在 `QingJianApp/QingJianMac/Vim/VimEngine.swift`
- [ ] T038 [US2] 将 Vim 引擎接入编辑器文本组件并支持开关在 `QingJianApp/QingJianMac/Vim/VimBindings.swift`
- [ ] T039 [US2] 插图 UX：拖拽/选择图片 → 调用 Import Local Image → 插入 Markdown 引用在 `QingJianApp/QingJianMac/UI/ImageInsertCoordinator.swift`
- [ ] T040 [US2] UI 回归项补齐：US2 手工验证步骤写入 `specs/001-qingjian-markdown-notes/checklists/ui-regression.md`
- [ ] T041 [US2] 性能门禁：编辑输入延迟与预览更新耗时埋点在 `QingJianApp/QingJianCore/Sources/QingJianCore/Telemetry/PerfMetrics.swift`

**Checkpoint**: macOS 编辑（含 Vim 与预览、插图）可独立回归

---

## Phase 5: User Story 3 - 多仓库工作流 + iCloud 同步 + 可控排序 (Priority: P3)

**Goal**: 支持多 Repo 同时打开；目录/文件拖拽排序持久化；iCloud 同步开关与状态；冲突提示与“保留/合并”处理；试用到期锁定但允许导出

**Independent Test**: 创建两个 Repo，拖拽排序并重启保持；开启 iCloud 后能看到状态/冲突入口；试用到期进入锁定但导出可用

### Tests for User Story 3

- [ ] T042 [P] [US3] XCTest：排序元数据与文件系统新增/删除合并规则在 `QingJianApp/Tests/QingJianCoreTests/OrderingMergeRulesTests.swift`
- [ ] T043 [P] [US3] XCTest：同步状态机与冲突实体状态转换在 `QingJianApp/Tests/QingJianCoreTests/SyncStateMachineTests.swift`
- [ ] T044 [P] [US3] XCTest：Export Repo 产物（folder/archive/shareSheet 之一至少可测）在 `QingJianApp/Tests/QingJianCoreTests/ExportUseCaseTests.swift`

### Implementation for User Story 3

- [ ] T045 [US3] 实现拖拽排序用例与持久化（更新 RepoMetadata.folderOrders）在 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/OrderingUseCases.swift`
- [ ] T046 [US3] macOS UI：目录树拖拽排序交互接入 OrderingUseCases 在 `QingJianApp/QingJianMac/UI/RepoTreeDragDrop.swift`
- [ ] T047 [US3] iOS UI：目录树排序展示一致（iOS 可不支持拖拽编辑，但要按元数据顺序展示）在 `QingJianApp/QingJianIOS/UI/RepoTreeView.swift`
- [ ] T048 [US3] 实现 iCloud 同步开关/状态用例（对齐 UC-Sync-01/02）在 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/SyncUseCases.swift`
- [ ] T049 [US3] 实现冲突处理用例 Resolve Conflict（对齐 UC-Sync-03，支持 keep/merge）在 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/ConflictUseCases.swift`
- [ ] T050 [US3] macOS UI：冲突列表与处理界面（保留/合并后保存）在 `QingJianApp/QingJianMac/UI/ConflictResolutionView.swift`
- [ ] T051 [US3] iOS UI：冲突状态可见与引导（只读也可进入冲突入口/提示去 macOS 合并）在 `QingJianApp/QingJianIOS/UI/ConflictStatusView.swift`
- [ ] T052 [US3] 实现导出/迁移用例（对齐 UC-Export-01）在 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/ExportUseCases.swift`
- [ ] T053 [US3] 实现试用/购买 gating：锁定状态下仅保留导出（不要求完整商店 UI，但要可触发购买入口）在 `QingJianApp/Shared/Purchase/PurchaseGate.swift`
- [ ] T054 [US3] iOS 快捷操作：复制/分享/导出（系统共享）在 `QingJianApp/QingJianIOS/UI/QuickActions.swift`
- [ ] T055 [US3] UI 回归项补齐：US3 手工验证步骤写入 `specs/001-qingjian-markdown-notes/checklists/ui-regression.md`

**Checkpoint**: 多 Repo + 排序 + 同步语义 + 冲突可恢复 + 锁定但可导出 均可独立回归

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 跨故事的体验一致性、性能回归、可访问性与文档完善

- [ ] T056 [P] 补齐可访问性检查项与验证步骤（暗色/动态字体/VoiceOver/键盘路径）在 `specs/001-qingjian-markdown-notes/checklists/ui-regression.md`
- [ ] T057 性能回归脚本/说明：如何用样例 Repo 跑门禁与记录结果在 `specs/001-qingjian-markdown-notes/quickstart.md`
- [ ] T058 [P] 文档整理：在 `specs/001-qingjian-markdown-notes/` 中互相链接（plan/research/data-model/contracts/quickstart）
- [ ] T059 清理与重构：将跨端共享逻辑下沉到 `QingJianCore`，避免平台分支散落在 `QingJianApp/QingJianMac/` 与 `QingJianApp/QingJianIOS/`
- [ ] T060 最终通读宪法门禁并记录任何豁免/回退（若有）在 `specs/001-qingjian-markdown-notes/plan.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 无依赖
- **Foundational (Phase 2)**: 依赖 Setup 完成，**阻塞所有用户故事**
- **US1 (Phase 3)**: 依赖 Foundational 完成；建议先完成作为 MVP
- **US2 (Phase 4)**: 依赖 Foundational；可在 US1 完成后推进（编辑依赖渲染/文档模型）
- **US3 (Phase 5)**: 依赖 Foundational；可与 US2 并行推进，但冲突/导出/购买 gating 会影响整体发布策略
- **Polish (Phase 6)**: 依赖已选择的用户故事完成

### User Story Dependencies

- **US1**: 无其它故事依赖（MVP）
- **US2**: 建议在 US1 的渲染/文档模型稳定后进行
- **US3**: 与 US1/US2 共享 Repo/元数据/事件基础设施；可并行但需要对共享核心变更做协调

### Parallel Opportunities

- Setup/Foundational 中标记 [P] 的任务可并行
- Phase 2 完成后：US2 与 US3 可由不同人并行推进（共享核心改动需串行评审）

---

## Parallel Example: US1

```bash
Task: "实现 Repo 用例在 QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/RepoUseCases.swift"
Task: "实现 macOS UI 在 QingJianApp/QingJianMac/UI/RepoBrowserView.swift"
Task: "实现 iOS UI 在 QingJianApp/QingJianIOS/UI/RepoBrowserView.swift"
```


