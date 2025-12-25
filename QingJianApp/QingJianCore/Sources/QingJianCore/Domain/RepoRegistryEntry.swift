//
//  RepoRegistryEntry.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  已添加仓库列表项（对齐 data-model.md: RepoRegistryEntry）
//

import Foundation

/// 已添加仓库列表项（用于跨重启持久化）
public struct RepoRegistryEntry: Codable, Equatable, Sendable, Identifiable {
    
    /// 仓库 ID（基于 rootURL 的 hash）
    public let repoId: String
    
    /// 显示名称
    public var displayName: String
    
    /// 用于恢复访问授权的 bookmark 数据
    public var rootURLBookmark: Data?
    
    /// 路径提示（用于展示/调试，不能作为唯一访问依据）
    public var rootPathHint: String
    
    /// 最后打开时间
    public var lastOpenedAt: Date?
    
    /// 是否启用 iCloud 同步
    public var iCloudEnabled: Bool
    
    public var id: String { repoId }
    
    public init(
        repoId: String,
        displayName: String,
        rootURLBookmark: Data? = nil,
        rootPathHint: String,
        lastOpenedAt: Date? = nil,
        iCloudEnabled: Bool = false
    ) {
        self.repoId = repoId
        self.displayName = displayName
        self.rootURLBookmark = rootURLBookmark
        self.rootPathHint = rootPathHint
        self.lastOpenedAt = lastOpenedAt
        self.iCloudEnabled = iCloudEnabled
    }
    
    /// 从 Repository 构造
    public init(from repo: Repository, bookmark: Data? = nil) {
        self.repoId = repo.id
        self.displayName = repo.displayName
        self.rootURLBookmark = bookmark
        self.rootPathHint = repo.rootURL.path
        self.lastOpenedAt = repo.lastOpenedAt
        self.iCloudEnabled = repo.iCloudEnabled
    }
}

/// 仓库列表注册表（用于持久化）
public struct RepoRegistry: Codable, Equatable, Sendable {
    /// 版本号（用于迁移）
    public var version: String = "1.0"
    
    /// 已添加仓库列表
    public var entries: [RepoRegistryEntry]
    
    public init(version: String = "1.0", entries: [RepoRegistryEntry] = []) {
        self.version = version
        self.entries = entries
    }
}

