import Foundation

/// 목록을 오가는 계산. 화면과 떨어진 순수 계산이라 여기서 검사한다.
public enum ListNav {
    /// 끝에서 한 칸 더 가면 반대쪽 끝으로 돌아온다.
    public static func wrapped(_ index: Int, by delta: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let moved = (index + delta) % count
        return moved < 0 ? moved + count : moved
    }

    /// 위에서부터 센 화면 번호를 배열 자리로. 없는 번호면 nil.
    public static func index(forNumber number: Int, count: Int) -> Int? {
        guard number >= 1, number <= count else { return nil }
        return number - 1
    }
}

/// 숫자 키로 번호를 찾아가는 버퍼. 1 을 누른 뒤 2 가 오면 12 번으로 본다.
public struct NumberJump: Equatable {
    /// 다음 자릿수를 기다리는 중인 번호. nil 이면 기다리지 않는다.
    public private(set) var pending: Int?

    public init() {}

    /// 숫자 키 하나를 받아 갈 자리를 돌려준다. nil 이면 그런 번호가 없다.
    public mutating func push(_ digit: Int, count: Int) -> Int? {
        let joined = (pending ?? 0) * 10 + digit
        // 이어 붙인 번호가 목록 밖이면 방금 누른 숫자로 다시 시작한다
        let number = ListNav.index(forNumber: joined, count: count) != nil ? joined : digit
        guard let index = ListNav.index(forNumber: number, count: count) else {
            pending = nil
            return nil
        }
        pending = number * 10 <= count ? number : nil // 더 긴 번호가 없으면 바로 끝낸다
        return index
    }

    public mutating func clear() { pending = nil }

    public var text: String { pending.map(String.init) ?? "" }
}
