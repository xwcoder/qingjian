//
//  ImageInsertCoordinator.swift
//  QingJianMac
//
//  Created by speckit on 2025-12-25.
//
//  图片导入与插入协调器
//

import SwiftUI
import UniformTypeIdentifiers
import QingJianCore

/// 图片插入协调器
@MainActor
class ImageInsertCoordinator: ObservableObject {
    
    @Published var isShowingFilePicker = false
    @Published var isImporting = false
    @Published var error: String?
    @Published var showingError = false
    
    private let assetUseCases = AssetUseCases()
    
    /// 插入回调
    var onInsert: ((String) -> Void)?
    
    // MARK: - Public API
    
    /// 显示文件选择器
    func showFilePicker() {
        isShowingFilePicker = true
    }
    
    /// 处理拖拽的文件
    func handleDrop(providers: [NSItemProvider], repoRootURL: URL, notePath: String) async -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                if let url = await loadURL(from: provider) {
                    await importAndInsert(sourceURL: url, repoRootURL: repoRootURL, notePath: notePath)
                    return true
                }
            }
        }
        return false
    }
    
    /// 处理选择的文件
    func handleSelectedFile(url: URL, repoRootURL: URL, notePath: String) async {
        await importAndInsert(sourceURL: url, repoRootURL: repoRootURL, notePath: notePath)
    }
    
    /// 处理粘贴的图片
    func handlePaste(repoRootURL: URL, notePath: String) async -> Bool {
        let pasteboard = NSPasteboard.general
        
        // 检查是否有文件 URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first,
           isImageFile(url) {
            await importAndInsert(sourceURL: url, repoRootURL: repoRootURL, notePath: notePath)
            return true
        }
        
        // 检查是否有图片数据
        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            await importFromData(data: data, repoRootURL: repoRootURL, notePath: notePath)
            return true
        }
        
        return false
    }
    
    // MARK: - Private
    
    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func importAndInsert(sourceURL: URL, repoRootURL: URL, notePath: String) async {
        isImporting = true
        defer { isImporting = false }
        
        do {
            let result = try await assetUseCases.importLocalImage(
                sourceURL: sourceURL,
                repoRootURL: repoRootURL,
                targetFolder: "assets",
                relativeToNotePath: notePath
            )
            
            onInsert?(result.markdownReference)
        } catch {
            self.error = error.localizedDescription
            self.showingError = true
        }
    }
    
    private func importFromData(data: Data, repoRootURL: URL, notePath: String) async {
        isImporting = true
        defer { isImporting = false }
        
        // 保存到临时文件
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("paste_\(Int(Date().timeIntervalSince1970)).png")
        
        do {
            try data.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            
            let result = try await assetUseCases.importLocalImage(
                sourceURL: tempURL,
                repoRootURL: repoRootURL,
                targetFolder: "assets",
                relativeToNotePath: notePath
            )
            
            onInsert?(result.markdownReference)
        } catch {
            self.error = error.localizedDescription
            self.showingError = true
        }
    }
    
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff", "heic"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}

// MARK: - Image Insert View

struct ImageInsertButton: View {
    let repoRootURL: URL
    let notePath: String
    let onInsert: (String) -> Void
    
    @StateObject private var coordinator = ImageInsertCoordinator()
    
    var body: some View {
        Button {
            coordinator.showFilePicker()
        } label: {
            Image(systemName: "photo")
        }
        .help("插入图片")
        .fileImporter(
            isPresented: $coordinator.isShowingFilePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await coordinator.handleSelectedFile(
                            url: url,
                            repoRootURL: repoRootURL,
                            notePath: notePath
                        )
                    }
                }
            case .failure:
                break
            }
        }
        .alert("导入失败", isPresented: $coordinator.showingError) {
            Button("确定") {}
        } message: {
            Text(coordinator.error ?? "未知错误")
        }
        .onAppear {
            coordinator.onInsert = onInsert
        }
    }
}

// MARK: - Drop Delegate

struct ImageDropDelegate: DropDelegate {
    let repoRootURL: URL
    let notePath: String
    let onInsert: (String) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.image])
    }
    
    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.image])
        guard !providers.isEmpty else { return false }
        
        let coordinator = ImageInsertCoordinator()
        coordinator.onInsert = onInsert
        
        Task {
            _ = await coordinator.handleDrop(
                providers: providers,
                repoRootURL: repoRootURL,
                notePath: notePath
            )
        }
        
        return true
    }
}

