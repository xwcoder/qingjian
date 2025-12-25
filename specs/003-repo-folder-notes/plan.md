# Implementation Plan: 仓库内目录与笔记管理

**Branch**: `[003-repo-folder-notes]` | **Date**: 2025-12-25 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-repo-folder-notes/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

在“已选中仓库”的作用域内，实现目录（创建/重命名/移动/删除）与笔记（创建/重命名/移动/删除/打开/保存）的管理能力，并保证：

- 共享核心负责业务规则与文件系统写入语义；macOS/iOS 仅做 UI 适配，保证跨端一致
- Markdown 文件与目录结构是源数据；`.qingjian_metadata.json` 仅用于排序/最近项等可恢复的辅助信息
- 所有写入操作具备明确的错误语义、可恢复提示与性能预算（可测量、可回归）

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Swift（Swift Package + Xcode 工程；与当前仓库工具链保持一致）  
**Primary Dependencies**: Foundation（文件 I/O）、Combine（事件总线）、CryptoKit（Repo ID）、SwiftUI（平台 UI）  
**Storage**: 文件系统（目录 + Markdown 文本）；Repo 元数据 `.qingjian_metadata.json`；仓库注册表 `repo_registry.json`（App Support）  
**Testing**: XCTest（`QingJianCoreTests`）  
**Target Platform**: macOS + iOS（同仓库双端应用）  
**Project Type**: mobile（共享核心 + 平台薄 UI 层）  
**Performance Goals**:
  - `repo.scan`：对中等规模仓库（~1,000 笔记）扫描在可接受范围内，并可通过 Debug 指标回归
  - `note.open` / `note.save`：打开/保存笔记可测量并满足交互期望
  - `editor.key_latency` / `preview.update`：编辑关键路径不产生明显卡顿（以现有 PerfMetrics 埋点回归）
**Constraints**: 离线优先；Markdown 语义与文件结构为真相；跨端一致（术语/行为/错误语义）；避免主线程阻塞（I/O 与扫描异步化）  
**Scale/Scope**: 支持多级目录与 1,000+ 笔记；目录/笔记重命名与移动需保证元数据可恢复且不会导致“丢失/幽灵条目”

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **跨端一致性（macOS+iOS）**：信息架构、术语、交互语义、错误语义一致；允许控件风格不同但行为一致
- **性能预算**：为关键路径写清指标与测量方式（冷启动/打开仓库/打开笔记/输入延迟/滚动/图片渲染）
- **零回归策略**：若存在回退，必须有原因、兜底与修复计划，并记录在本 plan
- **离线与可移植**：Markdown 作为源数据；无网可用；同步/iCloud 不改变语义且冲突可恢复
- **可访问性**：暗色模式、可读性（动态字体或等价策略）、VoiceOver/键盘路径（按平台）

结论：本功能无宪法冲突。目录/笔记管理规则（作用域、错误语义、删除确认、冲突保护）放入共享核心，保证双端一致；性能预算依赖 `PerfMetrics` 的现有指标并在实现中补齐关键路径测量。

## Project Structure

### Documentation (this feature)

```text
specs/003-repo-folder-notes/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
```text
QingJianApp/
├── QingJianCore/
│   ├── Sources/QingJianCore/
│   │   ├── Contracts/              # CoreError/CoreEvent 等跨端契约
│   │   ├── Domain/                 # Repository/TreeNode/NoteDocument 等领域模型
│   │   ├── Storage/                # NoteStore/RepoScanner/RepoMetadataStore 等
│   │   ├── UseCases/               # Browse/Edit/Ordering/Repo 等用例入口
│   │   ├── Rendering/              # Markdown 渲染与缓存
│   │   └── Telemetry/              # PerfMetrics 等性能指标
│   └── Tests/QingJianCoreTests/    # 共享核心单元/集成测试
├── QingJianIOS/                    # iOS 平台 UI（SwiftUI）
└── QingJianMac/                    # macOS 平台 UI（SwiftUI + 编辑器相关）
```

**Structure Decision**: 采用“共享核心（QingJianCore）+ 平台薄 UI（QingJianIOS/QingJianMac）”结构；目录/笔记管理的文件系统语义、冲突与错误处理、元数据维护都在共享核心实现，平台层只负责交互与呈现，保证双端一致性。

## Performance Budget (T035)

| Metric | Target | Measurement Method | Status |
|--------|--------|-------------------|--------|
| `repo.scan` | < 500ms for 1000 notes | `PerfMetrics.measure()` in `BrowseUseCases.loadRepoTree` | ✅ Instrumented |
| `note.open` | < 100ms | `PerfMetrics.measure()` in `BrowseUseCases.openNote` | ✅ Instrumented |
| `note.save` | < 50ms | `PerfMetrics.measure()` in `EditUseCases.saveNote` | ✅ Instrumented |
| `note.create` | < 100ms | `PerfMetrics.measure()` in `EditUseCases.createNote` | ✅ Instrumented |
| `folder.create` | < 50ms | `PerfMetrics.measure()` in `FolderUseCases.createFolder` | ✅ Instrumented |
| `folder.move` | < 100ms | `PerfMetrics.measure()` in `FolderUseCases.moveFolder` | ✅ Instrumented |
| `folder.delete` | < 100ms | `PerfMetrics.measure()` in `FolderUseCases.deleteFolder` | ✅ Instrumented |
| `editor.key_latency` | < 16ms | Platform-level input handler | 🔧 To be measured |

**Debug Observation**: 所有核心操作已通过 `PerfMetrics` 埋点，DEBUG 模式下会打印到控制台：
```
📊 [note.open] 45.23ms ["repoId": "xxx", "path": "docs/readme.md"]
```

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | 本功能无宪法冲突 | N/A |
