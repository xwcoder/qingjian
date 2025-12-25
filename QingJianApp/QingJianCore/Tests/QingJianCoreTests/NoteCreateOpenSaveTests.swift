//
//  NoteCreateOpenSaveTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//
//  笔记创建/打开/保存核心集成测试（US1）
//

import XCTest
@testable import QingJianCore

final class NoteCreateOpenSaveTests: XCTestCase {
    
    var tempDir: URL!
    var noteStore: NoteStore!
    var metadataStore: RepoMetadataStore!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        noteStore = NoteStore(repoRootURL: tempDir)
        metadataStore = RepoMetadataStore(repoRootURL: tempDir)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - T010: Create Note Tests
    
    func testCreateNote_Success() async throws {
        let doc = try await noteStore.create(path: "test.md", content: "# Hello\n\nContent")
        
        XCTAssertEqual(doc.note.path, "test.md")
        XCTAssertEqual(doc.note.name, "test.md")
        XCTAssertEqual(doc.note.displayTitle, "Hello")
        XCTAssertEqual(doc.content, "# Hello\n\nContent")
        XCTAssertFalse(doc.isDirty)
        
        // 验证文件已创建
        let fileURL = tempDir.appendingPathComponent("test.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func testCreateNote_InSubfolder() async throws {
        let doc = try await noteStore.create(path: "docs/api/readme.md", content: "# API Docs")
        
        XCTAssertEqual(doc.note.path, "docs/api/readme.md")
        XCTAssertEqual(doc.note.displayTitle, "API Docs")
        
        // 验证目录已自动创建
        let folderURL = tempDir.appendingPathComponent("docs/api")
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }
    
    func testCreateNote_AlreadyExists() async throws {
        // 先创建一个笔记
        try await noteStore.create(path: "existing.md", content: "")
        
        // 再次创建同名笔记应该失败
        do {
            _ = try await noteStore.create(path: "existing.md", content: "New content")
            XCTFail("Should throw error")
        } catch let error as CoreError {
            XCTAssertEqual(error, .ioError(path: "existing.md", reason: "文件已存在"))
        }
    }
    
    func testCreateNote_EmptyContent() async throws {
        let doc = try await noteStore.create(path: "empty.md", content: "")
        
        XCTAssertEqual(doc.content, "")
        XCTAssertEqual(doc.note.displayTitle, "empty") // fallback to filename without extension
    }
    
    // MARK: - Open Note Tests
    
    func testOpenNote_Success() async throws {
        // 先创建笔记
        let content = "# Test Note\n\nThis is content."
        try await noteStore.create(path: "test.md", content: content)
        
        // 打开笔记
        let doc = try await noteStore.read(path: "test.md")
        
        XCTAssertEqual(doc.note.path, "test.md")
        XCTAssertEqual(doc.content, content)
        XCTAssertEqual(doc.note.displayTitle, "Test Note")
    }
    
    func testOpenNote_NotFound() async throws {
        do {
            _ = try await noteStore.read(path: "nonexistent.md")
            XCTFail("Should throw error")
        } catch let error as CoreError {
            XCTAssertEqual(error, .noteNotFound(path: "nonexistent.md"))
        }
    }
    
    // MARK: - Save Note Tests
    
    func testSaveNote_Success() async throws {
        // 创建笔记
        var doc = try await noteStore.create(path: "test.md", content: "Original")
        
        // 修改并保存
        doc.content = "Modified content"
        try await noteStore.save(document: doc)
        
        // 重新读取验证
        let reloaded = try await noteStore.read(path: "test.md")
        XCTAssertEqual(reloaded.content, "Modified content")
    }
    
    // MARK: - T011: Conflict Protection Tests
    
    func testSaveNote_ConflictProtection_Success() async throws {
        // 创建笔记
        var doc = try await noteStore.create(path: "test.md", content: "Original")
        let originalHash = doc.contentHash
        
        // 使用正确的 expectedHash 保存
        doc.content = "Modified"
        try await noteStore.save(document: doc, expectedHash: originalHash)
        
        // 验证保存成功
        let reloaded = try await noteStore.read(path: "test.md")
        XCTAssertEqual(reloaded.content, "Modified")
    }
    
    func testSaveNote_ConflictProtection_HashMismatch() async throws {
        // 创建笔记
        var doc = try await noteStore.create(path: "test.md", content: "Original")
        
        // 模拟外部修改
        let fileURL = tempDir.appendingPathComponent("test.md")
        try "External modification".write(to: fileURL, atomically: true, encoding: .utf8)
        
        // 使用旧的 hash 保存应该失败
        doc.content = "My changes"
        do {
            try await noteStore.save(document: doc, expectedHash: doc.contentHash)
            XCTFail("Should throw conflict error")
        } catch let error as CoreError {
            XCTAssertEqual(error, .noteConflict(path: "test.md"))
        }
    }
    
    func testCheckExternalModification_Modified() async throws {
        // 创建笔记
        let doc = try await noteStore.create(path: "test.md", content: "Original")
        
        // 模拟外部修改
        let fileURL = tempDir.appendingPathComponent("test.md")
        try "External modification".write(to: fileURL, atomically: true, encoding: .utf8)
        
        // 检测外部修改
        let isModified = try await noteStore.checkExternalModification(path: "test.md", knownHash: doc.contentHash)
        XCTAssertTrue(isModified)
    }
    
    func testCheckExternalModification_NotModified() async throws {
        // 创建笔记
        let doc = try await noteStore.create(path: "test.md", content: "Original")
        
        // 不做任何修改
        let isModified = try await noteStore.checkExternalModification(path: "test.md", knownHash: doc.contentHash)
        XCTAssertFalse(isModified)
    }
    
    func testCheckExternalModification_FileDeleted() async throws {
        // 创建笔记
        let doc = try await noteStore.create(path: "test.md", content: "Original")
        
        // 删除文件
        let fileURL = tempDir.appendingPathComponent("test.md")
        try FileManager.default.removeItem(at: fileURL)
        
        // 文件删除也算"修改"
        let isModified = try await noteStore.checkExternalModification(path: "test.md", knownHash: doc.contentHash)
        XCTAssertTrue(isModified)
    }
    
    // MARK: - Integration with Metadata
    
    func testOpenNote_UpdatesRecentNotes() async throws {
        // 创建笔记
        try await noteStore.create(path: "test.md", content: "")
        
        // 模拟 BrowseUseCases.openNote 的行为：打开后更新 recentNotes
        try await metadataStore.addRecentNote(path: "test.md")
        
        // 验证 recentNotes 已更新
        let metadata = try await metadataStore.load()
        XCTAssertEqual(metadata.recentNotes.first, "test.md")
    }
}

