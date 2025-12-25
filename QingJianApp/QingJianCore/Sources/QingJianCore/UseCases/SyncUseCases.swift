//
//  SyncUseCases.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  同步用例（iCloud 同步开关、状态、冲突管理）
//

import Foundation

/// 同步冲突
public struct SyncConflict: Identifiable, Equatable, Sendable {
    public let id: String
    public let repoId: String
    public let path: String
    public let localVersion: String
    public let remoteVersion: String
    public let detectedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        repoId: String,
        path: String,
        localVersion: String,
        remoteVersion: String,
        detectedAt: Date = Date()
    ) {
        self.id = id
        self.repoId = repoId
        self.path = path
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
        self.detectedAt = detectedAt
    }
}

/// 冲突解决方式
public enum ConflictResolution: String, Sendable {
    case keepLocal
    case keepRemote
    case merge
}

/// 同步用例
public actor SyncUseCases {
    
    /// 同步状态
    private var syncStates: [String: SyncStatus] = [:]
    
    /// 已启用同步的 Repo
    private var syncEnabledRepos: Set<String> = []
    
    /// 未解决的冲突
    private var conflicts: [String: SyncConflict] = [:]
    
    /// 事件总线
    private let eventBus: CoreEventBus?
    
    public init(eventBus: CoreEventBus? = nil) {
        self.eventBus = eventBus
    }
    
    // MARK: - iCloud Availability
    
    /// 检查 iCloud 是否可用
    public func checkICloudAvailability() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    // MARK: - Sync Enable/Disable
    
    /// 启用同步
    public func enableSync(repoId: String) throws {
        guard checkICloudAvailability() else {
            throw CoreError.iCloudUnavailable(reason: "iCloud 账户不可用")
        }
        
        syncEnabledRepos.insert(repoId)
        syncStates[repoId] = .idle
        
        eventBus?.emit(.syncStatusChanged(repoId: repoId, status: .idle))
    }
    
    /// 禁用同步
    public func disableSync(repoId: String) {
        syncEnabledRepos.remove(repoId)
        syncStates.removeValue(forKey: repoId)
    }
    
    /// 检查是否已启用同步
    public func isSyncEnabled(repoId: String) -> Bool {
        return syncEnabledRepos.contains(repoId)
    }
    
    // MARK: - Sync State
    
    /// 获取同步状态
    public func getSyncState(repoId: String) -> SyncStatus {
        return syncStates[repoId] ?? .idle
    }
    
    /// 设置同步状态
    public func setSyncState(repoId: String, state: SyncStatus) {
        syncStates[repoId] = state
        eventBus?.emit(.syncStatusChanged(repoId: repoId, status: state))
    }
    
    // MARK: - Conflict Management
    
    /// 添加冲突
    public func addConflict(_ conflict: SyncConflict) {
        conflicts[conflict.id] = conflict
        eventBus?.emit(.syncConflictDetected(repoId: conflict.repoId, path: conflict.path))
    }
    
    /// 获取指定 Repo 的冲突
    public func getConflicts(repoId: String) -> [SyncConflict] {
        return conflicts.values.filter { $0.repoId == repoId }
    }
    
    /// 获取所有冲突
    public func getAllConflicts() -> [SyncConflict] {
        return Array(conflicts.values)
    }
    
    /// 解决冲突
    public func resolveConflict(id: String, resolution: ConflictResolution) {
        guard let conflict = conflicts[id] else { return }
        
        // 移除冲突
        conflicts.removeValue(forKey: id)
        
        // TODO: 根据 resolution 执行实际的文件操作
        // - keepLocal: 保持本地版本，上传覆盖云端
        // - keepRemote: 下载云端版本覆盖本地
        // - merge: 需要用户手动处理
    }
    
    /// 清除已解决的冲突
    public func clearResolvedConflicts(repoId: String) {
        let keysToRemove = conflicts.filter { $0.value.repoId == repoId }.keys
        for key in keysToRemove {
            conflicts.removeValue(forKey: key)
        }
    }
    
    // MARK: - Sync Operations
    
    /// 触发同步
    public func triggerSync(repoId: String, rootURL: URL) async throws {
        guard isSyncEnabled(repoId: repoId) else {
            throw CoreError.iCloudUnavailable(reason: "同步未启用")
        }
        
        setSyncState(repoId: repoId, state: .syncing)
        
        do {
            // TODO: 实现实际的 iCloud 同步逻辑
            // 1. 检查云端变更
            // 2. 下载新文件
            // 3. 上传本地变更
            // 4. 检测冲突
            
            // 模拟同步完成
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            
            setSyncState(repoId: repoId, state: .completed)
        } catch {
            setSyncState(repoId: repoId, state: .failed(reason: error.localizedDescription))
            throw error
        }
    }
    
    /// 获取同步进度
    public func getSyncProgress(repoId: String) -> Double {
        switch syncStates[repoId] {
        case .idle:
            return 0
        case .syncing:
            return 0.5
        case .completed:
            return 1.0
        case .failed:
            return 0
        case .none:
            return 0
        }
    }
}

