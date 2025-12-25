//
//  RepoUseCases.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  Repo 管理用例（对齐 contracts/use-cases.md: UC-Repo-*）
//

import Foundation

/// Repo 管理用例
public actor RepoUseCases {
    
    /// 已添加的 Repo 列表（内存）
    private var repos: [String: Repository] = [:]
    
    /// 可用性状态
    private var availabilityStates: [String: RepoAvailabilityState] = [:]
    
    /// 仓库列表持久化存储
    private let registryStore: (any RepoRegistryStore)?
    
    /// 事件总线
    private let eventBus: CoreEventBus?
    
    /// 性能埋点
    private let perfMetrics: PerfMetrics
    
    public init(
        eventBus: CoreEventBus? = nil,
        registryStore: (any RepoRegistryStore)? = nil,
        perfMetrics: PerfMetrics = .shared
    ) {
        self.eventBus = eventBus
        self.registryStore = registryStore
        self.perfMetrics = perfMetrics
    }
    
    // MARK: - Initialization (T010)
    
    /// 从持久化存储加载已添加仓库列表
    public func loadFromRegistry() async throws {
        let startTime = perfMetrics.startTimer()
        defer { perfMetrics.endTimer(startTime, metric: .repoListLoad) }
        
        guard let store = registryStore else { return }
        
        let registry = try await store.load()
        
        for entry in registry.entries {
            // 尝试从 bookmark 恢复 URL
            var rootURL: URL?
            var isAvailable = false
            
            if let bookmarkData = entry.rootURLBookmark {
                do {
                    let (url, isStale) = try BookmarkUtils.resolveBookmark(bookmarkData)
                    rootURL = url
                    
                    // 如果 bookmark 过期，尝试更新
                    if isStale {
                        // 仍然可用，但标记需要更新
                        isAvailable = RepoAvailability.checkAvailability(at: url) == .available
                    } else {
                        isAvailable = RepoAvailability.checkAvailability(at: url) == .available
                    }
                } catch {
                    // bookmark 恢复失败，使用 pathHint 作为降级
                    rootURL = URL(fileURLWithPath: entry.rootPathHint)
                    isAvailable = false
                }
            } else {
                // 无 bookmark，直接使用 pathHint
                rootURL = URL(fileURLWithPath: entry.rootPathHint)
                isAvailable = RepoAvailability.checkAvailability(at: rootURL!) == .available
            }
            
            guard let url = rootURL else { continue }
            
            let repo = Repository(
                displayName: entry.displayName,
                rootURL: url,
                lastOpenedAt: entry.lastOpenedAt,
                iCloudEnabled: entry.iCloudEnabled
            )
            
            repos[repo.id] = repo
            availabilityStates[repo.id] = isAvailable ? .available : .unavailable(reason: "路径不可访问")
        }
    }
    
    // MARK: - UC-Repo-00: Create Repo（新建仓库）(T011, T012)
    
    /// 新建仓库（确保元信息存在，加入列表）
    ///
    /// - Parameters:
    ///   - rootURL: Repo 根目录 URL
    ///   - displayName: 显示名称（可选，默认使用目录名）
    /// - Returns: Repo 摘要
    /// - Throws: `CoreError.invalidRepo`, `CoreError.permissionDenied`, `CoreError.alreadyAdded`
    public func createRepo(rootURL: URL, displayName: String? = nil) async throws -> RepoSummary {
        let startTime = perfMetrics.startTimer()
        defer { perfMetrics.endTimer(startTime, metric: .repoCreate, context: ["path": rootURL.lastPathComponent]) }
        
        // 检查路径可用性
        let availability = RepoAvailability.checkAvailability(at: rootURL)
        guard case .available = availability else {
            if case .unavailable(let reason) = availability {
                throw CoreError.invalidRepo(path: rootURL.path + (reason.map { " - \($0)" } ?? ""))
            }
            throw CoreError.invalidRepo(path: rootURL.path)
        }
        
        // 检查是否已添加（幂等：已添加则返回已有条目）
        let normalizedPath = rootURL.standardizedFileURL.path
        if let existing = repos.values.first(where: { $0.rootURL.standardizedFileURL.path == normalizedPath }) {
            return RepoSummary(from: existing, isAvailable: availabilityStates[existing.id] == .available)
        }
        
        // 确保元信息文件存在（核心区别：createRepo 会创建元信息）
        let metadataStore = RepoMetadataStore(repoRootURL: rootURL)
        try await metadataStore.ensureExists()
        
        // 创建 Repo
        let name = displayName ?? rootURL.lastPathComponent
        let repo = Repository(
            displayName: name,
            rootURL: rootURL,
            lastOpenedAt: Date()
        )
        
        repos[repo.id] = repo
        availabilityStates[repo.id] = .available
        
        // 持久化到 registry
        try await persistToRegistry(repo: repo, rootURL: rootURL)
        
        // 发出事件
        eventBus?.emit(.repoAdded(repoId: repo.id))
        
        return RepoSummary(from: repo, isAvailable: true)
    }
    
    // MARK: - UC-Repo-01: Open Repo（打开已有仓库）(T011, T013)
    
    /// 打开已有仓库（必须含有效元信息，加入列表）
    ///
    /// - Parameters:
    ///   - rootURL: Repo 根目录 URL
    ///   - displayName: 显示名称（可选，默认使用目录名）
    /// - Returns: Repo 摘要
    /// - Throws: `CoreError.invalidRepo`, `CoreError.permissionDenied`, `CoreError.alreadyAdded`
    public func openRepo(rootURL: URL, displayName: String? = nil) async throws -> RepoSummary {
        let startTime = perfMetrics.startTimer()
        defer { perfMetrics.endTimer(startTime, metric: .repoOpen, context: ["path": rootURL.lastPathComponent]) }
        
        // 检查路径可用性
        let availability = RepoAvailability.checkAvailability(at: rootURL)
        guard case .available = availability else {
            if case .unavailable(let reason) = availability {
                throw CoreError.invalidRepo(path: rootURL.path + (reason.map { " - \($0)" } ?? ""))
            }
            throw CoreError.invalidRepo(path: rootURL.path)
        }
        
        // 校验元信息文件（核心区别：openRepo 要求元信息必须存在且有效）
        if let validationError = RepoMetadataStore.validateMetadata(at: rootURL) {
            throw CoreError.invalidRepo(path: "\(rootURL.path) - \(validationError)")
        }
        
        // 检查是否已添加（幂等：已添加则返回已有条目）
        let normalizedPath = rootURL.standardizedFileURL.path
        if let existing = repos.values.first(where: { $0.rootURL.standardizedFileURL.path == normalizedPath }) {
            return RepoSummary(from: existing, isAvailable: availabilityStates[existing.id] == .available)
        }
        
        // 创建 Repo
        let name = displayName ?? rootURL.lastPathComponent
        let repo = Repository(
            displayName: name,
            rootURL: rootURL,
            lastOpenedAt: Date()
        )
        
        repos[repo.id] = repo
        availabilityStates[repo.id] = .available
        
        // 持久化到 registry
        try await persistToRegistry(repo: repo, rootURL: rootURL)
        
        // 发出事件
        eventBus?.emit(.repoAdded(repoId: repo.id))
        
        return RepoSummary(from: repo, isAvailable: true)
    }
    
    // MARK: - UC-Repo-04: Validate Repo Metadata（校验仓库元信息）
    
    /// 校验仓库元信息（仅校验，不产生副作用）
    ///
    /// - Parameter rootURL: Repo 根目录 URL
    /// - Throws: `CoreError.invalidRepo`, `CoreError.permissionDenied`
    public func validateRepoMetadata(rootURL: URL) throws {
        // 检查路径可用性
        let availability = RepoAvailability.checkAvailability(at: rootURL)
        guard case .available = availability else {
            if case .unavailable(let reason) = availability {
                throw CoreError.invalidRepo(path: rootURL.path + (reason.map { " - \($0)" } ?? ""))
            }
            throw CoreError.invalidRepo(path: rootURL.path)
        }
        
        // 校验元信息文件
        if let validationError = RepoMetadataStore.validateMetadata(at: rootURL) {
            throw CoreError.invalidRepo(path: "\(rootURL.path) - \(validationError)")
        }
    }
    
    // MARK: - UC-Repo-01: Add Repo（兼容入口，默认走 createRepo）
    
    /// 添加 Repo（兼容入口，默认走 createRepo 语义）
    ///
    /// - Parameters:
    ///   - rootURL: Repo 根目录 URL
    ///   - displayName: 显示名称（可选，默认使用目录名）
    /// - Returns: Repo 摘要
    /// - Throws: `CoreError.invalidRepo`, `CoreError.permissionDenied`, `CoreError.alreadyAdded`
    public func addRepo(rootURL: URL, displayName: String? = nil) async throws -> RepoSummary {
        return try await createRepo(rootURL: rootURL, displayName: displayName)
    }
    
    // MARK: - UC-Repo-02: Remove Repo (T015)
    
    /// 移除 Repo（仅移除引用，不删除磁盘文件）
    ///
    /// - Parameter id: Repo ID
    /// - Throws: `CoreError.repoNotFound`
    public func removeRepo(id: String) async throws {
        guard repos.removeValue(forKey: id) != nil else {
            throw CoreError.repoNotFound(id: id)
        }
        
        availabilityStates.removeValue(forKey: id)
        
        // 从 registry 移除
        try await registryStore?.remove(repoId: id)
        
        // 发出事件
        eventBus?.emit(.repoRemoved(repoId: id))
    }
    
    // MARK: - UC-Repo-03: List Repos (T014)
    
    /// 获取 Repo 列表
    ///
    /// - Returns: Repo 摘要列表（按最近打开时间排序）
    public func listRepos() -> [RepoSummary] {
        repos.values
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .map { RepoSummary(from: $0, isAvailable: availabilityStates[$0.id] == .available) }
    }
    
    // MARK: - Get Repo
    
    /// 获取单个 Repo
    ///
    /// - Parameter id: Repo ID
    /// - Returns: Repo（如果存在）
    public func getRepo(id: String) -> Repository? {
        repos[id]
    }
    
    /// 更新 Repo 的最近打开时间
    public func updateLastOpened(id: String) async {
        repos[id]?.lastOpenedAt = Date()
        
        // 同步更新 registry
        if let repo = repos[id] {
            try? await registryStore?.upsert(RepoRegistryEntry(from: repo))
        }
    }
    
    // MARK: - Availability
    
    /// 检查并更新 Repo 可用性
    public func checkAvailability(id: String) -> RepoAvailabilityState {
        guard let repo = repos[id] else {
            return .unavailable(reason: "Repo 不存在")
        }
        
        let state = RepoAvailability.checkAvailability(at: repo.rootURL)
        availabilityStates[id] = state
        return state
    }
    
    /// 获取 Repo 可用性状态
    public func getAvailabilityState(id: String) -> RepoAvailabilityState? {
        availabilityStates[id]
    }
    
    // MARK: - Relink Repo（重新定位仓库）(T037)
    
    /// 重新定位仓库（更新路径与授权）
    ///
    /// - Parameters:
    ///   - id: Repo ID
    ///   - newRootURL: 新的根目录 URL
    /// - Throws: `CoreError.repoNotFound`, `CoreError.invalidRepo`
    public func relinkRepo(id: String, newRootURL: URL) async throws {
        guard var repo = repos[id] else {
            throw CoreError.repoNotFound(id: id)
        }
        
        // 检查新路径可用性
        let availability = RepoAvailability.checkAvailability(at: newRootURL)
        guard case .available = availability else {
            if case .unavailable(let reason) = availability {
                throw CoreError.invalidRepo(path: newRootURL.path + (reason.map { " - \($0)" } ?? ""))
            }
            throw CoreError.invalidRepo(path: newRootURL.path)
        }
        
        // 校验元信息文件
        if let validationError = RepoMetadataStore.validateMetadata(at: newRootURL) {
            throw CoreError.invalidRepo(path: "\(newRootURL.path) - \(validationError)")
        }
        
        // 验证 repoId 一致性（路径 hash 应该匹配）
        let expectedId = Repository.generateId(from: newRootURL)
        guard expectedId == id else {
            throw CoreError.invalidRepo(path: "\(newRootURL.path) - 仓库标识不匹配，请选择正确的仓库目录")
        }
        
        // 更新内存状态
        repo = Repository(
            displayName: repo.displayName,
            rootURL: newRootURL,
            lastOpenedAt: Date(),
            iCloudEnabled: repo.iCloudEnabled
        )
        repos[id] = repo
        availabilityStates[id] = .available
        
        // 更新 registry
        try await persistToRegistry(repo: repo, rootURL: newRootURL)
        
        // 发送事件 (T038)
        eventBus?.emit(.repoAvailabilityChanged(repoId: id, state: .available))
    }
    
    // MARK: - Private Helpers
    
    /// 持久化 Repo 到 registry
    private func persistToRegistry(repo: Repository, rootURL: URL) async throws {
        guard let store = registryStore else { return }
        
        // 创建 bookmark
        var bookmark: Data? = nil
        do {
            bookmark = try BookmarkUtils.createBookmark(for: rootURL)
        } catch {
            // bookmark 创建失败不阻塞添加，但记录警告
            #if DEBUG
            print("⚠️ 创建 bookmark 失败: \(error.localizedDescription)")
            #endif
        }
        
        let entry = RepoRegistryEntry(from: repo, bookmark: bookmark)
        try await store.upsert(entry)
    }
}
