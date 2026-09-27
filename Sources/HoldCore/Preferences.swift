import Foundation

public final class PanelAppearance: ObservableObject {
    public static let opacityRange: ClosedRange<Double> = 0.3...1.0
    private static let opacityKey = "panelOpacity"
    private let defaults: UserDefaults

    /// 범위를 벗어난 값은 가장자리로 맞춘다.
    @Published public var opacity: Double {
        didSet {
            let clamped = min(max(opacity, Self.opacityRange.lowerBound), Self.opacityRange.upperBound)
            if clamped != opacity { opacity = clamped }
            defaults.set(opacity, forKey: Self.opacityKey)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.object(forKey: Self.opacityKey) as? Double ?? 0.95
        opacity = min(max(saved, Self.opacityRange.lowerBound), Self.opacityRange.upperBound)
    }
}
