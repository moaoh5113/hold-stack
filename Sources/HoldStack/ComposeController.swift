import AppKit
import Carbon
import HoldCore
import SwiftUI

final class ComposeModel: ObservableObject {
    @Published var quote: String?
    @Published var draft = ""
    @Published var focusTick = 0
}

private final class ComposePanel: NSPanel {
    var onClose: () -> Void = {}
    override var canBecomeKey: Bool { true }
    override func performClose(_ sender: Any?) { onClose() }
}

/// ⌃⇧H 로 여는 작성 창. 목록 창과 따로 떠 있고 자리도 따로 기억한다.
final class ComposeController {
    private let store: HoldStore
    private let prefs: Preferences
    private let model = ComposeModel()
    private var keepDraft = false // 다른 곳을 눌러 내렸으면 다음에 이어 쓴다
    private lazy var watcher = FocusLossWatcher { [weak self] reason in
        guard let self, self.prefs.shouldHide(for: reason), self.isVisible else { return }
        self.keepDraft = !self.model.draft.isEmpty || self.model.quote != nil
        self.hide()
    }
    private let panel: ComposePanel
    private let hosting: NSHostingView<ComposeView>
    private var keyMonitor: Any?
    private static let frameName = "HoldStackCompose"

    var isVisible: Bool { panel.isVisible }

    init(store: HoldStore, prefs: Preferences) {
        self.store = store
        self.prefs = prefs
        hosting = NSHostingView(rootView: ComposeView(model: model, prefs: prefs))
        panel = ComposePanel(contentRect: .zero,
                             styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
                             backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting
        panel.setFrameAutosaveName(Self.frameName)
        panel.onClose = { [weak self] in
            self?.keepDraft = false
            self?.hide()
        }
    }

    /// 이어 쓸 내용이 있으면 질문은 살리고, 새로 고른 문장이 있을 때만 문장을 바꾼다.
    func show(quote: String?) {
        if keepDraft {
            if let quote { model.quote = quote }
        } else {
            model.quote = quote
            model.draft = ""
        }
        keepDraft = false
        focus()
        // SwiftUI 가 바뀐 문장을 그린 다음에 재야 높이가 맞다
        DispatchQueue.main.async { [weak self] in self?.fitToContent() }
    }

    private func fitToContent() {
        hosting.layoutSubtreeIfNeeded()
        let top = panel.frame.maxY
        panel.setContentSize(hosting.fittingSize)
        if UserDefaults.standard.string(forKey: "NSWindow Frame \(Self.frameName)") == nil
            || !NSScreen.screens.contains(where: { $0.visibleFrame.contains(panel.frame) }) {
            panel.center()
        } else {
            panel.setFrameTopLeftPoint(NSPoint(x: panel.frame.minX, y: top)) // 문장 길이가 바뀌어도 윗변 고정
        }
    }

    func focus() {
        model.focusTick += 1
        panel.makeKeyAndOrderFront(nil)
        watcher.start()
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    func hide() {
        watcher.stop()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel.orderOut(nil)
    }

    private func handle(_ event: NSEvent) -> Bool {
        if (panel.firstResponder as? NSTextView)?.hasMarkedText() == true { return false } // 한글 조합 중
        switch Int(event.keyCode) {
        case kVK_Escape:
            keepDraft = false
            hide()
        case kVK_Return, kVK_ANSI_KeypadEnter:
            guard store.push(model.draft, quote: model.quote) else { NSSound.beep(); return true }
            keepDraft = false
            hide()
        default:
            return false
        }
        return true
    }
}

struct ComposeView: View {
    @ObservedObject var model: ComposeModel
    @ObservedObject var prefs: Preferences
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("의문 보관", systemImage: "square.and.pencil")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let quote = model.quote {
                ScrollView {
                    Text(quote)
                        .font(.system(size: prefs.quoteFontSize))
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 120)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1).fill(Color.accentColor).frame(width: 3).padding(.vertical, 6)
                }
            }

            TextField(model.quote == nil ? "떠오른 의문" : "이 문장에 대한 의문", text: $model.draft)
                .textFieldStyle(.plain)
                .font(.system(size: prefs.questionFontSize + 2))
                .padding(10)
                .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                .focused($focused)

            HStack {
                Text(model.quote == nil ? "선택한 문장 없이 의문만 보관합니다" : "질문을 비우면 문장만 보관합니다")
                Spacer()
                Text("⏎ 보관   esc 취소")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .padding(.top, 8)
        .frame(width: 460)
        .background(.regularMaterial)
        .onAppear { focused = true }
        .onChange(of: model.focusTick) { focused = true }
    }
}
