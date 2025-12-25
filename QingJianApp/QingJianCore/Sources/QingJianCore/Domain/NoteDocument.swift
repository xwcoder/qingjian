//
//  NoteDocument.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  笔记文档（完整内容）
//

import Foundation

/// 笔记文档
public struct NoteDocument: Equatable, Sendable {
    
    /// 笔记信息
    public let note: NoteInfo
    
    /// Markdown 内容
    public var content: String
    
    /// 内容 hash（用于冲突检测）
    public let contentHash: Int
    
    /// 加载时间
    public let loadedAt: Date
    
    /// 是否有未保存的更改
    public var isDirty: Bool
    
    public init(
        note: NoteInfo,
        content: String,
        contentHash: Int? = nil,
        loadedAt: Date = Date(),
        isDirty: Bool = false
    ) {
        self.note = note
        self.content = content
        self.contentHash = contentHash ?? content.hashValue
        self.loadedAt = loadedAt
        self.isDirty = isDirty
    }
    
    /// 从内容中提取标题
    public static func extractTitle(from content: String, fallback: String) -> String {
        // 查找第一个 # 标题
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return fallback
    }
    
    // MARK: - Unsaved Changes Contract (T017)
    
    /// 检查当前内容是否与已保存版本不同
    public func hasUnsavedChanges(currentContent: String) -> Bool {
        return currentContent.hashValue != contentHash
    }
    
    /// 创建一个标记为脏的副本（内容已修改）
    public func markDirty() -> NoteDocument {
        var copy = self
        copy.isDirty = true
        return copy
    }
    
    /// 创建一个已保存状态的副本（更新 hash）
    public func markSaved(newContent: String) -> NoteDocument {
        NoteDocument(
            note: note,
            content: newContent,
            contentHash: newContent.hashValue,
            loadedAt: loadedAt,
            isDirty: false
        )
    }
}

// MARK: - Unsaved Changes Action

/// 未保存更改时的用户操作选择
public enum UnsavedChangesAction: Sendable {
    /// 保存更改后继续
    case save
    /// 放弃更改继续
    case discard
    /// 取消操作
    case cancel
}

