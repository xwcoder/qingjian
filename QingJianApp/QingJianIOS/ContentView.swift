//
//  ContentView.swift
//  QingJianIOS
//
//  Created by speckit on 2025-12-25.
//

import SwiftUI
import QingJianCore

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        TabView {
            RepoListView(viewModel: viewModel)
                .tabItem {
                    Label("仓库", systemImage: "folder")
                }
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
    }
}

// MARK: - Main ViewModel

@MainActor
class MainViewModel: ObservableObject {
    @Published var repos: [RepoSummary] = []
    @Published var selectedRepo: RepoSummary?
    @Published var error: String?
    @Published var showingError = false
    
    private let repoUseCases: RepoUseCases
    
    init() {
        // 使用持久化存储初始化
        let registryStore = try? JSONRepoRegistryStore.defaultStore()
        self.repoUseCases = RepoUseCases(registryStore: registryStore)
        
        Task {
            await loadFromRegistry()
            await loadRepos()
        }
    }
    
    private func loadFromRegistry() async {
        try? await repoUseCases.loadFromRegistry()
    }
    
    func loadRepos() async {
        repos = await repoUseCases.listRepos()
    }
    
    /// 新建仓库（createRepo 语义：确保元信息存在）
    func createRepo(url: URL, name: String) async {
        do {
            _ = try await repoUseCases.createRepo(rootURL: url, displayName: name)
            await loadRepos()
        } catch {
            self.error = error.localizedDescription
            self.showingError = true
        }
    }
    
    /// 打开已有仓库（openRepo 语义：必须含有效元信息）
    func openRepo(url: URL, name: String) async {
        do {
            _ = try await repoUseCases.openRepo(rootURL: url, displayName: name)
            await loadRepos()
        } catch {
            self.error = error.localizedDescription
            self.showingError = true
        }
    }
    
    /// 兼容入口（默认走 createRepo）
    func addRepo(url: URL, name: String) async {
        await createRepo(url: url, name: name)
    }
    
    func removeRepo(id: String) async {
        do {
            try await repoUseCases.removeRepo(id: id)
            await loadRepos()
        } catch {
            self.error = error.localizedDescription
            self.showingError = true
        }
    }
    
    /// 重新定位仓库 (T036)
    func relinkRepo(id: String, newURL: URL) async {
        do {
            try await repoUseCases.relinkRepo(id: id, newRootURL: newURL)
            await loadRepos()
        } catch {
            self.error = error.localizedDescription
            self.showingError = true
        }
    }
}

// MARK: - Repo List View

struct RepoListView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var showingCreateRepo = false
    @State private var showingOpenRepo = false
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.repos.isEmpty {
                    ContentUnavailableView(
                        "没有仓库",
                        systemImage: "folder.badge.plus",
                        description: Text("点击右上角添加您的第一个仓库")
                    )
                } else {
                    ForEach(viewModel.repos) { repo in
                        NavigationLink {
                            RepoDetailView(repo: repo)
                        } label: {
                            RepoRowView(repo: repo, viewModel: viewModel)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let repo = viewModel.repos[index]
                            Task {
                                await viewModel.removeRepo(id: repo.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("青简")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingCreateRepo = true
                        } label: {
                            Label("新建仓库", systemImage: "folder.badge.plus")
                        }
                        
                        Button {
                            showingOpenRepo = true
                        } label: {
                            Label("打开仓库", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await viewModel.loadRepos()
            }
            .sheet(isPresented: $showingCreateRepo) {
                CreateRepoView(viewModel: viewModel, isPresented: $showingCreateRepo)
            }
            .sheet(isPresented: $showingOpenRepo) {
                OpenRepoView(viewModel: viewModel, isPresented: $showingOpenRepo)
            }
            .alert("错误", isPresented: $viewModel.showingError) {
                Button("确定") {}
            } message: {
                Text(viewModel.error ?? "未知错误")
            }
        }
    }
}

// MARK: - Repo Row View

struct RepoRowView: View {
    let repo: RepoSummary
    @ObservedObject var viewModel: MainViewModel
    @State private var showingRelinkPicker = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: repo.isAvailable ? "folder.fill" : "folder.badge.questionmark")
                .font(.title2)
                .foregroundStyle(repo.isAvailable ? .blue : .orange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(repo.displayName)
                    .font(.headline)
                
                if !repo.isAvailable {
                    HStack(spacing: 8) {
                        Text("不可用")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        
                        Button("重新定位") {
                            showingRelinkPicker = true
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .fileImporter(
            isPresented: $showingRelinkPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await viewModel.relinkRepo(id: repo.id, newURL: url)
                    }
                }
            case .failure:
                break
            }
        }
    }
}

// MARK: - Create Repo View（新建仓库）

struct CreateRepoView: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var isPresented: Bool
    @State private var selectedURL: URL?
    @State private var repoName: String = ""
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingFilePicker = true
                    } label: {
                        HStack {
                            Text("选择文件夹")
                            Spacer()
                            if let url = selectedURL {
                                Text(url.lastPathComponent)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("未选择")
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("仓库位置")
                } footer: {
                    Text("选择一个空文件夹或现有目录，将其初始化为青简仓库")
                }
                
                Section {
                    TextField("仓库名称", text: $repoName)
                } header: {
                    Text("显示名称")
                } footer: {
                    Text("留空将使用文件夹名称")
                }
            }
            .navigationTitle("新建仓库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("新建") {
                        guard let url = selectedURL else { return }
                        Task {
                            await viewModel.createRepo(
                                url: url,
                                name: repoName.isEmpty ? url.lastPathComponent : repoName
                            )
                            isPresented = false
                        }
                    }
                    .disabled(selectedURL == nil)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedURL = url
                        if repoName.isEmpty {
                            repoName = url.lastPathComponent
                        }
                    }
                case .failure:
                    break
                }
            }
        }
    }
}

