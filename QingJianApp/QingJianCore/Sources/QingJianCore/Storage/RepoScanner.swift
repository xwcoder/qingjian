//
//  RepoScanner.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  Repo 目录扫描器
//

import Foundation

/// Repo 目录扫描器
public actor RepoScanner {
    
    private let repoId: String
    private let repoRootURL: URL
    private let metadataStore: RepoMetadataStore
    private let fileManager: FileManager
    
    /// 支持的 Markdown 扩展名
    private let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkdn"]
    
    public init(
        repoId: String,
        repoRootURL: URL,
        metadataStore: RepoMetadataStore,
        fileManager: FileManager = .default
    ) {
        self.repoId = repoId
        self.repoRootURL = repoRootURL
        self.metadataStore = metadataStore
        self.fileManager = fileManager
    }
    
    // MARK: - Public API
    
    /// 扫描整个 Repo
    public func scan() async throws -> RepoTreeSnapshot {
        let metadata = try await metadataStore.load()
        var totalNotes = 0
        var totalFolders = 0
        
        let rootNodes = try await scanDirectory(
            at: repoRootURL,
            relativePath: "",
            metadata: metadata,
            totalNotes: &totalNotes,
            totalFolders: &totalFolders
        )
        
        // 更新最后扫描时间
        var updatedMetadata = metadata
        updatedMetadata.lastScannedAt = Date()
        try? await metadataStore.save(updatedMetadata)
        
        return RepoTreeSnapshot(
            repoId: repoId,
            rootNodes: rootNodes,
            totalNotes: totalNotes,
            totalFolders: totalFolders
        )
    }
    
    /// 更新指定路径
    public func updatePath(_ relativePath: String) async throws -> [TreeNode] {
        let url = repoRootURL.appendingPathComponent(relativePath)
        let metadata = try await metadataStore.load()
        var totalNotes = 0
        var totalFolders = 0
        
        return try await scanDirectory(
            at: url,
            relativePath: relativePath,
            metadata: metadata,
            totalNotes: &totalNotes,
            totalFolders: &totalFolders
        )
    }
    
    // MARK: - Private
    
    private func scanDirectory(
        at url: URL,
        relativePath: String,
        metadata: RepoMetadata,
        totalNotes: inout Int,
        totalFolders: inout Int
    ) async throws -> [TreeNode] {
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        
        var nodes: [TreeNode] = []
        
        for itemURL in contents {
            let itemName = itemURL.lastPathComponent
            let itemRelativePath = relativePath.isEmpty ? itemName : "\(relativePath)/\(itemName)"
            
            // 跳过元数据文件
            if itemName == ".qingjian_metadata.json" {
                continue
            }
            
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
            let isDirectory = resourceValues?.isDirectory ?? false
            
            if isDirectory {
                // 递归扫描子目录
                let children = try await scanDirectory(
                    at: itemURL,
                    relativePath: itemRelativePath,
                    metadata: metadata,
                    totalNotes: &totalNotes,
                    totalFolders: &totalFolders
                )
                
                let folderInfo = FolderInfo(
                    path: itemRelativePath,
                    name: itemName,
                    children: children,
                    isExpanded: false
                )
                
                nodes.append(.folder(folderInfo))
                totalFolders += 1
                
            } else if isMarkdownFile(itemURL) {
                // 读取笔记信息
                let modifiedAt = resourceValues?.contentModificationDate ?? Date()
                let sizeBytes = resourceValues?.fileSize ?? 0
                
                // 提取标题
                let displayTitle = extractTitle(from: itemURL, fallback: itemURL.deletingPathExtension().lastPathComponent)
                
                let noteInfo = NoteInfo(
                    path: itemRelativePath,
                    name: itemName,
                    displayTitle: displayTitle,
                    modifiedAt: modifiedAt,
                    sizeBytes: sizeBytes
                )
                
                nodes.append(.note(noteInfo))
                totalNotes += 1
            }
        }
        
        // 应用自定义排序
        let customOrder = metadata.folderOrders[relativePath] ?? []
        nodes = applySortOrder(nodes: nodes, customOrder: customOrder)
        
        return nodes
    }
    
    private func isMarkdownFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return markdownExtensions.contains(ext)
    }
    
    private func extractTitle(from url: URL, fallback: String) -> String {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return fallback
        }
        
        // 只读取前几行
        let lines = content.prefix(500).components(separatedBy: .newlines)
        for line in lines.prefix(10) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return fallback
    }
    
    private func applySortOrder(nodes: [TreeNode], customOrder: [String]) -> [TreeNode] {
        guard !customOrder.isEmpty else {
            // 默认排序：目录在前，文件在后，按名称排序
            return nodes.sorted { lhs, rhs in
                switch (lhs, rhs) {
                case (.folder, .note):
                    return true
                case (.note, .folder):
                    return false
                default:
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            }
        }
        
        // 应用自定义排序
        var nodesByPath: [String: TreeNode] = [:]
        for node in nodes {
            nodesByPath[node.path] = node
        }
        
        var sortedNodes: [TreeNode] = []
        
        // 按自定义顺序添加
        for path in customOrder {
            if let node = nodesByPath.removeValue(forKey: path) {
                sortedNodes.append(node)
            }
        }
        
        // 添加剩余的（新文件）
        let remaining = nodesByPath.values.sorted { $0.name < $1.name }
        sortedNodes.append(contentsOf: remaining)
        
        return sortedNodes
    }
}
