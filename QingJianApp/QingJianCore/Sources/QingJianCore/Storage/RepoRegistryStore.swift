//
//  RepoRegistryStore.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  仓库列表存储协议（对齐 contracts/use-cases.md）
//

import Foundation

/// 仓库列表存储协议
public protocol RepoRegistryStore: Sendable {
    /// 加载仓库列表
    func load() async throws -> RepoRegistry
    
    /// 保存仓库列表
    func save(_ registry: RepoRegistry) async throws
    
    /// 添加或更新仓库条目
    func upsert(_ entry: RepoRegistryEntry) async throws
    
    /// 移除仓库条目
    func remove(repoId: String) async throws
    
    /// 获取单个仓库条目
    func get(repoId: String) async throws -> RepoRegistryEntry?
}

