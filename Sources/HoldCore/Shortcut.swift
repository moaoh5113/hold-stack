import Foundation

public struct Shortcut: Codable, Equatable {
    public var keyCode: UInt32
    public var modifiers: UInt32 // Carbon 수식키 비트
    public var key: String       // 표시용

    public static let command: UInt32 = 1 << 8
    public static let shift: UInt32 = 1 << 9
    public static let option: UInt32 = 1 << 11
    public static let control: UInt32 = 1 << 12

    public init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    public var display: String {
        [(Self.control, "⌃"), (Self.option, "⌥"), (Self.shift, "⇧"), (Self.command, "⌘")]
            .filter { modifiers & $0.0 != 0 }
            .map(\.1)
            .joined() + key.uppercased()
    }

    /// ⇧ 만 붙은 조합은 평소 타이핑과 겹친다.
    public var hasRequiredModifier: Bool {
        modifiers & (Self.command | Self.option | Self.control) != 0
    }

    /// ⌘ 하나에 붙은 편집 키. 가로채면 모든 앱에서 복사, 붙여넣기가 먹통이 된다.
    public var isReserved: Bool {
        let reservedWithCommand: Set<UInt32> = [0, 6, 7, 8, 9, 12, 13, 48, 49] // A Z X C V Q W Tab Space
        return modifiers == Self.command && reservedWithCommand.contains(keyCode)
    }

    public func sameKeys(as other: Shortcut) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }
}

public enum HotKeyAction: String, CaseIterable, Codable, Identifiable {
    case hold, toggleList, pop

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hold: L("의문 적기")
        case .toggleList: L("목록 열기")
        case .pop: L("맨 위 꺼내기")
        }
    }

    public var defaultShortcut: Shortcut {
        let mods = Shortcut.control | Shortcut.shift
        return switch self {
        case .hold: Shortcut(keyCode: 4, modifiers: mods, key: "H")
        case .toggleList: Shortcut(keyCode: 37, modifiers: mods, key: "L")
        case .pop: Shortcut(keyCode: 35, modifiers: mods, key: "P")
        }
    }
}

public enum ShortcutError: Error, Equatable {
    case needsModifier
    case reserved
    case duplicate(HotKeyAction)

    public var message: String {
        switch self {
        case .needsModifier: L("⌃, ⌥, ⌘ 중 하나는 함께 눌러야 합니다")
        case .reserved: L("복사, 붙여넣기 같은 편집 단축키는 쓸 수 없습니다")
        case .duplicate(let other): L("「%@」에서 이미 쓰는 조합입니다", other.title)
        }
    }
}

public final class ShortcutSettings: ObservableObject {
    @Published public private(set) var shortcuts: [HotKeyAction: Shortcut] = [:]
    /// 끈 단축키는 등록하지 않는다. 조합은 남겨 두어 다시 켤 때 겹치지 않게 한다.
    @Published public private(set) var disabled: Set<HotKeyAction> = []
    private let defaults: UserDefaults
    private static let storageKey = "shortcuts"
    private static let disabledKey = "disabledShortcuts"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([String: Shortcut].self, from: $0) } ?? [:]
        for action in HotKeyAction.allCases {
            shortcuts[action] = saved[action.rawValue] ?? action.defaultShortcut
        }
        disabled = Set((defaults.stringArray(forKey: Self.disabledKey) ?? []).compactMap(HotKeyAction.init))
    }

    public func isEnabled(_ action: HotKeyAction) -> Bool { !disabled.contains(action) }

    public func setEnabled(_ on: Bool, for action: HotKeyAction) {
        if on { disabled.remove(action) } else { disabled.insert(action) }
        defaults.set(disabled.map(\.rawValue).sorted(), forKey: Self.disabledKey)
    }

    public subscript(action: HotKeyAction) -> Shortcut {
        shortcuts[action] ?? action.defaultShortcut
    }

    public func set(_ shortcut: Shortcut, for action: HotKeyAction) throws {
        guard shortcut.hasRequiredModifier else { throw ShortcutError.needsModifier }
        guard !shortcut.isReserved else { throw ShortcutError.reserved }
        if let other = HotKeyAction.allCases.first(where: { $0 != action && self[$0].sameKeys(as: shortcut) }) {
            throw ShortcutError.duplicate(other)
        }
        shortcuts[action] = shortcut
        save()
    }

    public func resetToDefaults() {
        for action in HotKeyAction.allCases { shortcuts[action] = action.defaultShortcut }
        save()
    }

    private func save() {
        let raw = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        defaults.set(try? JSONEncoder().encode(raw), forKey: Self.storageKey)
    }
}
