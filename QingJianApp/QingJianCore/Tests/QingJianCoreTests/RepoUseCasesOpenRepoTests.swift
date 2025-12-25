//
//  RepoUseCasesOpenRepoTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//
//  RepoUseCases.openRepo 成功/缺失元信息/损坏元信息/重复添加的单测 (T019, T039)
//

import XCTest
@testable import QingJianCore

final class RepoUseCasesOpenRepoTests: XCTestCase {
    
    var tempDir: URL!
    var registryFileURL: URL!
    var validRepoDir: URL!
    var invalidRepoDir: URL!
    var corruptedRepoDir: URL!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RepoUseCasesOpenRepoTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        registryFileURL = tempDir.appendingPathComponent("repo_registry.json")
        
        // 创建有效仓库目录（含元信息）
        validRepoDir = tempDir.appendingPathComponent("ValidRepo")
        try FileManager.default.createDirectory(at: validRepoDir, withIntermediateDirectories: true)
        let validMetadata = RepoMetadata()
        let validData = try JSONEncoder().encode(validMetadata)
        try validData.write(to: validRepoDir.appendingPathComponent(".qingjian_metadata.json"))
        
        // 创建无效仓库目录（无元信息）
        invalidRepoDir = tempDir.appendingPathComponent("InvalidRepo")
        try FileManager.default.createDirectory(at: invalidRepoDir, withIntermediateDirectories: true)
        
        // 创建损坏元信息仓库目录
        corruptedRepoDir = tempDir.appendingPathComponent("CorruptedRepo")
        try FileManager.default.createDirectory(at: corruptedRepoDir, withIntermediateDirectories: true)
        try "not valid json".write(
            to: corruptedRepoDir.appendingPathComponent(".qingjian_metadata.json"),
            atomically: true,
            encoding: .utf8
        )
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Success Tests
    
    func testOpenRepo_WithValidMetadata_Succeeds() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        
        // When
        let summary = try await useCases.openRepo(rootURL: validRepoDir)
        
        // Then
        XCTAssertEqual(summary.displayName, "ValidRepo")
        XCTAssertTrue(summary.isAvailable)
    }
    
    func testOpenRepo_WithCustomDisplayName_UsesCustomName() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        
        // When
        let summary = try await useCases.openRepo(rootURL: validRepoDir, displayName: "My Custom Name")
        
        // Then
        XCTAssertEqual(summary.displayName, "My Custom Name")
    }
    
    func testOpenRepo_PersistsToRegistry() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        
        // When
        let summary = try await useCases.openRepo(rootURL: validRepoDir)
        
        // Then
        let entry = try await store.get(repoId: summary.id)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.displayName, "ValidRepo")
    }
    
    // MARK: - Missing Metadata Tests
    
    func testOpenRepo_WithMissingMetadata_ThrowsInvalidRepo() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        
        // When/Then
        do {
            _ = try await useCases.openRepo(rootURL: invalidRepoDir)
            XCTFail("Expected error to be thrown")
        } catch let error as CoreError {
            if case .invalidRepo(let path) = error {
                XCTAssertTrue(path.contains("不存在"), "Error should mention missing metadata")
            } else {
                XCTFail("Expected invalidRepo error, got \(error)")
            }
        }
    }
    
    func testOpenRepo_WithMissingMetadata_DoesNotAddToList() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        
        // When
        _ = try? await useCases.openRepo(rootURL: invalidRepoDir)
        
        // Then
        let repos = await useCases.listRepos()
        XCTAssertEqual(repos.count, 0)
    }
    
    // MARK: - Corrupted Metadata Tests
    
    func testOpenRepo_WithCorruptedMetadata_ThrowsInvalidRepo() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        
        // When/Then
        do {
            _ = try await useCases.openRepo(rootURL: corruptedRepoDir)
            XCTFail("Expected error to be thrown")
        } catch let error as CoreError {
            if case .invalidRepo(let path) = error {
                XCTAssertTrue(path.contains("损坏"), "Error should mention corrupted metadata")
            } else {
                XCTFail("Expected invalidRepo error, got \(error)")
            }
        }
    }
    
    // MARK: - Duplicate Tests
    
    func testOpenRepo_WhenAlreadyAdded_ReturnsExistingEntry() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        _ = try await useCases.openRepo(rootURL: validRepoDir, displayName: "First Name")
        
        // When
        let summary = try await useCases.openRepo(rootURL: validRepoDir, displayName: "Second Name")
        
        // Then
        XCTAssertEqual(summary.displayName, "First Name") // 返回已有条目，不覆盖
    }
    
    func testOpenRepo_WhenAlreadyAdded_DoesNotDuplicate() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        _ = try await useCases.openRepo(rootURL: validRepoDir)
        
        // When
        _ = try await useCases.openRepo(rootURL: validRepoDir)
        _ = try await useCases.openRepo(rootURL: validRepoDir)
        
        // Then
        let repos = await useCases.listRepos()
        XCTAssertEqual(repos.count, 1)
    }
    
    // MARK: - Path Not Found Tests
    
    func testOpenRepo_WhenPathNotExists_ThrowsInvalidRepo() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        let nonExistentPath = tempDir.appendingPathComponent("NonExistent")
        
        // When/Then
        do {
            _ = try await useCases.openRepo(rootURL: nonExistentPath)
            XCTFail("Expected error to be thrown")
        } catch let error as CoreError {
            if case .invalidRepo = error {
                // Expected
            } else {
                XCTFail("Expected invalidRepo error, got \(error)")
            }
        }
    }
}

