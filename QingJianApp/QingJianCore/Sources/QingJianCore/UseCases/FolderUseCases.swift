//
//  FolderUseCases.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  目录管理用例（对齐 contracts/use-cases.md: UC-Manage-01–04）
//

import Foundation

/// 目录用例
public actor FolderUseCases {
    
    /// 事件总线
    private let eventBus: CoreEventBus?
    
    public init(eventBus: CoreEventBus? = nil) {
        self.eventBus = eventBus
    }
    
    // MARK: - UC-Manage-01: Create Folder (T022)
    
    /// 创建目录
    ///
    /// - Parameters:
    ///   - repoId: 仓库 ID
    ///   - rootURL: 仓库根目录
    ///   - path: 目录相对路径
    ///   - browseUseCases: BrowseUseCases 实例（用于刷新）
    /// - Returns: 创建的目录信息
    /// - Throws: `CoreError.folderAlreadyExists`, `CoreError.permissionDenied`, `CoreError.ioError`
    public func createFolder(
        repoId: String,
        rootURL: URL,
        path: String,
        browseUseCases: BrowseUseCases? = nil
    ) async throws -> FolderInfo {
        // 验证
        let validator = RepoPathValidator(repoRootURL: rootURL)
        if let error = validator.validateFolderCreate(at: path) {
            throw error
        }
        
        let folderURL = rootURL.appendingPathComponent(path)
        
        // 创建目录
        do {
            try await PerfMetrics.shared.measure(.folderCreate, context: ["repoId": repoId, "path": path]) {
                try FileManager.default.createDirectory(
                    at: folderURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
        } catch {
            throw CoreError.ioError(path: path, reason: error.localizedDescription)
        }
        
        // 通知刷新 (T025)
        await browseUseCases?.notifyRepoChanged(repoId: repoId, affectedPaths: [path])
        
        return FolderInfo(
            path: path,
            name: folderURL.lastPathComponent,
            children: [],
            isExpanded: false
        )
    }
    
    // MARK: - UC-Manage-02: Rename Folder (T023)
    
    /// 重命名目录
    ///
    /// - Parameters:
    ///   - repoId: 仓库 ID
    ///   - rootURL: 仓库根目录
    ///   - oldPath: 原路径
    ///   - newPath: 新路径
    ///   - browseUseCases: BrowseUseCases 实例
    /// - Returns: 重命名后的目录信息
    /// - Throws: `CoreError.folderNotFound`, `CoreError.folderAlreadyExists`, `CoreError.ioError`
    public func renameFolder(
        repoId: String,
        rootURL: URL,
        oldPath: String,
        newPath: String,
        browseUseCases: BrowseUseCases? = nil
    ) async throws -> FolderInfo {
        // 验证
        let validator = RepoPathValidator(repoRootURL: rootURL)
        if let error = validator.validateFolderMove(from: oldPath, to: newPath) {
            throw error
        }
        
        let oldURL = rootURL.appendingPathComponent(oldPath)
        let newURL = rootURL.appendingPathComponent(newPath)
        
        // 确保父目录存在
        let parentURL = newURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentURL.path) {
            try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
        }
        
        // 执行重命名
        do {
            try await PerfMetrics.shared.measure(.folderRename, context: ["repoId": repoId, "oldPath": oldPath, "newPath": newPath]) {
                try FileManager.default.moveItem(at: oldURL, to: newURL)
            }
        } catch {
            throw CoreError.ioError(path: oldPath, reason: error.localizedDescription)
        }
        
        // 迁移元数据 (T023)
        let metadataStore = RepoMetadataStore(repoRootURL: rootURL)
        try? await metadataStore.migratePaths(from: oldPath, to: newPath)
        
        // 通知刷新 (T025)
        await browseUseCases?.notifyRepoChanged(repoId: repoId, affectedPaths: [oldPath, newPath])
        
        return FolderInfo(
            path: newPath,
            name: newURL.lastPathComponent,
            children: [],
            isExpanded: false
        )
    }
    
    // MARK: - UC-Manage-03: Move Folder (T023)
    
    /// 移动目录
    ///
    /// - Parameters:
    ///   - repoId: 仓库 ID
    ///   - rootURL: 仓库根目录
    ///   - folderPath: 目录路径
    ///   - newParentPath: 新父目录路径
    ///   - browseUseCases: BrowseUseCases 实例
    /// - Returns: 移动后的目录信息
    /// - Throws: `CoreError.folderNotFound`, `CoreError.invalidFolderMove`, `CoreError.ioError`
    public func moveFolder(
        repoId: String,
        rootURL: URL,
        folderPath: String,
        newParentPath: String,
        browseUseCases: BrowseUseCases? = nil
    ) async throws -> FolderInfo {
        let folderName = URL(fileURLWithPath: folderPath).lastPathComponent
        let newPath = newParentPath.isEmpty ? folderName : "\(newParentPath)/\(folderName)"
        
        // 验证
        let validator = RepoPathValidator(repoRootURL: rootURL)
        if let error = validator.validateFolderMove(from: folderPath, to: newPath) {
            throw error
        }
        
        let oldURL = rootURL.appendingPathComponent(folderPath)
        let newURL = rootURL.appendingPathComponent(newPath)
        
        // 确保目标父目录存在
        let parentURL = newURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentURL.path) {
            try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
        }
        
        // 执行移动
        do {
            try await PerfMetrics.shared.measure(.folderMove, context: ["repoId": repoId, "from": folderPath, "to": newPath]) {
                try FileManager.default.moveItem(at: oldURL, to: newURL)
            }
        } catch {
            throw CoreError.ioError(path: folderPath, reason: error.localizedDescription)
        }
        
        // 迁移元数据 (T023)
        let metadataStore = RepoMetadataStore(repoRootURL: rootURL)
        try? await metadataStore.migratePaths(from: folderPath, to: newPath)
        
        // 通知刷新 (T025)
        await browseUseCases?.notifyRepoChanged(repoId: repoId, affectedPaths: [folderPath, newPath])
        
        return FolderInfo(
            path: newPath,
            name: folderName,
            children: [],
            isExpanded: false
        )
    }
    
    // MARK: - UC-Manage-04: Delete Folder (T024)
    
    /// 删除目录
    ///
    /// - Parameters:
    ///   - repoId: 仓库 ID
    ///   - rootURL: 仓库根目录
    ///   - path: 目录路径
    ///   - force: 是否强制删除非空目录
    ///   - browseUseCases: BrowseUseCases 实例
    /// - Throws: `CoreError.folderNotFound`, `CoreError.folderNotEmpty`, `CoreError.ioError`
    public func deleteFolder(
        repoId: String,
        rootURL: URL,
        path: String,
        force: Bool,
        browseUseCases: BrowseUseCases? = nil
    ) async throws {
        // 验证
        let validator = RepoPathValidator(repoRootURL: rootURL)
        if let error = validator.validateFolderDelete(at: path, allowNonEmpty: force) {
            throw error
        }
        
        let folderURL = rootURL.appendingPathComponent(path)
        
        // 执行删除
        do {
            try await PerfMetrics.shared.measure(.folderDelete, context: ["repoId": repoId, "path": path]) {
                try FileManager.default.removeItem(at: folderURL)
            }
        } catch {
            throw CoreError.ioError(path: path, reason: error.localizedDescription)
        }
        
        // 清理元数据 (T024)
        let metadataStore = RepoMetadataStore(repoRootURL: rootURL)
        try? await metadataStore.removePathsUnder(deletedPath: path)
        
        // 通知刷新 (T025)
        await browseUseCases?.notifyRepoChanged(repoId: repoId, affectedPaths: [path])
    }
}

