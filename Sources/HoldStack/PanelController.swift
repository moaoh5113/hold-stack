import AppKit
import Carbon
import HoldCore
import SwiftUI

/// 앱을 활성화하지 않고 키 입력만 받는 창. 원래 앱이 앞에 남아 있어야 붙여넣기가 그쪽으로 간다.
private final class HoldPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class PanelController {
    private let store: HoldStore
    private let model = PanelModel()
    private let panel: HoldPanel
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication? // 붙여넣을 곳
    private static let frameName = "HoldStackPanel"

    var isVisible: Bool { panel.isVisible }

    init(store: HoldStore) {
        self.store = store
        panel = HoldPanel(contentRect: .zero,
                          styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
                          backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HoldView(store: store, model: model))
        panel.contentMinSize = NSSize(width: 360, height: 220)
        panel.setContentSize(NSSize(width: 560, height: 400))
        // 옮기거나 크기를 바꾸면 UserDefaults 에 저장되고 다음 실행에 복원된다
        panel.setFrameAutosaveName(Self.frameName)

        model.onPick = { [weak self] in self?.load(at: $0) }
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                                               object: panel, queue: .main) { [weak self] _ in self?.hide() }
    }

    func toggle() { isVisible ? hide() : show() }

    /// compose 는 ⌃⇧H 로 열었을 때. 한 건 보관하면 닫힌다.
    func show(quote: String? = nil, compose: Bool = false) {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }
        model.draft = ""
        model.quote = quote
        model.composing = compose
        model.canPaste = Clipboard.canSendKeys
        model.selection = 0
        model.focusTick += 1
        if !hasUsableSavedFrame(panel.frame) { fitAndCenterOnActiveScreen() }
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func focusInput() {
        model.focusTick += 1
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel.orderOut(nil)
    }

    /// 창을 닫은 뒤 원래 앱에 붙여넣는다.
    private func load(at index: Int) {
        guard !Clipboard.isBusy, let item = store.remove(at: index) else { return NSSound.beep() }
        hide()
        // 원래 앱 창이 키 입력을 되찾을 시간
        let target = previousApp
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { Clipboard.paste(item.pasteText, into: target) }
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

        if model.composing {
            switch key {
            case kVK_Escape: hide()
            case kVK_Return, kVK_ANSI_KeypadEnter:
                guard store.push(model.draft, quote: model.quote) else { NSSound.beep(); return true }
                hide()
            default: return false
            }
            return true
        }

        switch key {
        case kVK_Escape:
            hide()
        case kVK_UpArrow:
            model.selection = max(model.selection - 1, 0)
        case kVK_DownArrow:
            model.selection = min(model.selection + 1, max(store.items.count - 1, 0))
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
            if !store.undo() { NSSound.beep() }
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
