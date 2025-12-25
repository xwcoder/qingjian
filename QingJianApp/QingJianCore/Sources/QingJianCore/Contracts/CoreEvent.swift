//
//  CoreEvent.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  跨平台事件类型（对齐 contracts/events.md）
//

import Foundation
import Combine

/// 核心事件类型
public enum CoreEvent: Sendable {
    
    // MARK: - Repo 事件
    
    /// Repo 已添加
    case repoAdded(repoId: String)
    
    /// Repo 已移除
    case repoRemoved(repoId: String)
    
    /// Repo 可用性变化
    case repoAvailabilityChanged(repoId: String, state: RepoAvailabilityState)
    
    /// Repo 内容变化（外部修改）
    case repoContentChanged(repoId: String, changedPaths: Set<String>)
    
    /// Repo 内容变化（简化版）
    case repoChanged(repoId: String, affectedPaths: [String])
    
    // MARK: - 笔记事件
    
    /// 笔记已打开
    case noteOpened(repoId: String, path: String)
    
    /// 笔记已保存
    case noteSaved(repoId: String, path: String)
    
    /// 笔记已关闭
    case noteClosed(repoId: String, path: String)
    
    /// 笔记被外部修改
    case noteExternallyModified(repoId: String, path: String)
    
    // MARK: - 同步事件
    
    /// 同步状态变化
    case syncStatusChanged(repoId: String, status: SyncStatus)
    
    /// 同步冲突检测到
    case syncConflictDetected(repoId: String, path: String)
    
    // MARK: - 应用事件
    
    /// 主题变化
    case themeChanged(isDark: Bool)
    
    /// 试用状态变化
    case trialStatusChanged(isActive: Bool, daysRemaining: Int)
    
    // MARK: - 购买事件
    
    /// 购买完成
    case purchaseCompleted(productId: String)
    
    /// 购买已恢复
    case purchaseRestored(productId: String)
}

/// 同步状态
public enum SyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case completed
    case failed(reason: String)
}

/// 核心事件总线
public final class CoreEventBus: @unchecked Sendable {
    
    private let subject = PassthroughSubject<CoreEvent, Never>()
    private let lock = NSLock()
    
    public var publisher: AnyPublisher<CoreEvent, Never> {
        subject.eraseToAnyPublisher()
    }
    
    public init() {}
    
    /// 发送事件
    public func emit(_ event: CoreEvent) {
        lock.lock()
        defer { lock.unlock() }
        subject.send(event)
    }
}
