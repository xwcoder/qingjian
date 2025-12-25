//
//  JSONRepoRegistryStore.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  JSON 文件实现的仓库列表存储
//

import Foundation

/// JSON 文件实现的仓库列表存储
public actor JSONRepoRegistryStore: RepoRegistryStore {
    
    /// 存储文件 URL
    private let fileURL: URL
    
    /// 缓存
    private var cachedRegistry: RepoRegistry?
    
    /// JSON 编码器
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    
    /// JSON 解码器
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    /// 初始化
    /// - Parameter fileURL: 存储文件路径，通常为 App Support 目录下的 `repo_registry.json`
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    /// 便捷初始化：使用默认路径（App Support/QingJian/repo_registry.json）
    public static func defaultStore() throws -> JSONRepoRegistryStore {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let qingjianDir = appSupport.appendingPathComponent("QingJian", isDirectory: true)
        try FileManager.default.createDirectory(at: qingjianDir, withIntermediateDirectories: true)
        let fileURL = qingjianDir.appendingPathComponent("repo_registry.json")
        return JSONRepoRegistryStore(fileURL: fileURL)
    }
    
    // MARK: - RepoRegistryStore
    
    public func load() async throws -> RepoRegistry {
        if let cached = cachedRegistry {
            return cached
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let registry = RepoRegistry()
            cachedRegistry = registry
            return registry
        }
        
        let data = try Data(contentsOf: fileURL)
        let registry = try decoder.decode(RepoRegistry.self, from: data)
        cachedRegistry = registry
        return registry
    }
    
    public func save(_ registry: RepoRegistry) async throws {
        let data = try encoder.encode(registry)
        
        // 确保目录存在
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        try data.write(to: fileURL, options: .atomic)
        cachedRegistry = registry
    }
    
    public func upsert(_ entry: RepoRegistryEntry) async throws {
        var registry = try await load()
        
        if let index = registry.entries.firstIndex(where: { $0.repoId == entry.repoId }) {
            registry.entries[index] = entry
        } else {
            registry.entries.append(entry)
        }
        
        try await save(registry)
    }
    
    public func remove(repoId: String) async throws {
        var registry = try await load()
        registry.entries.removeAll { $0.repoId == repoId }
        try await save(registry)
    }
    
    public func get(repoId: String) async throws -> RepoRegistryEntry? {
        let registry = try await load()
        return registry.entries.first { $0.repoId == repoId }
    }
    
    // MARK: - Internal
    
    /// 清除缓存（用于测试）
    public func invalidateCache() {
        cachedRegistry = nil
    }
}

