import AppKit
import Combine
import HoldCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = HoldStore(fileURL: HoldStore.defaultFileURL)
    private let settings = ShortcutSettings()
    private let prefs = Preferences()
    private lazy var panel = PanelController(store: store, prefs: prefs)
    private lazy var compose = ComposeController(store: store, prefs: prefs)
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private lazy var settingsWatcher = FocusLossWatcher { [weak self] reason in
        guard let self, self.prefs.shouldHide(for: reason) else { return }
        self.settingsWindow?.close()
    }
    private var bag: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        panel.onHide = { [weak self] in self?.settingsWindow?.close() }
        settings.$shortcuts
            .combineLatest(settings.$disabled)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.registerHotKeys()
                self?.rebuildMenu()
            }
            .store(in: &bag)
        prefs.$opacity
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
            guard settings.isEnabled(action) else { return false }
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

    /// 다시 켰는데 다른 앱이 그 조합을 차지했으면 끈 채로 되돌린다.
    private func applyEnabled(_ on: Bool, for action: HotKeyAction) -> String? {
        settings.setEnabled(on, for: action)
        guard on, registerHotKeys().contains(action) else { return nil }
        settings.setEnabled(false, for: action)
        registerHotKeys()
        return "\(settings[action].display) 는 다른 앱이나 시스템이 이미 쓰고 있어 켜지 못했습니다"
    }

    // MARK: 동작

    /// 선택한 문장을 붙잡아 두고, 그 문장에 대한 질문을 적는 창을 연다.
    private func holdSelection() {
        if compose.isVisible { return compose.focus() } // 쓰던 질문을 지우지 않는다
        if Clipboard.isBusy { return NSSound.beep() }
        guard Clipboard.canSendKeys else { return compose.show(quote: nil) }
        Clipboard.copySelection { [weak self] text in
            self?.compose.show(quote: text)
        }
    }

    private func popTop() {
        let front = NSWorkspace.shared.frontmostApplication
        if prefs.pasteOnlyIntoText, FocusInfo.shouldBlockPaste(FocusProbe.focused(in: front)) {
            DiagLog.write("pop blocked: app=\(front?.bundleIdentifier ?? "nil")")
            return NSSound.beep()
        }
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
            .combineLatest(prefs.$showCountInMenuBar)
            .sink { [weak self] items, show in
                self?.statusItem.button?.title = show && !items.isEmpty ? " \(items.count)" : ""
            }
            .store(in: &bag)
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(item(menuTitle(.toggleList), #selector(openPanel)))
        menu.addItem(item(menuTitle(.hold), #selector(composeFromMenu)))
        menu.addItem(item(menuTitle(.pop), #selector(popFromMenu)))
        menu.addItem(item("휴지통 열기", #selector(openTrash)))
        menu.addItem(.separator())
        menu.addItem(item("전체 비우기", #selector(clearAll)))
        menu.addItem(item("손쉬운 사용 권한 요청…", #selector(requestAccess)))
        let settingsItem = item("설정…", #selector(openSettings))
        settingsItem.keyEquivalent = ","
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func menuTitle(_ action: HotKeyAction) -> String {
        settings.isEnabled(action) ? "\(action.title)  \(settings[action].display)" : action.title
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openPanel() { panel.show() }
    @objc private func composeFromMenu() { compose.isVisible ? compose.focus() : compose.show(quote: nil) }
    @objc private func popFromMenu() { popTop() }
    @objc private func openTrash() { panel.showTrash() }
    @objc private func requestAccess() { Clipboard.requestAccess() }

    @objc func openSettings() {
        if settingsWindow == nil {
            let recorder = ShortcutRecorder(
                apply: { [weak self] in self?.applyShortcut($0, to: $1) },
                applyEnabled: { [weak self] in self?.applyEnabled($0, for: $1) },
                // 녹화 중에는 전역 단축키를 풀어야 키가 설정 창까지 온다
                setRecording: { [weak self] recording in
                    if recording { HotKeyCenter.shared.unregisterAll() } else { self?.registerHotKeys() }
                })
            let view = SettingsView(settings: settings, prefs: prefs, loginItem: LoginItem(), recorder: recorder)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "HoldStack 설정"
            window.styleMask = [.titled, .closable]
            window.level = .floating // 목록 창 뒤로 숨지 않게
            window.collectionBehavior = [.moveToActiveSpace] // 열 때 데스크탑을 넘기지 않는다
            window.isReleasedWhenClosed = false
            recorder.attach(to: window) { [weak window] in window?.close() }
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                                   object: window, queue: .main) { [weak self] _ in
                recorder.stop()
                self?.settingsWatcher.stop()
            }
            settingsWindow = window
        }
        settingsWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWatcher.start()
    }

    @objc private func clearAll() {
        let alert = NSAlert()
        alert.messageText = "보관된 의문 \(store.items.count)개를 모두 휴지통으로 옮길까요?"
        alert.informativeText = "휴지통에서 ⏎ 로 다시 되돌릴 수 있습니다."
        alert.addButton(withTitle: "휴지통으로")
        alert.addButton(withTitle: "취소")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { store.clear() }
    }
}
