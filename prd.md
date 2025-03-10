# 青简 PRD（产品需求文档）

## 1. 产品概述

青简是一款极简、单机的 Markdown 笔记软件，适用于 macOS 和 iOS。它基于文本文件，支持 Git、iCloud 以及其他云存储服务进行同步，具备高效的笔记管理能力，同时支持 Vim 模式和 Markdown 预览。

## 2. 核心特性

### 2.1 文件与存储

- **基于 Markdown**：所有笔记均为 `.md` 文件，支持标准 Markdown 语法。
- **基于文本文件**：便于版本管理、云同步、跨设备访问。
- **支持本地图片插入**：可直接插入和显示本地存储的图片文件。
- **支持多仓库（Repo）**：每个仓库对应一个文件夹，用户可管理多个仓库，支持切换。
- **支持无限层级目录**：可在仓库内创建和管理任意层级的子目录。
- **iCloud 同步支持**：可将笔记存储在 iCloud，自动同步至所有设备。

### 2.2 编辑与交互

- **Vim Mode**：支持 Vim 模式，提供高效的文本编辑体验。
- **简洁的 UI**：极简设计，减少冗余菜单和复杂配置项。
- **快捷键支持**：提供基础快捷键，提升操作效率。
- **Dark Mode**：支持黑暗模式，适配 macOS 和 iOS 主题切换。
- **Markdown 预览**：支持实时预览 Markdown 渲染效果。
- **本地图片预览**：可在 Markdown 预览模式下正确渲染本地图片。

### 2.3 同步与管理

- **Git 友好**：所有笔记基于文本文件，方便 Git 版本管理。
- **Cloud Storage 兼容**：支持通过 Dropbox、OneDrive 等云存储同步。
- **iCloud 集成**：可选择将仓库存储于 iCloud Drive，实现跨设备同步。
- **自动保存**：所有更改自动保存，无需手动操作。
- **多设备支持**：支持 macOS 和 iOS，数据无缝衔接。

### 2.4 其他功能

- **搜索功能**：支持全文搜索，快速定位笔记内容。
- **最少的配置项**：尽量减少用户需要配置的选项，提供即开即用的体验。
- **极简菜单设计**：仅保留最核心的功能，减少 UI 复杂度。

## 3. 界面设计

### 3.1 主界面

- **左侧：仓库与目录树**
  - 展示所有已加载的仓库
  - 目录树结构显示当前仓库内的笔记层级
  - 允许创建、重命名、删除文件或目录
- **中间：笔记列表**
  - 展示当前目录下的所有笔记
  - 支持按名称、创建时间、修改时间排序
  - 支持搜索和筛选
- **右侧：编辑区**
  - Markdown 编辑器（支持 Vim Mode）
  - 实时预览 Markdown 渲染效果
  - Dark Mode 适配

### 3.2 仓库管理界面

- **仓库列表**
- **新增仓库**
- **切换仓库**
- **删除仓库**

### 3.3 设置界面

- **主题模式（Light/Dark）**
- **Vim Mode 开关**
- **iCloud 开关**

## 4. 设计草图

### 4.1 主界面布局

```
+-------------------------------------------------+
| 仓库 & 目录树  | 笔记列表  | Markdown 编辑 & 预览 |
|-----------------------------------------------|
| Repo 1        | Note 1   | # 青简                     |
| ├── Folder A  | Note 2   | 青简是一款极简 Markdown 笔记软件 |
| ├── Folder B  | Note 3   | ...                          |
| └── Folder C  | ...      | ...                          |
+-------------------------------------------------+
```

## 5. 交互与快捷键

| 功能          | 快捷键（macOS）    |
| ----------- | ------------- |
| 新建笔记        | ⌘ + N         |
| 保存          | ⌘ + S         |
| 预览切换        | ⌘ + P         |
| Vim Mode 切换 | ⌘ + Shift + V |
| 搜索          | ⌘ + F         |

## 6. 版本计划

### 6.1 V1.0 目标

- 实现基本的 Markdown 编辑、预览和仓库管理
- 支持 Vim Mode
- 实现本地存储和 iCloud 同步
- 支持 Dark Mode

### 6.2 未来版本

- 增强搜索功能（支持全文搜索和模糊匹配）
- 增加更多 Markdown 渲染选项
- 提供更多 UI 主题方案

## 7. 结语

青简的目标是打造一款极简、高效、Git 友好的 Markdown 笔记软件，让用户能够专注于内容创作，享受极致流畅的编辑体验。
