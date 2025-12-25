//
//  RepoUseCasesCreateRepoTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//
//  RepoUseCases.createRepo 初始化元信息/幂等/无写权限失败的单测 (T020)
//

import XCTest
@testable import QingJianCore

final class RepoUseCasesCreateRepoTests: XCTestCase {
    
    var tempDir: URL!
    var registryFileURL: URL!
    var emptyRepoDir: URL!
    var existingRepoDir: URL!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RepoUseCasesCreateRepoTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        registryFileURL = tempDir.appendingPathComponent("repo_registry.json")
        
        // 创建空目录（无元信息）
        emptyRepoDir = tempDir.appendingPathComponent("EmptyRepo")
        try FileManager.default.createDirectory(at: emptyRepoDir, withIntermediateDirectories: true)
        
        // 创建已有元信息的目录
        existingRepoDir = tempDir.appendingPathComponent("ExistingRepo")
        try FileManager.default.createDirectory(at: existingRepoDir, withIntermediateDirectories: true)
        var metadata = RepoMetadata()
        metadata.recentNotes = ["existing.md"]
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: existingRepoDir.appendingPathComponent(".qingjian_metadata.json"))
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Metadata Initialization Tests
    
    func testCreateRepo_WithEmptyDir_CreatesMetadataFile() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        XCTAssertFalse(RepoMetadataStore.metadataExists(at: emptyRepoDir))
        
        // When
        _ = try await useCases.createRepo(rootURL: emptyRepoDir)
        
        // Then
        XCTAssertTrue(RepoMetadataStore.metadataExists(at: emptyRepoDir))
        XCTAssertNil(RepoMetadataStore.validateMetadata(at: emptyRepoDir))
    }
    
    func testCreateRepo_WithExistingMetadata_DoesNotOverwrite() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        
        // When
        _ = try await useCases.createRepo(rootURL: existingRepoDir)
        
        // Then
        let metadataStore = RepoMetadataStore(repoRootURL: existingRepoDir)
        let loaded = try await metadataStore.load()
        XCTAssertEqual(loaded.recentNotes, ["existing.md"]) // 原有数据未被覆盖
    }
    
    // MARK: - Success Tests
    
    func testCreateRepo_Succeeds() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        
        // When
        let summary = try await useCases.createRepo(rootURL: emptyRepoDir)
        
        // Then
        XCTAssertEqual(summary.displayName, "EmptyRepo")
        XCTAssertTrue(summary.isAvailable)
    }
    
    func testCreateRepo_WithCustomDisplayName_UsesCustomName() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        
        // When
        let summary = try await useCases.createRepo(rootURL: emptyRepoDir, displayName: "My New Repo")
        
        // Then
        XCTAssertEqual(summary.displayName, "My New Repo")
    }
    
    func testCreateRepo_PersistsToRegistry() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        
        // When
        let summary = try await useCases.createRepo(rootURL: emptyRepoDir)
        
        // Then
        let entry = try await store.get(repoId: summary.id)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.displayName, "EmptyRepo")
    }
    
    // MARK: - Idempotency Tests
    
    func testCreateRepo_WhenAlreadyAdded_ReturnsExistingEntry() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        _ = try await useCases.createRepo(rootURL: emptyRepoDir, displayName: "First Name")
        
        // When
        let summary = try await useCases.createRepo(rootURL: emptyRepoDir, displayName: "Second Name")
        
        // Then
        XCTAssertEqual(summary.displayName, "First Name") // 返回已有条目
    }
    
    func testCreateRepo_WhenAlreadyAdded_DoesNotDuplicate() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        
        // When
        _ = try await useCases.createRepo(rootURL: emptyRepoDir)
        _ = try await useCases.createRepo(rootURL: emptyRepoDir)
        _ = try await useCases.createRepo(rootURL: emptyRepoDir)
        
        // Then
        let repos = await useCases.listRepos()
        XCTAssertEqual(repos.count, 1)
    }
    
    // MARK: - Error Tests
    
    func testCreateRepo_WhenPathNotExists_ThrowsInvalidRepo() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        let nonExistentPath = tempDir.appendingPathComponent("NonExistent")
        
        // When/Then
        do {
            _ = try await useCases.createRepo(rootURL: nonExistentPath)
            XCTFail("Expected error to be thrown")
        } catch let error as CoreError {
            if case .invalidRepo = error {
                // Expected
            } else {
                XCTFail("Expected invalidRepo error, got \(error)")
            }
        }
    }
    
    // MARK: - addRepo Compatibility Tests
    
    func testAddRepo_UsesCreateRepoSemantics() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        XCTAssertFalse(RepoMetadataStore.metadataExists(at: emptyRepoDir))
        
        // When
        _ = try await useCases.addRepo(rootURL: emptyRepoDir)
        
        // Then - addRepo should create metadata like createRepo
        XCTAssertTrue(RepoMetadataStore.metadataExists(at: emptyRepoDir))
    }
}

