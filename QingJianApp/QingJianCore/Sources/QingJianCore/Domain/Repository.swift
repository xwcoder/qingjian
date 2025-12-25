//
//  Repository.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  仓库实体（对齐 data-model.md）
//

import Foundation
import CryptoKit

/// 仓库
public struct Repository: Identifiable, Equatable, Codable, Sendable {
    
    /// 唯一标识（基于 rootURL 的 SHA256 hash）
    public let id: String
    
    /// 显示名称
    public var displayName: String
    
    /// 根目录 URL
    public let rootURL: URL
    
    /// 最后打开时间
    public var lastOpenedAt: Date?
    
    /// 是否启用 iCloud 同步
    public var iCloudEnabled: Bool
    
    public init(
        displayName: String,
        rootURL: URL,
        lastOpenedAt: Date? = nil,
        iCloudEnabled: Bool = false
    ) {
        self.id = Self.generateId(from: rootURL)
        self.displayName = displayName
        self.rootURL = rootURL
        self.lastOpenedAt = lastOpenedAt
        self.iCloudEnabled = iCloudEnabled
    }
    
    /// 生成基于 URL 的唯一 ID
    public static func generateId(from url: URL) -> String {
        let data = Data(url.standardizedFileURL.path.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }
}

/// Repo 摘要（用于列表展示）
public struct RepoSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let rootPath: String
    public let lastOpenedAt: Date?
    public let isAvailable: Bool
    public let iCloudEnabled: Bool
    
    public init(from repo: Repository, isAvailable: Bool) {
        self.id = repo.id
        self.displayName = repo.displayName
        self.rootPath = repo.rootURL.path
        self.lastOpenedAt = repo.lastOpenedAt
        self.isAvailable = isAvailable
        self.iCloudEnabled = repo.iCloudEnabled
    }
    
    public init(
        id: String,
        displayName: String,
        rootPath: String,
        lastOpenedAt: Date?,
        isAvailable: Bool,
        iCloudEnabled: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.rootPath = rootPath
        self.lastOpenedAt = lastOpenedAt
        self.isAvailable = isAvailable
        self.iCloudEnabled = iCloudEnabled
    }
}
