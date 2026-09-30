import Carbon

/// 조합 입력기(한글, 일본어 등)가 켜져 있으면 합성 ⌘C, ⌘V 가 ㅊ, ㅍ 로 번역되어 앱에 닿는다.
/// 키를 보내는 동안만 영문 자판으로 바꾼다.
enum InputSource {
    static var isASCIICapable: Bool {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return true }
        return asciiCapable(current)
    }

    /// 영문 자판으로 바꾸고 되돌리는 일을 돌려준다. 이미 영문이면 아무것도 하지 않는다.
    static func useASCII() -> () -> Void {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              !asciiCapable(current),
              let ascii = TISCopyCurrentASCIICapableKeyboardInputSource()?.takeRetainedValue(),
              TISSelectInputSource(ascii) == noErr
        else { return {} }
        DiagLog.write("input source \(id(current) ?? "nil") -> \(id(ascii) ?? "nil")")
        return {
            if TISSelectInputSource(current) != noErr {
                DiagLog.write("input source restore failed: \(id(current) ?? "nil")")
            }
        }
    }

    private static func asciiCapable(_ source: TISInputSource) -> Bool {
        guard let value = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsASCIICapable) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue())
    }

    private static func id(_ source: TISInputSource) -> String? {
        TISGetInputSourceProperty(source, kTISPropertyInputSourceID).map {
            Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String
        }
    }
}
