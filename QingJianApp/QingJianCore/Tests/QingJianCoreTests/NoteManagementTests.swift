//
//  NoteManagementTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//
//  笔记 rename/move/delete 核心测试（US3: T028/T029）
//

import XCTest
@testable import QingJianCore

final class NoteManagementTests: XCTestCase {
    
    var tempDir: URL!
    var editUseCases: EditUseCases!
    var browseUseCases: BrowseUseCases!
    var metadataStore: RepoMetadataStore!
    let repoId = "test-repo"
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // 初始化元信息
        metadataStore = RepoMetadataStore(repoRootURL: tempDir)
        try await metadataStore.ensureExists()
        
        browseUseCases = BrowseUseCases()
        editUseCases = EditUseCases()
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Helper
    
    private func createNote(_ relativePath: String, content: String = "# Test") async throws {
        let url = tempDir.appendingPathComponent(relativePath)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func noteExists(_ relativePath: String) -> Bool {
        let url = tempDir.appendingPathComponent(relativePath)
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
    }
    
    private func readNoteContent(_ relativePath: String) throws -> String {
        let url = tempDir.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    // MARK: - T028: Rename Note Tests
    
    func testRenameNote_Success() async throws {
        try await createNote("old.md", content: "# Original")
        
        try await editUseCases.renameNote(
            repoId: repoId,
            rootURL: tempDir,
            oldPath: "old.md",
            newPath: "new.md",
            browseUseCases: browseUseCases
        )
        
        XCTAssertFalse(noteExists("old.md"))
        XCTAssertTrue(noteExists("new.md"))
        
        // 内容应该保持不变
        let content = try readNoteContent("new.md")
        XCTAssertEqual(content, "# Original")
    }
    
    func testRenameNote_ToSubfolder() async throws {
        try await createNote("note.md")
        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent("docs"),
            withIntermediateDirectories: true
        )
        
        try await editUseCases.renameNote(
            repoId: repoId,
            rootURL: tempDir,
            oldPath: "note.md",
            newPath: "docs/note.md",
            browseUseCases: browseUseCases
        )
        
        XCTAssertFalse(noteExists("note.md"))
        XCTAssertTrue(noteExists("docs/note.md"))
    }
    
    // MARK: - Move Note Tests
    
    func testMoveNote_Success() async throws {
        try await createNote("source/note.md")
        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent("target"),
            withIntermediateDirectories: true
        )
        
        try await editUseCases.moveNote(
            repoId: repoId,
            rootURL: tempDir,
            notePath: "source/note.md",
            newParentPath: "target",
            browseUseCases: browseUseCases
        )
        
        XCTAssertFalse(noteExists("source/note.md"))
        XCTAssertTrue(noteExists("target/note.md"))
    }
    
    func testMoveNote_ToRoot() async throws {
        try await createNote("folder/note.md")
        
        try await editUseCases.moveNote(
            repoId: repoId,
            rootURL: tempDir,
            notePath: "folder/note.md",
            newParentPath: "",
            browseUseCases: browseUseCases
        )
        
        XCTAssertFalse(noteExists("folder/note.md"))
        XCTAssertTrue(noteExists("note.md"))
    }
    
    // MARK: - Delete Note Tests
    
    func testDeleteNote_Success() async throws {
        try await createNote("toDelete.md")
        
        try await editUseCases.deleteNote(
            repoId: repoId,
            rootURL: tempDir,
            path: "toDelete.md",
            browseUseCases: browseUseCases
        )
        
        XCTAssertFalse(noteExists("toDelete.md"))
    }
    
    // MARK: - T029: Error Handling Tests
    
    func testRenameNote_NotFound() async throws {
        do {
            try await editUseCases.renameNote(
                repoId: repoId,
                rootURL: tempDir,
                oldPath: "nonexistent.md",
                newPath: "new.md",
                browseUseCases: browseUseCases
            )
            XCTFail("Should throw error")
        } catch let error as CoreError {
            XCTAssertEqual(error, .noteNotFound(path: "nonexistent.md"))
        }
    }
    
    func testRenameNote_TargetExists() async throws {
        try await createNote("source.md")
        try await createNote("target.md")
        
        do {
            try await editUseCases.renameNote(
                repoId: repoId,
                rootURL: tempDir,
                oldPath: "source.md",
                newPath: "target.md",
                browseUseCases: browseUseCases
            )
            XCTFail("Should throw error")
        } catch let error as CoreError {
            XCTAssertEqual(error, .noteAlreadyExists(path: "target.md"))
        }
    }
    
    func testDeleteNote_NotFound() async throws {
        do {
            try await editUseCases.deleteNote(
                repoId: repoId,
                rootURL: tempDir,
                path: "nonexistent.md",
                browseUseCases: browseUseCases
            )
            XCTFail("Should throw error")
        } catch let error as CoreError {
            XCTAssertEqual(error, .noteNotFound(path: "nonexistent.md"))
        }
    }
    
    // MARK: - Metadata Migration Tests
    
    func testRenameNote_UpdatesRecentNotes() async throws {
        try await createNote("old.md")
        
        // 设置初始元数据
        var metadata = try await metadataStore.load()
        metadata.recentNotes = ["old.md", "other.md"]
        try await metadataStore.save(metadata)
        
        // 重命名
        try await editUseCases.renameNote(
            repoId: repoId,
            rootURL: tempDir,
            oldPath: "old.md",
            newPath: "new.md",
            browseUseCases: browseUseCases
        )
        
        // 重新加载元数据（因为 EditUseCases 使用自己的 metadataStore 实例）
        await metadataStore.invalidateCache()
        let updatedMetadata = try await metadataStore.load()
        XCTAssertEqual(updatedMetadata.recentNotes, ["new.md", "other.md"])
    }
    
    func testDeleteNote_CleansRecentNotes() async throws {
        try await createNote("toDelete.md")
        
        // 设置初始元数据
        var metadata = try await metadataStore.load()
        metadata.recentNotes = ["toDelete.md", "other.md"]
        try await metadataStore.save(metadata)
        
        // 删除
        try await editUseCases.deleteNote(
            repoId: repoId,
            rootURL: tempDir,
            path: "toDelete.md",
            browseUseCases: browseUseCases
        )
        
        // 重新加载元数据（因为 EditUseCases 使用自己的 metadataStore 实例）
        await metadataStore.invalidateCache()
        let updatedMetadata = try await metadataStore.load()
        XCTAssertEqual(updatedMetadata.recentNotes, ["other.md"])
    }
}

