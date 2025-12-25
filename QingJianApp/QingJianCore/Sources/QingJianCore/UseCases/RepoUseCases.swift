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
    
    /// 已添加的 Repo 列表
    private var repos: [String: Repository] = [:]
    
    /// 可用性状态
    private var availabilityStates: [String: RepoAvailabilityState] = [:]
    
    /// 事件总线
    private let eventBus: CoreEventBus?
    
    public init(eventBus: CoreEventBus? = nil) {
        self.eventBus = eventBus
    }
    
    // MARK: - UC-Repo-01: Add Repo
    
    /// 添加 Repo
    ///
    /// - Parameters:
    ///   - rootURL: Repo 根目录 URL
    ///   - displayName: 显示名称（可选，默认使用目录名）
    /// - Returns: Repo 摘要
    /// - Throws: `CoreError.invalidRepo`, `CoreError.permissionDenied`, `CoreError.alreadyAdded`
    public func addRepo(rootURL: URL, displayName: String? = nil) throws -> RepoSummary {
        // 检查路径可用性
        let availability = RepoAvailability.checkAvailability(at: rootURL)
        guard case .available = availability else {
            if case .unavailable(let reason) = availability {
                throw CoreError.invalidRepo(path: rootURL.path + (reason.map { " - \($0)" } ?? ""))
            }
            throw CoreError.invalidRepo(path: rootURL.path)
        }
        
        // 检查是否已添加
        let normalizedPath = rootURL.standardizedFileURL.path
        if repos.values.contains(where: { $0.rootURL.standardizedFileURL.path == normalizedPath }) {
            throw CoreError.alreadyAdded(id: normalizedPath)
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
        
        // 发出事件
        eventBus?.emit(.repoAdded(repoId: repo.id))
        
        return RepoSummary(from: repo, isAvailable: true)
    }
    
    // MARK: - UC-Repo-02: Remove Repo
    
    /// 移除 Repo（仅移除引用，不删除磁盘文件）
    ///
    /// - Parameter id: Repo ID
    /// - Throws: `CoreError.repoNotFound`
    public func removeRepo(id: String) throws {
        guard repos.removeValue(forKey: id) != nil else {
            throw CoreError.repoNotFound(id: id)
        }
        
        availabilityStates.removeValue(forKey: id)
        
        // 发出事件
        eventBus?.emit(.repoRemoved(repoId: id))
    }
    
    // MARK: - UC-Repo-03: List Repos
    
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
    public func updateLastOpened(id: String) {
        repos[id]?.lastOpenedAt = Date()
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
}

