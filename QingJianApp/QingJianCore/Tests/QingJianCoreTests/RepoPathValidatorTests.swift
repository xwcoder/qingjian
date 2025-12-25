//
//  RepoPathValidatorTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//

import XCTest
@testable import QingJianCore

final class RepoPathValidatorTests: XCTestCase {
    
    var tempDir: URL!
    var validator: RepoPathValidator!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        validator = RepoPathValidator(repoRootURL: tempDir!)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Helper
    
    private func createFolder(_ relativePath: String) throws {
        let url = tempDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    private func createFile(_ relativePath: String, content: String = "") throws {
        let url = tempDir.appendingPathComponent(relativePath)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Folder Validation Tests
    
    func testValidateFolderCreate_Success() throws {
        let error = validator.validateFolderCreate(at: "newFolder")
        XCTAssertNil(error)
    }
    
    func testValidateFolderCreate_AlreadyExists() throws {
        try createFolder("existingFolder")
        
        let error = validator.validateFolderCreate(at: "existingFolder")
        XCTAssertEqual(error, .folderAlreadyExists(path: "existingFolder"))
    }
    
    func testValidateFolderMove_Success() throws {
        try createFolder("sourceFolder")
        
        let error = validator.validateFolderMove(from: "sourceFolder", to: "targetFolder")
        XCTAssertNil(error)
    }
    
    func testValidateFolderMove_NotFound() throws {
        let error = validator.validateFolderMove(from: "nonexistent", to: "target")
        XCTAssertEqual(error, .folderNotFound(path: "nonexistent"))
    }
    
    func testValidateFolderMove_ToSelf() throws {
        try createFolder("myFolder")
        
        let error = validator.validateFolderMove(from: "myFolder", to: "myFolder")
        XCTAssertEqual(error, .invalidFolderMove(path: "myFolder", reason: "不能移动到自身"))
    }
    
    func testValidateFolderMove_ToChild() throws {
        try createFolder("parent/child")
        
        let error = validator.validateFolderMove(from: "parent", to: "parent/child/newLocation")
        XCTAssertEqual(error, .invalidFolderMove(path: "parent", reason: "不能移动到自身的子目录"))
    }
    
    func testValidateFolderMove_TargetExists() throws {
        try createFolder("source")
        try createFolder("target")
        
        let error = validator.validateFolderMove(from: "source", to: "target")
        XCTAssertEqual(error, .folderAlreadyExists(path: "target"))
    }
    
    func testValidateFolderDelete_Success() throws {
        try createFolder("emptyFolder")
        
        let error = validator.validateFolderDelete(at: "emptyFolder", allowNonEmpty: false)
        XCTAssertNil(error)
    }
    
    func testValidateFolderDelete_NotFound() throws {
        let error = validator.validateFolderDelete(at: "nonexistent", allowNonEmpty: false)
        XCTAssertEqual(error, .folderNotFound(path: "nonexistent"))
    }
    
    func testValidateFolderDelete_NotEmpty() throws {
        try createFolder("nonEmptyFolder")
        try createFile("nonEmptyFolder/file.md")
        
        let error = validator.validateFolderDelete(at: "nonEmptyFolder", allowNonEmpty: false)
        XCTAssertEqual(error, .folderNotEmpty(path: "nonEmptyFolder"))
    }
    
    func testValidateFolderDelete_NotEmpty_Allowed() throws {
        try createFolder("nonEmptyFolder")
        try createFile("nonEmptyFolder/file.md")
        
        let error = validator.validateFolderDelete(at: "nonEmptyFolder", allowNonEmpty: true)
        XCTAssertNil(error)
    }
    
    // MARK: - Note Validation Tests
    
    func testValidateNoteCreate_Success() throws {
        let error = validator.validateNoteCreate(at: "newNote.md")
        XCTAssertNil(error)
    }
    
    func testValidateNoteCreate_AlreadyExists() throws {
        try createFile("existing.md")
        
        let error = validator.validateNoteCreate(at: "existing.md")
        XCTAssertEqual(error, .noteAlreadyExists(path: "existing.md"))
    }
    
    func testValidateNoteMove_Success() throws {
        try createFile("source.md")
        
        let error = validator.validateNoteMove(from: "source.md", to: "target.md")
        XCTAssertNil(error)
    }
    
    func testValidateNoteMove_NotFound() throws {
        let error = validator.validateNoteMove(from: "nonexistent.md", to: "target.md")
        XCTAssertEqual(error, .noteNotFound(path: "nonexistent.md"))
    }
    
    func testValidateNoteMove_TargetExists() throws {
        try createFile("source.md")
        try createFile("target.md")
        
        let error = validator.validateNoteMove(from: "source.md", to: "target.md")
        XCTAssertEqual(error, .noteAlreadyExists(path: "target.md"))
    }
    
    func testValidateNoteDelete_Success() throws {
        try createFile("note.md")
        
        let error = validator.validateNoteDelete(at: "note.md")
        XCTAssertNil(error)
    }
    
    func testValidateNoteDelete_NotFound() throws {
        let error = validator.validateNoteDelete(at: "nonexistent.md")
        XCTAssertEqual(error, .noteNotFound(path: "nonexistent.md"))
    }
}

