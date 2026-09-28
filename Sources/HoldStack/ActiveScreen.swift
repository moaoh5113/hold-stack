import AppKit
import HoldCore

/// 창을 어느 화면의 어디에 놓을지 정한다.
enum ActiveScreen {
    /// 지금 초점이 가 있는 화면. 손쉬운 사용 권한이 없으면 마우스가 있는 화면으로 물러선다.
    /// 어떤 근거로 골랐는지 함께 돌려준다. 엉뚱한 화면에 떴을 때 진단 기록으로 가린다.
    static func resolved() -> (screen: NSScreen?, source: String) {
        if let screen = focusedWindowScreen() { return (screen, "focus") }
        if let screen = screen(containing: NSEvent.mouseLocation) { return (screen, "mouse") }
        return (NSScreen.main, "main")
    }

    /// 앞에 나와 있는 다른 앱의 초점 창이 놓인 화면.
    private static func focusedWindowScreen() -> NSScreen? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let center = focusedWindowCenter(of: app) else { return nil }
        return screen(containing: center)
    }

    private static func focusedWindowCenter(of app: NSRunningApplication) -> NSPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier),
                                            kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let window = value as! AXUIElement
        guard let origin = point(window, kAXPositionAttribute),
              let size = size(window, kAXSizeAttribute),
              let base = primaryTop else { return nil }
        // 손쉬운 사용은 왼쪽 위가 0 이고 아래로 갈수록 y 가 커진다. Cocoa 는 반대라 뒤집어야 한다
        return NSPoint(x: origin.x + size.width / 2, y: base - (origin.y + size.height / 2))
    }

    private static var primaryTop: CGFloat? {
        (NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens.first)?.frame.maxY
    }

    private static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    private static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let value = axValue(element, attribute) else { return nil }
        var result = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &result) ? result : nil
    }

    private static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let value = axValue(element, attribute) else { return nil }
        var result = CGSize.zero
        return AXValueGetValue(value, .cgSize, &result) ? result : nil
    }

    private static func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }
}

/// 창을 초점이 가 있는 화면으로 옮긴다. 이미 그 화면에 있으면 건드리지 않는다.
/// force 는 저장된 자리를 무시하고 화면 가운데에 놓는다.
func placeOnActiveScreen(_ window: NSWindow, frameName: String, force: Bool = false) {
    let (active, source) = ActiveScreen.resolved()
    guard let active else { return }
    let target = active.visibleFrame
    let index = NSScreen.screens.firstIndex(of: active) ?? -1
    let saved = UserDefaults.standard.string(forKey: "NSWindow Frame \(frameName)") != nil
    let from = NSScreen.screens.first { $0.visibleFrame.contains(window.frame) }?.visibleFrame
    guard !force, saved, let from else {
        window.setFrame(ScreenFit.centered(window.frame, in: target), display: true)
        return DiagLog.write("place \(frameName) via=\(source) screen=\(index) centered")
    }
    if from.equalTo(target) { return }
    window.setFrame(ScreenFit.carried(window.frame, from: from, to: target), display: true)
    DiagLog.write("place \(frameName) via=\(source) screen=\(index) carried")
}
