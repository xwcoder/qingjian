//
//  ExportUseCaseTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//

import XCTest
@testable import QingJianCore

final class ExportUseCaseTests: XCTestCase {
    
    var tempDir: URL!
    var exportDir: URL!
    var exportUseCases: ExportUseCases!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        exportDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_export")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        exportUseCases = ExportUseCases()
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: exportDir)
    }
    
    // MARK: - Helper
    
    private func createFile(_ relativePath: String, content: String = "") throws {
        let url = tempDir.appendingPathComponent(relativePath)
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Export to Folder Tests
    
    func testExportToFolder_Success() async throws {
        // 直接在 tempDir 创建文件
        let fileURL = tempDir.appendingPathComponent("readme.md")
        try "# README".write(to: fileURL, atomically: true, encoding: .utf8)
        
        let targetDir = exportDir.appendingPathComponent("exported_\(UUID().uuidString)")
        
        let result = try await exportUseCases.exportToFolder(
            repoRootURL: tempDir,
            targetURL: targetDir
        )
        
        // 验证结果
        XCTAssertGreaterThanOrEqual(result.exportedFiles, 1, "Should export at least 1 file")
    }
    
    func testExportToFolder_ExcludesMetadata() async throws {
        // 直接在 tempDir 创建文件
        let fileURL = tempDir.appendingPathComponent("readme.md")
        try "# README".write(to: fileURL, atomically: true, encoding: .utf8)
        
        let targetDir = exportDir.appendingPathComponent("exported_\(UUID().uuidString)")
        
        let result = try await exportUseCases.exportToFolder(
            repoRootURL: tempDir,
            targetURL: targetDir
        )
        
        XCTAssertGreaterThanOrEqual(result.exportedFiles, 1)
    }
    
    func testExportToFolder_PreservesStructure() async throws {
        // 创建嵌套目录
        let nestedDir = tempDir.appendingPathComponent("a/b")
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        let fileURL = nestedDir.appendingPathComponent("deep.md")
        try "# Deep".write(to: fileURL, atomically: true, encoding: .utf8)
        
        let targetDir = exportDir.appendingPathComponent("exported_\(UUID().uuidString)")
        
        let result = try await exportUseCases.exportToFolder(
            repoRootURL: tempDir,
            targetURL: targetDir
        )
        
        XCTAssertGreaterThanOrEqual(result.exportedFiles, 1, "Should export at least 1 file")
    }
    
    // MARK: - Export Single Note Tests
    
    func testExportSingleNote() async throws {
        let content = "# My Note\n\nContent here."
        try createFile("note.md", content: content)
        
        let targetFile = exportDir.appendingPathComponent("exported_note.md")
        
        let result = try await exportUseCases.exportSingleNote(
            repoRootURL: tempDir,
            notePath: "note.md",
            targetURL: targetFile
        )
        
        XCTAssertTrue(result.success)
        
        let exportedContent = try String(contentsOf: targetFile, encoding: .utf8)
        XCTAssertEqual(exportedContent, content)
    }
    
    func testExportSingleNote_NotFound() async throws {
        let targetFile = exportDir.appendingPathComponent("exported_note.md")
        
        do {
            _ = try await exportUseCases.exportSingleNote(
                repoRootURL: tempDir,
                notePath: "nonexistent.md",
                targetURL: targetFile
            )
            XCTFail("Should throw error")
        } catch let error as CoreError {
            if case .noteNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }
    
    // MARK: - Export Stats Tests
    
    func testGetExportStats() async throws {
        try createFile("a.md", content: "# A")
        try createFile("b.md", content: "# B with more content")
        try createFile("docs/c.md", content: "# C")
        try createFile("assets/img.png", content: "fake png data")
        
        let stats = try await exportUseCases.getExportStats(repoRootURL: tempDir)
        
        XCTAssertEqual(stats.noteCount, 3)
        XCTAssertEqual(stats.assetCount, 1)
        XCTAssertGreaterThan(stats.totalSizeBytes, 0)
    }
    
    // MARK: - Export Filtered Tests
    
    func testExportFiltered_OnlyMarkdown() async throws {
        // 创建文件
        let noteURL = tempDir.appendingPathComponent("note.md")
        try "# Note".write(to: noteURL, atomically: true, encoding: .utf8)
        
        let imageURL = tempDir.appendingPathComponent("image.png")
        try "fake".write(to: imageURL, atomically: true, encoding: .utf8)
        
        let targetDir = exportDir.appendingPathComponent("filtered_\(UUID().uuidString)")
        
        let result = try await exportUseCases.exportFiltered(
            repoRootURL: tempDir,
            targetURL: targetDir,
            filter: .markdownOnly
        )
        
        XCTAssertGreaterThanOrEqual(result.exportedFiles, 1, "Should export at least 1 markdown file")
    }
    
    func testExportFiltered_WithAssets() async throws {
        // 创建文件
        let noteURL = tempDir.appendingPathComponent("note.md")
        try "# Note".write(to: noteURL, atomically: true, encoding: .utf8)
        
        let assetsDir = tempDir.appendingPathComponent("assets")
        try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        let imageURL = assetsDir.appendingPathComponent("image.png")
        try "fake".write(to: imageURL, atomically: true, encoding: .utf8)
        
        let targetDir = exportDir.appendingPathComponent("filtered_\(UUID().uuidString)")
        
        let result = try await exportUseCases.exportFiltered(
            repoRootURL: tempDir,
            targetURL: targetDir,
            filter: .markdownAndAssets
        )
        
        XCTAssertGreaterThanOrEqual(result.exportedFiles, 1, "Should export at least 1 file")
    }
}

