//
//  NoteStore.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  笔记存储（读写 Markdown 文件）
//

import Foundation

/// 笔记存储
public actor NoteStore {
    
    private let repoRootURL: URL
    private let fileManager: FileManager
    
    public init(repoRootURL: URL, fileManager: FileManager = .default) {
        self.repoRootURL = repoRootURL
        self.fileManager = fileManager
    }
    
    // MARK: - Read
    
    /// 读取笔记
    public func read(path: String) async throws -> NoteDocument {
        let url = repoRootURL.appendingPathComponent(path)
        
        guard fileManager.fileExists(atPath: url.path) else {
            throw CoreError.noteNotFound(path: path)
        }
        
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw CoreError.permissionDenied(path: path)
        }
        
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw CoreError.noteReadFailed(path: path, reason: error.localizedDescription)
        }
        
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let modifiedAt = (attributes[.modificationDate] as? Date) ?? Date()
        let sizeBytes = (attributes[.size] as? Int) ?? 0
        
        let displayTitle = NoteDocument.extractTitle(
            from: content,
            fallback: url.deletingPathExtension().lastPathComponent
        )
        
        let noteInfo = NoteInfo(
            path: path,
            name: url.lastPathComponent,
            displayTitle: displayTitle,
            modifiedAt: modifiedAt,
            sizeBytes: sizeBytes
        )
        
        return NoteDocument(
            note: noteInfo,
            content: content,
            contentHash: content.hashValue
        )
    }
    
    // MARK: - Write
    
    /// 保存笔记
    public func save(document: NoteDocument, expectedHash: Int? = nil) async throws {
        let url = repoRootURL.appendingPathComponent(document.note.path)
        
        // 冲突检测
        if let expectedHash {
            if fileManager.fileExists(atPath: url.path) {
                let currentContent = try? String(contentsOf: url, encoding: .utf8)
                let currentHash = currentContent?.hashValue ?? 0
                
                if currentHash != expectedHash {
                    throw CoreError.noteConflict(path: document.note.path)
                }
            }
        }
        
        // 确保目录存在
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        // 写入文件
        do {
            try document.content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw CoreError.noteSaveFailed(path: document.note.path, reason: error.localizedDescription)
        }
    }
    
    // MARK: - Delete
    
    /// 删除笔记
    public func delete(path: String) async throws {
        let url = repoRootURL.appendingPathComponent(path)
        
        guard fileManager.fileExists(atPath: url.path) else {
            throw CoreError.noteNotFound(path: path)
        }
        
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw CoreError.ioError(path: path, reason: error.localizedDescription)
        }
    }
    
    // MARK: - Create
    
    /// 创建新笔记
    public func create(path: String, content: String = "") async throws -> NoteDocument {
        let url = repoRootURL.appendingPathComponent(path)
        
        // 检查是否已存在
        if fileManager.fileExists(atPath: url.path) {
            throw CoreError.ioError(path: path, reason: "文件已存在")
        }
        
        // 确保目录存在
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        // 写入文件
        try content.write(to: url, atomically: true, encoding: .utf8)
        
        // 返回文档
        return try await read(path: path)
    }
    
    // MARK: - Check External Modification
    
    /// 检查文件是否被外部修改
    public func checkExternalModification(path: String, knownHash: Int) async throws -> Bool {
        let url = repoRootURL.appendingPathComponent(path)
        
        guard fileManager.fileExists(atPath: url.path) else {
            return true // 文件被删除也算修改
        }
        
        let currentContent = try String(contentsOf: url, encoding: .utf8)
        return currentContent.hashValue != knownHash
    }
}
