import AppKit
import Carbon
import HoldCore
import SwiftUI

/// 앱을 활성화하지 않고 키 입력만 받는 창. 원래 앱이 앞에 남아 있어야 붙여넣기가 그쪽으로 간다.
final class HoldPanel: NSPanel {
    var onClose: () -> Void = {}
    override var canBecomeKey: Bool { true }
    /// 빨간 닫기 버튼도 esc 와 같은 길로 닫는다.
    override func performClose(_ sender: Any?) { onClose() }
}

final class PanelController {
    private let store: HoldStore
    private let prefs: Preferences
    private let model = PanelModel()
    private let panel: HoldPanel
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication? // 붙여넣을 곳
    private var keepDraft = false // 다른 곳을 눌러 내렸으면 쓰던 질문을 살린다
    var onHide: () -> Void = {}
    private lazy var watcher = FocusLossWatcher { [weak self] reason in
        guard let self, self.prefs.shouldHide(for: reason), self.isVisible else { return }
        self.keepDraft = !self.model.draft.isEmpty
        self.hide()
    }
    private var generation = 0 // 열고 닫을 때마다 올라간다. 늦게 도는 다시 띄우기를 막는다
    private static let frameName = "HoldStackPanel"

    var isVisible: Bool { panel.isVisible }

    init(store: HoldStore, prefs: Preferences) {
        self.store = store
        self.prefs = prefs
        panel = HoldPanel(contentRect: .zero,
                          styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView, .resizable],
                          backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HoldView(store: store, model: model, prefs: prefs))
        panel.contentMinSize = NSSize(width: 360, height: 220)
        panel.setContentSize(NSSize(width: 560, height: 400))
        // 옮기거나 크기를 바꾸면 UserDefaults 에 저장되고 다음 실행에 복원된다
        panel.setFrameAutosaveName(Self.frameName)

