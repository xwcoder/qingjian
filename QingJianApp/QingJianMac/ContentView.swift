//
//  ContentView.swift
//  QingJianMac
//
//  Created by speckit on 2025-12-25.
//

import SwiftUI
import QingJianCore

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } content: {
            if let selectedRepo = viewModel.selectedRepo {
                RepoTreeView(
                    repoId: selectedRepo.id,
                    rootURL: URL(fileURLWithPath: selectedRepo.rootPath),
                    selectedNotePath: $viewModel.selectedNotePath,
                    onNoteSelected: { path in
                        viewModel.selectedNotePath = path
                    }
                )
            } else {
                ContentUnavailableView(
                    "选择一个仓库",
                    systemImage: "folder",
                    description: Text("从侧边栏选择或添加一个仓库")
                )
            }
        } detail: {
            if let notePath = viewModel.selectedNotePath,
               let repo = viewModel.selectedRepo {
                NoteDetailView(
                    repoId: repo.id,
                    rootURL: URL(fileURLWithPath: repo.rootPath),
                    notePath: notePath
                )
            } else {
                ContentUnavailableView(
                    "选择一个笔记",
                    systemImage: "doc.text",
                    description: Text("从目录中选择一个笔记查看内容")
                )
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        // 菜单命令触发的 sheet
        .sheet(isPresented: $appState.showingCreateRepoSheet) {
            CreateRepoSheet(viewModel: viewModel, isPresented: $appState.showingCreateRepoSheet)
        }
        .sheet(isPresented: $appState.showingOpenRepoSheet) {
            OpenRepoSheet(viewModel: viewModel, isPresented: $appState.showingOpenRepoSheet)
        }
    }
}

// MARK: - Main ViewModel

