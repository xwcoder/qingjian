# Implementation Plan: 打开已有仓库（添加已有仓库）

**Branch**: `002-open-existing-repo` | **Date**: 2025-12-25  
**Spec**: [spec.md](./spec.md)

## 文档导航

| 文档 | 说明 |
|------|------|
| [spec.md](./spec.md) | 功能规格说明（需求、场景、成功标准） |
| [plan.md](./plan.md) | 实现计划（本文档） |
| [research.md](./research.md) | Phase 0：关键技术决策与风险收敛 |
| [data-model.md](./data-model.md) | Phase 1：数据模型（Repo/元信息/授权/状态） |
| [quickstart.md](./quickstart.md) | Phase 1：开发与验证指南 |
| [contracts/](./contracts/) | Phase 1：契约（用例/错误/事件） |
| [tasks.md](./tasks.md) | Phase 2：任务拆分（由 `/speckit.tasks` 生成） |

## Summary

在仓库列表页的 “+” 按钮下新增下拉菜单：**新建仓库** 与 **打开仓库**。  
其中：
- **新建仓库**：在用户选择的目录下创建/初始化一个青简仓库（写入仓库元信息文件），并加入仓库列表（保留原能力，零回归）。  
- **打开仓库**：选择本地已存在且包含仓库元信息的目录，将其加入仓库列表并可打开；若无元信息或损坏，给出明确错误并不加入列表。

## Technical Context

**Language/Version**: Swift 6+  
**Primary Dependencies**: SwiftUI、Foundation（文件 I/O）、UniformTypeIdentifiers（文件选择）、XCTest（共享核心测试）  
**Storage**:
- Repo 内容：文件系统（Markdown + 资产目录）  
- Repo 元信息：Repo 根目录内的 `.qingjian_metadata.json`（已存在于 `RepoMetadataStore`）  
- “已添加仓库列表/授权信息”：App Support 内的一个 JSON 文件（跨端一致），包含必要的安全访问凭据（见 research/data-model）
**Testing**: XCTest（核心用例单测/集成测优先）  
**Target Platform**: macOS + iOS（现有工程已具备两个 target）  
**Project Type**: 单仓库、多 target；共享核心 `QingJianCore` + 平台 UI（`QingJianMac`/`QingJianIOS`）  
**Performance Goals**（Debug 可测、用于零回归门禁）:
- 打开仓库（验证+加入列表）：p95 ≤ 300ms（不含首次全量扫描）
- 新建仓库（初始化元信息+加入列表）：p95 ≤ 300ms
- 仓库列表首次渲染：≤ 200ms（常见设备/空列表或少量 Repo）
**Constraints**:
- **零回归**：不得移除/替换“新建仓库”入口与行为（spec: FR-001a）
- **跨端一致**：术语（新建/打开）、错误语义（缺失元信息/损坏/权限）一致
- **沙盒访问**：macOS/iOS 都需要对用户选择目录的持续访问策略（否则重启后无法打开）
**Scale/Scope**:
- 支持多个 Repo
- 支持同一 Repo 重复选择时不重复添加（幂等）

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **跨端一致性（macOS+iOS）**：本功能新增入口为“新建/打开”并列；共享核心承载校验/持久化，UI 仅接入；符合
- **性能预算**：已给出关键路径指标（新建/打开/列表渲染）；并要求可测；符合
- **零回归策略**：明确将原“新建仓库”能力保留为独立入口，并加回归门禁；符合
- **离线与可移植**：不引入网络依赖；元信息存于 Repo 内（可随 Repo 迁移）；符合
- **可访问性**：菜单入口/弹窗需可键盘可达与 VoiceOver 可读（在 tasks 中落地）；不阻塞

## Project Structure

### Documentation (this feature)

```text
specs/002-open-existing-repo/
├── plan.md
├── spec.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── tasks.md
```

### Source Code (repository root)

```text
QingJianApp/
├── QingJianCore/                         # Swift Package：共享核心
│   └── Sources/QingJianCore/
│       ├── Contracts/                    # CoreError/CoreEvent
│       ├── Domain/                       # Repository 等领域模型
│       ├── Storage/                      # RepoMetadataStore 等存储
│       └── UseCases/                     # RepoUseCases 等用例
├── QingJianMac/                          # macOS UI（Sidebar + “+”）
├── QingJianIOS/                          # iOS UI（RepoList + “+”）
└── Tests/                                # Xcode 工程级测试（如需要）
```

**Structure Decision**: 继续遵循“共享核心 + 平台薄 UI”分层；本功能的“校验/持久化/幂等/错误语义”在 `QingJianCore`，UI 仅负责文件选择与展示。

## Phase 0: Outline & Research (output: research.md)

Phase 0 需要收敛的关键点（不留 NEEDS CLARIFICATION）：
- **仓库“已存在”的判定**：以 `.qingjian_metadata.json` 存在且可解析作为唯一判定（与当前 Storage 实现一致）
- **沙盒持续访问**：对用户选取目录保存并恢复安全访问凭据（bookmark），以保证重启后仍可打开
- **仓库列表持久化**：将 Repo 列表（含 displayName、最近打开时间、访问凭据）持久化到 App Support
- **零回归策略**：保留“新建仓库”入口，且原行为不被“打开仓库”替代；建立回归测试与手工清单

## Phase 1: Design & Contracts (outputs: data-model.md, contracts/*, quickstart.md)

- `data-model.md`：Repository/RepoMetadata/RepoRegistryEntry/RepoAccessGrant 等实体与规则
- `contracts/`：用例（Create/Open/List/Remove/Validate）、错误语义、事件（RepoAdded/RepoRemoved/RepoAvailabilityChanged）
- `quickstart.md`：本地验证新建/打开/重启后仍可打开（验证持久化与 bookmark）

## Phase 1: Agent Context Update

完成 Phase 1 产物后运行：

```bash
cd /Users/creep/code/xwcoder/qingjian
./.specify/scripts/bash/update-agent-context.sh cursor-agent
```

## Phase 2: Tasks

本命令不生成 tasks；后续使用 `/speckit.tasks` 基于本 plan 拆分任务。

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | - | - |
