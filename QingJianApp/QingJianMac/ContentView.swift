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
    
    private let repoUseCases = RepoUseCases()
    
    init() {
        Task {
            await loadRepos()
        }
    }
    
    func loadRepos() async {
        repos = await repoUseCases.listRepos()
        if selectedRepo == nil, let first = repos.first {
            selectedRepo = first
        }
    }
    
    func addRepo(url: URL, name: String) async {
        do {
            let summary = try await repoUseCases.addRepo(rootURL: url, displayName: name)
            repos = await repoUseCases.listRepos()
            selectedRepo = summary
            selectedNotePath = nil
        } catch {
            self.error = error.localizedDescription
        }
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
        }
    }
    
    func selectRepo(_ repo: RepoSummary) {
        selectedRepo = repo
        selectedNotePath = nil
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var showingAddRepoSheet = false
    
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
                Button {
                    showingAddRepoSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("添加仓库")
            }
        }
        .sheet(isPresented: $showingAddRepoSheet) {
            AddRepoSheet(viewModel: viewModel, isPresented: $showingAddRepoSheet)
        }
    }
}

// MARK: - Add Repo Sheet

struct AddRepoSheet: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var isPresented: Bool
    @State private var selectedURL: URL?
    @State private var repoName: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("添加仓库")
                .font(.title2)
                .fontWeight(.semibold)
            
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
                
                Button("添加") {
                    guard let url = selectedURL else { return }
                    Task {
                        await viewModel.addRepo(url: url, name: repoName.isEmpty ? url.lastPathComponent : repoName)
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
        
        if panel.runModal() == .OK {
            selectedURL = panel.url
            if repoName.isEmpty, let url = panel.url {
                repoName = url.lastPathComponent
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

