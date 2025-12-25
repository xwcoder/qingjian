//
//  RepoMetadataStoreTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//
//  RepoMetadataStore 元信息存在性判定单测 (T017)
//

import XCTest
@testable import QingJianCore

final class RepoMetadataStoreTests: XCTestCase {
    
    var tempDir: URL!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RepoMetadataStoreTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - 静态方法测试
    
    func testMetadataExists_WhenFileExists_ReturnsTrue() throws {
        // Given
        let metadataURL = tempDir.appendingPathComponent(".qingjian_metadata.json")
        let metadata = RepoMetadata()
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL)
        
        // When
        let exists = RepoMetadataStore.metadataExists(at: tempDir)
        
        // Then
        XCTAssertTrue(exists)
    }
    
    func testMetadataExists_WhenFileNotExists_ReturnsFalse() {
        // When
        let exists = RepoMetadataStore.metadataExists(at: tempDir)
        
        // Then
        XCTAssertFalse(exists)
    }
    
    func testValidateMetadata_WhenFileValid_ReturnsNil() throws {
        // Given
        let metadataURL = tempDir.appendingPathComponent(".qingjian_metadata.json")
        let metadata = RepoMetadata()
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL)
        
        // When
        let error = RepoMetadataStore.validateMetadata(at: tempDir)
        
        // Then
        XCTAssertNil(error)
    }
    
    func testValidateMetadata_WhenFileNotExists_ReturnsError() {
        // When
        let error = RepoMetadataStore.validateMetadata(at: tempDir)
        
        // Then
        XCTAssertNotNil(error)
        XCTAssertTrue(error?.contains("不存在") ?? false)
    }
    
    func testValidateMetadata_WhenFileCorrupted_ReturnsError() throws {
        // Given
        let metadataURL = tempDir.appendingPathComponent(".qingjian_metadata.json")
        try "not valid json {{{".write(to: metadataURL, atomically: true, encoding: .utf8)
        
        // When
        let error = RepoMetadataStore.validateMetadata(at: tempDir)
        
        // Then
        XCTAssertNotNil(error)
        XCTAssertTrue(error?.contains("损坏") ?? false)
    }
    
    // MARK: - 实例方法测试
    
    func testExists_WhenFileExists_ReturnsTrue() async throws {
        // Given
        let metadataURL = tempDir.appendingPathComponent(".qingjian_metadata.json")
        let metadata = RepoMetadata()
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL)
        
        let store = RepoMetadataStore(repoRootURL: tempDir)
        
        // When
        let exists = await store.exists()
        
        // Then
        XCTAssertTrue(exists)
    }
    
    func testExists_WhenFileNotExists_ReturnsFalse() async {
        // Given
        let store = RepoMetadataStore(repoRootURL: tempDir)
        
        // When
        let exists = await store.exists()
        
        // Then
        XCTAssertFalse(exists)
    }
    
    func testValidate_WhenFileValid_ReturnsNil() async throws {
        // Given
        let metadataURL = tempDir.appendingPathComponent(".qingjian_metadata.json")
        let metadata = RepoMetadata()
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL)
        
        let store = RepoMetadataStore(repoRootURL: tempDir)
        
        // When
        let error = await store.validate()
        
        // Then
        XCTAssertNil(error)
    }
    
    func testValidate_WhenFileNotExists_ReturnsError() async {
        // Given
        let store = RepoMetadataStore(repoRootURL: tempDir)
        
        // When
        let error = await store.validate()
        
        // Then
        XCTAssertNotNil(error)
    }
    
    func testEnsureExists_WhenFileNotExists_CreatesFile() async throws {
        // Given
        let store = RepoMetadataStore(repoRootURL: tempDir)
        let existsBefore = await store.exists()
        XCTAssertFalse(existsBefore)
        
        // When
        try await store.ensureExists()
        
        // Then
        let existsAfter = await store.exists()
        let validateResult = await store.validate()
        XCTAssertTrue(existsAfter)
        XCTAssertNil(validateResult)
    }
    
    func testEnsureExists_WhenFileExists_DoesNothing() async throws {
        // Given
        let metadataURL = tempDir.appendingPathComponent(".qingjian_metadata.json")
        var metadata = RepoMetadata()
        metadata.recentNotes = ["test.md"]
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL)
        
        let store = RepoMetadataStore(repoRootURL: tempDir)
        
        // When
        try await store.ensureExists()
        
        // Then
        let loaded = try await store.load()
        XCTAssertEqual(loaded.recentNotes, ["test.md"]) // 原有数据未被覆盖
    }
}

