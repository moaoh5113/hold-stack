import AppKit
import Carbon

/// 다른 앱의 선택 영역을 복사하고, 텍스트를 붙여넣는다.
/// 키 입력을 흉내 내므로 손쉬운 사용 권한이 필요하다.
enum Clipboard {
    /// 복사나 붙여넣기 뒤 원래 클립보드를 되돌리기 전까지 true.
    private(set) static var isBusy = false

    /// 가짜 키 입력은 손쉬운 사용 권한과 이벤트 전송 권한 중 하나로 허용된다.
    /// 붙여넣기까지 지연이 있을 때, 그 사이 다른 복사나 붙여넣기가 끼어들지 못하게 먼저 잡는다.
    static func reserve() { isBusy = true }

    static var canSendKeys: Bool { AXIsProcessTrusted() || CGPreflightPostEventAccess() }

    static var permissionSummary: String {
        "ax=\(AXIsProcessTrusted()) postEvent=\(CGPreflightPostEventAccess())"
    }

    static func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        CGRequestPostEventAccess()
    }

    /// ⌘C 를 보내 선택 영역을 읽는다. 선택이 없으면 nil. 원래 클립보드는 되돌린다.
    static func copySelection(completion: @escaping (String?) -> Void) {
        guard !isBusy else { return }
        isBusy = true
        let pb = NSPasteboard.general
        let saved = snapshot()
        let before = pb.changeCount
        let restoreInput = InputSource.useASCII()
        poll(until: { InputSource.isASCIICapable }, timeout: 0.3) { _ in
            sendKey(kVK_ANSI_C)
            poll(until: { pb.changeCount != before }, timeout: 0.5) { changed in
                restoreInput()
                let text = changed ? pb.string(forType: .string) : nil
                if changed {
                    restore(saved)
                } else {
                    // 늦게 도착한 복사가 클립보드를 덮어쓰는 경우
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if pb.changeCount != before { restore(saved) }
                    }
                }
                isBusy = false
                completion(text)
            }
        }
    }

    /// target 이 맨 앞에 올 때까지 기다렸다가 ⌘V 를 보낸다. 권한이 없으면 클립보드에 넣어두기만 한다.
    static func paste(_ text: String, into target: NSRunningApplication?) {
        let pb = NSPasteboard.general
        let saved = snapshot()
        pb.clearContents()
        pb.setString(text, forType: .string)
        let front = NSWorkspace.shared.frontmostApplication
        DiagLog.write("paste len=\(text.count) \(permissionSummary) target=\(target?.bundleIdentifier ?? "nil") front=\(front?.bundleIdentifier ?? "nil")")
        guard canSendKeys else {
            isBusy = false
            return DiagLog.write("paste: no permission, clipboard only")
        }
        isBusy = true
        if let target, front?.processIdentifier != target.processIdentifier {
            target.activate()
        }
        let ready = { target == nil || NSWorkspace.shared.frontmostApplication?.processIdentifier == target?.processIdentifier }
        poll(until: ready, timeout: 1.0) { ok in
            let focus = FocusProbe.focused(in: target ?? NSWorkspace.shared.frontmostApplication)
            DiagLog.write("paste: send cmd+v frontReady=\(ok) front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil") focus: \(focus?.summary ?? "unreadable")")
            let ours = pb.changeCount
            let restoreInput = InputSource.useASCII()
            poll(until: { InputSource.isASCIICapable }, timeout: 0.3) { _ in
                sendKey(kVK_ANSI_V)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    restoreInput()
                    if pb.changeCount == ours { restore(saved) } // 그 사이 사용자가 새로 복사했으면 두기
                    isBusy = false
                }
            }
        }
    }

    private typealias Snapshot = [[NSPasteboard.PasteboardType: Data]]

    /// 이미지, 파일, 서식까지 모든 형식을 담는다.
    private static func snapshot() -> Snapshot {
        (NSPasteboard.general.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    private static func restore(_ snapshot: Snapshot) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(snapshot.map { entries in
            let item = NSPasteboardItem()
            entries.forEach { item.setData($0.value, forType: $0.key) }
            return item
        })
    }

    private static func poll(until condition: @escaping () -> Bool, timeout: TimeInterval,
                             done: @escaping (Bool) -> Void) {
        let deadline = Date().addingTimeInterval(timeout)
        func tick() {
            if condition() { return done(true) }
            if Date() >= deadline { return done(false) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: tick)
        }
        tick()
    }

    private static func sendKey(_ key: Int) {
        let src = CGEventSource(stateID: .combinedSessionState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(key), keyDown: isDown)
            event?.flags = .maskCommand // 누르고 있는 ⌃⇧ 를 덮어쓴다
            event?.post(tap: .cghidEventTap)
        }
    }
}
