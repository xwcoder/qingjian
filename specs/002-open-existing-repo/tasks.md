# Tasks: 打开已有仓库（添加已有仓库）

**Input**: `/Users/creep/code/xwcoder/qingjian/specs/002-open-existing-repo/` 下的 spec/plan/research/data-model/contracts/quickstart  
**Tests**: 按宪法要求：对共享核心变更必须包含 XCTest；对 UI 变更必须提供可回归验证（手工清单或 UI 测试）。

---

## Phase 1: Setup（项目与回归基线）

**Purpose**: 为“新建/打开仓库”并存改造建立最小可执行基线与回归清单文件。

- [x] T001 创建 UI 回归清单（新建仓库入口必须保留）`specs/002-open-existing-repo/checklists/ui-regression.md`
- [x] T002 创建可访问性检查清单（菜单/弹窗/错误提示）`specs/002-open-existing-repo/checklists/accessibility.md`
- [x] T003 补充一个"已有元信息"的测试仓库夹具（含 `.qingjian_metadata.json`）`QingJianApp/Tests/Fixtures/SampleRepo/.qingjian_metadata.json`
- [x] T004 [P] 为 Repo 打开/新建/列表加载补齐性能埋点枚举项（repo.open/repo.create/repo.list.load）`QingJianApp/QingJianCore/Sources/QingJianCore/Telemetry/PerfMetrics.swift`

---

## Phase 2: Foundational（共享核心：持久化 + 授权 + 新建/打开用例拆分）

**Purpose**: 让 Repo 列表具备跨重启持久化，并为沙盒目录持续访问（bookmark）留出可测试的核心边界；完成后 US1/US2 才能落地且不回归。

- [x] T005 [P] 定义 RepoRegistryEntry 数据结构（含 repoId、displayName、lastOpenedAt、iCloudEnabled、bookmarkData?）`QingJianApp/QingJianCore/Sources/QingJianCore/Domain/RepoRegistryEntry.swift`
- [x] T006 [P] 定义 RepoAccessGrant（bookmarkData + 时间戳 + 最近恢复错误）`QingJianApp/QingJianCore/Sources/QingJianCore/Domain/RepoAccessGrant.swift`
- [x] T007 [P] 定义 RepoRegistryStore 协议（load/save/upsert/remove）`QingJianApp/QingJianCore/Sources/QingJianCore/Storage/RepoRegistryStore.swift`
- [x] T008 实现 JSONRepoRegistryStore（文件路径由平台注入，落到 App Support）`QingJianApp/QingJianCore/Sources/QingJianCore/Storage/JSONRepoRegistryStore.swift`
- [x] T009 [P] 增加"仓库元信息是否存在"的纯函数/工具方法（避免 RepoMetadataStore.load() 自动创建语义干扰校验）`QingJianApp/QingJianCore/Sources/QingJianCore/Storage/RepoMetadataStore.swift`
- [x] T010 在 RepoUseCases 引入 repoRegistryStore（初始化时加载已添加仓库列表到内存）`QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/RepoUseCases.swift`
- [x] T011 将 RepoUseCases.addRepo 拆分为 createRepo/openRepo/validateRepoMetadata（保持 addRepo 为兼容入口并默认走 createRepo）`QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/RepoUseCases.swift`
- [x] T012 在 createRepo 中：确保 `.qingjian_metadata.json` 存在（不存在则写入默认 RepoMetadata），并写入 registry（幂等不重复）`QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/RepoUseCases.swift`
- [x] T013 在 openRepo 中：必须先校验元信息文件存在且可解析（缺失/损坏→InvalidRepo），成功后写入 registry（幂等）`QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/RepoUseCases.swift`
- [x] T014 在 listRepos 中：从 registry + availabilityStates 生成 RepoSummary（含不可用状态），并确保顺序按 lastOpenedAt `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/RepoUseCases.swift`
- [x] T015 在 removeRepo 中：同步移除 registry 与内存状态，并发送 repoRemoved 事件 `QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/RepoUseCases.swift`
- [x] T016 在 open/create/list 关键路径打点（repo.open/repo.create/repo.list.load）`QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/RepoUseCases.swift`

### Tests（Foundation 必须有）

