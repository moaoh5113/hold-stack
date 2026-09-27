import Foundation

/// → 로 펼칠 때의 모양.
public enum ExpandStyle: String, CaseIterable, Identifiable {
    case inline  // 그 줄만 커진다
    case detail  // 목록을 가리고 그 항목만 보인다

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .inline: "그 자리에서 펼치기"
        case .detail: "내용만 크게 보기"
        }
    }
}

public enum FocusLossReason {
    case otherApp     // 다른 앱 클릭, ⌘⇥
    case spaceChange  // 데스크탑 전환
}

/// 설정 창의 부가 기능. 모두 UserDefaults 에 저장된다.
public final class Preferences: ObservableObject {
    public static let opacityRange: ClosedRange<Double> = 0.3...1.0
    public static let fontSizeRange: ClosedRange<Double> = 10...24
    private enum Key {
        static let opacity = "panelOpacity"
        static let closeAfterLoad = "closeAfterLoad"
        static let showCount = "showCountInMenuBar"
        static let expandStyle = "expandStyle"
        static let hideOnFocusLoss = "hideOnFocusLoss"
        static let hideOnSpaceChange = "hideOnSpaceChange"
        static let questionFontSize = "questionFontSize"
        static let quoteFontSize = "quoteFontSize"
        static let pasteOnlyIntoText = "pasteOnlyIntoText"
        static let trashLimit = "trashLimit"
    }
    private let defaults: UserDefaults

    /// 범위를 벗어난 값은 가장자리로 맞춘다.
    @Published public var opacity: Double {
        didSet {
            let clamped = Self.clamp(opacity)
            if clamped != opacity { opacity = clamped }
            defaults.set(opacity, forKey: Key.opacity)
        }
    }

    /// 끄면 불러온 뒤에도 목록 창이 떠 있다.
    @Published public var closeAfterLoad: Bool {
        didSet { defaults.set(closeAfterLoad, forKey: Key.closeAfterLoad) }
    }

    @Published public var showCountInMenuBar: Bool {
        didSet { defaults.set(showCountInMenuBar, forKey: Key.showCount) }
    }

    /// 다른 앱을 누르거나 ⌘⇥ 로 넘어가면 창을 내린다.
    @Published public var hideOnFocusLoss: Bool {
        didSet { defaults.set(hideOnFocusLoss, forKey: Key.hideOnFocusLoss) }
    }

    @Published public var hideOnSpaceChange: Bool {
        didSet { defaults.set(hideOnSpaceChange, forKey: Key.hideOnSpaceChange) }
    }

    /// 데스크탑을 옮기면 닫을 창은 처음부터 따라오지 않게 한다. 따라왔다가 닫히면 깜빡인다.
    public var followsAcrossDesktops: Bool { !hideOnSpaceChange }

    /// 창이 내려갈 이유가 생겼을 때 설정에 따라 내릴지 정한다.
    public func shouldHide(for reason: FocusLossReason) -> Bool {
        switch reason {
        case .otherApp: hideOnFocusLoss
        case .spaceChange: hideOnSpaceChange
        }
    }

    /// 초점이 입력칸이 아니면 붙여넣지 않고 스택에 남긴다.
    @Published public var pasteOnlyIntoText: Bool {
        didSet { defaults.set(pasteOnlyIntoText, forKey: Key.pasteOnlyIntoText) }
    }

    /// 휴지통과 되돌리기 기록 개수.
    @Published public var trashLimit: Int {
        didSet {
            let clamped = min(max(trashLimit, HoldStore.trashLimitRange.lowerBound), HoldStore.trashLimitRange.upperBound)
            if clamped != trashLimit { trashLimit = clamped }
            defaults.set(trashLimit, forKey: Key.trashLimit)
        }
    }

    /// 나의 질문 글자 크기(pt).
    @Published public var questionFontSize: Double {
        didSet {
            let clamped = Self.clampFont(questionFontSize)
            if clamped != questionFontSize { questionFontSize = clamped }
            defaults.set(questionFontSize, forKey: Key.questionFontSize)
        }
    }

    /// 의문을 가진 문장 글자 크기(pt).
    @Published public var quoteFontSize: Double {
        didSet {
            let clamped = Self.clampFont(quoteFontSize)
            if clamped != quoteFontSize { quoteFontSize = clamped }
            defaults.set(quoteFontSize, forKey: Key.quoteFontSize)
        }
    }

    @Published public var expandStyle: ExpandStyle {
        didSet { defaults.set(expandStyle.rawValue, forKey: Key.expandStyle) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        opacity = Self.clamp(defaults.object(forKey: Key.opacity) as? Double ?? 0.95)
        closeAfterLoad = defaults.object(forKey: Key.closeAfterLoad) as? Bool ?? true
        showCountInMenuBar = defaults.object(forKey: Key.showCount) as? Bool ?? true
        hideOnFocusLoss = defaults.object(forKey: Key.hideOnFocusLoss) as? Bool ?? true
        hideOnSpaceChange = defaults.object(forKey: Key.hideOnSpaceChange) as? Bool ?? true
        trashLimit = min(max(defaults.object(forKey: Key.trashLimit) as? Int ?? HoldStore.defaultTrashLimit,
                             HoldStore.trashLimitRange.lowerBound), HoldStore.trashLimitRange.upperBound)
        pasteOnlyIntoText = defaults.object(forKey: Key.pasteOnlyIntoText) as? Bool ?? true
        questionFontSize = Self.clampFont(defaults.object(forKey: Key.questionFontSize) as? Double ?? 13)
        quoteFontSize = Self.clampFont(defaults.object(forKey: Key.quoteFontSize) as? Double ?? 12)
        expandStyle = defaults.string(forKey: Key.expandStyle).flatMap(ExpandStyle.init) ?? .detail
    }

    private static func clampFont(_ value: Double) -> Double {
        min(max(value.rounded(), fontSizeRange.lowerBound), fontSizeRange.upperBound)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, opacityRange.lowerBound), opacityRange.upperBound)
    }
}
