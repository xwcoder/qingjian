//
//  ImageResolver.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  图片解析器：将 Markdown 中的图片引用解析为实际可用的 URL
//

import Foundation

/// 解析后的图片
public struct ResolvedImage: Sendable, Equatable {
    /// 原始引用
    public let reference: String
    
    /// 解析后的 URL
    public let resolvedURL: URL?
    
    /// 是否为本地文件
    public let isLocal: Bool
    
    /// 解析状态
    public let status: Status
    
    /// 文件大小（字节，仅本地文件）
    public let fileSize: Int?
    
    public enum Status: Sendable, Equatable {
        case resolved
        case notFound
        case invalidReference
        case permissionDenied
    }
    
    public init(
        reference: String,
        resolvedURL: URL?,
        isLocal: Bool,
        status: Status,
        fileSize: Int? = nil
    ) {
        self.reference = reference
        self.resolvedURL = resolvedURL
        self.isLocal = isLocal
        self.status = status
        self.fileSize = fileSize
    }
}

/// 图片解析器
public actor ImageResolver {
    
    private let fileManager: FileManager
    
    /// 支持的图片格式
    private let supportedExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff", "heic"
    ]
    
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    // MARK: - Public API
    
    /// 解析图片引用
    ///
    /// - Parameters:
    ///   - reference: 图片引用（相对路径或 URL）
    ///   - repoRootURL: Repo 根目录
    ///   - notePath: 当前笔记的相对路径（用于解析相对路径）
    /// - Returns: 解析后的图片信息
    public func resolve(
        reference: String,
        repoRootURL: URL,
        notePath: String
    ) -> ResolvedImage {
        let trimmed = reference.trimmingCharacters(in: .whitespaces)
        
        // 检查是否为 URL
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return resolveRemote(reference: trimmed)
        }
        
        // 本地路径
        return resolveLocal(
            reference: trimmed,
            repoRootURL: repoRootURL,
            notePath: notePath
        )
    }
    
    /// 批量解析图片引用
    public func resolveAll(
        references: [ImageReference],
        repoRootURL: URL,
        notePath: String
    ) -> [ResolvedImage] {
        references.map { ref in
            resolve(
                reference: ref.source,
                repoRootURL: repoRootURL,
                notePath: notePath
            )
        }
    }
    
    /// 获取 Repo 中所有图片资源
    public func scanAssets(repoRootURL: URL, assetsFolder: String = "assets") -> [URL] {
        let assetsURL = repoRootURL.appendingPathComponent(assetsFolder)
        
        guard let enumerator = fileManager.enumerator(
            at: assetsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        var images: [URL] = []
        
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                images.append(fileURL)
            }
        }
        
        return images
    }
    
    // MARK: - Private
    
    private func resolveRemote(reference: String) -> ResolvedImage {
        guard let url = URL(string: reference) else {
            return ResolvedImage(
                reference: reference,
                resolvedURL: nil,
                isLocal: false,
                status: .invalidReference
            )
        }
        
        return ResolvedImage(
            reference: reference,
            resolvedURL: url,
            isLocal: false,
            status: .resolved
        )
    }
    
    private func resolveLocal(
        reference: String,
        repoRootURL: URL,
        notePath: String
    ) -> ResolvedImage {
        // 获取笔记所在目录
        let noteURL = repoRootURL.appendingPathComponent(notePath)
        let noteDir = noteURL.deletingLastPathComponent()
        
        // 解析相对路径
        var resolvedURL: URL
        
        if reference.hasPrefix("/") {
            // 绝对路径（相对于 Repo 根目录）
            resolvedURL = repoRootURL.appendingPathComponent(String(reference.dropFirst()))
        } else {
            // 相对路径（相对于笔记所在目录）
            resolvedURL = noteDir.appendingPathComponent(reference)
        }
        
        // 标准化路径
        resolvedURL = resolvedURL.standardizedFileURL
        
        // 检查文件是否存在
        guard fileManager.fileExists(atPath: resolvedURL.path) else {
            return ResolvedImage(
                reference: reference,
                resolvedURL: nil,
                isLocal: true,
                status: .notFound
            )
        }
        
        // 检查是否可读
        guard fileManager.isReadableFile(atPath: resolvedURL.path) else {
            return ResolvedImage(
                reference: reference,
                resolvedURL: resolvedURL,
                isLocal: true,
                status: .permissionDenied
            )
        }
        
        // 获取文件大小
        let attributes = try? fileManager.attributesOfItem(atPath: resolvedURL.path)
        let fileSize = attributes?[.size] as? Int
        
        return ResolvedImage(
            reference: reference,
            resolvedURL: resolvedURL,
            isLocal: true,
            status: .resolved,
            fileSize: fileSize
        )
    }
}