- [x] T017 [P] 添加 RepoMetadataStore 元信息存在性判定单测 `QingJianApp/QingJianCore/Tests/QingJianCoreTests/RepoMetadataStoreTests.swift`
- [x] T018 [P] 添加 JSONRepoRegistryStore 读写/迁移/幂等单测 `QingJianApp/QingJianCore/Tests/QingJianCoreTests/RepoRegistryStoreTests.swift`
- [x] T019 添加 RepoUseCases.openRepo 成功/缺失元信息/损坏元信息/重复添加的单测 `QingJianApp/QingJianCore/Tests/QingJianCoreTests/RepoUseCasesOpenRepoTests.swift`
- [x] T020 添加 RepoUseCases.createRepo 初始化元信息/幂等/无写权限失败的单测 `QingJianApp/QingJianCore/Tests/QingJianCoreTests/RepoUseCasesCreateRepoTests.swift`

**Checkpoint**: Repo 列表可跨重启恢复（至少在测试中可复现），并且 core 层已具备“新建 vs 打开”的语义分离。

---

## Phase 3: User Story 1 - 打开已有仓库并加入列表（Priority: P1）🎯 MVP

**Goal**: 仓库列表页 “+” 入口提供“新建仓库/打开仓库”两项；打开仓库仅接受含元信息的目录，成功后加入列表并可进入；同时 **新建仓库入口保持可用（零回归）**。

**Independent Test**: 参照 `specs/002-open-existing-repo/quickstart.md` 的手工验收步骤 1) 与 2)。

- [x] T021 [US1] macOS：将侧边栏工具栏 "+" 改为 Menu（新建仓库/打开仓库），保留原"新建仓库"路径可达 `QingJianApp/QingJianMac/ContentView.swift`
- [x] T022 [US1] macOS：将现有 AddRepoSheet 重命名/拆分为 CreateRepoSheet（沿用原表单：选目录+名称）`QingJianApp/QingJianMac/ContentView.swift`
- [x] T023 [US1] macOS：新增 OpenRepoSheet（选目录，可选显示名称；提交调用 openRepo）`QingJianApp/QingJianMac/ContentView.swift`
- [x] T024 [US1] macOS：把 ViewModel.addRepo 改为分别调用 createRepo/openRepo，并确保错误弹窗可见 `QingJianApp/QingJianMac/ContentView.swift`
- [x] T025 [US1] iOS：将仓库列表页右上角 "+" 改为 Menu（新建仓库/打开仓库）`QingJianApp/QingJianIOS/ContentView.swift`
- [x] T026 [US1] iOS：将现有 AddRepoView 作为 CreateRepoView（提交调用 createRepo）`QingJianApp/QingJianIOS/ContentView.swift`
- [x] T027 [US1] iOS：新增 OpenRepoView（fileImporter 选目录；提交调用 openRepo）`QingJianApp/QingJianIOS/ContentView.swift`
- [x] T028 [US1] iOS：ViewModel 增加 openRepo/createRepo 两个入口方法，并保持原 addRepo 行为不回归（可暂时代理到 createRepo）`QingJianApp/QingJianIOS/ContentView.swift`
- [x] T029 [P] [US1] 更新 QingJianMac 菜单命令中的"打开仓库..."接到同一 OpenRepoSheet（避免入口分叉）`QingJianApp/QingJianMac/QingJianMacApp.swift`

### UI 回归验证（必须）

- [x] T030 [US1] 补齐手工回归步骤：验证"新建仓库入口仍可用且流程不变"`specs/002-open-existing-repo/checklists/ui-regression.md`
- [x] T031 [US1] 补齐手工回归步骤：验证"打开仓库入口存在且文案清晰可区分"`specs/002-open-existing-repo/checklists/ui-regression.md`

**Checkpoint**: macOS+iOS 两端都能通过 “+ → 打开仓库” 将带 `.qingjian_metadata.json` 的目录加入列表，并且 “+ → 新建仓库” 仍可用。

---

## Phase 4: User Story 2 - 无效/不可用仓库的可理解反馈与恢复路径（Priority: P2）

