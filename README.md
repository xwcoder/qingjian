# 青简 - qingjian

## 目标
我想要这样一款笔记软件：
- [ ] 它是一款单机软件
- [ ] 如果收费，那么收费模式为一次性购买，而非订阅制
- [ ] 它是一款基于 markdown 的笔记软件
- [ ] 支持方便插入本地图片
- [ ] 支持 vim mode
- [ ] 支持预览
- [ ] 支持 macos 和 ios
- [ ] 基于文本文件，方便使用 git，cloud storage 等进行同步
- [ ] 支持 iCloud
- [ ] 支持 dark mode
- [ ] 支持无限层级目录
- [ ] 足够简洁：足够少的配置项、菜单、快捷键
- [ ] 支持多仓库（Repo）

## 关于产品名称
> 竹简。古代用以书写的狭长竹片。
> 《后汉书·吴佑传》：“ 恢 （ 吴恢 ）欲杀青简以写经书。” 李贤 注：“杀青者，以火炙简令汗，取其青易书，复不蠹，谓之杀青，亦谓汗简。”
> — 百度百科
> 
“青简”源自古代的书写材料，代表古典、优雅和知识积淀。简牍的意象赋予名字一种书香气息，适合注重深度、系统性和文化感的笔记软件。

## 概念
### Repository
Repository, 即仓库，可以类比 git/github repository 的概念。它是一组笔记、笔记目录的存储。物理上它对应一个文件夹。

## 功能
[青简 PRD](./prd.md) (使用 ChatGPT canvas 生成)

## 开发

### 环境要求
- macOS 14+ / iOS 17+
- Xcode 15.4+（Swift 6 支持）
- Swift 6.0+

### 快速开始

详细的本地开发、构建、测试与性能测量步骤见 [quickstart.md](./specs/001-qingjian-markdown-notes/quickstart.md)。

```bash
# 构建共享核心
cd QingJianApp/QingJianCore
swift build

# 运行单元测试
swift test
```

### 项目结构

```
QingJianApp/
├── QingJianCore/        # 共享核心（Swift Package）
│   ├── Sources/QingJianCore/
│   │   ├── Contracts/   # 错误/事件/用例协议
│   │   ├── Domain/      # 实体与状态机
│   │   ├── Storage/     # 文件 I/O、元数据、扫描
│   │   ├── UseCases/    # 业务用例实现
│   │   ├── Rendering/   # Markdown 渲染与缓存
│   │   └── Telemetry/   # 性能埋点
│   └── Tests/
├── QingJianMac/         # macOS 应用
│   ├── UI/              # SwiftUI 视图
│   └── Vim/             # Vim 模式引擎
├── QingJianIOS/         # iOS 应用（仅查看+快捷操作）
│   └── UI/
├── Shared/              # 跨端共享（购买 gating 等）
└── Tests/Fixtures/      # 测试夹具（样例 Repo）
```

### 设计文档

- [规格说明 spec.md](./specs/001-qingjian-markdown-notes/spec.md)
- [实现计划 plan.md](./specs/001-qingjian-markdown-notes/plan.md)
- [技术研究 research.md](./specs/001-qingjian-markdown-notes/research.md)
- [数据模型 data-model.md](./specs/001-qingjian-markdown-notes/data-model.md)
- [模块契约 contracts/](./specs/001-qingjian-markdown-notes/contracts/)
- [任务清单 tasks.md](./specs/001-qingjian-markdown-notes/tasks.md)


我想构建一款基于 markdown 的笔记软件, 中文名叫青简，英文qingjian。它有现代化的UI。它有 mac os 和 ios 版本。它是原生应用，保证性能。它是一款单机软件，支持通过 iCloud 同步文件。基于文本文件，方便使用 git，cloud storage 等进行同步。macos 上支持 vim mode 编辑笔记内容, ios端不支持 vim mode, ios端也可以不支持编辑 只支持查看, 这一点综合平衡实现复杂度和用户体验进行决策。支持边编辑边预览。支持 view 模式，将 markdown 渲染为优雅的格式。支持方便的插入本地图片和在线图片。支持 dark mode。支持多仓库（Repo）, 可以类比 git/github repository 的概念，它是一组笔记、笔记目录的存储，物理上它对应一个文件夹，这样可以将技术笔记仓库和生活笔记仓库，或其他笔记仓库分开。每个仓库支持无限层级目录， 可以通过设计保存元数据等手段使目录和文件支持拖动排序, 这点是区别于普通文件系统的。它是一款付费软件，一次性付费，不是订阅制，支持7天免费试用，试用和付费使用app store 提供的机制和能力。