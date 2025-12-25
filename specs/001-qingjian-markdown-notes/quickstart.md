# Quickstart: 青简（qingjian）(Swift 6+)

**Branch**: `001-qingjian-markdown-notes`  
**Date**: 2025-12-25  
**Spec**: [spec.md](./spec.md)  
**Plan**: [plan.md](./plan.md)

本 quickstart 面向开发者，用于在本地快速跑起来并验证关键路径（Repo 浏览 / View 渲染 / macOS 编辑 / iCloud 同步语义 / 导出与锁定）。

---

## Prerequisites

- macOS 14.0+ 开发机
- Xcode 15.0+（支持 Swift 6）

---

## Project Layout

```text
QingJianApp/
├── QingJian.xcworkspace       # Xcode Workspace
├── QingJian.xcodeproj         # Xcode Project
├── QingJianCore/              # 共享核心模块 (Swift Package)
│   ├── Package.swift
│   └── Sources/
├── QingJianMac/               # macOS 应用
│   ├── QingJianMacApp.swift
│   ├── ContentView.swift
│   ├── Editor/
│   └── Vim/
├── QingJianIOS/               # iOS 应用
│   ├── QingJianIOSApp.swift
│   └── ContentView.swift
└── Tests/
```

---

## 方式一：使用 Xcode 打开（推荐）

### 1. 打开 Workspace

```bash
cd /path/to/qingjian/QingJianApp
open QingJian.xcworkspace
```

或者双击 `QingJian.xcworkspace` 文件。

### 2. 选择 Scheme

- **QingJianMac**: 运行 macOS 版本
- **QingJianIOS**: 运行 iOS 版本

### 3. 构建运行

- 快捷键: `⌘R` (Run)
- 快捷键: `⌘B` (Build only)
- 快捷键: `⌘U` (Run tests)

### 4. 调试

- 设置断点: 点击代码行号左侧
- 查看变量: Debug area (`⇧⌘Y`)
- 控制台: 查看 `print()` 输出和性能日志

---

## 方式二：从零创建 Xcode 工程

如果 `.xcodeproj` 文件不可用或需要重新创建：

### 1. 创建 Workspace

```
File > New > Workspace
保存为: QingJianApp/QingJian.xcworkspace
```

### 2. 添加 Swift Package

```
File > Add Package Dependencies...
选择: Add Local...
路径: QingJianApp/QingJianCore
```

### 3. 创建 macOS App Target

```
File > New > Project...
模板: macOS > App
名称: QingJianMac
语言: Swift
界面: SwiftUI
```

配置:
- Bundle Identifier: `com.qingjian.mac`
- Deployment Target: macOS 14.0
- Swift Version: 6.0

添加依赖:
```
Project Settings > QingJianMac > Frameworks
添加: QingJianCore
```

### 4. 创建 iOS App Target

```
File > New > Target...
模板: iOS > App
名称: QingJianIOS
语言: Swift
界面: SwiftUI
```

配置:
- Bundle Identifier: `com.qingjian.ios`
- Deployment Target: iOS 17.0
- Swift Version: 6.0

添加依赖:
```
Project Settings > QingJianIOS > Frameworks
添加: QingJianCore
```

### 5. 配置 Entitlements (macOS)

创建 `QingJianMac.entitlements`:
- App Sandbox: YES
- User Selected File (Read/Write): YES
- iCloud: CloudDocuments

---

## 使用命令行构建

### 构建 macOS 应用

```bash
cd QingJianApp
xcodebuild -workspace QingJian.xcworkspace \
  -scheme QingJianMac \
  -configuration Debug \
  build
```

### 构建 iOS 应用

```bash
cd QingJianApp
xcodebuild -workspace QingJian.xcworkspace \
  -scheme QingJianIOS \
  -sdk iphonesimulator \
  -configuration Debug \
  build
```

### 运行单元测试

```bash
# 核心模块测试 (推荐)
cd QingJianApp/QingJianCore
swift test

# 或通过 Xcode
xcodebuild -workspace QingJian.xcworkspace \
  -scheme QingJianCore \
  test
```

---

## Test

运行所有测试：