**Goal**: 对“无元信息/损坏/不可访问/已存在/路径失效”提供一致错误语义；对于列表中不可用仓库，至少提供一种恢复路径（移除已具备，补充“重新定位/重新授权”更佳）。

**Independent Test**: 参照 `specs/002-open-existing-repo/spec.md` US2 的 Acceptance Scenarios 逐条验证。

- [x] T032 [US2] Core：openRepo 对缺失元信息/损坏元信息分别构造可读 reason（InvalidRepo message）`QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/RepoUseCases.swift`
- [x] T033 [US2] macOS：在 OpenRepoSheet 的错误提示中对 InvalidRepo/AlreadyAdded/PermissionDenied 做更明确的用户提示（不改变错误语义）`QingJianApp/QingJianMac/ContentView.swift`
- [x] T034 [US2] iOS：在 OpenRepoView 的错误提示中对 InvalidRepo/AlreadyAdded/PermissionDenied 做更明确的用户提示（不改变错误语义）`QingJianApp/QingJianIOS/ContentView.swift`
- [x] T035 [US2] macOS：当 Repo 在列表中显示为不可用时，增加右键菜单"重新定位…"（重新选择目录后重写 registry/bookmark）`QingJianApp/QingJianMac/ContentView.swift`
- [x] T036 [US2] iOS：当 Repo 为不可用时，在 RepoDetail 或列表项提供"重新定位…"入口（fileImporter 重新选择目录）`QingJianApp/QingJianIOS/ContentView.swift`
- [x] T037 [US2] Core：新增 relinkRepo(repoId,newRootURL) 用例（更新 registry + 重新校验元信息 + 更新可用性）`QingJianApp/QingJianCore/Sources/QingJianCore/UseCases/RepoUseCases.swift`
- [x] T038 [US2] Core：relinkRepo 成功/失败发送 repoAvailabilityChanged 事件，驱动 UI 刷新 `QingJianApp/QingJianCore/Sources/QingJianCore/Contracts/CoreEvent.swift`

### Tests（US2 涉及 core 变更，必须有）

- [x] T039 [US2] 添加 openRepo 错误分类覆盖（缺失/损坏/不可读写）`QingJianApp/QingJianCore/Tests/QingJianCoreTests/RepoUseCasesOpenRepoTests.swift`
- [x] T040 [US2] 添加 relinkRepo 成功与失败（不匹配 repoId/无元信息/权限）单测 `QingJianApp/QingJianCore/Tests/QingJianCoreTests/RepoUseCasesRelinkRepoTests.swift`

**Checkpoint**: US2 的错误场景不会把无效目录加入列表；不可用仓库可以移除或重新定位恢复。

---

## Phase 5: Polish & Cross-Cutting（收尾、性能门禁、文档一致性）

- [x] T041 [P] 对齐文案与术语（新建仓库/打开仓库/添加仓库）跨端一致性检查 `QingJianApp/QingJianMac/ContentView.swift, QingJianApp/QingJianIOS/ContentView.swift`
- [x] T042 [P] 完成可访问性检查清单（键盘路径/VoiceOver/暗色模式）`specs/002-open-existing-repo/checklists/accessibility.md`
- [x] T043 跑通 quickstart 全流程并记录结果（含重启后仍可打开）`specs/002-open-existing-repo/quickstart.md`
- [x] T044 运行核心测试并修复失败（作为合入门禁）`QingJianApp/QingJianCore/Tests/QingJianCoreTests/`

---

## Dependencies & Execution Order

- Phase 1 → Phase 2：先建立回归清单与夹具，再做核心拆分与持久化  
- Phase 2 → Phase 3/4：UI 改造与错误处理都依赖核心用例（create/open/validate/registry）  
- Phase 3（US1）优先：先把“打开已有仓库”跑通并确保“新建仓库不回归”  
- Phase 4（US2）随后：补齐失败语义与恢复路径（含 relink）

---

## Parallel Example

（以下任务可并行进行，减少互相阻塞）

```text
T005 与 T006 与 T007 可并行（分别新建 Domain/Storage 文件）
T017 与 T018 可并行（分别为元信息与 registry 写测试）
T022 与 T023 可并行（macOS 两个 Sheet）
T027 与 T025/T026 可并行（iOS OpenRepoView 与菜单改造）
```


