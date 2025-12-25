# Quickstart: 青简（qingjian）(Swift 6+)

**Branch**: `001-qingjian-markdown-notes`  
**Date**: 2025-12-25  
**Spec**: [spec.md](./spec.md)  
**Plan**: [plan.md](./plan.md)

本 quickstart 面向开发者，用于在本地快速跑起来并验证关键路径（Repo 浏览 / View 渲染 / macOS 编辑 / iCloud 同步语义 / 导出与锁定）。

---

## Prerequisites

- macOS 开发机
- Xcode（支持 Swift 6+ 的版本）

---

## Project Layout (目标结构)

> 说明：当前仓库尚未初始化工程，本结构是实现阶段要创建的目标布局。

```text
QingJianApp/
├── QingJianCore/
├── QingJianMac/
├── QingJianIOS/
└── Tests/
```

---

## Run (local)

1. 打开 Xcode 工程（实现阶段创建后补充具体路径）
2. 选择 `QingJianMac` scheme 运行 macOS 版
3. 选择 `QingJianIOS` scheme 运行 iOS 版（模拟器或真机）

---

## Test

- 运行 XCTest（核心逻辑优先）：Repo 扫描、排序元数据、外部变更检测、渲染缓存、冲突处理流程

---

## Sample Repo for Repeatable Testing

为性能门禁与回归测试准备固定样例 Repo：
- 目录层级：至少 5 层
- 笔记数量：1,000（用于 SC-002/SC-003）
- 大文件：≥ 50,000 行（用于降级策略验证）
- 图片：本地图片若干 + 在线图片若干（用于 FR-010/FR-011）

---

## Performance Measurement Hooks

关键路径埋点（Debug）至少覆盖：
- 冷启动到可交互
- 打开 Repo 到可浏览
- 切换笔记进入 View
- macOS 编辑输入延迟（采样方式在实现阶段确定）
- 预览更新可见延迟

---

## Trial Lock & Export Verification

试用到期未购买时：
- 应用进入锁定并引导购买
- 仍可导出/迁移 Repo（验证：用户能拿到完整文件夹内容）


