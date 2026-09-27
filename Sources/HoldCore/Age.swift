import Foundation

/// 목록에 보이는 경과 시간. 분 단위로 자른다.
public enum Age {
    public static func text(since date: Date, now: Date = Date()) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        switch minutes {
        case ..<1: return "방금"
        case ..<60: return "\(minutes)분 전"
        case ..<(60 * 24): return "\(minutes / 60)시간 전"
        default: return "\(minutes / (60 * 24))일 전"
        }
    }
}
