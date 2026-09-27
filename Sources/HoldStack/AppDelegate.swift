import AppKit
import Combine
import HoldCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = HoldStore(fileURL: HoldStore.defaultFileURL)
    private let settings = ShortcutSettings()
    private let appearance = PanelAppearance()
    private lazy var panel = PanelController(store: store)
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var bag: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        settings.$shortcuts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.registerHotKeys()
                self?.rebuildMenu()
            }
            .store(in: &bag)
        appearance.$opacity
            .sink { [weak self] in self?.panel.setOpacity($0) }
            .store(in: &bag)
        DiagLog.write("launch \(Bundle.main.bundleIdentifier ?? "nil") \(Clipboard.permissionSummary)")
        if !Clipboard.canSendKeys { Clipboard.requestAccess() }
    }

    // MARK: 단축키

    /// 등록에 실패한 동작 목록을 돌려준다.
    @discardableResult
    private func registerHotKeys() -> [HotKeyAction] {
        HotKeyCenter.shared.unregisterAll()
        return HotKeyAction.allCases.filter { action in
            let s = settings[action]
            let ok = HotKeyCenter.shared.register(keyCode: Int(s.keyCode), modifiers: Int(s.modifiers)) { [weak self] in
                self?.perform(action)
            }
            return !ok
        }
    }

    private func perform(_ action: HotKeyAction) {
        switch action {
        case .hold: holdSelection()
        case .toggleList: panel.toggle()
        case .pop: popTop()
        }
    }

    private func applyShortcut(_ shortcut: Shortcut, to action: HotKeyAction) -> String? {
        let previous = settings[action]
        do {
            try settings.set(shortcut, for: action)
        } catch let error as ShortcutError {
            return error.message
        } catch {
            return error.localizedDescription
        }
        guard registerHotKeys().contains(action) else { return nil }
        try? settings.set(previous, for: action)
        registerHotKeys()
        return "\(shortcut.display) 는 다른 앱이나 시스템이 이미 쓰고 있습니다"
    }

    // MARK: 동작

    /// 선택한 문장을 붙잡아 두고, 그 문장에 대한 질문을 적는 창을 연다.
    private func holdSelection() {
        if panel.isVisible { return panel.focusInput() } // 쓰던 질문을 지우지 않는다
        if Clipboard.isBusy { return NSSound.beep() }
        guard Clipboard.canSendKeys else { return panel.show(compose: true) }
        Clipboard.copySelection { [weak self] text in
            self?.panel.show(quote: text, compose: true)
        }
    }

    private func popTop() {
        guard !Clipboard.isBusy, let item = store.pop() else { return NSSound.beep() }
        Clipboard.paste(item.pasteText, into: NSWorkspace.shared.frontmostApplication)
    }

    // MARK: 메뉴 막대

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "HoldStack")
        statusItem.button?.imagePosition = .imageLeading
        store.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in self?.statusItem.button?.title = items.isEmpty ? "" : " \(items.count)" }
            .store(in: &bag)
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(item("\(HotKeyAction.toggleList.title)  \(settings[.toggleList].display)", #selector(openPanel)))
        menu.addItem(item("\(HotKeyAction.hold.title)  \(settings[.hold].display)", #selector(composeFromMenu)))
        menu.addItem(item("\(HotKeyAction.pop.title)  \(settings[.pop].display)", #selector(popFromMenu)))
        menu.addItem(.separator())
        menu.addItem(item("전체 비우기", #selector(clearAll)))
        menu.addItem(item("손쉬운 사용 권한 요청…", #selector(requestAccess)))
        let prefs = item("설정…", #selector(openSettings))
        prefs.keyEquivalent = ","
        menu.addItem(prefs)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openPanel() { panel.show() }
    @objc private func composeFromMenu() { panel.show(compose: true) }
    @objc private func popFromMenu() { popTop() }
    @objc private func requestAccess() { Clipboard.requestAccess() }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let recorder = ShortcutRecorder(
                apply: { [weak self] in self?.applyShortcut($0, to: $1) },
                // 녹화 중에는 전역 단축키를 풀어야 키가 설정 창까지 온다
                setRecording: { [weak self] recording in
                    if recording { HotKeyCenter.shared.unregisterAll() } else { self?.registerHotKeys() }
                })
            let view = SettingsView(settings: settings, appearance: appearance, recorder: recorder)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "HoldStack 설정"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            recorder.window = window
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                                   object: window, queue: .main) { _ in recorder.stop() }
            settingsWindow = window
        }
        settingsWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func clearAll() {
        let alert = NSAlert()
        alert.messageText = "보관된 의문 \(store.items.count)개를 모두 지울까요?"
        alert.addButton(withTitle: "지우기")
        alert.addButton(withTitle: "취소")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { store.clear() }
    }
}
