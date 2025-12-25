//
//  UseCaseBrowseTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//

import XCTest
@testable import QingJianCore

final class UseCaseBrowseTests: XCTestCase {
    
    var tempDir: URL!
    var repoUseCases: RepoUseCases!
    var browseUseCases: BrowseUseCases!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        repoUseCases = RepoUseCases()
        browseUseCases = BrowseUseCases()
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
    
    // MARK: - Add Repo Tests
    
    func testAddRepo() async throws {
        try createFile("readme.md", content: "# Test")
        
        let summary = try await repoUseCases.addRepo(rootURL: tempDir, displayName: "Test Repo")
        
        XCTAssertEqual(summary.displayName, "Test Repo")
        XCTAssertEqual(summary.rootPath, tempDir.path)
        XCTAssertTrue(summary.isAvailable)
    }
    
    func testAddRepoWithInvalidPath() async {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString)")
        
        do {
            _ = try await repoUseCases.addRepo(rootURL: invalidURL, displayName: "Invalid")
            XCTFail("Should throw error")
        } catch let error as CoreError {
            if case .invalidRepo = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testListRepos() async throws {
        try createFile("readme.md")
        
        _ = try await repoUseCases.addRepo(rootURL: tempDir, displayName: "Repo 1")
        
        let repos = await repoUseCases.listRepos()
        
        XCTAssertEqual(repos.count, 1)
        XCTAssertEqual(repos.first?.displayName, "Repo 1")
    }
    
    func testRemoveRepo() async throws {
        try createFile("readme.md")
        
        let summary = try await repoUseCases.addRepo(rootURL: tempDir, displayName: "To Remove")
        try await repoUseCases.removeRepo(id: summary.id)
        
        let repos = await repoUseCases.listRepos()
        XCTAssertTrue(repos.isEmpty)
    }
    
    // MARK: - Browse Tests
    
    func testLoadRepoTree() async throws {
        try createFile("readme.md", content: "# Root")
        try createFile("docs/guide.md", content: "# Guide")
        
        let summary = try await repoUseCases.addRepo(rootURL: tempDir, displayName: "Browse Test")
        let tree = try await browseUseCases.loadRepoTree(repoId: summary.id, rootURL: tempDir)
        
        XCTAssertEqual(tree.repoId, summary.id)
        XCTAssertEqual(tree.rootNodes.count, 2) // readme.md and docs folder
    }
    
    func testOpenNote() async throws {
        let content = "# Hello World\n\nThis is a test note."
        try createFile("test.md", content: content)
        
        let summary = try await repoUseCases.addRepo(rootURL: tempDir, displayName: "Note Test")
        let document = try await browseUseCases.openNote(repoId: summary.id, rootURL: tempDir, notePath: "test.md")
        
        XCTAssertEqual(document.content, content)
        XCTAssertEqual(document.note.displayTitle, "Hello World")
    }
    
    func testOpenNonExistentNote() async throws {
        try createFile("readme.md")
        
        let summary = try await repoUseCases.addRepo(rootURL: tempDir, displayName: "Test")
        
        do {
            _ = try await browseUseCases.openNote(repoId: summary.id, rootURL: tempDir, notePath: "nonexistent.md")
            XCTFail("Should throw error")
        } catch let error as CoreError {
            if case .noteNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
