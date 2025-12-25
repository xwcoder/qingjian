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
    
    private let repoUseCases = RepoUseCases()
    
    init() {
        Task {
            await loadRepos()
        }
    }
    
    func loadRepos() async {
        repos = await repoUseCases.listRepos()
    }
    
    func addRepo(url: URL, name: String) async {
        do {
            _ = try await repoUseCases.addRepo(rootURL: url, displayName: name)
            await loadRepos()
        } catch {
            self.error = error.localizedDescription
            self.showingError = true
        }
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
}

// MARK: - Repo List View

struct RepoListView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var showingAddRepo = false
    
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
                            RepoRowView(repo: repo)
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
                    Button {
                        showingAddRepo = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await viewModel.loadRepos()
            }
            .sheet(isPresented: $showingAddRepo) {
                AddRepoView(viewModel: viewModel, isPresented: $showingAddRepo)
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
                    Text("不可用")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Repo View

struct AddRepoView: View {
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
                }
                
                Section {
                    TextField("仓库名称", text: $repoName)
                } header: {
                    Text("显示名称")
                } footer: {
                    Text("留空将使用文件夹名称")
                }
            }
            .navigationTitle("添加仓库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        guard let url = selectedURL else { return }
                        Task {
                            await viewModel.addRepo(
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

