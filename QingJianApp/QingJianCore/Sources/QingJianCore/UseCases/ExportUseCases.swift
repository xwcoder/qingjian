//
//  ExportUseCases.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  导出用例（导出到文件夹、单个笔记、统计）
//

import Foundation

/// 导出结果
public struct ExportResult: Sendable {
    public let success: Bool
    public let exportedFiles: Int
    public let totalBytes: Int
    public let errors: [String]
    
    public init(success: Bool, exportedFiles: Int, totalBytes: Int, errors: [String] = []) {
        self.success = success
        self.exportedFiles = exportedFiles
        self.totalBytes = totalBytes
        self.errors = errors
    }
}

/// 导出统计
public struct ExportStats: Sendable {
    public let noteCount: Int
    public let assetCount: Int
    public let totalSizeBytes: Int
    
    public init(noteCount: Int, assetCount: Int, totalSizeBytes: Int) {
        self.noteCount = noteCount
        self.assetCount = assetCount
        self.totalSizeBytes = totalSizeBytes
    }
}

/// 导出过滤器
public enum ExportFilter: Sendable {
    case all
    case markdownOnly
    case markdownAndAssets
}

/// 导出用例
public actor ExportUseCases {
    
    /// 排除的文件名
    private let excludedFiles: Set<String> = [
        ".qingjian_metadata.json",
        ".DS_Store",
        ".git",
        ".gitignore"
    ]
    
    /// 资产文件夹名
    private let assetsFolderName = "assets"
    
    public init() {}
    
    // MARK: - Export to Folder
    
    /// 导出整个 Repo 到目标文件夹
    ///
    /// - Parameters:
    ///   - repoRootURL: Repo 根目录
    ///   - targetURL: 目标文件夹
    /// - Returns: 导出结果
    public func exportToFolder(
        repoRootURL: URL,
        targetURL: URL
    ) async throws -> ExportResult {
        return try await exportFiltered(
            repoRootURL: repoRootURL,
            targetURL: targetURL,
            filter: .all
        )
    }
    
    // MARK: - Export Filtered
    
    /// 按过滤器导出
    ///
    /// - Parameters:
    ///   - repoRootURL: Repo 根目录
    ///   - targetURL: 目标文件夹
    ///   - filter: 过滤器
    /// - Returns: 导出结果
    public func exportFiltered(
        repoRootURL: URL,
        targetURL: URL,
        filter: ExportFilter
    ) async throws -> ExportResult {
        // 在同步上下文中执行文件操作
        return try exportFilteredSync(
            repoRootURL: repoRootURL,
            targetURL: targetURL,
            filter: filter
        )
    }
    
    private func exportFilteredSync(
        repoRootURL: URL,
        targetURL: URL,
        filter: ExportFilter
    ) throws -> ExportResult {
        let fileManager = FileManager.default
        
        // 创建目标目录
        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
        
        var exportedCount = 0
        var totalBytes = 0
        var errors: [String] = []
        
        // 遍历源目录
        guard let enumerator = fileManager.enumerator(
            at: repoRootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw CoreError.ioError(path: repoRootURL.path, reason: "无法读取目录")
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            let fileName = fileURL.lastPathComponent
            
            // 跳过排除的文件
            if excludedFiles.contains(fileName) {
                continue
            }
            
            // 计算相对路径
            let relativePath = fileURL.path.replacingOccurrences(
                of: repoRootURL.path + "/",
                with: ""
            )
            
            // 应用过滤器
            if !shouldIncludeSync(relativePath: relativePath, filter: filter) {
                continue
            }
            
            // 目标路径
            let targetFileURL = targetURL.appendingPathComponent(relativePath)
            let targetDir = targetFileURL.deletingLastPathComponent()
            
            do {
                // 确保目标目录存在
                try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
                
                // 复制文件
                try fileManager.copyItem(at: fileURL, to: targetFileURL)
                
                // 统计
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = (attributes[.size] as? Int) ?? 0
                totalBytes += fileSize
                exportedCount += 1
            } catch {
                errors.append("\(relativePath): \(error.localizedDescription)")
            }
        }
        
        return ExportResult(
            success: errors.isEmpty,
            exportedFiles: exportedCount,
            totalBytes: totalBytes,
            errors: errors
        )
    }
    
    // MARK: - Export Single Note
    
    /// 导出单个笔记
    ///
    /// - Parameters:
    ///   - repoRootURL: Repo 根目录
    ///   - notePath: 笔记相对路径
    ///   - targetURL: 目标文件
    /// - Returns: 导出结果
    public func exportSingleNote(
        repoRootURL: URL,
        notePath: String,
        targetURL: URL
    ) async throws -> ExportResult {
        let fileManager = FileManager.default
        let sourceURL = repoRootURL.appendingPathComponent(notePath)
        
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw CoreError.noteNotFound(path: notePath)
        }
        
        // 确保目标目录存在
        let targetDir = targetURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        // 复制文件
        try fileManager.copyItem(at: sourceURL, to: targetURL)
        
        let attributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        let fileSize = (attributes[.size] as? Int) ?? 0
        
        return ExportResult(
            success: true,
            exportedFiles: 1,
            totalBytes: fileSize
        )
    }
    
    // MARK: - Get Export Stats
    
    /// 获取导出统计信息
    ///
    /// - Parameter repoRootURL: Repo 根目录
    /// - Returns: 导出统计
    public func getExportStats(repoRootURL: URL) async throws -> ExportStats {
        return try getExportStatsSync(repoRootURL: repoRootURL)
    }
    
    private func getExportStatsSync(repoRootURL: URL) throws -> ExportStats {
        let fileManager = FileManager.default
        
        var noteCount = 0
        var assetCount = 0
        var totalSize = 0
        
        guard let enumerator = fileManager.enumerator(
            at: repoRootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw CoreError.ioError(path: repoRootURL.path, reason: "无法读取目录")
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            let fileName = fileURL.lastPathComponent
            
            if excludedFiles.contains(fileName) {
                continue
            }
            
            let ext = fileURL.pathExtension.lowercased()
            let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = (attributes?[.size] as? Int) ?? 0
            
            totalSize += fileSize
            
            if ext == "md" || ext == "markdown" {
                noteCount += 1
            } else if isAssetFileSync(fileURL) {
                assetCount += 1
            }
        }
        
        return ExportStats(
            noteCount: noteCount,
            assetCount: assetCount,
            totalSizeBytes: totalSize
        )
    }
    
    // MARK: - Private
    
    private func shouldIncludeSync(relativePath: String, filter: ExportFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .markdownOnly:
            let ext = URL(fileURLWithPath: relativePath).pathExtension.lowercased()
            return ext == "md" || ext == "markdown"
        case .markdownAndAssets:
            let ext = URL(fileURLWithPath: relativePath).pathExtension.lowercased()
            if ext == "md" || ext == "markdown" {
                return true
            }
            // 包含 assets 文件夹中的文件
            return relativePath.hasPrefix(assetsFolderName + "/")
        }
    }
    
    private func isAssetFileSync(_ url: URL) -> Bool {
        let imageExtensions: Set<String> = [
            "png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff", "heic"
        ]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}

