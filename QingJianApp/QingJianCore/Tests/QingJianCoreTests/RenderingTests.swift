//
//  RenderingTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//

import XCTest
@testable import QingJianCore

final class RenderingTests: XCTestCase {
    
    var renderer: MarkdownRenderer!
    
    override func setUp() async throws {
        renderer = MarkdownRenderer()
    }
    
    // MARK: - Basic Rendering
    
    func testRenderHeadings() async throws {
        let markdown = """
        # Heading 1
        ## Heading 2
        ### Heading 3
        """
        
        let result = try await renderer.render(markdown: markdown)
        
        XCTAssertTrue(result.htmlContent.contains("<h1>Heading 1</h1>"))
        XCTAssertTrue(result.htmlContent.contains("<h2>Heading 2</h2>"))
        XCTAssertTrue(result.htmlContent.contains("<h3>Heading 3</h3>"))
    }
    
    func testRenderCodeBlock() async throws {
        let markdown = """
        ```swift
        let x = 1
        ```
        """
        
        let result = try await renderer.render(markdown: markdown)
        
        XCTAssertTrue(result.htmlContent.contains("<pre class=\"code-block\">"))
        XCTAssertTrue(result.htmlContent.contains("let x = 1"))
    }
    
    func testRenderInlineCode() async throws {
        let markdown = "Use `print()` to output"
        
        let result = try await renderer.render(markdown: markdown)
        
        XCTAssertTrue(result.htmlContent.contains("<code class=\"inline-code\">print()</code>"))
    }
    
    func testRenderBlockquote() async throws {
        let markdown = "> This is a quote"
        
        let result = try await renderer.render(markdown: markdown)
        
        XCTAssertTrue(result.htmlContent.contains("<blockquote>This is a quote</blockquote>"))
    }
    
    func testRenderList() async throws {
        let markdown = """
        - Item 1
        - Item 2
        """
        
        let result = try await renderer.render(markdown: markdown)
        
        XCTAssertTrue(result.htmlContent.contains("<li>Item 1</li>"))
        XCTAssertTrue(result.htmlContent.contains("<li>Item 2</li>"))
    }
    
    func testRenderLink() async throws {
        let markdown = "[Link](https://example.com)"
        
        let result = try await renderer.render(markdown: markdown)
        
        XCTAssertTrue(result.htmlContent.contains("<a href=\"https://example.com\">Link</a>"))
    }
    
    func testRenderImage() async throws {
        let markdown = "![Alt](image.png)"
        
        let result = try await renderer.render(markdown: markdown)
        
        XCTAssertTrue(result.htmlContent.contains("<img src=\"image.png\" alt=\"Alt\""))
        XCTAssertEqual(result.referencedImages.count, 1)
        XCTAssertEqual(result.referencedImages.first?.source, "image.png")
        XCTAssertTrue(result.referencedImages.first?.isLocal ?? false)
    }
    
    func testRenderRemoteImage() async throws {
        let markdown = "![Alt](https://example.com/image.png)"
        
        let result = try await renderer.render(markdown: markdown)
        
        XCTAssertEqual(result.referencedImages.count, 1)
        XCTAssertFalse(result.referencedImages.first?.isLocal ?? true)
    }
    
    // MARK: - Theme
    
    func testRenderWithDarkTheme() async throws {
        let markdown = "# Dark Mode"
        
        let result = try await renderer.render(markdown: markdown, theme: .dark)
        
        XCTAssertTrue(result.htmlContent.contains("class=\"dark\""))
        XCTAssertTrue(result.theme.isDark)
    }
    
    func testRenderWithLightTheme() async throws {
        let markdown = "# Light Mode"
        
        let result = try await renderer.render(markdown: markdown, theme: .default)
        
        XCTAssertTrue(result.htmlContent.contains("class=\"light\""))
        XCTAssertFalse(result.theme.isDark)
    }
    
    // MARK: - Cache Key
    
    func testCacheKeyDifferentContent() async throws {
        let result1 = try await renderer.render(markdown: "# A")
        let result2 = try await renderer.render(markdown: "# B")
        
        XCTAssertNotEqual(result1.cacheKey, result2.cacheKey)
    }
    
    func testCacheKeyDifferentTheme() async throws {
        let result1 = try await renderer.render(markdown: "# Test", theme: .default)
        let result2 = try await renderer.render(markdown: "# Test", theme: .dark)
        
        XCTAssertNotEqual(result1.cacheKey, result2.cacheKey)
    }
    
    // MARK: - Render Cache
    
    func testRenderCacheHit() async throws {
        let cache = RenderCache()
        
        let markdown = "# Test"
        let result = try await renderer.render(markdown: markdown)
        let modDate = Date()
        
        await cache.set(result, path: "test.md", modificationDate: modDate, contentHash: markdown.hashValue)
        
        // Use an earlier date for the query to ensure cache hit (entry.modificationDate >= query date)
        let cached = await cache.get(path: "test.md", modificationDate: modDate.addingTimeInterval(-1), contentHash: markdown.hashValue)
        
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.htmlContent, result.htmlContent)
    }
    
    func testRenderCacheMiss() async throws {
        let cache = RenderCache()
        
        let cached = await cache.get(path: "nonexistent.md", modificationDate: Date(), contentHash: 0)
        
        XCTAssertNil(cached)
    }
    
    func testRenderCacheInvalidation() async throws {
        let cache = RenderCache()
        
        let markdown = "# Test"
        let result = try await renderer.render(markdown: markdown)
        
        await cache.set(result, path: "test.md", modificationDate: Date(), contentHash: markdown.hashValue)
        await cache.invalidate(path: "test.md")
        
        let cached = await cache.get(path: "test.md", modificationDate: Date(), contentHash: markdown.hashValue)
        
        XCTAssertNil(cached)
    }
}

