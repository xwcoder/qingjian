//
//  StorageTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//

import XCTest
@testable import QingJianCore

final class StorageTests: XCTestCase {
    
    var tempDir: URL!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Helper
    
    private func createFile(_ relativePath: String, content: String = "") throws {
        let url = tempDir.appendingPathComponent(relativePath)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - RepoMetadataStore Tests
    
    func testMetadataStoreLoadEmpty() async throws {
        let store = RepoMetadataStore(repoRootURL: tempDir)
        let metadata = try await store.load()
        
        XCTAssertEqual(metadata.version, "1.0")
        XCTAssertTrue(metadata.folderOrders.isEmpty)
        XCTAssertTrue(metadata.recentNotes.isEmpty)
    }
    
    func testMetadataStoreSaveAndLoad() async throws {
        let store = RepoMetadataStore(repoRootURL: tempDir)
        
        var metadata = RepoMetadata()
        metadata.folderOrders["docs"] = ["a.md", "b.md"]
        metadata.recentNotes = ["c.md"]
        
        try await store.save(metadata)
        
        // Create new store instance to test persistence
        let store2 = RepoMetadataStore(repoRootURL: tempDir)
        let loaded = try await store2.load()
        
        XCTAssertEqual(loaded.folderOrders["docs"], ["a.md", "b.md"])
        XCTAssertEqual(loaded.recentNotes, ["c.md"])
    }
    
    func testMetadataStoreAddRecentNote() async throws {
        let store = RepoMetadataStore(repoRootURL: tempDir)
        
        try await store.addRecentNote(path: "a.md")
        try await store.addRecentNote(path: "b.md")
        try await store.addRecentNote(path: "a.md") // Move to top
        
        let metadata = try await store.load()
        XCTAssertEqual(metadata.recentNotes, ["a.md", "b.md"])
    }
    
    // MARK: - NoteStore Tests
    
    func testNoteStoreRead() async throws {
        try createFile("test.md", content: "# Hello\n\nWorld")
        
        let store = NoteStore(repoRootURL: tempDir)
        let doc = try await store.read(path: "test.md")
        
        XCTAssertEqual(doc.content, "# Hello\n\nWorld")
        XCTAssertEqual(doc.note.displayTitle, "Hello")
    }
    
    func testNoteStoreReadNotFound() async throws {
        let store = NoteStore(repoRootURL: tempDir)
        
        do {
            _ = try await store.read(path: "nonexistent.md")
            XCTFail("Should throw error")
        } catch let error as CoreError {
            if case .noteNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }
    
    func testNoteStoreSave() async throws {
        try createFile("test.md", content: "# Original")
        
        let store = NoteStore(repoRootURL: tempDir)
        var doc = try await store.read(path: "test.md")
        
        doc = NoteDocument(
            note: doc.note,
            content: "# Updated",
            contentHash: doc.contentHash
        )
        
        try await store.save(document: doc, expectedHash: doc.contentHash)
        
        let reloaded = try await store.read(path: "test.md")
        XCTAssertEqual(reloaded.content, "# Updated")
    }
    
    func testNoteStoreCreate() async throws {
        let store = NoteStore(repoRootURL: tempDir)
        
        let doc = try await store.create(path: "new.md", content: "# New Note")
        
        XCTAssertEqual(doc.content, "# New Note")
        XCTAssertEqual(doc.note.displayTitle, "New Note")
        
        // Verify file exists
        let url = tempDir.appendingPathComponent("new.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
    
    func testNoteStoreDelete() async throws {
        try createFile("to_delete.md", content: "# Delete Me")
        
        let store = NoteStore(repoRootURL: tempDir)
        try await store.delete(path: "to_delete.md")
        
        // Verify file is deleted
        let url = tempDir.appendingPathComponent("to_delete.md")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    
    // MARK: - RepoScanner Tests
    
    func testRepoScannerEmpty() async throws {
        let metadataStore = RepoMetadataStore(repoRootURL: tempDir)
        let scanner = RepoScanner(repoId: "test", repoRootURL: tempDir, metadataStore: metadataStore)
        
        let snapshot = try await scanner.scan()
        
        XCTAssertTrue(snapshot.rootNodes.isEmpty)
        XCTAssertEqual(snapshot.totalNotes, 0)
        XCTAssertEqual(snapshot.totalFolders, 0)
    }
    
    func testRepoScannerWithFiles() async throws {
        try createFile("readme.md", content: "# Readme")
        try createFile("docs/guide.md", content: "# Guide")
        try createFile("docs/api.md", content: "# API")
        
        let metadataStore = RepoMetadataStore(repoRootURL: tempDir)
        let scanner = RepoScanner(repoId: "test", repoRootURL: tempDir, metadataStore: metadataStore)
        
        let snapshot = try await scanner.scan()
        
        XCTAssertEqual(snapshot.rootNodes.count, 2) // docs folder + readme.md
        XCTAssertEqual(snapshot.totalNotes, 3)
        XCTAssertEqual(snapshot.totalFolders, 1)
    }
    
    func testRepoScannerIgnoresHiddenFiles() async throws {
        try createFile("readme.md")
        try createFile(".hidden.md")
        
        let metadataStore = RepoMetadataStore(repoRootURL: tempDir)
        let scanner = RepoScanner(repoId: "test", repoRootURL: tempDir, metadataStore: metadataStore)
        
        let snapshot = try await scanner.scan()
        
        XCTAssertEqual(snapshot.totalNotes, 1)
    }
    
    func testRepoScannerCustomOrder() async throws {
        try createFile("a.md")
        try createFile("b.md")
        try createFile("c.md")
        
        let metadataStore = RepoMetadataStore(repoRootURL: tempDir)
        
        // Set custom order
        var metadata = RepoMetadata()
        metadata.folderOrders[""] = ["c.md", "a.md", "b.md"]
        try await metadataStore.save(metadata)
        
        let scanner = RepoScanner(repoId: "test", repoRootURL: tempDir, metadataStore: metadataStore)
        let snapshot = try await scanner.scan()
        
        let paths = snapshot.rootNodes.map { $0.path }
        XCTAssertEqual(paths, ["c.md", "a.md", "b.md"])
    }
}

