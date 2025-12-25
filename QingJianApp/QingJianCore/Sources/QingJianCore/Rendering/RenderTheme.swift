//
//  RenderTheme.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  渲染主题（亮色/暗色，支持系统跟随）
//

import Foundation

/// 渲染主题
public struct RenderTheme: Equatable, Hashable, Sendable {
    
    /// 主题名称
    public let name: String
    
    /// 是否为暗色主题
    public let isDark: Bool
    
    /// CSS 样式
    public let cssStyles: String
    
    public init(name: String, isDark: Bool, cssStyles: String) {
        self.name = name
        self.isDark = isDark
        self.cssStyles = cssStyles
    }
    
    // MARK: - 预设主题
    
    /// 默认亮色主题
    public static let `default` = RenderTheme(
        name: "Default Light",
        isDark: false,
        cssStyles: Self.lightCSS
    )
    
    /// 默认暗色主题
    public static let dark = RenderTheme(
        name: "Default Dark",
        isDark: true,
        cssStyles: Self.darkCSS
    )
    
    // MARK: - CSS 样式
    
    private static let commonCSS = """
        :root {
            --font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
            --font-family-mono: ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas, Liberation Mono, monospace;
            --base-font-size: 16px;
            --line-height: 1.6;
        }
        
        * {
            box-sizing: border-box;
        }
        
        body {
            font-family: var(--font-family);
            font-size: var(--base-font-size);
            line-height: var(--line-height);
            margin: 0;
            padding: 16px;
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale;
        }
        
        .markdown-body {
            max-width: 800px;
            margin: 0 auto;
        }
        
        h1, h2, h3, h4, h5, h6 {
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
        }
        
        h1 { font-size: 2em; border-bottom: 1px solid var(--border-color); padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid var(--border-color); padding-bottom: 0.3em; }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1em; }
        h5 { font-size: 0.875em; }
        h6 { font-size: 0.85em; }
        
        p {
            margin-top: 0;
            margin-bottom: 16px;
        }
        
        a {
            color: var(--link-color);
            text-decoration: none;
        }
        
        a:hover {
            text-decoration: underline;
        }
        
        blockquote {
            margin: 0 0 16px;
            padding: 0 1em;
            border-left: 0.25em solid var(--blockquote-border);
            color: var(--blockquote-color);
        }
        
        code.inline-code {
            padding: 0.2em 0.4em;
            margin: 0;
            font-size: 85%;
            background-color: var(--code-bg);
            border-radius: 6px;
            font-family: var(--font-family-mono);
        }
        
        pre.code-block {
            padding: 16px;
            overflow: auto;
            font-size: 85%;
            line-height: 1.45;
            background-color: var(--code-block-bg);
            border-radius: 6px;
            margin-bottom: 16px;
        }
        
        pre.code-block code {
            display: block;
            padding: 0;
            margin: 0;
            overflow: visible;
            line-height: inherit;
            word-wrap: normal;
            background-color: transparent;
            border: 0;
            font-family: var(--font-family-mono);
        }
        
        ul, ol {
            margin-top: 0;
            margin-bottom: 16px;
            padding-left: 2em;
        }
        
        li {
            margin-top: 0.25em;
        }
        
        li + li {
            margin-top: 0.25em;
        }
        
        img.markdown-image {
            max-width: 100%;
            height: auto;
            border-radius: 4px;
        }
        
        img.image-error {
            min-width: 100px;
            min-height: 50px;
            background-color: var(--error-bg);
            border: 1px dashed var(--error-border);
        }
        
        img.image-error::before {
            content: "图片加载失败";
            display: block;
            text-align: center;
            padding: 20px;
            color: var(--error-color);
        }
        
        table {
            border-collapse: collapse;
            width: 100%;
            margin-bottom: 16px;
        }
        
        table th, table td {
            padding: 8px 12px;
            border: 1px solid var(--table-border);
        }
        
        table th {
            background-color: var(--table-header-bg);
            font-weight: 600;
        }
        
        table tr:nth-child(even) {
            background-color: var(--table-row-bg);
        }
        """
    
    private static let lightCSS = commonCSS + """
        
        :root {
            --bg-color: #ffffff;
            --text-color: #24292f;
            --link-color: #0969da;
            --border-color: hsla(210, 18%, 87%, 1);
            --blockquote-border: #d0d7de;
            --blockquote-color: #57606a;
            --code-bg: rgba(175, 184, 193, 0.2);
            --code-block-bg: #f6f8fa;
            --error-bg: #fff5f5;
            --error-border: #ff6b6b;
            --error-color: #c53030;
            --table-border: #d0d7de;
            --table-header-bg: #f6f8fa;
            --table-row-bg: #f6f8fa;
        }
        
        body.light {
            background-color: var(--bg-color);
            color: var(--text-color);
        }
        """
    
    private static let darkCSS = commonCSS + """
        
        :root {
            --bg-color: #0d1117;
            --text-color: #c9d1d9;
            --link-color: #58a6ff;
            --border-color: #30363d;
            --blockquote-border: #3b434b;
            --blockquote-color: #8b949e;
            --code-bg: rgba(110, 118, 129, 0.4);
            --code-block-bg: #161b22;
            --error-bg: #3d1a1a;
            --error-border: #ff6b6b;
            --error-color: #ffa0a0;
            --table-border: #30363d;
            --table-header-bg: #161b22;
            --table-row-bg: #161b22;
        }
        
        body.dark {
            background-color: var(--bg-color);
            color: var(--text-color);
        }
        """
}

