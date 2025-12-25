# Quickstart: 仓库内目录与笔记管理（开发验证）

本文件用于开发者在实现完成后快速验证“目录管理 + 笔记管理”在 macOS/iOS 两端语义一致、且性能指标可观测。

## 1) 打开工程

- 打开 `QingJianApp/QingJian.xcworkspace`
- 选择目标：`QingJianMac` 或 `QingJianIOS`

## 2) 运行共享核心测试

- 运行 `QingJianCoreTests`
  - 重点关注：`OrderingMergeRulesTests`（排序/合并规则）、Repo/Storage 相关测试

## 3) 手工验收（建议使用 fixtures）

使用仓库自带示例仓库：
- `QingJianApp/Tests/Fixtures/SampleRepo/`

建议验收路径（两端应一致）：
- **P1**：选中仓库 → 在根目录新建笔记 → 打开笔记 → 返回后仍可找到并打开
- **P2**：创建目录 → 重命名目录 → 将目录移动到另一个目录下 → 删除非空目录（确认提示正确）
- **P3**：重命名笔记 → 移动笔记到其他目录 → 删除笔记（确认提示正确）
- **边界**：重名冲突、移动到自身/子目录、仓库不可用、未保存更改保护

## 4) 性能观测（Debug）

在 Debug 环境下观察 `PerfMetrics` 输出，至少覆盖：
- `repo.scan`
- `note.open`
- `note.save`
- `editor.key_latency` / `preview.update`（如平台实现包含编辑预览）


