//
//  VimEngine.swift
//  QingJianMac
//
//  Created by speckit on 2025-12-25.
//
//  Vim 模式核心引擎（状态机 + 键位处理）
//

import AppKit

/// Vim 模式
public enum VimMode: String {
    case normal = "NORMAL"
    case insert = "INSERT"
    case visual = "VISUAL"
    case visualLine = "V-LINE"
    case command = "COMMAND"
}

/// Vim 动作
public enum VimMotion {
    case left           // h
    case down           // j
    case up             // k
    case right          // l
    case wordForward    // w
    case wordBackward   // b
    case lineStart      // 0
    case lineEnd        // $
    case firstNonBlank  // ^
    case fileStart      // gg
    case fileEnd        // G
    case pageDown       // Ctrl+D
    case pageUp         // Ctrl+U
    case findChar(Character)  // f{char}
    case tillChar(Character)  // t{char}
}

/// Vim 操作
public enum VimOperation {
    case delete         // d
    case change         // c
    case yank           // y
    case indent         // >
    case outdent        // <
}

/// Vim 引擎
@MainActor
public class VimEngine {
    
    /// 当前模式
    public private(set) var mode: VimMode = .normal
    
    /// 命令缓冲
    private var commandBuffer: String = ""
    
    /// 重复计数
    private var repeatCount: Int = 1
    
    /// 待处理的操作
    private var pendingOperation: VimOperation?
    
    /// 寄存器（剪贴板）
    private var registers: [Character: String] = [:]
    private var defaultRegister: String = ""
    
    /// 搜索模式
    private var searchPattern: String = ""
    private var searchForward: Bool = true
    
    /// 撤销栈
    private var undoStack: [String] = []
    private var redoStack: [String] = []
    
    /// 模式变化回调
    public var onModeChange: ((VimMode) -> Void)?
    
    /// 状态栏更新回调
    public var onStatusUpdate: ((String) -> Void)?
    
    public init() {}
    
    // MARK: - Mode Management
    
    /// 切换到指定模式
    public func setMode(_ newMode: VimMode) {
        mode = newMode
        commandBuffer = ""
        repeatCount = 1
        pendingOperation = nil
        onModeChange?(mode)
        updateStatus()
    }
    
    /// 进入插入模式
    public func enterInsert() {
        setMode(.insert)
    }
    
    /// 进入普通模式
    public func enterNormal() {
        setMode(.normal)
    }
    
    /// 进入可视模式
    public func enterVisual() {
        setMode(.visual)
    }
    
    // MARK: - Key Handling
    
    /// 处理按键
    ///
    /// - Parameters:
    ///   - key: 按键字符
    ///   - modifiers: 修饰键
    ///   - textView: 目标文本视图
    /// - Returns: 是否消费了该按键
    public func handleKey(
        _ key: Character,
        modifiers: NSEvent.ModifierFlags,
        textView: NSTextView
    ) -> Bool {
        switch mode {
        case .normal:
            return handleNormalMode(key: key, modifiers: modifiers, textView: textView)
        case .insert:
            return handleInsertMode(key: key, modifiers: modifiers, textView: textView)
        case .visual, .visualLine:
            return handleVisualMode(key: key, modifiers: modifiers, textView: textView)
        case .command:
            return handleCommandMode(key: key, modifiers: modifiers, textView: textView)
        }
    }
    
    // MARK: - Normal Mode
    
