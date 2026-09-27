import Foundation

/// 목록에 보이는 경과 시간. 분 단위로 자른다.
public enum Age {
    public static func text(since date: Date, now: Date = Date()) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        switch minutes {
        case ..<1: return L("방금")
        case ..<60: return L("%d분 전", minutes)
        case ..<(60 * 24): return L("%d시간 전", minutes / 60)
        default: return L("%d일 전", minutes / (60 * 24))
        }
    }
}
