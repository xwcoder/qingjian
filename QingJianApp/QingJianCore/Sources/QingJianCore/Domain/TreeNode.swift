//
//  TreeNode.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  目录树节点（目录/笔记）
//

import Foundation

/// 目录树节点
public enum TreeNode: Identifiable, Equatable, Sendable {
    case folder(FolderInfo)
    case note(NoteInfo)
    
    public var id: String {
        switch self {
        case .folder(let info): return "folder:\(info.path)"
        case .note(let info): return "note:\(info.path)"
        }
    }
    
    public var path: String {
        switch self {
        case .folder(let info): return info.path
        case .note(let info): return info.path
        }
    }
    
    public var name: String {
        switch self {
        case .folder(let info): return info.name
        case .note(let info): return info.name
        }
    }
    
    public var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }
}

/// 目录信息
public struct FolderInfo: Equatable, Sendable {
    public let path: String
    public let name: String
    public var children: [TreeNode]
    public var isExpanded: Bool
    
    public init(
        path: String,
        name: String,
        children: [TreeNode] = [],
        isExpanded: Bool = false
    ) {
        self.path = path
        self.name = name
        self.children = children
        self.isExpanded = isExpanded
    }
}

/// 笔记信息（轻量，用于目录树展示）
public struct NoteInfo: Equatable, Sendable {
    public let path: String
    public let name: String
    public let displayTitle: String
    public let modifiedAt: Date
    public let sizeBytes: Int
    
    public init(
        path: String,
        name: String,
        displayTitle: String,
        modifiedAt: Date,
        sizeBytes: Int
    ) {
        self.path = path
        self.name = name
        self.displayTitle = displayTitle
        self.modifiedAt = modifiedAt
        self.sizeBytes = sizeBytes
    }
}

/// 目录树快照
public struct RepoTreeSnapshot: Equatable, Sendable {
    public let repoId: String
    public let rootNodes: [TreeNode]
    public let scannedAt: Date
    public let totalNotes: Int
    public let totalFolders: Int
    
    public init(
        repoId: String,
        rootNodes: [TreeNode],
        scannedAt: Date = Date(),
        totalNotes: Int,
        totalFolders: Int
    ) {
        self.repoId = repoId
        self.rootNodes = rootNodes
        self.scannedAt = scannedAt
        self.totalNotes = totalNotes
        self.totalFolders = totalFolders
    }
}

