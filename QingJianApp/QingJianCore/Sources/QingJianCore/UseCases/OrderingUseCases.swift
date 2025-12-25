//
//  OrderingUseCases.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  排序用例（拖拽排序持久化、外部变更合并）
//

import Foundation

/// 排序用例
public actor OrderingUseCases {
    
    public init() {}
    
    // MARK: - Reorder Items
    
    /// 重新排序目录内的项目
    ///
    /// - Parameters:
    ///   - repoRootURL: Repo 根目录
    ///   - folderPath: 目录相对路径（空字符串表示根目录）
    ///   - newOrder: 新的顺序（相对路径列表）
    public func reorderItems(
        repoRootURL: URL,
        folderPath: String,
        newOrder: [String]
    ) async throws {
        let metadataStore = RepoMetadataStore(repoRootURL: repoRootURL)
        try await metadataStore.updateFolderOrder(path: folderPath, childPaths: newOrder)
    }
    
    // MARK: - Move Item
    
    /// 移动单个项目到指定位置
    ///
    /// - Parameters:
    ///   - repoRootURL: Repo 根目录
    ///   - folderPath: 目录相对路径
    ///   - itemPath: 要移动的项目路径
    ///   - toIndex: 目标位置索引
    public func moveItem(
        repoRootURL: URL,
        folderPath: String,
        itemPath: String,
        toIndex: Int
    ) async throws {
        let metadataStore = RepoMetadataStore(repoRootURL: repoRootURL)
        let metadata = try await metadataStore.load()
        
        var order = metadata.folderOrders[folderPath] ?? []
        
        // 移除原位置
        order.removeAll { $0 == itemPath }
        
        // 插入新位置
        let safeIndex = min(toIndex, order.count)
        order.insert(itemPath, at: safeIndex)
        
        try await metadataStore.updateFolderOrder(path: folderPath, childPaths: order)
    }
    
    // MARK: - Merge with File System
    
    /// 将现有排序与文件系统状态合并
    ///
    /// 规则：
    /// - 保持已存在项目的相对顺序
    /// - 删除不再存在的项目
    /// - 新项目追加到末尾
    ///
    /// - Parameters:
    ///   - existingOrder: 现有排序
    ///   - currentFiles: 当前文件系统中的文件列表
    /// - Returns: 合并后的排序
    public func mergeWithFileSystem(
        existingOrder: [String],
        currentFiles: [String]
    ) -> [String] {
        let currentSet = Set(currentFiles)
        
        // 保留存在的项目，保持顺序
        var merged = existingOrder.filter { currentSet.contains($0) }
        
        // 添加新项目
        let existingSet = Set(existingOrder)
        let newItems = currentFiles.filter { !existingSet.contains($0) }
        merged.append(contentsOf: newItems)
        
        return merged
    }
    
    // MARK: - Sync Order with File System
    
    /// 同步排序与文件系统
    ///
    /// - Parameters:
    ///   - repoRootURL: Repo 根目录
    ///   - folderPath: 目录相对路径
    public func syncOrderWithFileSystem(
        repoRootURL: URL,
        folderPath: String
    ) async throws {
        let fileManager = FileManager.default
        let folderURL = folderPath.isEmpty ? repoRootURL : repoRootURL.appendingPathComponent(folderPath)
        
        // 获取当前文件
        let contents = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        
        let currentFiles = contents.map { url -> String in
            let name = url.lastPathComponent
            return folderPath.isEmpty ? name : "\(folderPath)/\(name)"
        }
        
        // 加载现有排序
        let metadataStore = RepoMetadataStore(repoRootURL: repoRootURL)
        let metadata = try await metadataStore.load()
        let existingOrder = metadata.folderOrders[folderPath] ?? []
        
        // 合并
        let merged = mergeWithFileSystem(existingOrder: existingOrder, currentFiles: currentFiles)
        
        // 保存
        if merged != existingOrder {
            try await metadataStore.updateFolderOrder(path: folderPath, childPaths: merged)
        }
    }
    
    // MARK: - Get Order
    
    /// 获取目录的排序
    ///
    /// - Parameters:
    ///   - repoRootURL: Repo 根目录
    ///   - folderPath: 目录相对路径
    /// - Returns: 排序后的路径列表
    public func getOrder(repoRootURL: URL, folderPath: String) async throws -> [String] {
        let metadataStore = RepoMetadataStore(repoRootURL: repoRootURL)
        let metadata = try await metadataStore.load()
        return metadata.folderOrders[folderPath] ?? []
    }
}

