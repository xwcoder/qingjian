//
//  RepoAccessGrant.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  沙盒访问授权（对齐 data-model.md: RepoAccessGrant）
//

import Foundation

/// 沙盒访问授权
public struct RepoAccessGrant: Equatable, Sendable {
    
    /// Bookmark 数据
    public let bookmarkData: Data
    
    /// 创建时间
    public let createdAt: Date
    
    /// 最近恢复时间
    public var lastResolvedAt: Date?
    
    /// 最近恢复错误
    public var lastResolveError: String?
    
    public init(
        bookmarkData: Data,
        createdAt: Date = Date(),
        lastResolvedAt: Date? = nil,
        lastResolveError: String? = nil
    ) {
        self.bookmarkData = bookmarkData
        self.createdAt = createdAt
        self.lastResolvedAt = lastResolvedAt
        self.lastResolveError = lastResolveError
    }
}

// MARK: - Bookmark Utilities

public enum BookmarkError: Error, LocalizedError {
    case creationFailed(String)
    case resolutionFailed(String)
    case stale
    
    public var errorDescription: String? {
        switch self {
        case .creationFailed(let reason):
            return "创建书签失败: \(reason)"
        case .resolutionFailed(let reason):
            return "恢复书签失败: \(reason)"
        case .stale:
            return "书签已过期"
        }
    }
}

/// Bookmark 工具
public enum BookmarkUtils {
    
    /// 创建 security-scoped bookmark
    public static func createBookmark(for url: URL) throws -> Data {
        do {
            #if os(macOS)
            return try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #else
            return try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #endif
        } catch {
            throw BookmarkError.creationFailed(error.localizedDescription)
        }
    }
    
    /// 从 bookmark 恢复 URL
    public static func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        do {
            #if os(macOS)
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            #else
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            #endif
            return (url, isStale)
        } catch {
            throw BookmarkError.resolutionFailed(error.localizedDescription)
        }
    }
    
    /// 开始访问 security-scoped 资源
    public static func startAccessing(_ url: URL) -> Bool {
        return url.startAccessingSecurityScopedResource()
    }
    
    /// 停止访问 security-scoped 资源
    public static func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

