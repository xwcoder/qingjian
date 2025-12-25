# Implementation Plan: 青简（qingjian）Markdown 笔记应用（macOS/iOS）

**Branch**: `001-qingjian-markdown-notes` | **Date**: 2025-12-25 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/001-qingjian-markdown-notes/spec.md`

**Note**: 本文件由 `/speckit.plan` 生成并完善，作为实现阶段的技术与门禁依据。

## Summary

用 Swift 6+ 构建原生 macOS+iOS Markdown 笔记应用：以“Repo=文件夹”为核心数据模型，支持多仓库、无限层级目录、优雅渲染（View 模式）、macOS 编辑（含 Vim 模式与边写边预览）、图片资产随 Repo 存储、深色模式；iOS 端仅查看+快捷操作；支持 iCloud 同步并在冲突时提示用户选择/合并；提供 7 天试用，试用结束未购买则锁定但允许导出/迁移。

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Swift 6+  
**Primary Dependencies**: SwiftUI（跨端 UI）、Foundation（文件 I/O）、XCTest（单元/集成测试）；其它依赖在 Phase 0 研究后收敛（例如 Markdown 渲染方案）  
**Storage**: 文件系统（Markdown + 图片资产）+ Repo 元数据文件（用于自定义排序/状态等）  
**Testing**: XCTest（共享核心单测/集成测）+ 基础 UI 回归清单（必要时再引入 UI 测试）  
**Target Platform**: macOS + iOS（版本范围在 Phase 0 确认；默认支持当前主流系统版本）  
**Project Type**: 原生移动+桌面应用（单仓库，多 target；共享核心模块 + 平台 UI 层）  
**Performance Goals**:
- 冷启动到可交互：≤ 2s（常见设备条件下）
- 打开含 1,000 篇笔记的 Repo 并可浏览：≤ 2s
- 切换笔记进入 View：p95 ≤ 300ms
- macOS 编辑输入延迟：主观“无明显卡顿”（Phase 0 定义可测指标与采样方式）
- 预览更新可见：p95 ≤ 200ms（允许批量/节流，不要求逐字即时）
- 滚动流畅：目标 60fps 体感（Phase 0 定义测量方式）
**Constraints**:
- 离线可用（浏览/搜索/编辑/插图/目录管理）
- “文件即真相”：不引入私有二进制封装锁死数据
- iCloud 同步不改变文件结构/文本语义；冲突可解释可恢复（选择/合并）
- iOS 仅查看+快捷操作（复制/分享/导出/系统共享）
- 试用到期未购买：锁定但允许导出/迁移
**Scale/Scope**:
- 多 Repo 同时打开
- Repo 内无限层级目录
- 资源类型：Markdown 文本 + 图片（本地与在线）

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **跨端一致性（macOS+iOS）**：信息架构、术语、交互语义、错误语义一致；允许控件风格不同但行为一致
- **性能预算**：为关键路径写清指标与测量方式（冷启动/打开仓库/打开笔记/输入延迟/滚动/图片渲染）
- **零回归策略**：若存在回退，必须有原因、兜底与修复计划，并记录在本 plan
- **离线与可移植**：Markdown 作为源数据；无网可用；同步/iCloud 不改变语义且冲突可恢复
- **可访问性**：暗色模式、可读性（动态字体或等价策略）、VoiceOver/键盘路径（按平台）

**Gate Evaluation (pre-Phase 0)**:
- 跨端一致性：计划采用共享核心（Repo/文件/同步/冲突/排序）+ 平台薄 UI；符合
- 性能预算：已在 Technical Context 给出关键指标；Phase 0 将补齐“测量方式与门禁”；暂不阻塞
- 离线与可移植：以文件为源数据 + 离线可用 + iCloud 不改语义；符合
- 可访问性：已纳入 dark mode/键盘/VoiceOver；Phase 0 明确验收清单；暂不阻塞

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
```text
# 说明：当前仓库尚未初始化 Xcode 工程/Swift Package 结构（需在实现阶段创建）
QingJianApp/                 # Xcode 工程根（待创建）
├── QingJianCore/            # 共享核心：domain + storage + sync + indexing + rendering facade
├── QingJianUIShared/        # 跨端可复用 UI 组件（可选，尽量薄）
├── QingJianMac/             # macOS app target（窗口/命令/键盘/Vim/分栏预览）
├── QingJianIOS/             # iOS app target（查看+快捷操作/分享）
└── Tests/                   # XCTest（核心逻辑优先）
```

**Structure Decision**: 单仓库、多 target 的原生应用结构；共享核心模块承载一致性与性能优化，平台层仅做 UI 与系统能力适配（符合 Constitution IV）。

## Phase 0: Outline & Research (output: research.md)

需要在 research.md 中收敛并形成明确决策的研究主题（全部在 Phase 0 解决，不留 NEEDS CLARIFICATION）：

- Markdown 渲染方案：可扩展语法覆盖范围、暗色模式、代码块高亮、图片/链接处理、性能与缓存策略
- macOS “Vim 模式”编辑：可行范围（必须覆盖的高频操作）、输入法/快捷键冲突处理、与预览联动策略
- Repo 元数据设计：拖拽排序的持久化方式、与文件系统变更（新增/删除/重命名）一致性规则
- 文件变更监听：外部工具（git/云盘/编辑器）改动触发刷新、去抖与性能影响
- iCloud 同步与冲突：文件级冲突识别、提示与合并流程、用户可恢复性（不丢内容）
- 性能门禁与测量：冷启动/打开 Repo/打开笔记/输入延迟/滚动/渲染的测量方法与阈值写入
- 试用/付费锁定后的“允许导出”路径：导出形式（直接暴露 Repo 文件夹/系统分享/打包导出）与用户体验

## Phase 1: Design & Contracts (outputs: data-model.md, contracts/*, quickstart.md)

- 产出 `data-model.md`：Repo/Folder/Note/Asset/Metadata/SyncConflict 等实体与状态机
- 产出 `contracts/`：共享核心与平台 UI 的边界协议（用例/事件/错误语义/文件操作契约），不使用 Web API 形式
- 产出 `quickstart.md`：本地构建运行、测试入口、性能测量入口、最小示例 Repo

## Phase 1: Agent Context Update

完成 Phase 1 产物后运行：

```bash
./.specify/scripts/bash/update-agent-context.sh cursor-agent
```

## Phase 2: Tasks

本命令不生成 tasks；后续使用 `/speckit.tasks` 基于本 plan 拆分任务。

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
