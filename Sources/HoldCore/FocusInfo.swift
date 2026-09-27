import Foundation

/// 붙여넣을 앱에서 초점이 가 있는 요소의 종류. 내용은 담지 않는다.
public struct FocusInfo: Equatable {
    public let role: String?
    public let subrole: String?
    public let valueSettable: Bool
    public let hasEditableAncestor: Bool

    public init(role: String?, subrole: String? = nil, valueSettable: Bool, hasEditableAncestor: Bool) {
        self.role = role
        self.subrole = subrole
        self.valueSettable = valueSettable
        self.hasEditableAncestor = hasEditableAncestor
    }

    static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

    /// 웹페이지 본문(AXWebArea)도 선택 범위를 갖고 있어서 그것만으로는 가리지 않는다.
    public var isTextInput: Bool {
        (role.map(Self.textRoles.contains) ?? false) || valueSettable || hasEditableAncestor
    }

    /// 초점을 읽지 못했으면 막지 않는다. 읽었는데 입력칸이 아닐 때만 막는다.
    public static func shouldBlockPaste(_ info: FocusInfo?) -> Bool {
        guard let info else { return false }
        return !info.isTextInput
    }
}
