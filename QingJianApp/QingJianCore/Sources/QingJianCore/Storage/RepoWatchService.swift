//
//  RepoWatchService.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  文件系统变更监听与去抖批处理
//

import Foundation

/// 文件变更事件
public struct FileChangeEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case created
        case modified
        case deleted
        case renamed(oldPath: String)
    }
    
    public let path: String
    public let kind: Kind
    public let timestamp: Date
    
    public init(path: String, kind: Kind, timestamp: Date = Date()) {
        self.path = path
        self.kind = kind
        self.timestamp = timestamp
    }
}

/// Repo 文件监听服务
public actor RepoWatchService {
    
    private let repoId: String
    private let repoRootURL: URL
    private let eventBus: CoreEventBus
    
    /// 去抖间隔（毫秒）
    private let debounceInterval: UInt64
    
    /// 待处理的变更事件（去抖缓冲）
    private var pendingChanges: [FileChangeEvent] = []
    
    /// 去抖任务
    private var debounceTask: Task<Void, Never>?
    
    /// 文件系统监听源（DispatchSource）
    private var fileDescriptor: Int32?
    private var dispatchSource: DispatchSourceFileSystemObject?
    
    /// 是否正在监听
    private(set) var isWatching: Bool = false
    
    public init(
        repoId: String,
        repoRootURL: URL,
        eventBus: CoreEventBus,
        debounceIntervalMs: UInt64 = 300
    ) {
        self.repoId = repoId
        self.repoRootURL = repoRootURL
        self.eventBus = eventBus
        self.debounceInterval = debounceIntervalMs
    }
    
    deinit {
        // 清理资源
        dispatchSource?.cancel()
        if let fd = fileDescriptor {
            close(fd)
        }
    }
    
    // MARK: - Start/Stop
    
    /// 开始监听
    public func startWatching() {
        guard !isWatching else { return }
        
        let fd = open(repoRootURL.path, O_EVTONLY)
        guard fd >= 0 else {
            // 无法打开目录，可能权限问题
            return
        }
        
        fileDescriptor = fd
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task {
                await self.handleFileSystemEvent()
            }
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        dispatchSource = source
        source.resume()
        isWatching = true
    }
    
    /// 停止监听
    public func stopWatching() {
        guard isWatching else { return }
        
        debounceTask?.cancel()
        debounceTask = nil
        
        dispatchSource?.cancel()
        dispatchSource = nil
        fileDescriptor = nil
        
        isWatching = false
    }
    
    // MARK: - Event Handling
    
    /// 处理文件系统事件
    private func handleFileSystemEvent() {
        // 添加到待处理队列
        let event = FileChangeEvent(path: "", kind: .modified)
        pendingChanges.append(event)
        
        // 重置去抖计时器
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: debounceInterval * 1_000_000)
            guard !Task.isCancelled else { return }
            await flushPendingChanges()
        }
    }
    
    /// 批量处理待处理的变更
    private func flushPendingChanges() async {
        guard !pendingChanges.isEmpty else { return }
        
        let changes = pendingChanges
        pendingChanges = []
        
        // 收集受影响的路径（简化处理：整个 Repo 标记为变更）
        let affectedPaths = changes.map { $0.path }.filter { !$0.isEmpty }
        
        // 发出事件
        eventBus.emit(.repoChanged(repoId: repoId, affectedPaths: affectedPaths))
    }
    
    // MARK: - Manual Trigger
    
    /// 手动触发重新扫描（例如从后台恢复时）
    public func triggerRescan() {
        eventBus.emit(.repoChanged(repoId: repoId, affectedPaths: []))
    }
    
    /// 通知特定笔记被外部修改
    public func notifyNoteExternallyModified(notePath: String) {
        eventBus.emit(.noteExternallyModified(repoId: repoId, path: notePath))
    }
}

