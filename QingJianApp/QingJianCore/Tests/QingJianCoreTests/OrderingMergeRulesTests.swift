//
//  OrderingMergeRulesTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//

import XCTest
@testable import QingJianCore

final class OrderingMergeRulesTests: XCTestCase {
    
    var tempDir: URL!
    var orderingUseCases: OrderingUseCases!
    var metadataStore: RepoMetadataStore!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        metadataStore = RepoMetadataStore(repoRootURL: tempDir)
        orderingUseCases = OrderingUseCases()
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Helper
    
    private func createFile(_ relativePath: String) throws {
        let url = tempDir.appendingPathComponent(relativePath)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "".write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Reorder Tests
    
    func testReorderItems_Success() async throws {
        try createFile("a.md")
        try createFile("b.md")
        try createFile("c.md")
        
        // 设置初始顺序
        var metadata = RepoMetadata()
        metadata.folderOrders[""] = ["a.md", "b.md", "c.md"]
        try await metadataStore.save(metadata)
        
        // 重新排序
        let newOrder = ["c.md", "a.md", "b.md"]
        try await orderingUseCases.reorderItems(
            repoRootURL: tempDir,
            folderPath: "",
            newOrder: newOrder
        )
        
        // 创建新的 metadataStore 以避免缓存问题
        let freshStore = RepoMetadataStore(repoRootURL: tempDir)
        let updatedMetadata = try await freshStore.load()
        XCTAssertEqual(updatedMetadata.folderOrders[""], newOrder)
    }
    
    func testReorderItems_NestedFolder() async throws {
        try createFile("docs/a.md")
        try createFile("docs/b.md")
        
        let newOrder = ["docs/b.md", "docs/a.md"]
        try await orderingUseCases.reorderItems(
            repoRootURL: tempDir,
            folderPath: "docs",
            newOrder: newOrder
        )
        
        let metadata = try await metadataStore.load()
        XCTAssertEqual(metadata.folderOrders["docs"], newOrder)
    }
    
    // MARK: - Merge Rules Tests
    
    func testMergeNewFiles_Appended() async throws {
        // 初始顺序
        var metadata = RepoMetadata()
        metadata.folderOrders[""] = ["a.md", "b.md"]
        try await metadataStore.save(metadata)
        
        // 创建新文件
        try createFile("a.md")
        try createFile("b.md")
        try createFile("c.md") // 新文件
        try createFile("d.md") // 新文件
        
        // 合并
        let currentFiles = ["a.md", "b.md", "c.md", "d.md"]
        let merged = await orderingUseCases.mergeWithFileSystem(
            existingOrder: metadata.folderOrders[""] ?? [],
            currentFiles: currentFiles
        )
        
        // 验证：已有顺序保持，新文件追加到末尾
        XCTAssertEqual(merged, ["a.md", "b.md", "c.md", "d.md"])
    }
    
    func testMergeDeletedFiles_Removed() async throws {
        // 初始顺序
        var metadata = RepoMetadata()
        metadata.folderOrders[""] = ["a.md", "b.md", "c.md"]
        try await metadataStore.save(metadata)
        
        // b.md 被删除
        let currentFiles = ["a.md", "c.md"]
        let merged = await orderingUseCases.mergeWithFileSystem(
            existingOrder: metadata.folderOrders[""] ?? [],
            currentFiles: currentFiles
        )
        
        // 验证：删除的文件被移除
        XCTAssertEqual(merged, ["a.md", "c.md"])
    }
    
    func testMergeMixedChanges() async throws {
        // 初始顺序
        var metadata = RepoMetadata()
        metadata.folderOrders[""] = ["a.md", "b.md", "c.md"]
        try await metadataStore.save(metadata)
        
        // b.md 删除，d.md 新增
        let currentFiles = ["a.md", "c.md", "d.md"]
        let merged = await orderingUseCases.mergeWithFileSystem(
            existingOrder: metadata.folderOrders[""] ?? [],
            currentFiles: currentFiles
        )
        
        // 验证：删除的移除，新增的追加
        XCTAssertEqual(merged, ["a.md", "c.md", "d.md"])
    }
    
    func testMergeEmptyExisting() async throws {
        let currentFiles = ["c.md", "a.md", "b.md"]
        let merged = await orderingUseCases.mergeWithFileSystem(
            existingOrder: [],
            currentFiles: currentFiles
        )
        
        // 验证：按原顺序返回
        XCTAssertEqual(merged, ["c.md", "a.md", "b.md"])
    }
    
    // MARK: - Move Item Tests
    
    func testMoveItem_ToPosition() async throws {
        try createFile("a.md")
        try createFile("b.md")
        try createFile("c.md")
        
        var metadata = RepoMetadata()
        metadata.folderOrders[""] = ["a.md", "b.md", "c.md"]
        try await metadataStore.save(metadata)
        
        // 将 c.md 移动到第一个位置
        try await orderingUseCases.moveItem(
            repoRootURL: tempDir,
            folderPath: "",
            itemPath: "c.md",
            toIndex: 0
        )
        
        // 创建新的 metadataStore 以避免缓存问题
        let freshStore = RepoMetadataStore(repoRootURL: tempDir)
        let updatedMetadata = try await freshStore.load()
        XCTAssertEqual(updatedMetadata.folderOrders[""], ["c.md", "a.md", "b.md"])
    }
    
    func testMoveItem_ToEnd() async throws {
        try createFile("a.md")
        try createFile("b.md")
        try createFile("c.md")
        
        var metadata = RepoMetadata()
        metadata.folderOrders[""] = ["a.md", "b.md", "c.md"]
        try await metadataStore.save(metadata)
        
        // 将 a.md 移动到最后
        try await orderingUseCases.moveItem(
            repoRootURL: tempDir,
            folderPath: "",
            itemPath: "a.md",
            toIndex: 2
        )
        
        // 创建新的 metadataStore 以避免缓存问题
        let freshStore = RepoMetadataStore(repoRootURL: tempDir)
        let updatedMetadata = try await freshStore.load()
        XCTAssertEqual(updatedMetadata.folderOrders[""], ["b.md", "c.md", "a.md"])
    }
}

