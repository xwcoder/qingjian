//
//  QingJianMacApp.swift
//  QingJianMac
//
//  Created by speckit on 2025-12-25.
//

import SwiftUI
import QingJianCore

@main
struct QingJianMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建笔记") {
                    // TODO: Implement new note
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("打开仓库...") {
                    // TODO: Implement open repo
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .sidebar) {
                Button("切换侧边栏") {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(
                        #selector(NSSplitViewController.toggleSidebar(_:)),
                        with: nil
                    )
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 记录冷启动时间
        PerfMetrics.shared.record(.appColdStart, durationMs: 0)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("editorFontSize") private var editorFontSize = 14.0
    @AppStorage("vimModeEnabled") private var vimModeEnabled = false
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                isDarkMode: $isDarkMode,
                editorFontSize: $editorFontSize
            )
            .tabItem {
                Label("通用", systemImage: "gear")
            }
            
            EditorSettingsView(
                vimModeEnabled: $vimModeEnabled
            )
            .tabItem {
                Label("编辑器", systemImage: "pencil")
            }
        }
        .frame(width: 450, height: 250)
    }
}

struct GeneralSettingsView: View {
    @Binding var isDarkMode: Bool
    @Binding var editorFontSize: Double
    
    var body: some View {
        Form {
            Toggle("使用暗色模式", isOn: $isDarkMode)
            
            Slider(value: $editorFontSize, in: 10...24, step: 1) {
                Text("字体大小: \(Int(editorFontSize))")
            }
        }
        .padding()
    }
}

struct EditorSettingsView: View {
    @Binding var vimModeEnabled: Bool
    
    var body: some View {
        Form {
            Toggle("启用 Vim 模式", isOn: $vimModeEnabled)
            
            Text("Vim 模式支持基础操作：hjkl 移动、v 选择、d 删除、u 撤销、/ 查找")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
