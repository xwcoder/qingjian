//
//  RepoMetadataMigrationTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//

import XCTest
@testable import QingJianCore

final class RepoMetadataMigrationTests: XCTestCase {
    
    // MARK: - Path Migration Tests
    
    func testMigratePaths_FolderOrders_Key() {
        var metadata = RepoMetadata()
        metadata.folderOrders["docs/api"] = ["file1.md", "file2.md"]
        
        let result = RepoMetadataMigration.migratePaths(
            in: metadata,
            from: "docs",
            to: "documentation"
        )
        
        XCTAssertNil(result.folderOrders["docs/api"])
        XCTAssertEqual(result.folderOrders["documentation/api"], ["file1.md", "file2.md"])
    }
    
    func testMigratePaths_FolderOrders_Value() {
        var metadata = RepoMetadata()
        metadata.folderOrders[""] = ["docs/readme.md", "docs/api", "other.md"]
        
        let result = RepoMetadataMigration.migratePaths(
            in: metadata,
            from: "docs",
            to: "documentation"
        )
        
        XCTAssertEqual(result.folderOrders[""], ["documentation/readme.md", "documentation/api", "other.md"])
    }
    
    func testMigratePaths_RecentNotes() {
        var metadata = RepoMetadata()
        metadata.recentNotes = ["docs/readme.md", "docs/api/spec.md", "notes/todo.md"]
        
        let result = RepoMetadataMigration.migratePaths(
            in: metadata,
            from: "docs",
            to: "documentation"
        )
        
        XCTAssertEqual(result.recentNotes, ["documentation/readme.md", "documentation/api/spec.md", "notes/todo.md"])
    }
    
    func testMigratePaths_ExactMatch() {
        var metadata = RepoMetadata()
        metadata.folderOrders["docs"] = ["docs/file.md"]
        metadata.recentNotes = ["docs"]
        
        let result = RepoMetadataMigration.migratePaths(
            in: metadata,
            from: "docs",
            to: "documentation"
        )
        
        XCTAssertEqual(result.folderOrders["documentation"], ["documentation/file.md"])
        XCTAssertEqual(result.recentNotes, ["documentation"])
    }
    
    // MARK: - Cleanup Tests
    
    func testCleanupInvalidPaths_FolderOrders() {
        var metadata = RepoMetadata()
        metadata.folderOrders[""] = ["existing.md", "deleted.md", "folder"]
        metadata.folderOrders["folder"] = ["folder/a.md", "folder/deleted.md"]
        metadata.folderOrders["deleted_folder"] = ["deleted_folder/x.md"]
        
        let existingPaths: Set<String> = ["existing.md", "folder", "folder/a.md"]
        
        let result = RepoMetadataMigration.cleanupInvalidPaths(in: metadata, existingPaths: existingPaths)
        
        XCTAssertEqual(result.folderOrders[""], ["existing.md", "folder"])
        XCTAssertEqual(result.folderOrders["folder"], ["folder/a.md"])
        XCTAssertNil(result.folderOrders["deleted_folder"])
    }
    
    func testCleanupInvalidPaths_RecentNotes() {
        var metadata = RepoMetadata()
        metadata.recentNotes = ["existing.md", "deleted.md", "folder/existing.md"]
        
        let existingPaths: Set<String> = ["existing.md", "folder/existing.md"]
        
        let result = RepoMetadataMigration.cleanupInvalidPaths(in: metadata, existingPaths: existingPaths)
        
        XCTAssertEqual(result.recentNotes, ["existing.md", "folder/existing.md"])
    }
    
    func testCleanupInvalidPaths_RootOrderPreserved() {
        var metadata = RepoMetadata()
        metadata.folderOrders[""] = []
        
        let existingPaths: Set<String> = []
        
        let result = RepoMetadataMigration.cleanupInvalidPaths(in: metadata, existingPaths: existingPaths)
        
        // 根目录排序应该保留，即使为空
        XCTAssertNotNil(result.folderOrders[""])
    }
    
    // MARK: - Remove Paths Under Tests
    
    func testRemovePathsUnder_FolderOrders() {
        var metadata = RepoMetadata()
        metadata.folderOrders[""] = ["docs", "notes", "docs/api"]
        metadata.folderOrders["docs"] = ["docs/readme.md", "docs/api"]
        metadata.folderOrders["docs/api"] = ["docs/api/spec.md"]
        metadata.folderOrders["notes"] = ["notes/todo.md"]
        
        let result = RepoMetadataMigration.removePathsUnder(in: metadata, deletedPath: "docs")
        
        // docs 相关的 key 应该被删除
        XCTAssertNil(result.folderOrders["docs"])
        XCTAssertNil(result.folderOrders["docs/api"])
        
        // notes 应该保留
        XCTAssertEqual(result.folderOrders["notes"], ["notes/todo.md"])
        
        // 根目录排序中 docs 相关的应该被删除
        XCTAssertEqual(result.folderOrders[""], ["notes"])
    }
    
    func testRemovePathsUnder_RecentNotes() {
        var metadata = RepoMetadata()
        metadata.recentNotes = ["docs/readme.md", "docs/api/spec.md", "notes/todo.md"]
        
        let result = RepoMetadataMigration.removePathsUnder(in: metadata, deletedPath: "docs")
        
        XCTAssertEqual(result.recentNotes, ["notes/todo.md"])
    }
    
    // MARK: - Recent Notes Update Tests
    
    func testRemoveFromRecentNotes() {
        var metadata = RepoMetadata()
        metadata.recentNotes = ["a.md", "b.md", "c.md"]
        
        let result = RepoMetadataMigration.removeFromRecentNotes(in: metadata, path: "b.md")
        
        XCTAssertEqual(result.recentNotes, ["a.md", "c.md"])
    }
    
    func testUpdateRecentNotePath() {
        var metadata = RepoMetadata()
        metadata.recentNotes = ["old.md", "other.md", "old.md"]
        
        let result = RepoMetadataMigration.updateRecentNotePath(
            in: metadata,
            from: "old.md",
            to: "new.md"
        )
        
        XCTAssertEqual(result.recentNotes, ["new.md", "other.md", "new.md"])
    }
}