// MARK: - Open Repo View（打开已有仓库）

struct OpenRepoView: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var isPresented: Bool
    @State private var selectedURL: URL?
    @State private var repoName: String = ""
    @State private var showingFilePicker = false
    @State private var validationError: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingFilePicker = true
                    } label: {
                        HStack {
                            Text("选择仓库文件夹")
                            Spacer()
                            if let url = selectedURL {
                                Text(url.lastPathComponent)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("未选择")
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    if let error = validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("仓库位置")
                } footer: {
                    Text("选择一个包含 .qingjian_metadata.json 的已有仓库目录")
                }
                
                Section {
                    TextField("显示名称", text: $repoName)
                } header: {
                    Text("显示名称（可选）")
                } footer: {
                    Text("留空将使用文件夹名称")
                }
            }
            .navigationTitle("打开仓库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("打开") {
                        guard let url = selectedURL else { return }
                        Task {
                            await viewModel.openRepo(
                                url: url,
                                name: repoName.isEmpty ? url.lastPathComponent : repoName
                            )
                            isPresented = false
                        }
                    }
                    .disabled(selectedURL == nil || validationError != nil)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        // 需要获取安全访问权限
                        guard url.startAccessingSecurityScopedResource() else {
                            validationError = "无法访问所选文件夹"
                            return
                        }
                        defer { url.stopAccessingSecurityScopedResource() }
                        
                        selectedURL = url
                        if repoName.isEmpty {
                            repoName = url.lastPathComponent
                        }
                        
                        // 校验元信息
                        if let error = RepoMetadataStore.validateMetadata(at: url) {
                            validationError = "无法识别为青简仓库: \(error)"
                        } else {
                            validationError = nil
                        }
                    }
                case .failure:
                    break
                }
            }
        }
    }
}

// MARK: - Repo Detail View

struct RepoDetailView: View {
    let repo: RepoSummary
    
    @State private var tree: RepoTreeSnapshot?
    @State private var selectedNotePath: String?
    @State private var isLoading = false
    @State private var error: String?
    
    private let browseUseCases = BrowseUseCases()
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载中...")
            } else if let error {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let tree, !tree.rootNodes.isEmpty {
                List(selection: $selectedNotePath) {
                    TreeNodeListView(
                        nodes: tree.rootNodes,
                        repoId: repo.id,
                        rootURL: URL(fileURLWithPath: repo.rootPath)
                    )
                }
            } else {
                ContentUnavailableView(
                    "空仓库",
                    systemImage: "folder",
                    description: Text("此仓库中没有笔记")
                )
            }
        }
        .navigationTitle(repo.displayName)
        .task {
            await loadTree()
        }
        .refreshable {
            await loadTree(forceRefresh: true)
        }
    }
    
    private func loadTree(forceRefresh: Bool = false) async {
        isLoading = true
        error = nil
        
        do {
            tree = try await browseUseCases.loadRepoTree(
                repoId: repo.id,
                rootURL: URL(fileURLWithPath: repo.rootPath),
                forceRefresh: forceRefresh
            )
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Tree Node List View

struct TreeNodeListView: View {
    let nodes: [TreeNode]
    let repoId: String
    let rootURL: URL
    
    var body: some View {
        ForEach(nodes) { node in
            switch node {
            case .folder(let folder):
                DisclosureGroup {
                    TreeNodeListView(
                        nodes: folder.children,
                        repoId: repoId,
                        rootURL: rootURL
                    )
                } label: {
                    Label(folder.name, systemImage: "folder.fill")
                        .foregroundStyle(.primary)
                }
                
            case .note(let note):
                NavigationLink {
                    NoteViewerView(
                        repoId: repoId,
                        rootURL: rootURL,
                        notePath: note.path,
                        title: note.displayTitle
                    )
                } label: {
                    Label(note.displayTitle, systemImage: "doc.text")
                }
            }
        }
    }
}

// MARK: - Note Viewer View

struct NoteViewerView: View {
    let repoId: String
    let rootURL: URL
    let notePath: String
    let title: String
    
    @State private var document: NoteDocument?
    @State private var renderedHTML: String?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showShareSheet = false
    
    private let browseUseCases = BrowseUseCases()
    private let renderer = MarkdownRenderer()
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载中...")
            } else if let error {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let html = renderedHTML {
                NoteWebView(html: html)
            } else {
                ContentUnavailableView(
                    "无内容",
                    systemImage: "doc.text",
                    description: Text("笔记内容为空")
                )
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(document == nil)
            }
        }
        .task {
            await loadNote()
        }
        .sheet(isPresented: $showShareSheet) {
            if let content = document?.content {
                ShareSheet(items: [content])
            }
        }
    }
    
    private func loadNote() async {
        isLoading = true
        error = nil
        
        do {
            let doc = try await browseUseCases.openNote(
                repoId: repoId,
                rootURL: rootURL,
                notePath: notePath
            )
            document = doc
            
            let rendered = try await renderer.render(document: doc)
            renderedHTML = rendered.htmlContent
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Note Web View (iOS)

import WebKit

struct NoteWebView: UIViewRepresentable {
    let html: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("外观") {
                    Toggle("暗色模式", isOn: $isDarkMode)
                }
                
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(QingJianCore.version)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    ContentView()
}

