//
//  EditorSplitView.swift
//  QingJianMac
//
//  Created by speckit on 2025-12-25.
//
//  编辑器分栏视图（Markdown 输入 + 实时预览）
//

import SwiftUI
import QingJianCore

struct EditorSplitView: View {
    let repoId: String
    let rootURL: URL
    let notePath: String
    
    @StateObject private var viewModel: EditorViewModel
    @AppStorage("vimModeEnabled") private var vimModeEnabled = false
    @AppStorage("editorFontSize") private var editorFontSize = 14.0
    
    init(repoId: String, rootURL: URL, notePath: String) {
        self.repoId = repoId
        self.rootURL = rootURL
        self.notePath = notePath
        self._viewModel = StateObject(wrappedValue: EditorViewModel(
            repoId: repoId,
            rootURL: rootURL,
            notePath: notePath
        ))
    }
    
    var body: some View {
        HSplitView {
            // 编辑区
            VStack(spacing: 0) {
                EditorToolbar(viewModel: viewModel, vimModeEnabled: $vimModeEnabled)
                
                MarkdownEditorView(
                    text: $viewModel.content,
                    fontSize: editorFontSize,
                    vimModeEnabled: vimModeEnabled,
                    onTextChange: { viewModel.handleTextChange() }
                )
            }
            .frame(minWidth: 300)
            
            // 预览区
            PreviewView(
                html: viewModel.renderedHTML,
                isLoading: viewModel.isRendering
            )
            .frame(minWidth: 300)
        }
        .navigationTitle(viewModel.displayTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    if viewModel.isDirty {
                        Circle()
                            .fill(.orange)
                            .frame(width: 8, height: 8)
                            .help("有未保存的更改")
                    }
                    
                    Button {
                        Task {
                            await viewModel.save()
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!viewModel.isDirty)
                    .help("保存 (⌘S)")
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .alert("保存失败", isPresented: $viewModel.showingError) {
            Button("确定") {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }
}

// MARK: - Editor ViewModel

@MainActor
class EditorViewModel: ObservableObject {
    let repoId: String
    let rootURL: URL
    let notePath: String
    
    @Published var content: String = ""
    @Published var renderedHTML: String = ""
    @Published var displayTitle: String = "笔记"
    @Published var isDirty: Bool = false
    @Published var isLoading: Bool = false
    @Published var isRendering: Bool = false
    @Published var showingError: Bool = false
    @Published var errorMessage: String?
    
    private var originalContent: String = ""
    private var originalHash: Int = 0
    private var renderTask: Task<Void, Never>?
    
    private let browseUseCases = BrowseUseCases()
    private let editUseCases = EditUseCases()
    private let renderer = MarkdownRenderer()
    
    init(repoId: String, rootURL: URL, notePath: String) {
        self.repoId = repoId
        self.rootURL = rootURL
        self.notePath = notePath
    }
    
    // MARK: - Load
    
    func load() async {
        isLoading = true
        
        do {
            let document = try await browseUseCases.openNote(
                repoId: repoId,
                rootURL: rootURL,
                notePath: notePath
            )
            
            content = document.content
            originalContent = document.content
            originalHash = document.contentHash
            displayTitle = document.note.displayTitle
            isDirty = false
            
            await render()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Save
    
    func save() async {
        do {
            _ = try await editUseCases.saveNote(
                rootURL: rootURL,
                path: notePath,
                content: content,
                expectedHash: originalHash
            )
            
            originalContent = content
            originalHash = content.hashValue
            isDirty = false
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    // MARK: - Text Change
    
    func handleTextChange() {
        isDirty = content != originalContent
        
        // 去抖渲染
        renderTask?.cancel()
        renderTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            guard !Task.isCancelled else { return }
            await render()
        }
    }
    
    // MARK: - Render
    
    private func render() async {
        isRendering = true
        
        do {
            let result = try await renderer.render(markdown: content)
            renderedHTML = result.htmlContent
        } catch {
            // Render error - just show empty
            renderedHTML = ""
        }
        
        isRendering = false
    }
}

// MARK: - Editor Toolbar

struct EditorToolbar: View {
    @ObservedObject var viewModel: EditorViewModel
    @Binding var vimModeEnabled: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Button {
                insertMarkdown("**", "**")
            } label: {
                Image(systemName: "bold")
            }
            .help("粗体 (⌘B)")
            
            Button {
                insertMarkdown("*", "*")
            } label: {
                Image(systemName: "italic")
            }
            .help("斜体 (⌘I)")
            
            Button {
                insertMarkdown("`", "`")
            } label: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
            .help("行内代码")
            
            Divider()
                .frame(height: 16)
            
            Button {
                insertMarkdown("# ", "")
            } label: {
                Image(systemName: "textformat.size")
            }
            .help("标题")
            
            Button {
                insertMarkdown("- ", "")
            } label: {
                Image(systemName: "list.bullet")
            }
            .help("列表")
            
            Button {
                insertMarkdown("> ", "")
            } label: {
                Image(systemName: "text.quote")
            }
            .help("引用")
            
            Divider()
                .frame(height: 16)
            
            Button {
                insertMarkdown("[", "](url)")
            } label: {
                Image(systemName: "link")
            }
            .help("链接")
            
            Button {
                insertMarkdown("![", "](image.png)")
            } label: {
                Image(systemName: "photo")
            }
            .help("图片")
            
            Spacer()
            
            Toggle(isOn: $vimModeEnabled) {
                Text("Vim")
                    .font(.caption)
            }
            .toggleStyle(.button)
            .controlSize(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }
    
    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        viewModel.content += prefix + suffix
        viewModel.handleTextChange()
    }
}

// MARK: - Markdown Editor View

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: Double
    let vimModeEnabled: Bool
    let onTextChange: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
        }
        
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        context.coordinator.vimModeEnabled = vimModeEnabled
    }
    
    @MainActor
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MarkdownEditorView
        var vimModeEnabled: Bool = false
        var vimEngine: VimEngine?
        
        init(_ parent: MarkdownEditorView) {
            self.parent = parent
            super.init()
            self.vimEngine = VimEngine()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onTextChange()
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard vimModeEnabled, let vimEngine else { return false }
            
            // Vim 模式下拦截按键
            // TODO: 实现完整的 Vim 键位处理
            return false
        }
    }
}

// MARK: - Preview View

struct PreviewView: View {
    let html: String
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if html.isEmpty {
                ContentUnavailableView(
                    "无预览",
                    systemImage: "doc.text",
                    description: Text("输入内容后将显示预览")
                )
            } else {
                PreviewWebView(html: html)
            }
        }
    }
}

struct PreviewWebView: NSViewRepresentable {
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

import WebKit

