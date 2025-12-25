# Quickstart: 打开已有仓库（添加已有仓库）

**Branch**: `002-open-existing-repo`  
**Date**: 2025-12-25  
**Spec**: [spec.md](./spec.md)  
**Plan**: [plan.md](./plan.md)

本 quickstart 面向开发者，用于在本地快速验证本功能：**新建仓库** 与 **打开仓库** 两个入口并存且零回归、仓库列表持久化、沙盒访问可跨重启恢复。

---

## Prerequisites

- macOS 14+ 开发机
- Xcode 15+（Swift 6+）

---

## 运行方式（推荐）

```bash
cd /Users/creep/code/xwcoder/qingjian/QingJianApp
open QingJian.xcworkspace
```

选择 Scheme：
- `QingJianMac`（macOS）
- `QingJianIOS`（iOS Simulator）

---

## 核心测试（推荐先跑）

```bash
cd /Users/creep/code/xwcoder/qingjian/QingJianApp/QingJianCore
swift test
```

---

## 手工验收步骤（跨端一致）

### 1) 新建仓库（不丢）

1. 打开仓库列表页，点击 “+”
2. 选择 “新建仓库”
3. 选择一个目录作为仓库根目录（或创建一个新目录）
4. 期望：
   - 仓库被加入列表
   - Repo 根目录中出现 `.qingjian_metadata.json`

### 2) 打开仓库（仅允许已有元信息）

1. 准备一个包含 `.qingjian_metadata.json` 的目录
2. 点击 “+ → 打开仓库” 选择该目录
3. 期望：加入列表并可打开

反例（必须失败）：
- 选择一个普通目录（无 `.qingjian_metadata.json`）→ 提示“缺少仓库元信息，无法打开”，且不加入列表

### 3) 重启后仍可打开（验证持久化 + bookmark）

1. 添加至少一个仓库
2. 关闭应用并重新打开
3. 期望：
   - 仓库列表仍存在
   - 打开仓库不要求用户重新选择目录
   - 若授权失效/路径被移走：列表显示“不可用”，并能通过“重新定位/移除”恢复

---

## Debug 性能门禁（可选）

在 Debug 控制台关注：
- `repo.create`
- `repo.open`
- `repo.list.load`

阈值见 [plan.md](./plan.md) 的 Performance Goals。