@MainActor
class MainViewModel: ObservableObject {
    @Published var repos: [RepoSummary] = []
    @Published var selectedRepo: RepoSummary?
    @Published var selectedNotePath: String?
    @Published var isAddingRepo = false
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
        if selectedRepo == nil, let first = repos.first {
            selectedRepo = first
        }
    }
    
    /// 新建仓库（createRepo 语义：确保元信息存在）
    func createRepo(url: URL, name: String) async {
        do {
            let summary = try await repoUseCases.createRepo(rootURL: url, displayName: name)
            repos = await repoUseCases.listRepos()
            selectedRepo = summary
            selectedNotePath = nil
        } catch {
            self.error = error.localizedDescription
            self.showingError = true
        }
    }
    
    /// 打开已有仓库（openRepo 语义：必须含有效元信息）
    func openRepo(url: URL, name: String) async {
        do {
            let summary = try await repoUseCases.openRepo(rootURL: url, displayName: name)
            repos = await repoUseCases.listRepos()
            selectedRepo = summary
            selectedNotePath = nil
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
            repos = await repoUseCases.listRepos()
            if selectedRepo?.id == id {
                selectedRepo = repos.first
                selectedNotePath = nil
            }
        } catch {
            self.error = error.localizedDescription
            self.showingError = true
        }
    }
    
    func selectRepo(_ repo: RepoSummary) {
        selectedRepo = repo
        selectedNotePath = nil
    }
    
    /// 重新定位仓库 (T035)
    func relinkRepo(id: String, newURL: URL) async {
        do {
            try await repoUseCases.relinkRepo(id: id, newRootURL: newURL)
            repos = await repoUseCases.listRepos()
        } catch {
            self.error = error.localizedDescription
            self.showingError = true
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var showingCreateRepoSheet = false
    @State private var showingOpenRepoSheet = false
    
    var body: some View {
        List(selection: Binding(
            get: { viewModel.selectedRepo?.id },
            set: { id in
                if let id, let repo = viewModel.repos.first(where: { $0.id == id }) {
                    viewModel.selectRepo(repo)
                }
            }
        )) {
            Section("仓库") {
                ForEach(viewModel.repos) { repo in
                    HStack {
                        Image(systemName: repo.isAvailable ? "folder.fill" : "folder.badge.questionmark")
                            .foregroundStyle(repo.isAvailable ? .blue : .orange)
                        VStack(alignment: .leading) {
                            Text(repo.displayName)
                                .font(.headline)
                            Text(repo.rootPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .tag(repo.id)
                    .contextMenu {
                        if !repo.isAvailable {
                            Button {
                                relinkRepo(repo)
                            } label: {
                                Label("重新定位...", systemImage: "arrow.triangle.2.circlepath")
                            }
                            
                            Divider()
                        }
                        
                        Button(role: .destructive) {
                            Task {
                                await viewModel.removeRepo(id: repo.id)
                            }
                        } label: {
                            Label("移除仓库", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("青简")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingCreateRepoSheet = true
                    } label: {
                        Label("新建仓库", systemImage: "folder.badge.plus")
                    }
                    
                    Button {
                        showingOpenRepoSheet = true
                    } label: {
                        Label("打开仓库", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .help("添加仓库")
            }
        }
        .sheet(isPresented: $showingCreateRepoSheet) {
            CreateRepoSheet(viewModel: viewModel, isPresented: $showingCreateRepoSheet)
        }
        .sheet(isPresented: $showingOpenRepoSheet) {
            OpenRepoSheet(viewModel: viewModel, isPresented: $showingOpenRepoSheet)
        }
        .alert("错误", isPresented: $viewModel.showingError) {
            Button("确定") {}
        } message: {
            Text(viewModel.error ?? "未知错误")
        }
    }
    
    /// 重新定位仓库
    private func relinkRepo(_ repo: RepoSummary) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "选择"
        panel.message = "选择仓库「\(repo.displayName)」的新位置"
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await viewModel.relinkRepo(id: repo.id, newURL: url)
            }
        }
    }
}

// MARK: - Create Repo Sheet（新建仓库）

struct CreateRepoSheet: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var isPresented: Bool
    @State private var selectedURL: URL?
    @State private var repoName: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("新建仓库")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("选择一个空文件夹或现有目录，将其初始化为青简仓库")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("选择文件夹")
                    .font(.headline)
                
                HStack {
                    if let url = selectedURL {
                        Text(url.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("未选择")
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("浏览...") {
                        selectFolder()
                    }
                }
                .padding(8)
                .background(.quaternary)
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("仓库名称")
                    .font(.headline)
                
                TextField("输入名称", text: $repoName)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("新建") {
                    guard let url = selectedURL else { return }
                    Task {
                        await viewModel.createRepo(url: url, name: repoName.isEmpty ? url.lastPathComponent : repoName)
                        isPresented = false
                    }
                }
                .keyboardShortcut(.return)
                .disabled(selectedURL == nil)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "选择"
        panel.message = "选择一个文件夹作为新仓库的根目录"
        
        if panel.runModal() == .OK {
            selectedURL = panel.url
            if repoName.isEmpty, let url = panel.url {
                repoName = url.lastPathComponent
            }
        }
    }
}

// MARK: - Open Repo Sheet（打开已有仓库）

struct OpenRepoSheet: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var isPresented: Bool
    @State private var selectedURL: URL?
    @State private var repoName: String = ""
    @State private var validationError: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("打开仓库")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("选择一个包含 .qingjian_metadata.json 的已有仓库目录")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("选择仓库文件夹")
                    .font(.headline)
                
                HStack {
                    if let url = selectedURL {
                        Text(url.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("未选择")
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("浏览...") {
                        selectFolder()
                    }
                }
                .padding(8)
                .background(.quaternary)
                .cornerRadius(8)
                
                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("显示名称（可选）")
                    .font(.headline)
                
                TextField("使用文件夹名称", text: $repoName)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("打开") {
                    guard let url = selectedURL else { return }
                    Task {
                        await viewModel.openRepo(url: url, name: repoName.isEmpty ? url.lastPathComponent : repoName)
                        isPresented = false
                    }
                }
                .keyboardShortcut(.return)
                .disabled(selectedURL == nil || validationError != nil)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "打开"
        panel.message = "选择一个已有的青简仓库目录"
        
        if panel.runModal() == .OK, let url = panel.url {
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
    }
}

// MARK: - Repo Tree View

struct RepoTreeView: View {
    let repoId: String
    let rootURL: URL
    @Binding var selectedNotePath: String?
    let onNoteSelected: (String) -> Void
    
    @State private var tree: RepoTreeSnapshot?
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
            } else if let tree {
                List(selection: $selectedNotePath) {
                    TreeNodeListView(
                        nodes: tree.rootNodes,
                        selectedPath: $selectedNotePath,
                        onNoteSelected: onNoteSelected
                    )
                }
                .listStyle(.sidebar)
            } else {
                ContentUnavailableView(
                    "空仓库",
                    systemImage: "folder",
                    description: Text("此仓库中没有笔记")
                )
            }
        }
        .navigationTitle("目录")
        .task(id: repoId) {
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
                repoId: repoId,
                rootURL: rootURL,
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
    @Binding var selectedPath: String?
    let onNoteSelected: (String) -> Void
    
    var body: some View {
        ForEach(nodes) { node in
            switch node {
            case .folder(let folder):
                DisclosureGroup {
                    TreeNodeListView(
                        nodes: folder.children,
                        selectedPath: $selectedPath,
                        onNoteSelected: onNoteSelected
                    )
                } label: {
                    Label(folder.name, systemImage: "folder.fill")
                        .foregroundStyle(.primary)
                }
                
            case .note(let note):
                Label(note.displayTitle, systemImage: "doc.text")
                    .tag(note.path)
            }
        }
    }
}

// MARK: - Note Detail View

struct NoteDetailView: View {
    let repoId: String
    let rootURL: URL
    let notePath: String
    
    @State private var isEditing = false
    @State private var document: NoteDocument?
    @State private var renderedHTML: String?
    @State private var isLoading = false
    @State private var error: String?
    
    private let browseUseCases = BrowseUseCases()
    private let renderer = MarkdownRenderer()
    
    var body: some View {
        Group {
            if isEditing {
                EditorSplitView(
                    repoId: repoId,
                    rootURL: rootURL,
                    notePath: notePath
                )
            } else {
                viewModeContent
            }
        }
        .navigationTitle(document?.note.displayTitle ?? "笔记")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isEditing.toggle()
                } label: {
                    Image(systemName: isEditing ? "eye" : "pencil")
                }
                .help(isEditing ? "查看模式" : "编辑模式")
            }
        }
        .task(id: notePath) {
            if !isEditing {
                await loadNote()
            }
        }
        .onChange(of: isEditing) { _, newValue in
            if !newValue {
                Task {
                    await loadNote()
                }
            }
        }
    }
    
    @ViewBuilder
    private var viewModeContent: some View {
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

// MARK: - Note Web View (macOS)

import WebKit

struct NoteWebView: NSViewRepresentable {
    let html: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

#Preview {
    ContentView()
}

