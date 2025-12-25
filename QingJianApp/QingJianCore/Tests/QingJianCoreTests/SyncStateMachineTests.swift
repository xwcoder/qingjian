//
//  SyncStateMachineTests.swift
//  QingJianCoreTests
//
//  Created by speckit on 2025-12-25.
//

import XCTest
@testable import QingJianCore

final class SyncStateMachineTests: XCTestCase {
    
    var syncUseCases: SyncUseCases!
    
    override func setUp() async throws {
        syncUseCases = SyncUseCases()
    }
    
    // MARK: - Sync State Tests
    
    func testInitialState_Idle() async {
        let state = await syncUseCases.getSyncState(repoId: "test")
        XCTAssertEqual(state, .idle)
    }
    
    func testStateTransition_IdleToSyncing() async throws {
        await syncUseCases.setSyncState(repoId: "test", state: .syncing)
        let state = await syncUseCases.getSyncState(repoId: "test")
        XCTAssertEqual(state, .syncing)
    }
    
    func testStateTransition_SyncingToCompleted() async throws {
        await syncUseCases.setSyncState(repoId: "test", state: .syncing)
        await syncUseCases.setSyncState(repoId: "test", state: .completed)
        let state = await syncUseCases.getSyncState(repoId: "test")
        XCTAssertEqual(state, .completed)
    }
    
    func testStateTransition_SyncingToFailed() async throws {
        await syncUseCases.setSyncState(repoId: "test", state: .syncing)
        await syncUseCases.setSyncState(repoId: "test", state: .failed(reason: "Network error"))
        let state = await syncUseCases.getSyncState(repoId: "test")
        if case .failed(let reason) = state {
            XCTAssertEqual(reason, "Network error")
        } else {
            XCTFail("Expected failed state")
        }
    }
    
    // MARK: - Conflict Tests
    
    func testDetectConflict() async throws {
        let conflict = SyncConflict(
            id: UUID().uuidString,
            repoId: "test",
            path: "note.md",
            localVersion: "v1",
            remoteVersion: "v2",
            detectedAt: Date()
        )
        
        await syncUseCases.addConflict(conflict)
        
        let conflicts = await syncUseCases.getConflicts(repoId: "test")
        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.path, "note.md")
    }
    
    func testResolveConflict_KeepLocal() async throws {
        let conflict = SyncConflict(
            id: "conflict-1",
            repoId: "test",
            path: "note.md",
            localVersion: "v1",
            remoteVersion: "v2",
            detectedAt: Date()
        )
        
        await syncUseCases.addConflict(conflict)
        
        await syncUseCases.resolveConflict(id: "conflict-1", resolution: .keepLocal)
        
        let conflicts = await syncUseCases.getConflicts(repoId: "test")
        XCTAssertTrue(conflicts.isEmpty)
    }
    
    func testResolveConflict_KeepRemote() async throws {
        let conflict = SyncConflict(
            id: "conflict-1",
            repoId: "test",
            path: "note.md",
            localVersion: "v1",
            remoteVersion: "v2",
            detectedAt: Date()
        )
        
        await syncUseCases.addConflict(conflict)
        
        await syncUseCases.resolveConflict(id: "conflict-1", resolution: .keepRemote)
        
        let conflicts = await syncUseCases.getConflicts(repoId: "test")
        XCTAssertTrue(conflicts.isEmpty)
    }
    
    func testMultipleConflicts() async throws {
        let conflict1 = SyncConflict(id: "c1", repoId: "test", path: "a.md", localVersion: "v1", remoteVersion: "v2", detectedAt: Date())
        let conflict2 = SyncConflict(id: "c2", repoId: "test", path: "b.md", localVersion: "v1", remoteVersion: "v2", detectedAt: Date())
        let conflict3 = SyncConflict(id: "c3", repoId: "other", path: "c.md", localVersion: "v1", remoteVersion: "v2", detectedAt: Date())
        
        await syncUseCases.addConflict(conflict1)
        await syncUseCases.addConflict(conflict2)
        await syncUseCases.addConflict(conflict3)
        
        let testConflicts = await syncUseCases.getConflicts(repoId: "test")
        XCTAssertEqual(testConflicts.count, 2)
        
        let otherConflicts = await syncUseCases.getConflicts(repoId: "other")
        XCTAssertEqual(otherConflicts.count, 1)
    }
    
    // MARK: - iCloud Availability Tests
    
    func testICloudAvailability() async {
        // 在测试环境中，iCloud 通常不可用
        let isAvailable = await syncUseCases.checkICloudAvailability()
        // 不断言具体值，因为取决于测试环境
        _ = isAvailable
    }
    
    // MARK: - Sync Enable/Disable Tests
    
    func testEnableSync() async throws {
        // 在没有 iCloud 的测试环境中，应该抛出错误
        let isAvailable = await syncUseCases.checkICloudAvailability()
        
        if isAvailable {
            try await syncUseCases.enableSync(repoId: "test")
            let isEnabled = await syncUseCases.isSyncEnabled(repoId: "test")
            XCTAssertTrue(isEnabled)
        } else {
            // 在 CI 或没有 iCloud 的环境中，预期抛出错误
            do {
                try await syncUseCases.enableSync(repoId: "test")
                XCTFail("Should throw error when iCloud is not available")
            } catch let error as CoreError {
                if case .iCloudUnavailable = error {
                    // Expected
                } else {
                    XCTFail("Wrong error: \(error)")
                }
            }
        }
    }
    
    func testDisableSync() async throws {
        // 测试禁用同步（不需要 iCloud 可用）
        await syncUseCases.disableSync(repoId: "test")
        let isEnabled = await syncUseCases.isSyncEnabled(repoId: "test")
        XCTAssertFalse(isEnabled)
    }
}

