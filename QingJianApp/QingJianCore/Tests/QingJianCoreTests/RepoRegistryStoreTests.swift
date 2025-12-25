//
//  RepoRegistryStoreTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//
//  JSONRepoRegistryStore 读写/迁移/幂等单测 (T018)
//

import XCTest
@testable import QingJianCore

final class RepoRegistryStoreTests: XCTestCase {
    
    var tempDir: URL!
    var registryFileURL: URL!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RepoRegistryStoreTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        registryFileURL = tempDir.appendingPathComponent("repo_registry.json")
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Load Tests
    
    func testLoad_WhenFileNotExists_ReturnsEmptyRegistry() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        
        // When
        let registry = try await store.load()
        
        // Then
        XCTAssertEqual(registry.entries.count, 0)
        XCTAssertEqual(registry.version, "1.0")
    }
    
    func testLoad_WhenFileExists_ReturnsStoredRegistry() async throws {
        // Given
        let entry = RepoRegistryEntry(
            repoId: "test-id",
            displayName: "Test Repo",
            rootPathHint: "/path/to/repo",
            lastOpenedAt: Date()
        )
        let registry = RepoRegistry(entries: [entry])
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(registry)
        try data.write(to: registryFileURL)
        
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        
        // When
        let loaded = try await store.load()
        
        // Then
        XCTAssertEqual(loaded.entries.count, 1)
        XCTAssertEqual(loaded.entries[0].repoId, "test-id")
        XCTAssertEqual(loaded.entries[0].displayName, "Test Repo")
    }
    
    // MARK: - Save Tests
    
    func testSave_WritesToFile() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let entry = RepoRegistryEntry(
            repoId: "new-id",
            displayName: "New Repo",
            rootPathHint: "/new/path"
        )
        let registry = RepoRegistry(entries: [entry])
        
        // When
        try await store.save(registry)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: registryFileURL.path))
        
        let data = try Data(contentsOf: registryFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = try decoder.decode(RepoRegistry.self, from: data)
        XCTAssertEqual(loaded.entries.count, 1)
        XCTAssertEqual(loaded.entries[0].repoId, "new-id")
    }
    
    // MARK: - Upsert Tests
    
    func testUpsert_WhenEntryNotExists_AddsEntry() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let entry = RepoRegistryEntry(
            repoId: "repo-1",
            displayName: "Repo 1",
            rootPathHint: "/path/1"
        )
        
        // When
        try await store.upsert(entry)
        
        // Then
        let registry = try await store.load()
        XCTAssertEqual(registry.entries.count, 1)
        XCTAssertEqual(registry.entries[0].repoId, "repo-1")
    }
    
    func testUpsert_WhenEntryExists_UpdatesEntry() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let entry1 = RepoRegistryEntry(
            repoId: "repo-1",
            displayName: "Repo 1",
            rootPathHint: "/path/1"
        )
        try await store.upsert(entry1)
        
        // When
        var updatedEntry = entry1
        updatedEntry.displayName = "Updated Repo 1"
        try await store.upsert(updatedEntry)
        
        // Then
        let registry = try await store.load()
        XCTAssertEqual(registry.entries.count, 1)
        XCTAssertEqual(registry.entries[0].displayName, "Updated Repo 1")
    }
    
    func testUpsert_IsIdempotent() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let entry = RepoRegistryEntry(
            repoId: "repo-1",
            displayName: "Repo 1",
            rootPathHint: "/path/1"
        )
        
        // When
        try await store.upsert(entry)
        try await store.upsert(entry)
        try await store.upsert(entry)
        
        // Then
        let registry = try await store.load()
        XCTAssertEqual(registry.entries.count, 1)
    }
    
    // MARK: - Remove Tests
    
    func testRemove_WhenEntryExists_RemovesEntry() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let entry = RepoRegistryEntry(
            repoId: "repo-1",
            displayName: "Repo 1",
            rootPathHint: "/path/1"
        )
        try await store.upsert(entry)
        
        // When
        try await store.remove(repoId: "repo-1")
        
        // Then
        let registry = try await store.load()
        XCTAssertEqual(registry.entries.count, 0)
    }
    
    func testRemove_WhenEntryNotExists_DoesNothing() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        
        // When/Then - should not throw
        try await store.remove(repoId: "non-existent")
        
        let registry = try await store.load()
        XCTAssertEqual(registry.entries.count, 0)
    }
    
    // MARK: - Get Tests
    
    func testGet_WhenEntryExists_ReturnsEntry() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let entry = RepoRegistryEntry(
            repoId: "repo-1",
            displayName: "Repo 1",
            rootPathHint: "/path/1"
        )
        try await store.upsert(entry)
        
        // When
        let result = try await store.get(repoId: "repo-1")
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.repoId, "repo-1")
    }
    
    func testGet_WhenEntryNotExists_ReturnsNil() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        
        // When
        let result = try await store.get(repoId: "non-existent")
        
        // Then
        XCTAssertNil(result)
    }
    
    // MARK: - Cache Tests
    
    func testCache_IsInvalidatedAfterSave() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let entry1 = RepoRegistryEntry(
            repoId: "repo-1",
            displayName: "Repo 1",
            rootPathHint: "/path/1"
        )
        try await store.upsert(entry1)
        _ = try await store.load() // populate cache
        
        // When - directly write to file
        let entry2 = RepoRegistryEntry(
            repoId: "repo-2",
            displayName: "Repo 2",
            rootPathHint: "/path/2"
        )
        try await store.upsert(entry2)
        
        // Then - should see both entries
        let registry = try await store.load()
        XCTAssertEqual(registry.entries.count, 2)
    }
    
    func testInvalidateCache_ClearsCache() async throws {
        // Given
        let store = JSONRepoRegistryStore(fileURL: registryFileURL)
        let entry = RepoRegistryEntry(
            repoId: "repo-1",
            displayName: "Repo 1",
            rootPathHint: "/path/1"
        )
        try await store.upsert(entry)
        _ = try await store.load() // populate cache
        
        // When
        await store.invalidateCache()
        
        // Then - should reload from file
        let registry = try await store.load()
        XCTAssertEqual(registry.entries.count, 1)
    }
}

