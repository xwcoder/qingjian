//
//  RepoPathValidator.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  路径校验与冲突检测（重名/非法移动/越界）
//

import Foundation

/// 路径校验器
public struct RepoPathValidator {
    
    private let repoRootURL: URL
    
    public init(repoRootURL: URL) {
        self.repoRootURL = repoRootURL
    }
    
    private var fileManager: FileManager { .default }
    
    // MARK: - Public API
    
    /// 检查路径是否在仓库范围内
    public func isWithinRepo(_ relativePath: String) -> Bool {
        let fullURL = repoRootURL.appendingPathComponent(relativePath).standardizedFileURL
        return fullURL.path.hasPrefix(repoRootURL.standardizedFileURL.path)
    }
    
    /// 检查路径是否存在
    public func exists(_ relativePath: String) -> Bool {
        let url = repoRootURL.appendingPathComponent(relativePath)
        return fileManager.fileExists(atPath: url.path)
    }
    
    /// 检查路径是否为目录
    public func isDirectory(_ relativePath: String) -> Bool {
        let url = repoRootURL.appendingPathComponent(relativePath)
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
    
    /// 检查路径是否为文件
    public func isFile(_ relativePath: String) -> Bool {
        let url = repoRootURL.appendingPathComponent(relativePath)
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
    }
    
    /// 验证目录创建（检查重名）
    /// - Returns: 如果验证通过返回 nil，否则返回错误
    public func validateFolderCreate(at relativePath: String) -> CoreError? {
        // 检查是否在仓库范围内
        guard isWithinRepo(relativePath) else {
            return .ioError(path: relativePath, reason: "路径超出仓库范围")
        }
        
        // 检查是否已存在
        if exists(relativePath) {
            return .folderAlreadyExists(path: relativePath)
        }
        
        return nil
    }
    
    /// 验证目录重命名/移动
    /// - Parameters:
    ///   - oldPath: 原路径
    ///   - newPath: 新路径
    /// - Returns: 如果验证通过返回 nil，否则返回错误
    public func validateFolderMove(from oldPath: String, to newPath: String) -> CoreError? {
        // 检查原路径是否存在
        guard exists(oldPath) else {
            return .folderNotFound(path: oldPath)
        }
        
        // 检查原路径是否为目录
        guard isDirectory(oldPath) else {
            return .folderNotFound(path: oldPath)
        }
        
        // 检查新路径是否在仓库范围内
        guard isWithinRepo(newPath) else {
            return .ioError(path: newPath, reason: "目标路径超出仓库范围")
        }
        
        // 检查是否移动到自身
        let normalizedOld = normalizePath(oldPath)
        let normalizedNew = normalizePath(newPath)
        
        if normalizedOld == normalizedNew {
            return .invalidFolderMove(path: oldPath, reason: "不能移动到自身")
        }
        
        // 检查是否移动到子目录
        if normalizedNew.hasPrefix(normalizedOld + "/") {
            return .invalidFolderMove(path: oldPath, reason: "不能移动到自身的子目录")
        }
        
        // 检查目标是否已存在
        if exists(newPath) {
            return .folderAlreadyExists(path: newPath)
        }
        
        return nil
    }
    
    /// 验证目录删除
    /// - Parameters:
    ///   - path: 目录路径
    ///   - allowNonEmpty: 是否允许删除非空目录
    /// - Returns: 如果验证通过返回 nil，否则返回错误
    public func validateFolderDelete(at path: String, allowNonEmpty: Bool) -> CoreError? {
        // 检查是否存在
        guard exists(path) else {
            return .folderNotFound(path: path)
        }
        
        // 检查是否为目录
        guard isDirectory(path) else {
            return .folderNotFound(path: path)
        }
        
        // 检查是否非空
        if !allowNonEmpty && !isFolderEmpty(path) {
            return .folderNotEmpty(path: path)
        }
        
        return nil
    }
    
    /// 验证笔记创建（检查重名）
    public func validateNoteCreate(at relativePath: String) -> CoreError? {
        // 检查是否在仓库范围内
        guard isWithinRepo(relativePath) else {
            return .ioError(path: relativePath, reason: "路径超出仓库范围")
        }
        
        // 检查是否已存在
        if exists(relativePath) {
            return .noteAlreadyExists(path: relativePath)
        }
        
        return nil
    }
    
    /// 验证笔记重命名/移动
    public func validateNoteMove(from oldPath: String, to newPath: String) -> CoreError? {
        // 检查原路径是否存在
        guard exists(oldPath) else {
            return .noteNotFound(path: oldPath)
        }
        
        // 检查原路径是否为文件
        guard isFile(oldPath) else {
            return .noteNotFound(path: oldPath)
        }
        
        // 检查新路径是否在仓库范围内
        guard isWithinRepo(newPath) else {
            return .ioError(path: newPath, reason: "目标路径超出仓库范围")
        }
        
        // 检查目标是否已存在
        if exists(newPath) {
            return .noteAlreadyExists(path: newPath)
        }
        
        return nil
    }
    
    /// 验证笔记删除
    public func validateNoteDelete(at path: String) -> CoreError? {
        // 检查是否存在
        guard exists(path) else {
            return .noteNotFound(path: path)
        }
        
        // 检查是否为文件
        guard isFile(path) else {
            return .noteNotFound(path: path)
        }
        
        return nil
    }
    
    // MARK: - Private
    
    /// 规范化路径（去除尾部斜杠、处理 . 和 ..）
    private func normalizePath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path, relativeTo: repoRootURL)
        return url.standardizedFileURL.path
            .replacingOccurrences(of: repoRootURL.standardizedFileURL.path, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    
    /// 检查目录是否为空
    private func isFolderEmpty(_ relativePath: String) -> Bool {
        let url = repoRootURL.appendingPathComponent(relativePath)
        guard let contents = try? fileManager.contentsOfDirectory(atPath: url.path) else {
            return true
        }
        // 过滤隐藏文件
        let visibleContents = contents.filter { !$0.hasPrefix(".") }
        return visibleContents.isEmpty
    }
}

