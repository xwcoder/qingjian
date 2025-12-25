//
//  EditUseCases.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  编辑用例（对齐 contracts/use-cases.md: UC-Edit-*）
//

import Foundation

/// 保存结果
public struct SaveResult: Sendable {
    public let success: Bool
    public let conflict: ConflictInfo?
    public let savedAt: Date
    
    public init(success: Bool, conflict: ConflictInfo? = nil, savedAt: Date = Date()) {
        self.success = success
        self.conflict = conflict
        self.savedAt = savedAt
    }
}

/// 冲突信息
public struct ConflictInfo: Sendable {
    public let path: String
    public let localHash: Int
    public let currentHash: Int
    public let detectedAt: Date
    
    public init(path: String, localHash: Int, currentHash: Int, detectedAt: Date = Date()) {
        self.path = path
        self.localHash = localHash
        self.currentHash = currentHash
        self.detectedAt = detectedAt
    }
}

/// 编辑用例
public actor EditUseCases {
    
    /// 事件总线
    private let eventBus: CoreEventBus?
    
    /// 自动保存去抖任务
    private var autoSaveTasks: [String: Task<Void, Never>] = [:]
    
    /// 自动保存间隔（毫秒）
    private let autoSaveDebounceMs: UInt64 = 300
    
    public init(eventBus: CoreEventBus? = nil) {
        self.eventBus = eventBus
    }
    
    // MARK: - UC-Edit-01: Save Note
    
    /// 保存笔记
    ///
    /// - Parameters:
    ///   - rootURL: Repo 根目录
    ///   - path: 笔记相对路径
    ///   - content: 新内容
    ///   - expectedHash: 期望的基础版本 hash（用于冲突检测，nil 表示强制保存）
    /// - Returns: 保存结果
    /// - Throws: `CoreError.noteConflict`, `CoreError.noteSaveFailed`
    public func saveNote(
        rootURL: URL,
        path: String,
        content: String,
        expectedHash: Int?
    ) async throws -> SaveResult {
        let noteStore = NoteStore(repoRootURL: rootURL)
        
        // 冲突检测
        if let expectedHash {
            let hasConflict = try await noteStore.checkExternalModification(path: path, knownHash: expectedHash)
            if hasConflict {
                throw CoreError.noteConflict(path: path)
            }
        }
        
        // 构建文档
        let noteInfo = NoteInfo(
            path: path,
            name: URL(fileURLWithPath: path).lastPathComponent,
            displayTitle: NoteDocument.extractTitle(from: content, fallback: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent),
            modifiedAt: Date(),
            sizeBytes: content.utf8.count
        )
        
        let document = NoteDocument(
            note: noteInfo,
            content: content,
            contentHash: content.hashValue
        )
        
        // 保存
        try await PerfMetrics.shared.measure(.noteSave, context: ["path": path]) {
            try await noteStore.save(document: document, expectedHash: expectedHash)
        }
        
        // 发出事件
        eventBus?.emit(.noteSaved(repoId: rootURL.lastPathComponent, path: path))
        
        return SaveResult(success: true)
    }
    
    // MARK: - Auto-save with Debounce
    
    /// 队列自动保存（去抖）
    ///
    /// - Parameters:
    ///   - rootURL: Repo 根目录
    ///   - path: 笔记相对路径
    ///   - content: 新内容
    ///   - expectedHash: 期望的基础版本 hash
    public func queueAutoSave(
        rootURL: URL,
        path: String,
        content: String,
        expectedHash: Int?
    ) async throws {
        // 取消之前的任务
        autoSaveTasks[path]?.cancel()
        
        // 创建新的去抖任务
        autoSaveTasks[path] = Task {
            do {
                try await Task.sleep(nanoseconds: autoSaveDebounceMs * 1_000_000)
                guard !Task.isCancelled else { return }
                
                _ = try await saveNote(
                    rootURL: rootURL,
                    path: path,
                    content: content,
                    expectedHash: expectedHash
                )
            } catch {
                // Auto-save 失败不抛出，只记录
                #if DEBUG
                print("⚠️ Auto-save failed for \(path): \(error)")
                #endif
            }
        }
    }
    
    /// 立即执行所有待保存的自动保存任务
    public func flushPendingAutoSaves() async {
        for (_, task) in autoSaveTasks {
            task.cancel()
        }
        autoSaveTasks.removeAll()
    }
    
    // MARK: - UC-Edit-02: Create Note
    
    /// 创建新笔记
    ///
    /// - Parameters:
    ///   - rootURL: Repo 根目录
    ///   - path: 笔记相对路径
    ///   - initialContent: 初始内容（默认空）
    /// - Returns: 创建的笔记文档
    /// - Throws: `CoreError.ioError` if file already exists
    public func createNote(
        rootURL: URL,
        path: String,
        initialContent: String = ""
    ) async throws -> NoteDocument {
        let noteStore = NoteStore(repoRootURL: rootURL)
        return try await noteStore.create(path: path, content: initialContent)
    }
    
    // MARK: - UC-Edit-03: Delete Note
    
    /// 删除笔记
    ///
    /// - Parameters:
    ///   - rootURL: Repo 根目录
    ///   - path: 笔记相对路径
    /// - Throws: `CoreError.noteNotFound`, `CoreError.ioError`
    public func deleteNote(rootURL: URL, path: String) async throws {
        let noteStore = NoteStore(repoRootURL: rootURL)
        try await noteStore.delete(path: path)
    }
    
    // MARK: - UC-Edit-04: Rename Note
    
    /// 重命名笔记
    ///
    /// - Parameters:
    ///   - rootURL: Repo 根目录
    ///   - oldPath: 原路径
    ///   - newPath: 新路径
    /// - Throws: `CoreError.noteNotFound`, `CoreError.ioError`
    public func renameNote(rootURL: URL, oldPath: String, newPath: String) async throws {
        let fileManager = FileManager.default
        let oldURL = rootURL.appendingPathComponent(oldPath)
        let newURL = rootURL.appendingPathComponent(newPath)
        
        guard fileManager.fileExists(atPath: oldURL.path) else {
            throw CoreError.noteNotFound(path: oldPath)
        }
        
        // 确保目标目录存在
        let newDir = newURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: newDir.path) {
            try fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)
        }
        
        do {
            try fileManager.moveItem(at: oldURL, to: newURL)
        } catch {
            throw CoreError.ioError(path: oldPath, reason: error.localizedDescription)
        }
    }
}

