//
//  RepoMetadataStore.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  Repo 元数据存储（自定义排序、最近笔记等）
//

import Foundation

/// Repo 元数据
public struct RepoMetadata: Codable, Equatable, Sendable {
    /// 版本号（用于迁移）
    public var version: String = "1.0"
    
    /// 目录自定义排序（path -> [childPath]）
    public var folderOrders: [String: [String]] = [:]
    
    /// 最近打开的笔记路径
    public var recentNotes: [String] = []
    
    /// 最后扫描时间
    public var lastScannedAt: Date?
    
    public init(
        version: String = "1.0",
        folderOrders: [String: [String]] = [:],
        recentNotes: [String] = [],
        lastScannedAt: Date? = nil
    ) {
        self.version = version
        self.folderOrders = folderOrders
        self.recentNotes = recentNotes
        self.lastScannedAt = lastScannedAt
    }
}

/// Repo 元数据存储
public actor RepoMetadataStore {
    
    private let repoRootURL: URL
    private let metadataFileName = ".qingjian_metadata.json"
    private var cachedMetadata: RepoMetadata?
    
    public init(repoRootURL: URL) {
        self.repoRootURL = repoRootURL
    }
    
    // MARK: - Public API
    
    /// 加载元数据
    public func load() async throws -> RepoMetadata {
        if let cached = cachedMetadata {
            return cached
        }
        
        let url = metadataFileURL
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            let metadata = RepoMetadata()
            cachedMetadata = metadata
            return metadata
        }
        
        let data = try Data(contentsOf: url)
        let metadata = try JSONDecoder().decode(RepoMetadata.self, from: data)
        cachedMetadata = metadata
        return metadata
    }
    
    /// 保存元数据
    public func save(_ metadata: RepoMetadata) async throws {
        let url = metadataFileURL
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: url, options: .atomic)
        cachedMetadata = metadata
    }
    
    /// 更新目录排序
    public func updateFolderOrder(path: String, childPaths: [String]) async throws {
        var metadata = try await load()
        metadata.folderOrders[path] = childPaths
        try await save(metadata)
    }
    
    /// 添加最近打开的笔记
    public func addRecentNote(path: String, maxCount: Int = 20) async throws {
        var metadata = try await load()
        
        // 移除已存在的
        metadata.recentNotes.removeAll { $0 == path }
        
        // 添加到开头
        metadata.recentNotes.insert(path, at: 0)
        
        // 限制数量
        if metadata.recentNotes.count > maxCount {
            metadata.recentNotes = Array(metadata.recentNotes.prefix(maxCount))
        }
        
        try await save(metadata)
    }
    
    /// 获取指定目录的子项排序
    public func getFolderOrder(path: String) async throws -> [String]? {
        let metadata = try await load()
        return metadata.folderOrders[path]
    }
    
    /// 刷新缓存
    public func invalidateCache() {
        cachedMetadata = nil
    }
    
    // MARK: - Private
    
    private var metadataFileURL: URL {
        repoRootURL.appendingPathComponent(metadataFileName)
    }
}
