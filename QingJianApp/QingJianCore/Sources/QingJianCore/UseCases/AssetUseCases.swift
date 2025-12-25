//
//  AssetUseCases.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  资产管理用例（导入图片、生成引用）
//

import Foundation

/// 导入结果
public struct ImportResult: Sendable {
    public let success: Bool
    public let relativePath: String
    public let markdownReference: String
    public let fileSize: Int
    
    public init(success: Bool, relativePath: String, markdownReference: String, fileSize: Int) {
        self.success = success
        self.relativePath = relativePath
        self.markdownReference = markdownReference
        self.fileSize = fileSize
    }
}

/// 资产管理用例
public actor AssetUseCases {
    
    /// 支持的图片格式
    private let supportedImageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff", "heic"
    ]
    
    public init() {}
    
    // MARK: - Import Local Image
    
    /// 导入本地图片到 Repo
    ///
    /// - Parameters:
    ///   - sourceURL: 源文件 URL
    ///   - repoRootURL: Repo 根目录
    ///   - targetFolder: 目标文件夹（相对于 Repo 根目录）
    ///   - relativeToNotePath: 笔记路径（用于生成相对引用）
    /// - Returns: 导入结果（包含相对路径和 Markdown 引用）
    /// - Throws: `CoreError.pathNotFound`, `CoreError.imageLoadFailed`
    public func importLocalImage(
        sourceURL: URL,
        repoRootURL: URL,
        targetFolder: String = "assets",
        relativeToNotePath: String? = nil
    ) async throws -> ImportResult {
        let fileManager = FileManager.default
        
        // 验证源文件存在
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw CoreError.pathNotFound(path: sourceURL.path)
        }
        
        // 验证格式
        let ext = sourceURL.pathExtension.lowercased()
        guard supportedImageExtensions.contains(ext) else {
            throw CoreError.imageLoadFailed(path: sourceURL.path, reason: "不支持的图片格式: \(ext)")
        }
        
        // 确保目标目录存在
        let targetDir = repoRootURL.appendingPathComponent(targetFolder)
        if !fileManager.fileExists(atPath: targetDir.path) {
            try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }
        
        // 生成唯一文件名
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let targetName = generateUniqueName(
            baseName: originalName,
            extension: ext,
            in: targetDir,
            fileManager: fileManager
        )
        
        let targetURL = targetDir.appendingPathComponent(targetName)
        let relativePath = "\(targetFolder)/\(targetName)"
        
        // 复制文件
        do {
            try fileManager.copyItem(at: sourceURL, to: targetURL)
        } catch {
            throw CoreError.ioError(path: relativePath, reason: error.localizedDescription)
        }
        
        // 获取文件大小
        let attributes = try fileManager.attributesOfItem(atPath: targetURL.path)
        let fileSize = (attributes[.size] as? Int) ?? 0
        
        // 生成 Markdown 引用
        let markdownReference = generateMarkdownReferenceInternal(
            relativePath: relativePath,
            altText: originalName,
            relativeToNotePath: relativeToNotePath
        )
        
        return ImportResult(
            success: true,
            relativePath: relativePath,
            markdownReference: markdownReference,
            fileSize: fileSize
        )
    }
    
    // MARK: - Generate Markdown Reference
    
    /// 生成 Markdown 图片引用
    ///
    /// - Parameters:
    ///   - relativePath: 图片相对路径
    ///   - altText: 替代文本（可选，默认使用文件名）
    /// - Returns: Markdown 图片引用字符串
    public func generateMarkdownReference(
        relativePath: String,
        altText: String?
    ) -> String {
        let alt = altText ?? URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent
        return "![\(alt)](\(relativePath))"
    }
    
    // MARK: - Private
    
    private func generateUniqueName(
        baseName: String,
        extension ext: String,
        in directory: URL,
        fileManager: FileManager
    ) -> String {
        let fullName = "\(baseName).\(ext)"
        let targetURL = directory.appendingPathComponent(fullName)
        
        if !fileManager.fileExists(atPath: targetURL.path) {
            return fullName
        }
        
        // 添加时间戳后缀
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(baseName)_\(timestamp).\(ext)"
    }
    
    private func generateMarkdownReferenceInternal(
        relativePath: String,
        altText: String,
        relativeToNotePath: String?
    ) -> String {
        var referencePath = relativePath
        
        // 如果提供了笔记路径，计算相对路径
        if let notePath = relativeToNotePath {
            let noteDir = URL(fileURLWithPath: notePath).deletingLastPathComponent().relativePath
            // 只有当笔记不在根目录时才需要添加 ../
            if !noteDir.isEmpty && noteDir != "." {
                let noteDepth = noteDir.components(separatedBy: "/").filter { !$0.isEmpty }.count
                if noteDepth > 0 {
                    let prefix = String(repeating: "../", count: noteDepth)
                    referencePath = prefix + relativePath
                }
            }
        }
        
        return "![\(altText)](\(referencePath))"
    }
    
    // MARK: - List Assets
    
    /// 列出 Repo 中的所有图片资产
    ///
    /// - Parameters:
    ///   - repoRootURL: Repo 根目录
    ///   - folder: 资产文件夹（默认 "assets"）
    /// - Returns: 图片文件路径列表（相对路径）
    public func listAssets(repoRootURL: URL, folder: String = "assets") -> [String] {
        let fileManager = FileManager.default
        let assetsDir = repoRootURL.appendingPathComponent(folder)
        
        guard let enumerator = fileManager.enumerator(
            at: assetsDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        var assets: [String] = []
        
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if supportedImageExtensions.contains(ext) {
                // 计算相对路径
                let relativePath = fileURL.path.replacingOccurrences(
                    of: repoRootURL.path + "/",
                    with: ""
                )
                assets.append(relativePath)
            }
        }
        
        return assets.sorted()
    }
    
    // MARK: - Delete Asset
    
    /// 删除资产文件
    ///
    /// - Parameters:
    ///   - repoRootURL: Repo 根目录
    ///   - relativePath: 资产相对路径
    /// - Throws: `CoreError.pathNotFound`, `CoreError.ioError`
    public func deleteAsset(repoRootURL: URL, relativePath: String) async throws {
        let fileManager = FileManager.default
        let fileURL = repoRootURL.appendingPathComponent(relativePath)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw CoreError.pathNotFound(path: relativePath)
        }
        
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw CoreError.ioError(path: relativePath, reason: error.localizedDescription)
        }
    }
}