```bash
cd QingJianApp/QingJianCore
swift test
```

测试覆盖：
- Repo 扫描、排序元数据、外部变更检测
- 渲染缓存、冲突处理流程
- 导出、同步状态机
- 编辑保存、图片导入

---

## Sample Repo for Repeatable Testing

为性能门禁与回归测试准备固定样例 Repo：
- 目录层级：至少 5 层
- 笔记数量：1,000（用于 SC-002/SC-003）
- 大文件：≥ 50,000 行（用于降级策略验证）
- 图片：本地图片若干 + 在线图片若干（用于 FR-010/FR-011）

### 生成样例 Repo 脚本

```bash
#!/bin/bash
# generate_sample_repo.sh

REPO_DIR="${1:-./SamplePerfRepo}"
mkdir -p "$REPO_DIR"

# 创建目录结构（5 层）
for l1 in {1..5}; do
  for l2 in {1..3}; do
    for l3 in {1..2}; do
      mkdir -p "$REPO_DIR/level1_$l1/level2_$l2/level3_$l3/level4/level5"
    done
  done
done

# 创建 1000 个笔记
for i in $(seq 1 1000); do
  dir_idx=$((i % 30 + 1))
  l1=$(( (dir_idx - 1) / 6 + 1 ))
  l2=$(( (dir_idx - 1) % 6 / 2 + 1 ))
  l3=$(( (dir_idx - 1) % 2 + 1 ))
  cat > "$REPO_DIR/level1_$l1/level2_$l2/level3_$l3/note_$i.md" << EOF
# Note $i

This is note number $i for performance testing.

## Section 1
Content for section 1.

## Section 2
- Item 1
- Item 2
- Item 3

## Code Example
\`\`\`swift
func example() -> Int {
    return $i
}
\`\`\`
EOF
done

# 创建大文件（50,000 行）
echo "# Large File" > "$REPO_DIR/large_file.md"
for i in $(seq 1 50000); do
  echo "Line $i: Lorem ipsum dolor sit amet, consectetur adipiscing elit." >> "$REPO_DIR/large_file.md"
done

echo "Sample repo created at $REPO_DIR"
```

---

## Performance Measurement Hooks

关键路径埋点（Debug）至少覆盖：
- 冷启动到可交互
- 打开 Repo 到可浏览
- 切换笔记进入 View
- macOS 编辑输入延迟（采样方式在实现阶段确定）
- 预览更新可见延迟

### 性能指标门禁

| 指标 | 目标 | 测量方法 |
|------|------|----------|
| 冷启动 | < 1s | `app_cold_start` |
| Repo 打开 | < 500ms | `repo_open` |
| Repo 扫描 (1000 笔记) | < 2s | `repo_scan` |
| 笔记切换 | < 100ms | `note_view_load` |
| Markdown 渲染 | < 50ms | `markdown_render` |
| 预览更新 | < 200ms | `preview_update` |

### 运行性能回归测试

```bash
# 1. 生成样例 Repo
./generate_sample_repo.sh ./PerfTestRepo

# 2. 启动应用并打开性能测试 Repo
# (手动或通过 UI 测试自动化)

# 3. 查看控制台输出的性能指标
# 📊 [repo.scan] 1234.56ms
# 📊 [note.open] 45.67ms
# 📊 [markdown.render] 12.34ms

# 4. 对比基准值，确保不超过门禁
```

### XCTest 性能测试

```swift
func testRepoScanPerformance() throws {
    let repoURL = URL(fileURLWithPath: "/path/to/PerfTestRepo")
    let scanner = RepoScanner(repoRootURL: repoURL)
    
    measure {
        let _ = try? scanner.scan(repoId: "perf-test")
    }
}

func testMarkdownRenderPerformance() throws {
    let content = String(repeating: "# Heading\n\nParagraph.\n\n", count: 1000)
    let renderer = MarkdownRenderer()
    
    measure {
        let _ = try? renderer.render(markdown: content)
    }
}
```

---

## Trial Lock & Export Verification

试用到期未购买时：
- 应用进入锁定并引导购买
- 仍可导出/迁移 Repo（验证：用户能拿到完整文件夹内容）


