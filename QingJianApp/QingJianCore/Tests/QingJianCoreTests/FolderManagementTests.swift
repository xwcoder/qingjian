//
//  FolderManagementTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//
//  目录 CRUD + 扫描回归测试（US2: T018/T019/T020）
//

import XCTest
@testable import QingJianCore

final class FolderManagementTests: XCTestCase {
    
    var tempDir: URL!
    var folderUseCases: FolderUseCases!
    var browseUseCases: BrowseUseCases!
    var metadataStore: RepoMetadataStore!
    let repoId = "test-repo"
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // 初始化元信息
        metadataStore = RepoMetadataStore(repoRootURL: tempDir)
        try await metadataStore.ensureExists()
        
        browseUseCases = BrowseUseCases()
        folderUseCases = FolderUseCases()
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Helper
    
    private func createFolder(_ relativePath: String) throws {
        let url = tempDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    private func createFile(_ relativePath: String, content: String = "test") throws {
        let url = tempDir.appendingPathComponent(relativePath)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func folderExists(_ relativePath: String) -> Bool {
        let url = tempDir.appendingPathComponent(relativePath)
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
    
    // MARK: - T018: Create Folder Tests
    
    func testCreateFolder_Success() async throws {
        let result = try await folderUseCases.createFolder(
            repoId: repoId,
            rootURL: tempDir,
            path: "newFolder"
        )
        
        XCTAssertEqual(result.path, "newFolder")
        XCTAssertEqual(result.name, "newFolder")
        XCTAssertTrue(folderExists("newFolder"))
    }
    
    func testCreateFolder_Nested() async throws {
        let result = try await folderUseCases.createFolder(
            repoId: repoId,
            rootURL: tempDir,
            path: "parent/child/grandchild"
        )
        
        XCTAssertEqual(result.path, "parent/child/grandchild")
        XCTAssertTrue(folderExists("parent/child/grandchild"))
    }
    
    func testCreateFolder_AlreadyExists() async throws {
        try createFolder("existing")
        
        do {
            _ = try await folderUseCases.createFolder(
                repoId: repoId,
                rootURL: tempDir,
                path: "existing"
            )
            XCTFail("Should throw error")
        } catch let error as CoreError {
            XCTAssertEqual(error, .folderAlreadyExists(path: "existing"))
        }
    }
    
    // MARK: - Rename Folder Tests
    
    func testRenameFolder_Success() async throws {
        try createFolder("oldName")
        
        let result = try await folderUseCases.renameFolder(
            repoId: repoId,
            rootURL: tempDir,
            oldPath: "oldName",
            newPath: "newName"
        )
        
        XCTAssertEqual(result.path, "newName")
        XCTAssertFalse(folderExists("oldName"))
        XCTAssertTrue(folderExists("newName"))
    }
    
    func testRenameFolder_NotFound() async throws {
        do {
            _ = try await folderUseCases.renameFolder(
                repoId: repoId,
                rootURL: tempDir,
                oldPath: "nonexistent",
                newPath: "newName"
            )
            XCTFail("Should throw error")
        } catch let error as CoreError {
            XCTAssertEqual(error, .folderNotFound(path: "nonexistent"))
        }
    }
    
    // MARK: - T019: Move Folder Tests (Including Invalid Moves)
    
    func testMoveFolder_Success() async throws {
        try createFolder("source")
        try createFolder("target")
        
        let result = try await folderUseCases.moveFolder(
            repoId: repoId,
            rootURL: tempDir,
            folderPath: "source",
            newParentPath: "target"
        )
        
        XCTAssertEqual(result.path, "target/source")
        XCTAssertFalse(folderExists("source"))
        XCTAssertTrue(folderExists("target/source"))
    }
    
    func testMoveFolder_ToSelf_Fails() async throws {
        try createFolder("myFolder")
        
        do {
            _ = try await folderUseCases.moveFolder(
                repoId: repoId,
                rootURL: tempDir,
                folderPath: "myFolder",
                newParentPath: "myFolder"
            )
            XCTFail("Should throw error for moving to self")
        } catch let error as CoreError {
            if case .invalidFolderMove(_, let reason) = error {
                XCTAssertTrue(reason.contains("自身"))
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
    
    func testMoveFolder_ToChild_Fails() async throws {
        try createFolder("parent/child")
        
        do {
            _ = try await folderUseCases.moveFolder(
                repoId: repoId,
                rootURL: tempDir,
                folderPath: "parent",
                newParentPath: "parent/child"
            )
            XCTFail("Should throw error for moving to child")
        } catch let error as CoreError {
            if case .invalidFolderMove(_, let reason) = error {
                XCTAssertTrue(reason.contains("子目录"))
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
    
    // MARK: - Delete Folder Tests
    
    func testDeleteFolder_Empty_Success() async throws {
        try createFolder("emptyFolder")
        
        try await folderUseCases.deleteFolder(
            repoId: repoId,
            rootURL: tempDir,
            path: "emptyFolder",
            force: false
        )
        
        XCTAssertFalse(folderExists("emptyFolder"))
    }
    
    func testDeleteFolder_NonEmpty_RequiresForce() async throws {
        try createFolder("nonEmpty")
        try createFile("nonEmpty/file.md")
        
        do {
            try await folderUseCases.deleteFolder(
                repoId: repoId,
                rootURL: tempDir,
                path: "nonEmpty",
                force: false
            )
            XCTFail("Should throw error")
        } catch let error as CoreError {
            XCTAssertEqual(error, .folderNotEmpty(path: "nonEmpty"))
        }
        
        // 确保文件夹仍然存在
        XCTAssertTrue(folderExists("nonEmpty"))
    }
    
    func testDeleteFolder_NonEmpty_WithForce() async throws {
        try createFolder("nonEmpty")
        try createFile("nonEmpty/file.md")
        
        try await folderUseCases.deleteFolder(
            repoId: repoId,
            rootURL: tempDir,
            path: "nonEmpty",
            force: true
        )
        
        XCTAssertFalse(folderExists("nonEmpty"))
    }
    
    // MARK: - T020: Metadata Migration Tests
    
    func testRenameFolder_MigratesMetadata() async throws {
        try createFolder("docs")
        try createFile("docs/readme.md")
        
        // 设置 folderOrders
        var metadata = try await metadataStore.load()
        metadata.folderOrders["docs"] = ["docs/readme.md"]
        metadata.recentNotes = ["docs/readme.md"]
        try await metadataStore.save(metadata)
        
        // 重命名目录
        _ = try await folderUseCases.renameFolder(
            repoId: repoId,
            rootURL: tempDir,
            oldPath: "docs",
            newPath: "documentation",
            browseUseCases: browseUseCases
        )
        
        // 重新加载元数据（因为 FolderUseCases 使用自己的 metadataStore 实例）
        await metadataStore.invalidateCache()
        let updatedMetadata = try await metadataStore.load()
        XCTAssertNil(updatedMetadata.folderOrders["docs"])
        XCTAssertEqual(updatedMetadata.folderOrders["documentation"], ["documentation/readme.md"])
        XCTAssertEqual(updatedMetadata.recentNotes, ["documentation/readme.md"])
    }
    
    func testMoveFolder_MigratesMetadata() async throws {
        try createFolder("source")
        try createFolder("target")
        try createFile("source/note.md")
        
        // 设置初始元数据
        var metadata = try await metadataStore.load()
        metadata.folderOrders["source"] = ["source/note.md"]
        metadata.recentNotes = ["source/note.md"]
        try await metadataStore.save(metadata)
        
        // 移动目录
        _ = try await folderUseCases.moveFolder(
            repoId: repoId,
            rootURL: tempDir,
            folderPath: "source",
            newParentPath: "target",
            browseUseCases: browseUseCases
        )
        
        // 重新加载元数据（因为 FolderUseCases 使用自己的 metadataStore 实例）
        await metadataStore.invalidateCache()
        let updatedMetadata = try await metadataStore.load()
        XCTAssertNil(updatedMetadata.folderOrders["source"])
        XCTAssertEqual(updatedMetadata.folderOrders["target/source"], ["target/source/note.md"])
        XCTAssertEqual(updatedMetadata.recentNotes, ["target/source/note.md"])
    }
    
    func testDeleteFolder_CleansMetadata() async throws {
        try createFolder("toDelete")
        try createFile("toDelete/note.md")
        
        // 设置初始元数据
        var metadata = try await metadataStore.load()
        metadata.folderOrders["toDelete"] = ["toDelete/note.md"]
        metadata.folderOrders[""] = ["toDelete", "other"]
        metadata.recentNotes = ["toDelete/note.md", "other/note.md"]
        try await metadataStore.save(metadata)
        
        // 删除目录
        try await folderUseCases.deleteFolder(
            repoId: repoId,
            rootURL: tempDir,
            path: "toDelete",
            force: true,
            browseUseCases: browseUseCases
        )
        
        // 重新加载元数据（因为 FolderUseCases 使用自己的 metadataStore 实例）
        await metadataStore.invalidateCache()
        let updatedMetadata = try await metadataStore.load()
        XCTAssertNil(updatedMetadata.folderOrders["toDelete"])
        XCTAssertEqual(updatedMetadata.folderOrders[""], ["other"])
        XCTAssertEqual(updatedMetadata.recentNotes, ["other/note.md"])
    }
    
    // MARK: - Scan Regression Tests
    
    func testCreateFolder_ScanReflectsChange() async throws {
        // 创建目录
        _ = try await folderUseCases.createFolder(
            repoId: repoId,
            rootURL: tempDir,
            path: "newFolder",
            browseUseCases: browseUseCases
        )
        
        // 扫描并验证
        let tree = try await browseUseCases.loadRepoTree(
            repoId: repoId,
            rootURL: tempDir,
            forceRefresh: true
        )
        
        let folderNames = tree.rootNodes.compactMap { node -> String? in
            if case .folder(let info) = node { return info.name }
            return nil
        }
        
        XCTAssertTrue(folderNames.contains("newFolder"))
    }
}

