# QingJianCore

青简共享核心模块，包含跨 macOS/iOS 平台的业务逻辑、数据模型和存储层。

## 架构

```
QingJianCore/
├── Sources/QingJianCore/
│   ├── Contracts/        # 接口契约（错误、事件）
│   │   ├── CoreError.swift
│   │   └── CoreEvent.swift
│   ├── Domain/           # 领域模型
│   │   ├── Repository.swift
│   │   ├── TreeNode.swift
│   │   ├── NoteDocument.swift
│   │   └── RepoAvailability.swift
│   ├── Storage/          # 存储层
│   │   ├── RepoMetadataStore.swift
│   │   ├── RepoScanner.swift
│   │   ├── NoteStore.swift
│   │   └── RepoWatchService.swift
│   ├── UseCases/         # 用例层
│   │   ├── RepoUseCases.swift
│   │   ├── BrowseUseCases.swift
│   │   ├── EditUseCases.swift
│   │   ├── AssetUseCases.swift
│   │   ├── OrderingUseCases.swift
│   │   ├── SyncUseCases.swift
│   │   ├── ExportUseCases.swift
│   │   └── PurchaseUseCases.swift
│   ├── Rendering/        # Markdown 渲染
│   │   ├── MarkdownRenderer.swift
│   │   ├── RenderTheme.swift
│   │   ├── RenderCache.swift
│   │   └── ImageResolver.swift
│   ├── Telemetry/        # 性能监控
│   │   └── PerfMetrics.swift
│   └── QingJianCore.swift # 模块入口
└── Tests/QingJianCoreTests/
    ├── StorageTests.swift
    ├── RenderingTests.swift
    ├── UseCaseBrowseTests.swift
    ├── UseCaseEditSaveTests.swift
    ├── UseCaseImportImageTests.swift
    ├── OrderingMergeRulesTests.swift
    ├── SyncStateMachineTests.swift
    └── ExportUseCaseTests.swift
```

## 设计原则

### 1. 分层架构

- **Contracts**: 定义跨层通信的错误和事件类型
- **Domain**: 纯数据模型，无业务逻辑
- **Storage**: 文件系统和持久化操作
- **UseCases**: 业务逻辑，协调 Storage 和 Domain
- **Rendering**: Markdown 渲染和缓存

### 2. Actor 隔离

所有 UseCases 使用 `actor` 实现线程安全：

```swift
public actor RepoUseCases {
    public func addRepo(rootURL: URL, displayName: String?) throws -> RepoSummary
    public func removeRepo(id: String) throws
    public func listRepos() -> [RepoSummary]
}
```

### 3. 事件驱动

使用 `CoreEventBus` 进行模块间通信：

```swift
let eventBus = CoreEventBus()

// 发送事件
eventBus.emit(.repoAdded(repoId: "xxx"))

// 订阅事件
eventBus.publisher
    .sink { event in
        switch event {
        case .repoAdded(let repoId):
            // 处理
        default:
            break
        }
    }
```

### 4. 错误处理

所有可失败操作使用 `CoreError` 类型：

```swift
public enum CoreError: LocalizedError, Equatable, Sendable {
    case invalidRepo(path: String)
    case noteNotFound(path: String)
    case noteConflict(path: String)
    case iCloudUnavailable(reason: String)
    // ...
}
```

## 使用

### 添加 Repo

```swift
let repoUseCases = RepoUseCases()
let summary = try await repoUseCases.addRepo(
    rootURL: URL(fileURLWithPath: "/path/to/repo"),
    displayName: "My Notes"
)
```

### 浏览笔记

```swift
let browseUseCases = BrowseUseCases()
let tree = try await browseUseCases.loadRepoTree(repoId: repoId, rootURL: repoURL)
let document = try await browseUseCases.openNote(repoId: repoId, rootURL: repoURL, notePath: "note.md")
```

### 编辑保存

```swift
let editUseCases = EditUseCases()
let result = try await editUseCases.saveNote(
    rootURL: repoURL,
    path: "note.md",
    content: "# Updated Content",
    expectedHash: document.contentHash
)
```

### 渲染 Markdown

```swift
let renderer = MarkdownRenderer()
let result = try await renderer.render(document: document)
// result.htmlContent, result.extractedTitle, result.imageReferences
```

## 测试

```bash
cd QingJianApp/QingJianCore
swift test
```

## 性能埋点

所有关键路径都有性能埋点：

```
📊 [repo.scan] 5.27ms ["repoId": "xxx"]
📊 [note.open] 1.38ms ["path": "note.md"]
📊 [note.save] 4.20ms ["path": "note.md"]
📊 [markdown.render] 12.34ms
```

