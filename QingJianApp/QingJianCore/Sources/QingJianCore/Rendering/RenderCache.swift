//
//  RenderCache.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  渲染结果缓存（基于 mtime + 内容 hash）
//

import Foundation

/// 缓存条目
public struct RenderCacheEntry: Sendable {
    public let document: RenderedDocument
    public let createdAt: Date
    public let modificationDate: Date
    public let contentHash: Int
    
    public init(
        document: RenderedDocument,
        createdAt: Date = Date(),
        modificationDate: Date,
        contentHash: Int
    ) {
        self.document = document
        self.createdAt = createdAt
        self.modificationDate = modificationDate
        self.contentHash = contentHash
    }
}

/// 渲染缓存（基于 mtime + 内容 hash）
public actor RenderCache {
    
    /// 缓存存储
    private var cache: [String: RenderCacheEntry] = [:]
    
    /// 缓存配置
    private let maxEntries: Int
    private let maxAge: TimeInterval
    
    /// 统计
    private var hits: Int = 0
    private var misses: Int = 0
    
    public init(maxEntries: Int = 100, maxAge: TimeInterval = 3600) {
        self.maxEntries = maxEntries
        self.maxAge = maxAge
    }
    
    // MARK: - Public API
    
    /// 获取缓存的渲染结果
    ///
    /// - Parameters:
    ///   - path: 笔记相对路径
    ///   - modificationDate: 文件修改时间
    ///   - contentHash: 内容 hash
    /// - Returns: 缓存的渲染结果（如果有效）
    public func get(path: String, modificationDate: Date, contentHash: Int) -> RenderedDocument? {
        guard let entry = cache[path] else {
            misses += 1
            return nil
        }
        
        // 检查有效性
        let isValid = entry.modificationDate >= modificationDate
                   && entry.contentHash == contentHash
                   && Date().timeIntervalSince(entry.createdAt) < maxAge
        
        if isValid {
            hits += 1
            return entry.document
        } else {
            misses += 1
            cache.removeValue(forKey: path)
            return nil
        }
    }
    
    /// 存储渲染结果
    ///
    /// - Parameters:
    ///   - document: 渲染后的文档
    ///   - path: 笔记相对路径
    ///   - modificationDate: 文件修改时间
    ///   - contentHash: 内容 hash
    public func set(
        _ document: RenderedDocument,
        path: String,
        modificationDate: Date,
        contentHash: Int
    ) {
        // 容量检查
        if cache.count >= maxEntries {
            evictOldest()
        }
        
        let entry = RenderCacheEntry(
            document: document,
            modificationDate: modificationDate,
            contentHash: contentHash
        )
        
        cache[path] = entry
    }
    
    /// 使指定路径的缓存失效
    public func invalidate(path: String) {
        cache.removeValue(forKey: path)
    }
    
    /// 使指定 Repo 下所有缓存失效
    public func invalidate(repoPrefix: String) {
        let keysToRemove = cache.keys.filter { $0.hasPrefix(repoPrefix) }
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }
    
    /// 清空所有缓存
    public func clear() {
        cache.removeAll()
        hits = 0
        misses = 0
    }
    
    /// 获取缓存统计
    public func stats() -> (hits: Int, misses: Int, count: Int, hitRate: Double) {
        let total = hits + misses
        let hitRate = total > 0 ? Double(hits) / Double(total) : 0
        return (hits, misses, cache.count, hitRate)
    }
    
    // MARK: - Private
    
    /// 淘汰最旧的条目
    private func evictOldest() {
        guard let oldest = cache.min(by: { $0.value.createdAt < $1.value.createdAt }) else {
            return
        }
        cache.removeValue(forKey: oldest.key)
    }
}

