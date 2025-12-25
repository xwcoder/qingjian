# Research: 仓库内目录与笔记管理

本文件记录在实现前需要明确的关键技术决策（以降低返工风险），并对每项决策给出理由与备选方案。

## Decision 1: “目录/笔记”与文件系统的映射

- **Decision**: 目录 = 文件系统目录；笔记 = Markdown 文件（由 `RepoScanner` 的扩展名白名单识别）
- **Rationale**: 与宪法“离线优先 + 数据可移植”一致；外部工具可直接读写；无需额外数据库迁移
- **Alternatives considered**:
  - 在应用内部维护虚拟目录树：会引入同步与可移植风险，且跨端一致性成本更高

## Decision 2: 元数据文件的角色与恢复策略

- **Decision**: `.qingjian_metadata.json` 仅承载“可恢复”的辅助信息（自定义排序、最近笔记、最后扫描时间），不作为源数据
- **Rationale**: 即使元数据损坏/丢失，也应能通过文件系统完整重建仓库内容；符合可移植与稳定性要求
- **Alternatives considered**:
  - 将目录/笔记主数据写入元数据文件：会把源数据从文件系统转移，违背宪法并提高冲突复杂度

## Decision 3: 重名冲突策略（目录/笔记）

- **Decision**: 默认“阻止并返回明确错误”，由 UI 决定是否提供“自动追加序号”的便捷选项
- **Rationale**: 行为可预测、可测试；避免核心层暗中改名导致跨端语义不一致
- **Alternatives considered**:
  - 核心层自动改名：实现更方便但语义隐蔽，易造成用户误解与跨端不一致

## Decision 4: 目录移动/重命名与元数据迁移

- **Decision**: 对发生路径变化的目录（含子树）执行“元数据迁移 + 清理”：
  - 迁移 `folderOrders` 的 key：将 `oldPrefix/...` 统一替换为 `newPrefix/...`
  - 迁移 `folderOrders` 的 value（childPaths）：同样进行前缀替换
  - 迁移 `recentNotes`：对受影响路径做前缀替换；对不存在文件做剔除
- **Rationale**: 保留用户排序与最近项，避免移动后“排序丢失/最近列表失真”；同时保持元数据可恢复
- **Alternatives considered**:
  - 简化为“删除所有元数据并重新生成”：实现简单但用户排序与最近项全丢失，体验退化明显

## Decision 5: 删除非空目录的语义

- **Decision**: 删除目录为“确认后的永久移除”（由 UI 做强确认），核心层执行递归删除
- **Rationale**: 与当前文件系统模型一致；实现简单且可测试；若未来要支持“回收站”，应作为独立能力设计
- **Alternatives considered**:
  - 移动到应用回收站目录：需要额外规则与同步语义（未来可作为增强功能）

## Decision 6: 写入后的刷新与事件语义

- **Decision**:
  - 任何目录/笔记写入后，核心层应使目录树缓存失效（`BrowseUseCases.invalidateTreeCache`）并在需要时触发重新扫描
  - 对外仅发出“仓库内容变化”类事件（例如 `CoreEvent.repoChanged`），避免新增过细的 folder* 事件导致跨端行为分叉
- **Rationale**: 维持契约简洁；平台层可基于“受影响路径”选择局部刷新；与 `RepoWatchService` 的外部变更模型一致
- **Alternatives considered**:
  - 为每个 folder 操作新增事件：可读性更强但会扩大跨端一致性面，且与 watch 事件重复

## Decision 7: 性能预算与测量方式

- **Decision**: 以 `PerfMetrics` 已有指标作为门禁基础，并在目录/笔记管理关键路径补充测量点（必要时新增 metric）
- **Rationale**: 宪法要求“性能预算与零回归”；已有 `repo.scan`、`note.open`、`note.save` 等可直接复用
- **Alternatives considered**:
  - 只靠主观体验：无法回归，容易在不同平台产生性能分叉