    private func handleNormalMode(
        key: Character,
        modifiers: NSEvent.ModifierFlags,
        textView: NSTextView
    ) -> Bool {
        // 数字前缀（重复计数）
        if key.isNumber && key != "0" {
            if let digit = key.wholeNumberValue {
                if repeatCount == 1 && commandBuffer.isEmpty {
                    repeatCount = digit
                } else {
                    repeatCount = repeatCount * 10 + digit
                }
                commandBuffer.append(key)
                updateStatus()
                return true
            }
        }
        
        // 待处理操作后的动作
        if let operation = pendingOperation {
            if let motion = parseMotion(key) {
                executeOperationWithMotion(operation, motion: motion, textView: textView)
                pendingOperation = nil
                commandBuffer = ""
                repeatCount = 1
                updateStatus()
                return true
            }
        }
        
        // 基础命令
        switch key {
        // 模式切换
        case "i":
            enterInsert()
            return true
        case "I":
            moveToLineStart(textView: textView)
            enterInsert()
            return true
        case "a":
            moveRight(textView: textView, count: 1)
            enterInsert()
            return true
        case "A":
            moveToLineEnd(textView: textView)
            enterInsert()
            return true
        case "o":
            insertLineBelow(textView: textView)
            enterInsert()
            return true
        case "O":
            insertLineAbove(textView: textView)
            enterInsert()
            return true
        case "v":
            enterVisual()
            return true
        case "V":
            setMode(.visualLine)
            return true
        case ":":
            setMode(.command)
            commandBuffer = ":"
            updateStatus()
            return true
            
        // 移动
        case "h":
            moveLeft(textView: textView, count: repeatCount)
            resetCommand()
            return true
        case "j":
            moveDown(textView: textView, count: repeatCount)
            resetCommand()
            return true
        case "k":
            moveUp(textView: textView, count: repeatCount)
            resetCommand()
            return true
        case "l":
            moveRight(textView: textView, count: repeatCount)
            resetCommand()
            return true
        case "w":
            moveWordForward(textView: textView, count: repeatCount)
            resetCommand()
            return true
        case "b":
            moveWordBackward(textView: textView, count: repeatCount)
            resetCommand()
            return true
        case "0":
            moveToLineStart(textView: textView)
            resetCommand()
            return true
        case "$":
            moveToLineEnd(textView: textView)
            resetCommand()
            return true
        case "^":
            moveToFirstNonBlank(textView: textView)
            resetCommand()
            return true
        case "G":
            if repeatCount > 1 {
                gotoLine(textView: textView, line: repeatCount)
            } else {
                moveToFileEnd(textView: textView)
            }
            resetCommand()
            return true
        case "g":
            commandBuffer.append(key)
            updateStatus()
            return true
            
        // 操作
        case "d":
            if commandBuffer == "d" {
                // dd - 删除整行
                deleteLine(textView: textView, count: repeatCount)
                resetCommand()
            } else {
                pendingOperation = .delete
                commandBuffer.append(key)
                updateStatus()
            }
            return true
        case "c":
            if commandBuffer == "c" {
                // cc - 修改整行
                deleteLine(textView: textView, count: repeatCount)
                enterInsert()
                resetCommand()
            } else {
                pendingOperation = .change
                commandBuffer.append(key)
                updateStatus()
            }
            return true
        case "y":
            if commandBuffer == "y" {
                // yy - 复制整行
                yankLine(textView: textView, count: repeatCount)
                resetCommand()
            } else {
                pendingOperation = .yank
                commandBuffer.append(key)
                updateStatus()
            }
            return true
        case "p":
            paste(textView: textView, after: true)
            resetCommand()
            return true
        case "P":
            paste(textView: textView, after: false)
            resetCommand()
            return true
        case "x":
            deleteChar(textView: textView, count: repeatCount)
            resetCommand()
            return true
        case "X":
            deleteCharBefore(textView: textView, count: repeatCount)
            resetCommand()
            return true
            
        // 撤销/重做
        case "u":
            undo(textView: textView)
            resetCommand()
            return true
        case "r" where modifiers.contains(.control):
            redo(textView: textView)
            resetCommand()
            return true
            
        // 搜索
        case "/":
            setMode(.command)
            commandBuffer = "/"
            updateStatus()
            return true
        case "?":
            setMode(.command)
            commandBuffer = "?"
            updateStatus()
            return true
        case "n":
            findNext(textView: textView)
            return true
        case "N":
            findPrevious(textView: textView)
            return true
            
        // gg - 文件开头
        case _ where commandBuffer == "g":
            if key == "g" {
                if repeatCount > 1 {
                    gotoLine(textView: textView, line: repeatCount)
                } else {
                    moveToFileStart(textView: textView)
                }
                resetCommand()
                return true
            }
            resetCommand()
            return false
            
        default:
            resetCommand()
            return false
        }
    }
    
