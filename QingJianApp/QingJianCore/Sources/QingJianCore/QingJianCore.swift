//
//  QingJianCore.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  青简核心模块
//

import Foundation

/// 青简核心模块版本
public let QingJianCoreVersion = "0.1.0"

/// 青简核心模块
public enum QingJianCore {
    
    /// 版本号
    public static var version: String { QingJianCoreVersion }
    
    /// 构建信息
    public static var buildInfo: String {
        #if DEBUG
        return "Debug"
        #else
        return "Release"
        #endif
    }
}

// MARK: - Re-exports

// Domain
public typealias Repo = Repository

// Use Cases
public typealias RepoManager = RepoUseCases
public typealias Browser = BrowseUseCases

// Rendering
public typealias Renderer = MarkdownRenderer
public typealias Theme = RenderTheme
