import AppKit
import HoldCore

/// 붙여넣을 앱에서 초점이 어떤 요소에 있는지 읽는다. 내용은 읽지 않는다.
enum FocusProbe {
    static func focused(in app: NSRunningApplication?) -> FocusInfo? {
        guard let app else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        return FocusInfo(role: string(element, kAXRoleAttribute),
                         subrole: string(element, kAXSubroleAttribute),
                         valueSettable: settable.boolValue,
                         hasEditableAncestor: has(element, "AXEditableAncestor"))
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func has(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success && value != nil
    }
}

extension FocusInfo {
    var summary: String {
        "role=\(role ?? "nil") subrole=\(subrole ?? "nil") valueSettable=\(valueSettable) editableAncestor=\(hasEditableAncestor) text=\(isTextInput)"
    }
}
