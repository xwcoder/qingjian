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


