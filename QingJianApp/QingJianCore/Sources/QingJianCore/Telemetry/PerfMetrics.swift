//
//  PerfMetrics.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  性能埋点（对齐 plan.md 性能指标）
//

import Foundation

/// 性能指标名称
public enum PerfMetric: String, Sendable {
    // 启动
    case appColdStart = "app.cold_start"
    case appWarmStart = "app.warm_start"
    
    // Repo
    case repoCreate = "repo.create"
    case repoOpen = "repo.open"
    case repoScan = "repo.scan"
    case repoWatch = "repo.watch"
    case repoListLoad = "repo.list.load"
    
    // 笔记
    case noteOpen = "note.open"
    case noteSave = "note.save"
    case noteSwitch = "note.switch"
    case noteCreate = "note.create"
    case noteRename = "note.rename"
    case noteMove = "note.move"
    case noteDelete = "note.delete"
    
    // 目录
    case folderCreate = "folder.create"
    case folderRename = "folder.rename"
    case folderMove = "folder.move"
    case folderDelete = "folder.delete"
    
    // 渲染
    case renderTotal = "render.total"
    case renderParse = "render.parse"
    case renderHTML = "render.html"
    case renderImage = "render.image"
    
    // 编辑
    case editorKeyLatency = "editor.key_latency"
    case previewUpdate = "preview.update"
    
    // 同步
    case syncCycle = "sync.cycle"
    case syncUpload = "sync.upload"
    case syncDownload = "sync.download"
}

/// 性能埋点
public final class PerfMetrics: @unchecked Sendable {
    
    public static let shared = PerfMetrics()
    
    /// 是否启用
    public var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    /// 性能数据回调
    public var onMetric: ((PerfMetric, TimeInterval, [String: String]) -> Void)?
    
    private init() {}
    
    // MARK: - Public API
    
    /// 记录指标
    public func record(_ metric: PerfMetric, durationMs: TimeInterval, context: [String: String] = [:]) {
        guard isEnabled else { return }
        
        #if DEBUG
        print("📊 [\(metric.rawValue)] \(String(format: "%.2f", durationMs))ms \(context)")
        #endif
        
        onMetric?(metric, durationMs, context)
    }
    
    /// 测量同步操作
    public func measureSync<T>(
        _ metric: PerfMetric,
        context: [String: String] = [:],
        block: () throws -> T
    ) rethrows -> T {
        guard isEnabled else { return try block() }
        
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        
        record(metric, durationMs: duration, context: context)
        return result
    }
    
    /// 测量异步操作
    public func measure<T>(
        _ metric: PerfMetric,
        context: [String: String] = [:],
        block: () async throws -> T
    ) async rethrows -> T {
        guard isEnabled else { return try await block() }
        
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        
        record(metric, durationMs: duration, context: context)
        return result
    }
    
    /// 开始计时
    public func startTimer() -> CFAbsoluteTime {
        return CFAbsoluteTimeGetCurrent()
    }
    
    /// 结束计时并记录
    public func endTimer(_ start: CFAbsoluteTime, metric: PerfMetric, context: [String: String] = [:]) {
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        record(metric, durationMs: duration, context: context)
    }
}
