//
//  RepoAvailability.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  Repo 可用性状态
//

import Foundation

/// Repo 可用性状态
public enum RepoAvailabilityState: Equatable, Sendable {
    case available
    case unavailable(reason: String?)
    case recovering
}

/// Repo 可用性检查工具
public enum RepoAvailabilityChecker {
    
    /// 检查 Repo 根目录可用性
    ///
    /// - Parameter url: Repo 根目录 URL
    /// - Returns: 可用性状态
    public static func checkAvailability(at url: URL) -> RepoAvailabilityState {
        let fileManager = FileManager.default
        
        // 检查路径是否存在
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return .unavailable(reason: "路径不存在")
        }
        
        // 检查是否为目录
        guard isDirectory.boolValue else {
            return .unavailable(reason: "路径不是目录")
        }
        
        // 检查读取权限
        guard fileManager.isReadableFile(atPath: url.path) else {
            return .unavailable(reason: "没有读取权限")
        }
        
        // 检查写入权限（用于保存元数据）
        guard fileManager.isWritableFile(atPath: url.path) else {
            return .unavailable(reason: "没有写入权限")
        }
        
        return .available
    }
    
    /// 检查是否为 iCloud Drive 路径
    public static func isICloudPath(_ url: URL) -> Bool {
        let path = url.path
        return path.contains("/Library/Mobile Documents/") ||
               path.contains("/iCloud~") ||
               path.contains("com~apple~CloudDocs")
    }
}

// MARK: - Backward compatibility
public typealias RepoAvailability = RepoAvailabilityChecker
