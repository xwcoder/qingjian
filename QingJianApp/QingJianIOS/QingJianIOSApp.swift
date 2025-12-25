//
//  QingJianIOSApp.swift
//  QingJianIOS
//
//  Created by speckit on 2025-12-25.
//

import SwiftUI
import QingJianCore

@main
struct QingJianIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 记录冷启动时间
        PerfMetrics.shared.record(.appColdStart, durationMs: 0)
        return true
    }
}
