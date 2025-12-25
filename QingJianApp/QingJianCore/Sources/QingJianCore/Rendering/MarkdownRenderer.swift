//
//  MarkdownRenderer.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  Markdown 渲染器（满足标题/列表/代码块/引用/链接/图片；支持主题）
//

import Foundation

/// 渲染后的文档
public struct RenderedDocument: Equatable, Sendable {
    /// 渲染后的 HTML 或 AttributedString 表示
    public let htmlContent: String
    
    /// 原始 Markdown 内容
    public let sourceMarkdown: String
    
    /// 使用的主题
    public let theme: RenderTheme
    
    /// 渲染缓存键
    public let cacheKey: String
    
    /// 引用的图片（本地或在线）
    public let referencedImages: [ImageReference]
    
    public init(
        htmlContent: String,
        sourceMarkdown: String,
        theme: RenderTheme,
        cacheKey: String,
        referencedImages: [ImageReference] = []
    ) {
        self.htmlContent = htmlContent
        self.sourceMarkdown = sourceMarkdown
        self.theme = theme
        self.cacheKey = cacheKey
        self.referencedImages = referencedImages
    }
}

/// 图片引用
public struct ImageReference: Equatable, Sendable {
    public let altText: String
    public let source: String
    public let isLocal: Bool
    
    public init(altText: String, source: String, isLocal: Bool) {
        self.altText = altText
        self.source = source
        self.isLocal = isLocal
    }
}

/// Markdown 渲染器
public final class MarkdownRenderer: Sendable {
    
    private let theme: RenderTheme
    
    public init(theme: RenderTheme = .default) {
        self.theme = theme
    }
    
    // MARK: - UC-Render-01: Render Markdown
    
    /// 渲染 Markdown 为 HTML
    ///
    /// - Parameters:
    ///   - document: 笔记文档
    ///   - theme: 渲染主题（可选，默认使用初始化时的主题）
    /// - Returns: 渲染后的文档
    /// - Throws: `CoreError.renderFailed`
    public func render(document: NoteDocument, theme: RenderTheme? = nil) async throws -> RenderedDocument {
        let effectiveTheme = theme ?? self.theme
        
        let result = performRender(markdown: document.content, theme: effectiveTheme)
        let cacheKey = generateCacheKey(content: document.content, theme: effectiveTheme)
        
        return RenderedDocument(
            htmlContent: result.html,
            sourceMarkdown: document.content,
            theme: effectiveTheme,
            cacheKey: cacheKey,
            referencedImages: result.images
        )
    }
    
    /// 渲染 Markdown 字符串
    public func render(markdown: String, theme: RenderTheme? = nil) async throws -> RenderedDocument {
        let effectiveTheme = theme ?? self.theme
        
        let result = performRender(markdown: markdown, theme: effectiveTheme)
        let cacheKey = generateCacheKey(content: markdown, theme: effectiveTheme)
        
        return RenderedDocument(
            htmlContent: result.html,
            sourceMarkdown: markdown,
            theme: effectiveTheme,
            cacheKey: cacheKey,
            referencedImages: result.images
        )
    }
    
    // MARK: - Private
    
    private struct RenderResult {
        let html: String
        let images: [ImageReference]
    }
    
    private func performRender(markdown: String, theme: RenderTheme) -> RenderResult {
        // 简单的 Markdown -> HTML 转换（生产环境应使用 cmark 或其他库）
        var html = markdown
        var images: [ImageReference] = []
        
        // 处理标题
        html = processHeadings(html)
        
        // 处理代码块
        html = processCodeBlocks(html, theme: theme)
        
        // 处理行内代码
        html = processInlineCode(html, theme: theme)
        
        // 处理引用
        html = processBlockquotes(html, theme: theme)
        
        // 处理列表
        html = processLists(html)
        
        // 处理图片（并收集引用）
        (html, images) = processImages(html)
        
        // 处理链接
        html = processLinks(html)
        
        // 处理段落
        html = processParagraphs(html)
        
        // 处理粗体和斜体
        html = processEmphasis(html)
        
        // 包装为完整 HTML
        html = wrapInHTML(html, theme: theme)
        
        return RenderResult(html: html, images: images)
    }
    
