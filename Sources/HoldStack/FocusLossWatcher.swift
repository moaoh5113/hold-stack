import AppKit
import HoldCore

/// 입력칸에 초점이 가면 macOS 가 글 전체를 선택한다. 이어 쓰다 통째로 지우지 않게 커서를 끝으로 옮긴다.
func moveCursorToEnd(in window: NSWindow) {
    DispatchQueue.main.async {
        guard let editor = window.firstResponder as? NSTextView else { return }
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
    }
}

/// 따라오지 않는 창은 연 데스크탑에 머문다. 전환하면 보이지 않는 곳에서 조용히 닫힌다.
func applySpaceBehavior(to window: NSWindow, prefs: Preferences) {
    window.collectionBehavior = prefs.followsAcrossDesktops
        ? [.canJoinAllSpaces, .fullScreenAuxiliary]
        : [.moveToActiveSpace, .fullScreenAuxiliary]
}

/// 다른 앱 클릭, ⌘⇥, 데스크탑 전환을 이유와 함께 알린다.
final class FocusLossWatcher {
    private let onLeave: (FocusLossReason) -> Void
    private var mouseMonitor: Any?
    private var observers: [Any] = []
    private var lastSpaceChange = Date.distantPast
    private var generation = 0 // stop 뒤 늦게 도는 확인이 새로 켠 감시를 건드리지 않게
    private var ignoredApp: (pid: pid_t, until: Date)?

    init(onLeave: @escaping (FocusLossReason) -> Void) {
        self.onLeave = onLeave
    }

    /// ignoring 은 우리 붙여넣기가 앞으로 불러올 앱. 잠깐 그 앱의 활성화는 떠남으로 보지 않는다.
    func start(ignoring app: NSRunningApplication? = nil) {
        if let app { ignoredApp = (app.processIdentifier, Date().addingTimeInterval(1.5)) }
        guard mouseMonitor == nil else { return }
        generation += 1
        let current = generation
        // 전역 모니터는 다른 앱 창에 떨어진 클릭만 받는다
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.onLeave(.otherApp)
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            self?.lastSpaceChange = Date()
            self?.onLeave(.spaceChange)
        })
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                            object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let self, let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            if let ignored = self.ignoredApp, ignored.pid == app.processIdentifier, Date() < ignored.until { return }
            // 데스크탑을 옮기면 그 화면의 앱이 앞으로 온다. 전환 알림이 뒤따라 오므로 잠깐 기다린다
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, self.generation == current, self.mouseMonitor != nil else { return }
                if Date().timeIntervalSince(self.lastSpaceChange) > 0.6 { self.onLeave(.otherApp) }
            }
        })
    }

    func stop() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
        generation += 1
    }
}
