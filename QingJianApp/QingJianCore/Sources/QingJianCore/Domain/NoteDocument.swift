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
}