    // MARK: - Insert Mode
    
    private func handleInsertMode(
        key: Character,
        modifiers: NSEvent.ModifierFlags,
        textView: NSTextView
    ) -> Bool {
        // Escape 返回普通模式
        if key == Character(UnicodeScalar(27)) { // ESC
            enterNormal()
            moveLeft(textView: textView, count: 1) // Vim 行为：退出插入模式后光标左移
            return true
        }
        
        // 其他按键不拦截，让系统处理
        return false
    }
    
    // MARK: - Visual Mode
    
    private func handleVisualMode(
        key: Character,
        modifiers: NSEvent.ModifierFlags,
        textView: NSTextView
    ) -> Bool {
        switch key {
        case Character(UnicodeScalar(27)): // ESC
            enterNormal()
            return true
        case "h":
            extendSelectionLeft(textView: textView, count: repeatCount)
            resetCommand()
            return true
        case "j":
            extendSelectionDown(textView: textView, count: repeatCount)
            resetCommand()
            return true
        case "k":
            extendSelectionUp(textView: textView, count: repeatCount)
            resetCommand()
            return true
        case "l":
            extendSelectionRight(textView: textView, count: repeatCount)
            resetCommand()
            return true
        case "d", "x":
            deleteSelection(textView: textView)
            enterNormal()
            return true
        case "y":
            yankSelection(textView: textView)
            enterNormal()
            return true
        case "c":
            deleteSelection(textView: textView)
            enterInsert()
            return true
        default:
            return false
        }
    }
    
    // MARK: - Command Mode
    
    private func handleCommandMode(
        key: Character,
        modifiers: NSEvent.ModifierFlags,
        textView: NSTextView
    ) -> Bool {
        switch key {
        case Character(UnicodeScalar(27)): // ESC
            enterNormal()
            return true
        case "\r", "\n": // Enter
            executeCommand(textView: textView)
            enterNormal()
            return true
        case Character(UnicodeScalar(127)): // Backspace
            if commandBuffer.count > 1 {
                commandBuffer.removeLast()
                updateStatus()
            } else {
                enterNormal()
            }
            return true
        default:
            commandBuffer.append(key)
            updateStatus()
            return true
        }
    }
    
    // MARK: - Movement Helpers
    
    private func parseMotion(_ key: Character) -> VimMotion? {
        switch key {
        case "h": return .left
        case "j": return .down
        case "k": return .up
        case "l": return .right
        case "w": return .wordForward
        case "b": return .wordBackward
        case "0": return .lineStart
        case "$": return .lineEnd
        case "^": return .firstNonBlank
        case "G": return .fileEnd
        default: return nil
        }
    }
    
    private func moveLeft(textView: NSTextView, count: Int) {
        let range = textView.selectedRange()
        let newLocation = max(0, range.location - count)
        textView.setSelectedRange(NSRange(location: newLocation, length: 0))
    }
    
    private func moveRight(textView: NSTextView, count: Int) {
        let range = textView.selectedRange()
        let maxLocation = textView.string.utf16.count
        let newLocation = min(maxLocation, range.location + count)
        textView.setSelectedRange(NSRange(location: newLocation, length: 0))
    }
    
