//
//  UseCaseEditSaveTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//

import XCTest
@testable import QingJianCore

final class UseCaseEditSaveTests: XCTestCase {
    
    var tempDir: URL!
    var editUseCases: EditUseCases!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        editUseCases = EditUseCases()
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Helper
    
    private func createFile(_ relativePath: String, content: String) throws {
        let url = tempDir.appendingPathComponent(relativePath)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func readFile(_ relativePath: String) throws -> String {
        let url = tempDir.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    // MARK: - Save Tests
    
    func testSaveNote_Success() async throws {
        let originalContent = "# Original"
        try createFile("test.md", content: originalContent)
        
        let noteStore = NoteStore(repoRootURL: tempDir)
        let document = try await noteStore.read(path: "test.md")
        
        let newContent = "# Updated Content\n\nThis is the updated content."
        let result = try await editUseCases.saveNote(
            rootURL: tempDir,
            path: "test.md",
            content: newContent,
            expectedHash: document.contentHash
        )
        
        XCTAssertTrue(result.success)
        XCTAssertNil(result.conflict)
        
        let savedContent = try readFile("test.md")
        XCTAssertEqual(savedContent, newContent)
    }
    
    func testSaveNote_ConflictDetected() async throws {
        let originalContent = "# Original"
        try createFile("test.md", content: originalContent)
        
        let noteStore = NoteStore(repoRootURL: tempDir)
        let document = try await noteStore.read(path: "test.md")
        
        // Simulate external modification
        try createFile("test.md", content: "# External Change")
        
        let newContent = "# My Change"
        
        do {
            _ = try await editUseCases.saveNote(
                rootURL: tempDir,
                path: "test.md",
                content: newContent,
                expectedHash: document.contentHash
            )
            XCTFail("Should throw conflict error")
        } catch let error as CoreError {
            if case .noteConflict(let path) = error {
                XCTAssertEqual(path, "test.md")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
        
        // Verify original (external) content is preserved
        let currentContent = try readFile("test.md")
        XCTAssertEqual(currentContent, "# External Change")
    }
    
    func testSaveNote_ForceSave() async throws {
        let originalContent = "# Original"
        try createFile("test.md", content: originalContent)
        
        // Simulate external modification
        try createFile("test.md", content: "# External Change")
        
        let newContent = "# Force Save"
        let result = try await editUseCases.saveNote(
            rootURL: tempDir,
            path: "test.md",
            content: newContent,
            expectedHash: nil // No hash check = force save
        )
        
        XCTAssertTrue(result.success)
        
        let savedContent = try readFile("test.md")
        XCTAssertEqual(savedContent, newContent)
    }
    
    func testSaveNote_CreateNew() async throws {
        let newContent = "# New Note\n\nCreated from scratch."
        
        let result = try await editUseCases.saveNote(
            rootURL: tempDir,
            path: "new_note.md",
            content: newContent,
            expectedHash: nil
        )
        
        XCTAssertTrue(result.success)
        
        let savedContent = try readFile("new_note.md")
        XCTAssertEqual(savedContent, newContent)
    }
    
    func testSaveNote_CreateInSubdirectory() async throws {
        let newContent = "# Nested Note"
        
        let result = try await editUseCases.saveNote(
            rootURL: tempDir,
            path: "docs/nested/note.md",
            content: newContent,
            expectedHash: nil
        )
        
        XCTAssertTrue(result.success)
        
        let savedContent = try readFile("docs/nested/note.md")
        XCTAssertEqual(savedContent, newContent)
    }
    
    // MARK: - Auto-save Tests
    
    func testAutoSave_Debounced() async throws {
        let originalContent = "# Original"
        try createFile("test.md", content: originalContent)
        
        let noteStore = NoteStore(repoRootURL: tempDir)
        let document = try await noteStore.read(path: "test.md")
        
        // Simulate rapid changes
        for i in 1...5 {
            _ = try? await editUseCases.queueAutoSave(
                rootURL: tempDir,
                path: "test.md",
                content: "# Change \(i)",
                expectedHash: document.contentHash
            )
        }
        
        // Wait for debounce
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // The last change should be saved
        let savedContent = try readFile("test.md")
        XCTAssertEqual(savedContent, "# Change 5")
    }
}

