//
//  CoreError.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  跨平台错误类型（对齐 contracts/errors.md）
//

import Foundation

/// 核心错误类型
public enum CoreError: LocalizedError, Equatable, Sendable {
    
    // MARK: - Repo 错误
    
    /// Repo 路径无效或不可用
    case invalidRepo(path: String)
    
    /// Repo 已添加
    case alreadyAdded(id: String)
    
    /// Repo 未找到
    case repoNotFound(id: String)
    
    /// Repo 不可用
    case repoUnavailable(id: String, reason: String?)
    
    // MARK: - 目录错误
    
    /// 目录未找到
    case folderNotFound(path: String)
    
    /// 目录已存在（重名冲突）
    case folderAlreadyExists(path: String)
    
    /// 非法的目录移动（例如移动到自身或子目录）
    case invalidFolderMove(path: String, reason: String)
    
    /// 目录非空（删除时未确认）
    case folderNotEmpty(path: String)
    
    // MARK: - 笔记错误
    
    /// 笔记未找到
    case noteNotFound(path: String)
    
    /// 笔记已存在（重名冲突）
    case noteAlreadyExists(path: String)
    
    /// 笔记读取失败
    case noteReadFailed(path: String, reason: String)
    
    /// 笔记保存失败
    case noteSaveFailed(path: String, reason: String)
    
    /// 笔记已被外部修改（冲突）
    case noteConflict(path: String)
    
    // MARK: - 文件系统错误
    
    /// 权限被拒绝
    case permissionDenied(path: String)
    
    /// 路径不存在
    case pathNotFound(path: String)
    
    /// IO 错误
    case ioError(path: String, reason: String)
    
    // MARK: - 渲染错误
    
    /// 渲染失败
    case renderFailed(reason: String)
    
    /// 图片加载失败
    case imageLoadFailed(path: String, reason: String)
    
    // MARK: - 同步错误
    
    /// iCloud 不可用
    case iCloudUnavailable(reason: String)
    
    /// 同步冲突
    case syncConflict(path: String, localVersion: String, remoteVersion: String)
    
    // MARK: - 购买错误
    
    /// 试用已过期
    case trialExpired(feature: String)
    
    /// 购买失败
    case purchaseFailed(reason: String)
    
    /// 购买已取消
    case purchaseCancelled
    
    // MARK: - LocalizedError
    
    public var errorDescription: String? {
        switch self {
        case .invalidRepo(let path):
            return "无效的仓库路径: \(path)"
        case .alreadyAdded(let id):
            return "仓库已添加: \(id)"
        case .repoNotFound(let id):
            return "未找到仓库: \(id)"
        case .repoUnavailable(let id, let reason):
            return "仓库不可用: \(id)" + (reason.map { " - \($0)" } ?? "")
        case .folderNotFound(let path):
            return "未找到目录: \(path)"
        case .folderAlreadyExists(let path):
            return "目录已存在: \(path)"
        case .invalidFolderMove(let path, let reason):
            return "非法的目录移动: \(path) - \(reason)"
        case .folderNotEmpty(let path):
            return "目录非空: \(path)"
        case .noteNotFound(let path):
            return "未找到笔记: \(path)"
        case .noteAlreadyExists(let path):
            return "笔记已存在: \(path)"
        case .noteReadFailed(let path, let reason):
            return "笔记读取失败: \(path) - \(reason)"
        case .noteSaveFailed(let path, let reason):
            return "笔记保存失败: \(path) - \(reason)"
        case .noteConflict(let path):
            return "笔记已被外部修改: \(path)"
        case .permissionDenied(let path):
            return "权限被拒绝: \(path)"
        case .pathNotFound(let path):
            return "路径不存在: \(path)"
        case .ioError(let path, let reason):
            return "IO 错误: \(path) - \(reason)"
        case .renderFailed(let reason):
            return "渲染失败: \(reason)"
        case .imageLoadFailed(let path, let reason):
            return "图片加载失败: \(path) - \(reason)"
        case .iCloudUnavailable(let reason):
            return "iCloud 不可用: \(reason)"
        case .syncConflict(let path, _, _):
            return "同步冲突: \(path)"
        case .trialExpired(let feature):
            return "试用期已结束，\(feature)需要购买完整版"
        case .purchaseFailed(let reason):
            return "购买失败: \(reason)"
        case .purchaseCancelled:
            return "购买已取消"
        }
    }
}