        model.onPick = { [weak self] in self?.pick(at: $0) }
        model.onTab = { [weak self] in self?.setTrashMode($0) }
        model.onDelete = { [weak self] in self?.delete(at: $0) }
        panel.onClose = { [weak self] in self?.hide() }
        // 창을 띄운 채 다른 앱을 쓰면 그 앱이 붙여넣을 곳이 된다
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier { self?.previousApp = app }
        }
    }

    /// 데스크탑을 옮겨도 닫히지 않으므로, 떠 있지만 초점이 없으면 초점만 준다.
    func toggle() {
        if !isVisible { return show() }
        panel.isKeyWindow ? hide() : focusInput()
    }

    func show() {
        generation += 1
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }
        if !keepDraft { model.draft = "" }
        keepDraft = false
        model.showingTrash = false
        model.canPaste = Clipboard.canSendKeys
        model.selection = 0
        model.focusTick += 1
        if !hasUsableSavedFrame(panel.frame) { fitAndCenterOnActiveScreen() }
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        watcher.start()
    }

    func focusInput() {
        model.focusTick += 1
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        watcher.start()
    }

    func hide() {
        generation += 1
        watcher.stop()
        onHide()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel.orderOut(nil)
    }

    func showTrash() {
        if !isVisible { show() }
        focusInput()
        setTrashMode(true)
    }

    /// 크게 보기 중이면 옆 항목도 크게 보인 채로 넘어간다.
    private func moveSelection(to index: Int, count: Int) {
        let keepDetail = model.expanded && prefs.expandStyle == .detail
        model.selection = min(max(index, 0), max(count - 1, 0))
        if keepDetail { model.expanded = true }
    }

    private func undo() {
        let ok = store.undo()
        DiagLog.write("undo ok=\(ok) remaining=\(store.undoSteps) trash=\(model.showingTrash)")
        if !ok { NSSound.beep() }
        let count = model.showingTrash ? store.trash.count : store.items.count
        model.selection = min(model.selection, max(count - 1, 0))
    }

    private func setTrashMode(_ on: Bool) {
        model.showingTrash = on
        model.selection = 0
        if !on { model.focusTick += 1 } // 입력칸이 다시 생기므로 초점을 돌려준다
    }

    private func pick(at index: Int) {
        model.showingTrash ? restore(at: index) : load(at: index)
    }

    /// 스택에서는 휴지통으로, 휴지통에서는 지우기. 둘 다 ⌘Z 로 되돌린다.
    private func delete(at index: Int) {
        if model.showingTrash {
            store.deleteFromTrash(at: index)
            model.selection = min(model.selection, max(store.trash.count - 1, 0))
        } else {
            guard store.remove(at: index) != nil else { return }
            model.selection = min(model.selection, max(store.items.count - 1, 0))
        }
    }

    private func restore(at index: Int) {
        guard store.restoreFromTrash(at: index) else { return NSSound.beep() }
        setTrashMode(false)
    }

    /// 창을 닫은 뒤 원래 앱에 붙여넣는다.
    private func load(at index: Int) {
        guard !Clipboard.isBusy, let item = store.remove(at: index) else { return NSSound.beep() }
        Clipboard.reserve()
        // 창이 초점을 쥐고 있으면 ⌘V 가 이 창으로 온다. 잠깐 내렸다가 초점 없이 다시 띄운다
        hide()
        model.selection = min(model.selection, max(store.items.count - 1, 0))
        let target = previousApp
        let reopen = !prefs.closeAfterLoad
        let expected = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            Clipboard.paste(item.pasteText, into: target)
            guard reopen else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard let self, self.generation == expected else { return }
                self.panel.orderFront(nil)
                self.installKeyMonitor()
                self.watcher.start(ignoring: target)
            }
        }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    /// true 면 이벤트를 삼킨다.
    private func handle(_ event: NSEvent) -> Bool {
        let editor = panel.firstResponder as? NSTextView
        if editor?.hasMarkedText() == true { return false } // 한글 조합 중에는 IME 에 맡긴다
        let draftEmpty = model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let key = Int(event.keyCode)

        if model.showingTrash {
            switch key {
            case kVK_Escape: if model.expanded { model.expanded = false } else { hide() }
            case kVK_Tab: setTrashMode(false)
            case kVK_RightArrow: model.expanded = true
            case kVK_LeftArrow: model.expanded = false
            case kVK_UpArrow: moveSelection(to: model.selection - 1, count: store.trash.count)
            case kVK_DownArrow: moveSelection(to: model.selection + 1, count: store.trash.count)
            case kVK_Return, kVK_ANSI_KeypadEnter: restore(at: model.selection)
            case kVK_ANSI_Z where event.modifierFlags.contains(.command): undo()
            case kVK_Delete, kVK_ForwardDelete:
                store.deleteFromTrash(at: model.selection)
                model.selection = min(model.selection, max(store.trash.count - 1, 0))
            default: return false
            }
            return true
        }

        switch key {
        case kVK_Escape:
            if model.expanded { model.expanded = false } else { hide() }
        case kVK_Tab:
            setTrashMode(true)
        case kVK_RightArrow where draftEmpty:
            model.expanded = true
        case kVK_LeftArrow where draftEmpty:
            model.expanded = false
        case kVK_UpArrow:
            moveSelection(to: model.selection - 1, count: store.items.count)
        case kVK_DownArrow:
            moveSelection(to: model.selection + 1, count: store.items.count)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if draftEmpty {
                load(at: model.selection)
            } else {
                store.push(model.draft)
                model.draft = ""
                model.selection = 0
            }
        case kVK_Delete where draftEmpty, kVK_ForwardDelete where draftEmpty:
            guard store.remove(at: model.selection) != nil else { return true }
            model.selection = min(model.selection, max(store.items.count - 1, 0))
        case kVK_ANSI_Z where draftEmpty && event.modifierFlags.contains(.command):
            undo()
        default:
            return false
        }
        return true
    }

    /// 저장된 자리가 있고, 창이 한 화면 안에 통째로 들어가 있어야 true.
    private func hasUsableSavedFrame(_ frame: NSRect) -> Bool {
        UserDefaults.standard.string(forKey: "NSWindow Frame \(Self.frameName)") != nil
            && NSScreen.screens.contains { $0.visibleFrame.contains(frame) }
    }

    /// 마우스가 있는 화면 가운데로 옮기고, 화면보다 크면 줄인다.
    private func fitAndCenterOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let width = min(panel.frame.width, visible.width - 40)
        let height = min(panel.frame.height, visible.height - 40)
        let y = min(visible.midY - height / 2 + visible.height / 6, visible.maxY - height)
        panel.setFrame(NSRect(x: visible.midX - width / 2, y: y, width: width, height: height), display: true)
    }

    func setOpacity(_ value: Double) { panel.alphaValue = CGFloat(value) }
}
