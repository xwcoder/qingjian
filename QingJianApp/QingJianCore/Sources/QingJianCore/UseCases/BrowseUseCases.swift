//
//  BrowseUseCases.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  浏览用例（对齐 contracts/use-cases.md: UC-Browse-*）
//

import Foundation

/// 浏览用例
public actor BrowseUseCases {
    
    /// 缓存的目录树快照
    private var treeCache: [String: RepoTreeSnapshot] = [:]
    
    /// 事件总线
    private let eventBus: CoreEventBus?
    
    public init(eventBus: CoreEventBus? = nil) {
        self.eventBus = eventBus
    }
    
    // MARK: - UC-Browse-01: Load Repo Tree
    
    /// 加载 Repo 目录树
    ///
    /// - Parameters:
    ///   - repoId: Repo ID
    ///   - rootURL: Repo 根目录 URL
    ///   - forceRefresh: 是否强制刷新（忽略缓存）
    /// - Returns: 目录树快照
    /// - Throws: `CoreError.repoUnavailable`, `CoreError.permissionDenied`
    public func loadRepoTree(repoId: String, rootURL: URL, forceRefresh: Bool = false) async throws -> RepoTreeSnapshot {
        // 检查可用性
        let availability = RepoAvailability.checkAvailability(at: rootURL)
        guard case .available = availability else {
            if case .unavailable(let reason) = availability {
                throw CoreError.repoUnavailable(id: repoId, reason: reason)
            }
            throw CoreError.repoUnavailable(id: repoId, reason: nil)
        }
        
        // 检查缓存
        if !forceRefresh, let cached = treeCache[repoId] {
            return cached
        }
        
        // 扫描目录
        let metadataStore = RepoMetadataStore(repoRootURL: rootURL)
        let scanner = RepoScanner(repoId: repoId, repoRootURL: rootURL, metadataStore: metadataStore)
        
        let snapshot = try await PerfMetrics.shared.measure(.repoScan, context: ["repoId": repoId]) {
            try await scanner.scan()
        }
        
        // 缓存结果
        treeCache[repoId] = snapshot
        
        return snapshot
    }
    
    /// 刷新指定路径（增量更新）
    public func refreshPath(repoId: String, rootURL: URL, path: String) async throws -> [TreeNode] {
        let metadataStore = RepoMetadataStore(repoRootURL: rootURL)
        let scanner = RepoScanner(repoId: repoId, repoRootURL: rootURL, metadataStore: metadataStore)
        
        let nodes = try await scanner.updatePath(path)
        
        // 更新缓存中的对应路径（简化处理：清除缓存）
        treeCache.removeValue(forKey: repoId)
        
        return nodes
    }
    
    // MARK: - UC-Browse-02: Open Note (T014)
    
    /// 打开笔记
    ///
    /// - Parameters:
    ///   - repoId: Repo ID
    ///   - rootURL: Repo 根目录 URL
    ///   - notePath: 笔记相对路径
    /// - Returns: 笔记文档
    /// - Throws: `CoreError.noteNotFound`, `CoreError.permissionDenied`, `CoreError.corruptedFile`
    public func openNote(repoId: String, rootURL: URL, notePath: String) async throws -> NoteDocument {
        let noteStore = NoteStore(repoRootURL: rootURL)
        
        let document = try await PerfMetrics.shared.measure(.noteOpen, context: ["repoId": repoId, "path": notePath]) {
            try await noteStore.read(path: notePath)
        }
        
        // 更新最近打开列表
        let metadataStore = RepoMetadataStore(repoRootURL: rootURL)
        try? await metadataStore.addRecentNote(path: notePath)
        
        // 发出 noteOpened 事件 (T014)
        emitNoteOpened(repoId: repoId, path: notePath)
        
        return document
    }
    
    // MARK: - Cache Management
    
    /// 清除目录树缓存
    public func invalidateTreeCache(repoId: String? = nil) {
        if let repoId {
            treeCache.removeValue(forKey: repoId)
        } else {
            treeCache.removeAll()
        }
    }
    
    /// 获取缓存的目录树
    public func getCachedTree(repoId: String) -> RepoTreeSnapshot? {
        treeCache[repoId]
    }
    
    // MARK: - Refresh Strategy (T009)
    
    /// 通知仓库内容变化（写入操作后调用）
    ///
    /// 统一的"写入后刷新"策略：
    /// 1. 清除对应仓库的目录树缓存
    /// 2. 发出 `repoChanged` 事件通知订阅者
    ///
    /// - Parameters:
    ///   - repoId: 仓库 ID
    ///   - affectedPaths: 受影响的路径列表
    public func notifyRepoChanged(repoId: String, affectedPaths: [String]) {
        // 清除缓存
        invalidateTreeCache(repoId: repoId)
        
        // 发出事件
        eventBus?.emit(.repoChanged(repoId: repoId, affectedPaths: affectedPaths))
    }
    
    /// 发出笔记已打开事件
    public func emitNoteOpened(repoId: String, path: String) {
        eventBus?.emit(.noteOpened(repoId: repoId, path: path))
    }
    
    /// 发出笔记已保存事件
    public func emitNoteSaved(repoId: String, path: String) {
        eventBus?.emit(.noteSaved(repoId: repoId, path: path))
    }
}