    private func moveUp(textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveUp(nil)
        }
    }
    
    private func moveDown(textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveDown(nil)
        }
    }
    
    private func moveWordForward(textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveWordForward(nil)
        }
    }
    
    private func moveWordBackward(textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveWordBackward(nil)
        }
    }
    
    private func moveToLineStart(textView: NSTextView) {
        textView.moveToBeginningOfLine(nil)
    }
    
    private func moveToLineEnd(textView: NSTextView) {
        textView.moveToEndOfLine(nil)
    }
    
    private func moveToFirstNonBlank(textView: NSTextView) {
        textView.moveToBeginningOfLine(nil)
        // TODO: 跳过空白字符
    }
    
    private func moveToFileStart(textView: NSTextView) {
        textView.setSelectedRange(NSRange(location: 0, length: 0))
    }
    
    private func moveToFileEnd(textView: NSTextView) {
        let length = textView.string.utf16.count
        textView.setSelectedRange(NSRange(location: length, length: 0))
    }
    
    private func gotoLine(textView: NSTextView, line: Int) {
        let lines = textView.string.components(separatedBy: .newlines)
        var offset = 0
        for (index, lineContent) in lines.enumerated() {
            if index + 1 == line {
                textView.setSelectedRange(NSRange(location: offset, length: 0))
                return
            }
            offset += lineContent.utf16.count + 1
        }
        // 如果行号超出范围，跳到文件末尾
        moveToFileEnd(textView: textView)
    }
    
    // MARK: - Edit Operations
    
    private func insertLineBelow(textView: NSTextView) {
        textView.moveToEndOfLine(nil)
        textView.insertNewline(nil)
    }
    
    private func insertLineAbove(textView: NSTextView) {
        textView.moveToBeginningOfLine(nil)
        textView.insertNewline(nil)
        textView.moveUp(nil)
    }
    
    private func deleteChar(textView: NSTextView, count: Int) {
        let range = textView.selectedRange()
        let maxLength = textView.string.utf16.count - range.location
        let deleteLength = min(count, maxLength)
        if deleteLength > 0 {
            textView.setSelectedRange(NSRange(location: range.location, length: deleteLength))
            textView.delete(nil)
        }
    }
    
    private func deleteCharBefore(textView: NSTextView, count: Int) {
        let range = textView.selectedRange()
        let deleteLength = min(count, range.location)
        if deleteLength > 0 {
            textView.setSelectedRange(NSRange(location: range.location - deleteLength, length: deleteLength))
            textView.delete(nil)
        }
    }
    
    private func deleteLine(textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveToBeginningOfLine(nil)
            textView.moveToEndOfLineAndModifySelection(nil)
            textView.moveForwardAndModifySelection(nil) // 包含换行符
            defaultRegister = String(textView.string[Range(textView.selectedRange(), in: textView.string)!])
            textView.delete(nil)
        }
    }
    
    private func yankLine(textView: NSTextView, count: Int) {
        let currentRange = textView.selectedRange()
        textView.moveToBeginningOfLine(nil)
        for _ in 0..<count {
            textView.moveToEndOfLineAndModifySelection(nil)
            textView.moveForwardAndModifySelection(nil)
        }
        defaultRegister = String(textView.string[Range(textView.selectedRange(), in: textView.string)!])
        textView.setSelectedRange(currentRange)
    }
    
    private func paste(textView: NSTextView, after: Bool) {
        if after {
            moveRight(textView: textView, count: 1)
        }
        textView.insertText(defaultRegister, replacementRange: textView.selectedRange())
    }
    
    private func deleteSelection(textView: NSTextView) {
        let range = textView.selectedRange()
        if range.length > 0 {
            defaultRegister = String(textView.string[Range(range, in: textView.string)!])
            textView.delete(nil)
        }
    }
    
    private func yankSelection(textView: NSTextView) {
        let range = textView.selectedRange()
        if range.length > 0 {
            defaultRegister = String(textView.string[Range(range, in: textView.string)!])
        }
    }
    
    // MARK: - Selection Extension
    
    private func extendSelectionLeft(textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveLeftAndModifySelection(nil)
        }
    }
    
    private func extendSelectionRight(textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveRightAndModifySelection(nil)
        }
    }
    
    private func extendSelectionUp(textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveUpAndModifySelection(nil)
        }
    }
    
    private func extendSelectionDown(textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveDownAndModifySelection(nil)
        }
    }
    
    // MARK: - Operation with Motion
    
    private func executeOperationWithMotion(
        _ operation: VimOperation,
        motion: VimMotion,
        textView: NSTextView
    ) {
        // 选择动作范围
        let startRange = textView.selectedRange()
        
        switch motion {
        case .left:
            extendSelectionLeft(textView: textView, count: repeatCount)
        case .right:
            extendSelectionRight(textView: textView, count: repeatCount)
        case .down:
            extendSelectionDown(textView: textView, count: repeatCount)
        case .up:
            extendSelectionUp(textView: textView, count: repeatCount)
        case .wordForward:
            for _ in 0..<repeatCount {
                textView.moveWordForwardAndModifySelection(nil)
            }
        case .wordBackward:
            for _ in 0..<repeatCount {
                textView.moveWordBackwardAndModifySelection(nil)
            }
        case .lineStart:
            textView.moveToBeginningOfLineAndModifySelection(nil)
        case .lineEnd:
            textView.moveToEndOfLineAndModifySelection(nil)
        default:
            break
        }
        
        // 执行操作
        switch operation {
        case .delete:
            deleteSelection(textView: textView)
        case .change:
            deleteSelection(textView: textView)
            enterInsert()
        case .yank:
            yankSelection(textView: textView)
            textView.setSelectedRange(startRange)
        default:
            break
        }
    }
    
    // MARK: - Undo/Redo
    
    private func undo(textView: NSTextView) {
        textView.undoManager?.undo()
    }
    
    private func redo(textView: NSTextView) {
        textView.undoManager?.redo()
    }
    
    // MARK: - Search
    
    private func findNext(textView: NSTextView) {
        guard !searchPattern.isEmpty else { return }
        
        let range = textView.selectedRange()
        let searchRange = NSRange(location: range.location + range.length, length: textView.string.utf16.count - range.location - range.length)
        
        let foundRange = (textView.string as NSString).range(of: searchPattern, options: [], range: searchRange)
        if foundRange.location != NSNotFound {
            textView.setSelectedRange(foundRange)
            textView.scrollRangeToVisible(foundRange)
        }
    }
    
    private func findPrevious(textView: NSTextView) {
        guard !searchPattern.isEmpty else { return }
        
        let range = textView.selectedRange()
        let searchRange = NSRange(location: 0, length: range.location)
        
        let foundRange = (textView.string as NSString).range(of: searchPattern, options: .backwards, range: searchRange)
        if foundRange.location != NSNotFound {
            textView.setSelectedRange(foundRange)
            textView.scrollRangeToVisible(foundRange)
        }
    }
    
    // MARK: - Command Execution
    
    private func executeCommand(textView: NSTextView) {
        let cmd = commandBuffer
        
        if cmd.hasPrefix("/") {
            // 搜索
            searchPattern = String(cmd.dropFirst())
            searchForward = true
            findNext(textView: textView)
        } else if cmd.hasPrefix("?") {
            // 反向搜索
            searchPattern = String(cmd.dropFirst())
            searchForward = false
            findPrevious(textView: textView)
        } else if cmd == ":w" {
            // 保存（由外部处理）
            onStatusUpdate?("保存请使用 ⌘S")
        } else if cmd == ":q" {
            // 退出（由外部处理）
            onStatusUpdate?("退出请使用 ⌘W")
        } else if cmd.hasPrefix(":") {
            // 跳转到行
            if let lineNumber = Int(String(cmd.dropFirst())) {
                gotoLine(textView: textView, line: lineNumber)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func resetCommand() {
        commandBuffer = ""
        repeatCount = 1
        pendingOperation = nil
        updateStatus()
    }
    
    private func updateStatus() {
        var status = "-- \(mode.rawValue) --"
        if !commandBuffer.isEmpty {
            status += " \(commandBuffer)"
        }
        onStatusUpdate?(status)
    }
}

