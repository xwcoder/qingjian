# 可访问性检查清单

## 概述

本文档定义青简应用的可访问性验证步骤，确保应用对所有用户可用。

---

## 1. 暗色模式支持

### macOS

- [ ] 系统暗色模式下，侧边栏背景正确切换
- [ ] 编辑器文本在暗色模式下可读
- [ ] 预览区域暗色主题正确应用
- [ ] 所有图标在暗色模式下可见
- [ ] 工具栏按钮对比度符合 WCAG AA 标准

### iOS

- [ ] 系统暗色模式下，导航栏背景正确切换
- [ ] 笔记列表在暗色模式下可读
- [ ] 预览区域暗色主题正确应用
- [ ] 所有图标在暗色模式下可见

### 测试步骤

1. 打开系统偏好设置 > 外观 > 暗色
2. 启动青简应用
3. 验证所有界面元素颜色正确
4. 切换回浅色模式，验证颜色正确恢复

---

## 2. 动态字体支持

### macOS

- [ ] 编辑器字体大小可通过设置调整
- [ ] 预览字体响应系统字体大小设置
- [ ] 侧边栏文字响应系统字体大小
- [ ] 极大字体下 UI 不溢出或截断

### iOS

- [ ] 应用支持 Dynamic Type
- [ ] 笔记列表文字响应系统字体大小
- [ ] 预览内容响应系统字体大小
- [ ] 极大字体 (AX1-AX5) 下 UI 不溢出

### 测试步骤

1. 打开系统偏好设置 > 显示 > 文字大小
2. 调整到最大值
3. 验证所有文字可读，UI 不破坏
4. 调整到最小值，验证文字仍可读

---

## 3. VoiceOver 支持

### macOS

- [ ] 侧边栏 Repo 列表可通过 VoiceOver 导航
- [ ] 目录树结构可通过 VoiceOver 遍历
- [ ] 笔记标题被正确朗读
- [ ] 编辑器输入可通过 VoiceOver 操作
- [ ] 工具栏按钮有正确的可访问性标签
- [ ] 对话框和弹窗可通过 VoiceOver 交互

### iOS

- [ ] 导航栏可通过 VoiceOver 导航
- [ ] 笔记列表可通过 VoiceOver 遍历
- [ ] 预览内容可通过 VoiceOver 朗读
- [ ] 所有按钮有正确的可访问性标签

### 测试步骤

1. 启用 VoiceOver (macOS: Cmd+F5, iOS: 设置 > 辅助功能)
2. 使用 Tab/滑动导航整个应用
3. 验证所有交互元素可被聚焦
4. 验证所有标签被正确朗读
5. 验证常见操作可通过 VoiceOver 完成

---

## 4. 键盘导航 (macOS)

### 基本导航

- [ ] Tab 键可在主要区域间切换
- [ ] 方向键可在列表中导航
- [ ] Enter 键可激活选中项
- [ ] Escape 键可取消/关闭

### 快捷键

- [ ] ⌘N 创建新笔记
- [ ] ⌘S 保存
- [ ] ⌘W 关闭窗口
- [ ] ⌘, 打开设置
- [ ] ⌘F 搜索
- [ ] ⌘B 粗体 (编辑模式)
- [ ] ⌘I 斜体 (编辑模式)

### Vim 模式

- [ ] Vim 模式下所有基本移动键位可用
- [ ] Vim 模式可通过设置开关
- [ ] Vim 模式状态在 UI 中可见

### 测试步骤

1. 使用纯键盘操作应用
2. 验证所有功能可通过键盘完成
3. 验证没有键盘陷阱（无法退出的焦点状态）

---

## 5. 色彩对比度

### 检查项

- [ ] 正文文字对比度 ≥ 4.5:1 (WCAG AA)
- [ ] 大文字（≥18pt）对比度 ≥ 3:1
- [ ] 链接颜色与正文有区分
- [ ] 错误提示颜色与背景有足够对比
- [ ] 聚焦指示器清晰可见

### 工具

- 使用 macOS 辅助功能检查器
- 使用 Xcode Accessibility Inspector
- 使用在线对比度检查工具

---

## 6. 减少动画

### 检查项

- [ ] 响应系统"减少动画"设置
- [ ] 关键动画有非动画替代
- [ ] 没有闪烁或快速闪动的元素

### 测试步骤

1. 打开系统偏好设置 > 辅助功能 > 显示 > 减少动画
2. 验证应用动画被简化或移除
3. 验证功能不受影响

---

## 7. 触控支持 (iOS)

### 检查项

- [ ] 所有可点击元素尺寸 ≥ 44×44 点
- [ ] 滑动手势有按钮替代
- [ ] 多指手势有单指替代
- [ ] 长按操作有上下文菜单替代

---

## 8. 辅助功能检查工具

### 自动化测试

```swift
// XCTest 中的可访问性测试
func testAccessibility() throws {
    let app = XCUIApplication()
    app.launch()
    
    // 验证主要元素有可访问性标识
    XCTAssertTrue(app.buttons["addRepo"].exists)
    XCTAssertTrue(app.tables["repoList"].exists)
    
    // 运行可访问性审计
    try app.performAccessibilityAudit()
}
```

### 手动检查清单

使用 Xcode Accessibility Inspector:

1. 打开 Xcode > Open Developer Tool > Accessibility Inspector
2. 选择目标应用
3. 检查每个元素的可访问性属性
4. 验证标签、提示、特征正确设置

---

## 验证记录

| 日期 | 测试者 | 平台 | 结果 | 备注 |
|------|--------|------|------|------|
| | | | | |

---

## 参考资源

- [Apple Human Interface Guidelines - Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [SwiftUI Accessibility](https://developer.apple.com/documentation/swiftui/accessibility)

