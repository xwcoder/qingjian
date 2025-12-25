//
//  UseCaseImportImageTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//

import XCTest
@testable import QingJianCore

final class UseCaseImportImageTests: XCTestCase {
    
    var tempDir: URL!
    var sourceDir: URL!
    var assetUseCases: AssetUseCases!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        sourceDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_source")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        assetUseCases = AssetUseCases()
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: sourceDir)
    }
    
    // MARK: - Helper
    
    private func createTestImage(at url: URL) throws {
        // Create a minimal PNG file (1x1 pixel)
        let pngData = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
            0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0xCC, 0x59,
            0xE7, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND chunk
            0x44, 0xAE, 0x42, 0x60, 0x82
        ])
        try pngData.write(to: url)
    }
    
    // MARK: - Import Tests
    
    func testImportLocalImage_Success() async throws {
        // Create source image
        let sourceImageURL = sourceDir.appendingPathComponent("photo.png")
        try createTestImage(at: sourceImageURL)
        
        let result = try await assetUseCases.importLocalImage(
            sourceURL: sourceImageURL,
            repoRootURL: tempDir,
            targetFolder: "assets"
        )
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.relativePath, "assets/photo.png")
        XCTAssertEqual(result.markdownReference, "![photo](assets/photo.png)")
        
        // Verify file was copied
        let targetURL = tempDir.appendingPathComponent("assets/photo.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetURL.path))
    }
    
    func testImportLocalImage_UniqueNaming() async throws {
        // Create existing file in assets
        let assetsDir = tempDir.appendingPathComponent("assets")
        try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        try createTestImage(at: assetsDir.appendingPathComponent("photo.png"))
        
        // Create source image with same name
        let sourceImageURL = sourceDir.appendingPathComponent("photo.png")
        try createTestImage(at: sourceImageURL)
        
        let result = try await assetUseCases.importLocalImage(
            sourceURL: sourceImageURL,
            repoRootURL: tempDir,
            targetFolder: "assets"
        )
        
        XCTAssertTrue(result.success)
        // Should have unique name
        XCTAssertNotEqual(result.relativePath, "assets/photo.png")
        XCTAssertTrue(result.relativePath.hasPrefix("assets/photo"))
        XCTAssertTrue(result.relativePath.hasSuffix(".png"))
    }
    
    func testImportLocalImage_InvalidSource() async throws {
        let invalidURL = sourceDir.appendingPathComponent("nonexistent.png")
        
        do {
            _ = try await assetUseCases.importLocalImage(
                sourceURL: invalidURL,
                repoRootURL: tempDir,
                targetFolder: "assets"
            )
            XCTFail("Should throw error")
        } catch let error as CoreError {
            if case .pathNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }
    
    func testImportLocalImage_UnsupportedFormat() async throws {
        // Create a text file with image extension
        let sourceURL = sourceDir.appendingPathComponent("fake.xyz")
        try "not an image".write(to: sourceURL, atomically: true, encoding: .utf8)
        
        do {
            _ = try await assetUseCases.importLocalImage(
                sourceURL: sourceURL,
                repoRootURL: tempDir,
                targetFolder: "assets"
            )
            XCTFail("Should throw error")
        } catch let error as CoreError {
            if case .imageLoadFailed = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }
    
    func testImportLocalImage_CustomFolder() async throws {
        let sourceImageURL = sourceDir.appendingPathComponent("screenshot.png")
        try createTestImage(at: sourceImageURL)
        
        let result = try await assetUseCases.importLocalImage(
            sourceURL: sourceImageURL,
            repoRootURL: tempDir,
            targetFolder: "images/screenshots"
        )
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.relativePath, "images/screenshots/screenshot.png")
        
        let targetURL = tempDir.appendingPathComponent("images/screenshots/screenshot.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetURL.path))
    }
    
    func testImportLocalImage_RelativeToNote() async throws {
        let sourceImageURL = sourceDir.appendingPathComponent("diagram.png")
        try createTestImage(at: sourceImageURL)
        
        let result = try await assetUseCases.importLocalImage(
            sourceURL: sourceImageURL,
            repoRootURL: tempDir,
            targetFolder: "assets",
            relativeToNotePath: "docs/guide.md"
        )
        
        XCTAssertTrue(result.success)
        // Reference should be relative to note location
        XCTAssertEqual(result.markdownReference, "![diagram](../assets/diagram.png)")
    }
    
    // MARK: - Generate Reference Tests
    
    func testGenerateMarkdownReference() async throws {
        let reference = await assetUseCases.generateMarkdownReference(
            relativePath: "assets/image.png",
            altText: "My Image"
        )
        
        XCTAssertEqual(reference, "![My Image](assets/image.png)")
    }
    
    func testGenerateMarkdownReference_DefaultAlt() async throws {
        let reference = await assetUseCases.generateMarkdownReference(
            relativePath: "assets/photo.png",
            altText: nil
        )
        
        XCTAssertEqual(reference, "![photo](assets/photo.png)")
    }
}

