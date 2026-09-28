import CoreGraphics

/// 창을 화면 안 어디에 놓을지 계산한다. 화면을 읽지 않는 순수 계산이다.
public enum ScreenFit {
    /// 화면 가운데보다 조금 위에 놓는다. 화면보다 크면 줄인다.
    public static func centered(_ frame: CGRect, in visible: CGRect) -> CGRect {
        let width = min(frame.width, visible.width - margin)
        let height = min(frame.height, visible.height - margin)
        let y = min(visible.midY - height / 2 + visible.height / 6, visible.maxY - height)
        return CGRect(x: visible.midX - width / 2, y: y, width: width, height: height)
    }

    /// 쓰던 자리를 화면 안의 비율로 바꿔 다른 화면의 같은 자리에 놓는다.
    public static func carried(_ frame: CGRect, from old: CGRect, to new: CGRect) -> CGRect {
        let width = min(frame.width, new.width - margin)
        let height = min(frame.height, new.height - margin)
        let x = new.minX + (new.width - width) * ratio(frame.minX - old.minX, old.width - frame.width)
        let y = new.minY + (new.height - height) * ratio(frame.minY - old.minY, old.height - frame.height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static let margin: CGFloat = 40

    /// 창이 화면을 꽉 채워 움직일 여지가 없으면 가운데로 본다.
    private static func ratio(_ offset: CGFloat, _ span: CGFloat) -> CGFloat {
        span > 0 ? min(max(offset / span, 0), 1) : 0.5
    }
}
