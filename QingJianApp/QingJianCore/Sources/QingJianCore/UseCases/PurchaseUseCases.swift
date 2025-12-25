//
//  PurchaseUseCases.swift
//  QingJianCore
//
//  Created by speckit on 2025-12-25.
//
//  购买用例（试用期、购买状态、功能 gating）
//

import Foundation
import StoreKit

/// 购买状态
public enum PurchaseStatus: Equatable, Sendable {
    case unknown
    case trial(daysRemaining: Int)
    case trialExpired
    case purchased
}

/// 购买用例
public actor PurchaseUseCases {
    
    /// 产品 ID
    public static let productId = "com.qingjian.fullversion"
    
    /// 试用天数
    public static let trialDays = 7
    
    /// 用户默认存储键
    private enum UserDefaultsKey {
        static let firstLaunchDate = "qingjian.firstLaunchDate"
        static let purchaseDate = "qingjian.purchaseDate"
    }
    
    /// 当前状态
    private var currentStatus: PurchaseStatus = .unknown
    
    /// 事件总线
    private let eventBus: CoreEventBus?
    
    public init(eventBus: CoreEventBus? = nil) {
        self.eventBus = eventBus
    }
    
    // MARK: - Initialize
    
    /// 初始化购买状态
    public func initialize() async {
        // 检查是否已购买
        if await checkPurchased() {
            currentStatus = .purchased
            return
        }
        
        // 检查试用状态
        let trialStatus = checkTrialStatus()
        currentStatus = trialStatus
    }
    
    // MARK: - Get Status
    
    /// 获取当前购买状态
    public func getStatus() -> PurchaseStatus {
        return currentStatus
    }
    
    /// 是否已解锁完整功能
    public func isUnlocked() -> Bool {
        switch currentStatus {
        case .purchased, .trial:
            return true
        case .trialExpired, .unknown:
            return false
        }
    }
    
    // MARK: - Trial
    
    /// 检查试用状态
    private func checkTrialStatus() -> PurchaseStatus {
        let defaults = UserDefaults.standard
        
        // 获取首次启动日期
        let firstLaunchDate: Date
        if let stored = defaults.object(forKey: UserDefaultsKey.firstLaunchDate) as? Date {
            firstLaunchDate = stored
        } else {
            // 首次启动，记录日期
            firstLaunchDate = Date()
            defaults.set(firstLaunchDate, forKey: UserDefaultsKey.firstLaunchDate)
        }
        
        // 计算剩余天数
        let daysSinceFirstLaunch = Calendar.current.dateComponents(
            [.day],
            from: firstLaunchDate,
            to: Date()
        ).day ?? 0
        
        let daysRemaining = Self.trialDays - daysSinceFirstLaunch
        
        if daysRemaining > 0 {
            return .trial(daysRemaining: daysRemaining)
        } else {
            return .trialExpired
        }
    }
    
    /// 获取试用剩余天数
    public func getTrialDaysRemaining() -> Int {
        switch currentStatus {
        case .trial(let days):
            return days
        default:
            return 0
        }
    }
    
    // MARK: - Purchase
    
    /// 检查是否已购买
    private func checkPurchased() async -> Bool {
        // 检查 UserDefaults（用于快速检查）
        let defaults = UserDefaults.standard
        if defaults.object(forKey: UserDefaultsKey.purchaseDate) != nil {
            // 验证 StoreKit
            return await verifyPurchaseWithStoreKit()
        }
        return false
    }
    
    /// 使用 StoreKit 验证购买
    private func verifyPurchaseWithStoreKit() async -> Bool {
        do {
            // 使用 StoreKit 2 验证
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if transaction.productID == Self.productId {
                        return true
                    }
                }
            }
        } catch {
            // StoreKit 验证失败，回退到本地记录
            return UserDefaults.standard.object(forKey: UserDefaultsKey.purchaseDate) != nil
        }
        return false
    }
    
    /// 购买产品
    public func purchase() async throws {
        // 获取产品
        let products = try await Product.products(for: [Self.productId])
        guard let product = products.first else {
            throw CoreError.purchaseFailed(reason: "产品不存在")
        }
        
        // 发起购买
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                // 购买成功
                await transaction.finish()
                UserDefaults.standard.set(Date(), forKey: UserDefaultsKey.purchaseDate)
                currentStatus = .purchased
                eventBus?.emit(.purchaseCompleted(productId: Self.productId))
                
            case .unverified:
                throw CoreError.purchaseFailed(reason: "购买验证失败")
            }
            
        case .userCancelled:
            throw CoreError.purchaseCancelled
            
        case .pending:
            throw CoreError.purchaseFailed(reason: "购买待处理")
            
        @unknown default:
            throw CoreError.purchaseFailed(reason: "未知错误")
        }
    }
    
    /// 恢复购买
    public func restore() async throws {
        try await AppStore.sync()
        
        if await verifyPurchaseWithStoreKit() {
            UserDefaults.standard.set(Date(), forKey: UserDefaultsKey.purchaseDate)
            currentStatus = .purchased
            eventBus?.emit(.purchaseRestored(productId: Self.productId))
        } else {
            throw CoreError.purchaseFailed(reason: "未找到可恢复的购买")
        }
    }
    
    // MARK: - Feature Gating
    
    /// 检查功能是否可用
    public func isFeatureAvailable(_ feature: GatedFeature) -> Bool {
        switch currentStatus {
        case .purchased:
            return true
        case .trial:
            // 试用期间所有功能可用
            return true
        case .trialExpired, .unknown:
            // 试用过期后，限制某些功能
            return feature.availableInExpiredTrial
        }
    }
    
    /// 检查并抛出错误（用于需要完整功能的操作）
    public func requireUnlocked() throws {
        guard isUnlocked() else {
            throw CoreError.trialExpired(feature: "此功能")
        }
    }
}

/// 受限功能
public enum GatedFeature: String, Sendable {
    case createNote = "创建笔记"
    case editNote = "编辑笔记"
    case viewNote = "查看笔记"
    case addRepo = "添加仓库"
    case exportRepo = "导出仓库"
    case iCloudSync = "iCloud 同步"
    
    /// 试用过期后是否仍可用
    var availableInExpiredTrial: Bool {
        switch self {
        case .viewNote:
            return true // 仅查看可用
        case .createNote, .editNote, .addRepo, .exportRepo, .iCloudSync:
            return false
        }
    }
}

