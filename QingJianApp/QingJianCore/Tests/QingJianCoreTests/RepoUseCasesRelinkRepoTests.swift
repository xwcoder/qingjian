//
//  RepoUseCasesRelinkRepoTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//
//  RepoUseCases.relinkRepo 成功与失败（不匹配 repoId/无元信息/权限）单测 (T040)
//

import XCTest
@testable import QingJianCore

final class RepoUseCasesRelinkRepoTests: XCTestCase {
    
    var tempDir: URL!
    var registryFileURL: URL!
    var originalRepoDir: URL!
    var movedRepoDir: URL!
    var invalidDir: URL!
    var differentRepoDir: URL!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RepoUseCasesRelinkRepoTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        registryFileURL = tempDir.appendingPathComponent("repo_registry.json")
        
        // 创建原始仓库目录（含元信息）
        originalRepoDir = tempDir.appendingPathComponent("OriginalRepo")
        try FileManager.default.createDirectory(at: originalRepoDir, withIntermediateDirectories: true)
        let metadata = RepoMetadata()
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: originalRepoDir.appendingPathComponent(".qingjian_metadata.json"))
        
        // 创建"移动后"的仓库目录（路径相同内容，模拟用户移动仓库）
        // 注意：由于 repoId 基于路径 hash，我们需要保持相同路径来模拟正确的 relink
        movedRepoDir = originalRepoDir // 在实际场景中，用户会移动整个目录
        
        // 创建无元信息目录
        invalidDir = tempDir.appendingPathComponent("InvalidDir")
        try FileManager.default.createDirectory(at: invalidDir, withIntermediateDirectories: true)
        
        // 创建不同仓库目录（元信息存在但 repoId 不匹配）
        differentRepoDir = tempDir.appendingPathComponent("DifferentRepo")
        try FileManager.default.createDirectory(at: differentRepoDir, withIntermediateDirectories: true)
        try data.write(to: differentRepoDir.appendingPathComponent(".qingjian_metadata.json"))
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Success Tests
    
    func testRelinkRepo_WhenValidPath_Succeeds() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        let summary = try await useCases.createRepo(rootURL: originalRepoDir)
        
        // When - 使用相同路径 relink（模拟授权恢复）
        try await useCases.relinkRepo(id: summary.id, newRootURL: originalRepoDir)
        
        // Then
        let repos = await useCases.listRepos()
        XCTAssertEqual(repos.count, 1)
        XCTAssertTrue(repos[0].isAvailable)
    }
    
    // MARK: - Failure Tests
    
    func testRelinkRepo_WhenRepoNotFound_ThrowsError() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        
        // When/Then
        do {
            try await useCases.relinkRepo(id: "non-existent", newRootURL: originalRepoDir)
            XCTFail("Expected error to be thrown")
        } catch let error as CoreError {
            if case .repoNotFound = error {
                // Expected
            } else {
                XCTFail("Expected repoNotFound error, got \(error)")
            }
        }
    }
    
    func testRelinkRepo_WhenPathHasNoMetadata_ThrowsError() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        let summary = try await useCases.createRepo(rootURL: originalRepoDir)
        
        // When/Then
        do {
            try await useCases.relinkRepo(id: summary.id, newRootURL: invalidDir)
            XCTFail("Expected error to be thrown")
        } catch let error as CoreError {
            if case .invalidRepo(let path) = error {
                XCTAssertTrue(path.contains("不存在"), "Error should mention missing metadata")
            } else {
                XCTFail("Expected invalidRepo error, got \(error)")
            }
        }
    }
    
    func testRelinkRepo_WhenPathNotExists_ThrowsError() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        let summary = try await useCases.createRepo(rootURL: originalRepoDir)
        let nonExistentPath = tempDir.appendingPathComponent("NonExistent")
        
        // When/Then
        do {
            try await useCases.relinkRepo(id: summary.id, newRootURL: nonExistentPath)
            XCTFail("Expected error to be thrown")
        } catch let error as CoreError {
            if case .invalidRepo = error {
                // Expected
            } else {
                XCTFail("Expected invalidRepo error, got \(error)")
            }
        }
    }
    
    func testRelinkRepo_WhenRepoIdMismatch_ThrowsError() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let useCases = RepoUseCases(registryStore: store)
        let summary = try await useCases.createRepo(rootURL: originalRepoDir)
        
        // When/Then - 尝试用不同路径的仓库 relink
        do {
            try await useCases.relinkRepo(id: summary.id, newRootURL: differentRepoDir)
            XCTFail("Expected error to be thrown")
        } catch let error as CoreError {
            if case .invalidRepo(let path) = error {
                XCTAssertTrue(path.contains("不匹配"), "Error should mention ID mismatch")
            } else {
                XCTFail("Expected invalidRepo error, got \(error)")
            }
        }
    }
}

