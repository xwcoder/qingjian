//
//  RepoMetadataMigration.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  元数据路径迁移与清理（folderOrders + recentNotes）
//

import Foundation

/// 元数据迁移辅助
public struct RepoMetadataMigration: Sendable {
    
    /// 迁移路径前缀
    /// - Parameters:
    ///   - metadata: 原元数据
    ///   - oldPrefix: 旧路径前缀
    ///   - newPrefix: 新路径前缀
    /// - Returns: 迁移后的元数据
    public static func migratePaths(
        in metadata: RepoMetadata,
        from oldPrefix: String,
        to newPrefix: String
    ) -> RepoMetadata {
        var result = metadata
        
        // 迁移 folderOrders 的 key
        var newFolderOrders: [String: [String]] = [:]
        for (key, value) in metadata.folderOrders {
            let newKey = migratePathIfNeeded(key, from: oldPrefix, to: newPrefix)
            // 迁移 value 中的路径
            let newValue = value.map { migratePathIfNeeded($0, from: oldPrefix, to: newPrefix) }
            newFolderOrders[newKey] = newValue
        }
        result.folderOrders = newFolderOrders
        
        // 迁移 recentNotes
        result.recentNotes = metadata.recentNotes.map {
            migratePathIfNeeded($0, from: oldPrefix, to: newPrefix)
        }
        
        return result
    }
    
    /// 清理不存在的路径
    /// - Parameters:
    ///   - metadata: 原元数据
    ///   - existingPaths: 当前存在的路径集合
    /// - Returns: 清理后的元数据
    public static func cleanupInvalidPaths(
        in metadata: RepoMetadata,
        existingPaths: Set<String>
    ) -> RepoMetadata {
        var result = metadata
        
        // 清理 folderOrders
        var cleanedFolderOrders: [String: [String]] = [:]
        for (key, value) in metadata.folderOrders {
            // 只保留存在的 key（目录路径）
            // 注意：根目录（空字符串）总是有效的
            if key.isEmpty || existingPaths.contains(key) {
                let cleanedValue = value.filter { existingPaths.contains($0) }
                if !cleanedValue.isEmpty || key.isEmpty {
                    cleanedFolderOrders[key] = cleanedValue
                }
            }
        }
        result.folderOrders = cleanedFolderOrders
        
        // 清理 recentNotes
        result.recentNotes = metadata.recentNotes.filter { existingPaths.contains($0) }
        
        return result
    }
    
    /// 删除指定路径及其子路径相关的元数据
    /// - Parameters:
    ///   - metadata: 原元数据
    ///   - deletedPath: 被删除的路径
    /// - Returns: 清理后的元数据
    public static func removePathsUnder(
        in metadata: RepoMetadata,
        deletedPath: String
    ) -> RepoMetadata {
        var result = metadata
        let normalizedDeleted = normalizePath(deletedPath)
        
        // 清理 folderOrders
        var cleanedFolderOrders: [String: [String]] = [:]
        for (key, value) in metadata.folderOrders {
            let normalizedKey = normalizePath(key)
            
            // 跳过被删除路径及其子路径的 key
            if normalizedKey == normalizedDeleted ||
                normalizedKey.hasPrefix(normalizedDeleted + "/") {
                continue
            }
            
            // 过滤 value 中被删除路径及其子路径
            let cleanedValue = value.filter { path in
                let normalizedPath = normalizePath(path)
                return normalizedPath != normalizedDeleted &&
                    !normalizedPath.hasPrefix(normalizedDeleted + "/")
            }
            
            cleanedFolderOrders[key] = cleanedValue
        }
        result.folderOrders = cleanedFolderOrders
        
        // 清理 recentNotes
        result.recentNotes = metadata.recentNotes.filter { path in
            let normalizedPath = normalizePath(path)
            return normalizedPath != normalizedDeleted &&
                !normalizedPath.hasPrefix(normalizedDeleted + "/")
        }
        
        return result
    }
    
    /// 从 recentNotes 中移除指定路径
    /// - Parameters:
    ///   - metadata: 原元数据
    ///   - path: 要移除的路径
    /// - Returns: 更新后的元数据
    public static func removeFromRecentNotes(
        in metadata: RepoMetadata,
        path: String
    ) -> RepoMetadata {
        var result = metadata
        result.recentNotes = metadata.recentNotes.filter { $0 != path }
        return result
    }
    
    /// 更新 recentNotes 中的路径
    /// - Parameters:
    ///   - metadata: 原元数据
    ///   - oldPath: 旧路径
    ///   - newPath: 新路径
    /// - Returns: 更新后的元数据
    public static func updateRecentNotePath(
        in metadata: RepoMetadata,
        from oldPath: String,
        to newPath: String
    ) -> RepoMetadata {
        var result = metadata
        result.recentNotes = metadata.recentNotes.map { $0 == oldPath ? newPath : $0 }
        return result
    }
    
    // MARK: - Private
    
    /// 如果路径匹配旧前缀，则替换为新前缀
    private static func migratePathIfNeeded(
        _ path: String,
        from oldPrefix: String,
        to newPrefix: String
    ) -> String {
        let normalizedPath = normalizePath(path)
        let normalizedOld = normalizePath(oldPrefix)
        let normalizedNew = normalizePath(newPrefix)
        
        // 完全匹配
        if normalizedPath == normalizedOld {
            return newPrefix
        }
        
        // 前缀匹配（子路径）
        if normalizedPath.hasPrefix(normalizedOld + "/") {
            let suffix = String(normalizedPath.dropFirst(normalizedOld.count))
            return normalizedNew + suffix
        }
        
        return path
    }
    
    /// 规范化路径
    private static func normalizePath(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

