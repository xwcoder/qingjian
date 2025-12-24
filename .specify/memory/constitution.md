<!--
Sync Impact Report

- Version change: TEMPLATE → 1.0.0
- Modified principles: N/A (template bootstrap)
- Added sections: Core Principles (filled), Platform & Architecture Constraints, Development Workflow & Quality Gates, Governance
- Removed sections: N/A
- Templates requiring updates:
  - ✅ updated: `.specify/templates/plan-template.md`
  - ✅ updated: `.specify/templates/tasks-template.md`
  - ✅ updated: `.specify/templates/checklist-template.md`
  - ✅ verified: `.specify/templates/spec-template.md` (no changes required)
  - ✅ verified: `.specify/templates/agent-file-template.md` (no changes required)
  - ⚠ pending: `.specify/templates/commands/*.md` (directory not present in this repo)
- Deferred TODOs:
  - TODO(RATIFICATION_DATE): 仓库中未找到首次通过宪法的日期；确认后替换
-->

# 青简（qingjian）Constitution

## Core Principles

### I. macOS + iOS 体验一致性（非谈判项）
- **MUST**：同一能力在 macOS 与 iOS 上的“结果一致”（数据、格式、同步语义、错误语义一致）。
- **MUST**：关键用户旅程在两端保持一致的交互模型（例如：编辑/预览、仓库/目录、搜索、插图）。
- **MUST**：同一业务概念使用同一术语与信息架构（IA），避免平台间同义不同名。
- **SHOULD**：在遵循平台人机指南（HIG）的前提下做到“认知一致”，允许控件样式不同，但不允许行为不一致。

Rationale：青简的价值来自“跨设备同一套笔记体验”。一致性减少学习成本与数据风险。

### II. 性能预算与零回归（非谈判项）
- **MUST**：每个变更在合入前定义并记录性能预算（至少覆盖：冷启动、打开仓库、打开笔记、编辑输入延迟、滚动流畅度、图片插入/渲染）。
- **MUST**：为关键路径提供可观测性（本地指标/日志），并能在 Debug 环境快速定位卡顿/慢操作。
- **MUST**：任何性能回退都需要：
  - 明确的回退指标与原因分析
  - 回退修复计划或短期兜底（例如降级策略、异步化、缓存）
  - 记录在变更说明中（PR/plan.md）
- **SHOULD**：优先用共享核心逻辑 + 平台薄 UI 层实现，避免双端重复实现导致难以优化与不一致。

Rationale：跨端一致性必须靠“可测量的性能门禁”支撑，否则体验会在平台间分叉。

### III. 离线优先与数据可移植（非谈判项）
- **MUST**：核心笔记以纯文本（Markdown）为源数据，便于 git / cloud storage 同步与备份。
- **MUST**：应用在无网络情况下可完成核心任务（浏览、搜索、编辑、插图、目录管理）。
- **MUST**：同步（包括 iCloud）不得改变用户文件结构与文本语义；冲突必须可解释、可恢复。
- **SHOULD**：对外格式稳定，避免无必要的私有二进制封装锁死用户数据。

Rationale：青简是“本地文件即真相”的笔记工具，可靠性与可迁移性是底线。

### IV. 共享核心，平台分层
- **MUST**：将业务规则/数据模型/同步策略放入共享核心模块（可被 macOS+iOS 复用）。
- **MUST**：平台层只处理 UI、系统能力适配（键盘/鼠标/触控、窗口、多场景、分享扩展等）。
- **MUST**：跨端差异必须被显式建模（例如 capability flags），不得靠“平台分支散落在各处”。
- **SHOULD**：共享核心可独立测试、可在不启动 UI 的情况下验证关键逻辑。

Rationale：共享核心是“一致性”和“性能”的工程基础，也是控制复杂度的唯一方式。

### V. 可访问性与系统一致性
- **MUST**：暗色模式、动态字体（或等价的可读性策略）、VoiceOver/辅助功能可用。
- **MUST**：macOS 端支持键盘优先工作流（快捷键、焦点移动、菜单/命令）。
- **MUST**：iOS 端支持触控手势、分享/文件导入等系统能力的合理接入。
- **SHOULD**：对可访问性与平台行为做回归检查，避免“只在一端可用”。

Rationale：一致性不仅是视觉，更是“可达性与系统行为”的一致。

## Platform & Architecture Constraints

- **Target**：macOS + iOS 双端应用；同一 repo 维护。
- **Data Model**：Markdown 文本 + 本地图片资源；目录结构映射到文件系统。
- **Sync**：支持 iCloud；并以“文件可被外部工具同步/版本控制”为设计前提。
- **Architecture**：
  - 共享核心模块（domain + storage + sync）与平台 UI 层分离
  - 关键路径必须避免主线程阻塞；对 I/O、解析、渲染做异步/缓存策略
- **UX**：保持简洁（少配置、少菜单、少快捷键），但关键能力在两端可达。

## Development Workflow & Quality Gates

- **Definition of Done (DoD)**：
  - 需求/验收场景明确（spec.md）
  - 关键路径性能预算写入（plan.md），并有测量方式
  - 双端体验一致性检查通过（至少覆盖：信息架构、交互语义、错误处理）
  - 可访问性基本项通过（暗色、可读性/动态字体、VoiceOver/键盘路径）
- **PR Gate（合入门禁）**：
  - 对共享核心的变更：**MUST** 有自动化测试覆盖（单元/集成至少其一）
  - 对 UI 行为的变更：**MUST** 提供可回归的验证方式（UI 测试、快照、或明确的手工检查清单）
  - 若需豁免：必须写明原因、风险与后续补齐计划
- **Release Discipline**：
  - 面向用户的变更必须有变更说明（尤其是数据/同步语义）
  - 破坏性变更必须提供迁移/回滚方案

## Governance

- **Supremacy**：本宪法约束高于所有模板与习惯做法；若冲突，以本宪法为准。
- **Amendment Process**：
  - 任何修订必须通过 PR，说明动机、影响范围、迁移/兼容策略（如适用）
  - 修订后必须同步更新 `.specify/templates/*` 中依赖此宪法的内容
- **Versioning Policy**：
  - 采用语义化版本（MAJOR.MINOR.PATCH）
  - MAJOR：原则/门禁的非兼容变更或删除
  - MINOR：新增原则/新增强制门禁/新增重要章节
  - PATCH：澄清/措辞/无语义改变的整理
- **Compliance Review**：
  - 每个 feature 的 plan.md 必须包含“Constitution Check”
  - 如存在违反，必须在 plan.md 的 Complexity Tracking（或等价区）记录理由与替代方案

**Version**: 1.0.0 | **Ratified**: TODO(RATIFICATION_DATE) | **Last Amended**: 2025-12-24