    private func processHeadings(_ text: String) -> String {
        var result = text
        // H1 - H6
        for level in (1...6).reversed() {
            let prefix = String(repeating: "#", count: level)
            let pattern = "(?m)^\(prefix) (.+)$"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "<h\(level)>$1</h\(level)>"
                )
            }
        }
        return result
    }
    
    private func processCodeBlocks(_ text: String, theme: RenderTheme) -> String {
        var result = text
        // 代码块 ```lang ... ```
        let pattern = "(?s)```(\\w*)\\n(.*?)```"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<pre class=\"code-block\"><code class=\"language-$1\">$2</code></pre>"
            )
        }
        return result
    }
    
    private func processInlineCode(_ text: String, theme: RenderTheme) -> String {
        var result = text
        let pattern = "`([^`]+)`"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<code class=\"inline-code\">$1</code>"
            )
        }
        return result
    }
    
    private func processBlockquotes(_ text: String, theme: RenderTheme) -> String {
        var result = text
        let pattern = "(?m)^> (.+)$"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<blockquote>$1</blockquote>"
            )
        }
        return result
    }
    
    private func processLists(_ text: String) -> String {
        var result = text
        // 无序列表
        let ulPattern = "(?m)^- (.+)$"
        if let regex = try? NSRegularExpression(pattern: ulPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<li>$1</li>"
            )
        }
        // 简化处理：将连续的 <li> 包装在 <ul> 中
        result = result.replacingOccurrences(of: "(<li>.*</li>\n?)+", with: "<ul>$0</ul>", options: .regularExpression)
        return result
    }
    
    private func processImages(_ text: String) -> (String, [ImageReference]) {
        var result = text
        var images: [ImageReference] = []
        
        let pattern = "!\\[([^\\]]*)\\]\\(([^)]+)\\)"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches.reversed() {
                if let altRange = Range(match.range(at: 1), in: text),
                   let srcRange = Range(match.range(at: 2), in: text) {
                    let alt = String(text[altRange])
                    let src = String(text[srcRange])
                    let isLocal = !src.hasPrefix("http://") && !src.hasPrefix("https://")
                    images.append(ImageReference(altText: alt, source: src, isLocal: isLocal))
                }
            }
            
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<img src=\"$2\" alt=\"$1\" class=\"markdown-image\" onerror=\"this.classList.add('image-error')\" />"
            )
        }
        
        return (result, images)
    }
    
    private func processLinks(_ text: String) -> String {
        var result = text
        let pattern = "\\[([^\\]]+)\\]\\(([^)]+)\\)"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<a href=\"$2\">$1</a>"
            )
        }
        return result
    }
    
    private func processParagraphs(_ text: String) -> String {
        var result = text
        // 简化处理：将非标签开头的行包装为 <p>
        let lines = result.components(separatedBy: "\n\n")
        result = lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("<") {
                return line
            }
            return "<p>\(line)</p>"
        }.joined(separator: "\n")
        return result
    }
    
    private func processEmphasis(_ text: String) -> String {
        var result = text
        // 粗体 **text**
        if let regex = try? NSRegularExpression(pattern: "\\*\\*([^*]+)\\*\\*") {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<strong>$1</strong>"
            )
        }
        // 斜体 *text*
        if let regex = try? NSRegularExpression(pattern: "\\*([^*]+)\\*") {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<em>$1</em>"
            )
        }
        return result
    }
    
    private func wrapInHTML(_ content: String, theme: RenderTheme) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                \(theme.cssStyles)
            </style>
        </head>
        <body class="\(theme.isDark ? "dark" : "light")">
            <article class="markdown-body">
                \(content)
            </article>
        </body>
        </html>
        """
    }
    
    private func generateCacheKey(content: String, theme: RenderTheme) -> String {
        let contentHash = content.hashValue
        let themeHash = theme.hashValue
        return "\(contentHash)-\(themeHash)"
    }
}
