import AppKit
import Carbon
import HoldCore
import SwiftUI

/// 단축키 녹화 상태. 키 감시 클로저가 붙잡을 수 있게 클래스로 둔다.
final class ShortcutRecorder: ObservableObject {
    @Published private(set) var recording: HotKeyAction?
    @Published var message: String?
    private var monitor: Any?
    private var resignObserver: Any?
    weak var window: NSWindow?
    private let apply: (Shortcut, HotKeyAction) -> String?
    private let setRecording: (Bool) -> Void

    /// apply 는 실패하면 사용자에게 보여줄 문구를 돌려준다.
    init(apply: @escaping (Shortcut, HotKeyAction) -> String?, setRecording: @escaping (Bool) -> Void) {
        self.apply = apply
        self.setRecording = setRecording
    }

    func start(_ action: HotKeyAction) {
        stop()
        recording = action
        message = nil
        setRecording(true)
        // 다른 앱으로 넘어가면 녹화를 끝내야 전역 단축키가 돌아온다
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.stop() }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            self.stop()
            if Int(event.keyCode) != kVK_Escape {
                self.message = self.apply(Shortcut(event: event), action)
            }
            return nil
        }
    }

    func stop() {
        guard recording != nil else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        monitor = nil
        resignObserver = nil
        recording = nil
        setRecording(false)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: ShortcutSettings
    @ObservedObject var appearance: PanelAppearance
    @ObservedObject var recorder: ShortcutRecorder

    var body: some View {
        Form {
            Section("전역 단축키") {
                ForEach(HotKeyAction.allCases) { action in
                    LabeledContent(action.title) {
                        Button(recorder.recording == action ? "키 조합을 누르세요…" : settings[action].display) {
                            recorder.start(action)
                        }
                        .frame(minWidth: 140)
                    }
                }
                if let message = recorder.message {
                    Text(message).foregroundStyle(.red).font(.callout)
                }
            }
            Section("목록 창") {
                LabeledContent("투명도") {
                    HStack {
                        Slider(value: $appearance.opacity, in: PanelAppearance.opacityRange)
                        Text("\(Int((appearance.opacity * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                    .frame(width: 220)
                }
                Text("창을 옮기거나 크기를 바꾸면 다음에도 그 자리, 그 크기로 열립니다")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("목록 창 안의 키 (고정)") {
                Text("↑↓ 이동   ⏎ 불러오기   ⌫ 지우기   ⌘Z 되돌리기   esc 닫기")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("기본값으로") {
                    recorder.stop()
                    settings.resetToDefaults()
                    recorder.message = nil
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .onDisappear { recorder.stop() }
    }
}

extension Shortcut {
    init(event: NSEvent) {
        let flags = event.modifierFlags
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= Shortcut.command }
        if flags.contains(.shift) { mods |= Shortcut.shift }
        if flags.contains(.option) { mods |= Shortcut.option }
        if flags.contains(.control) { mods |= Shortcut.control }
        self.init(keyCode: UInt32(event.keyCode), modifiers: mods, key: Shortcut.keyName(event))
    }

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static let ansiKeys: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E", kVK_ANSI_F: "F",
        kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R",
        kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z", kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
    ]

    /// 한글 자판이나 ⇧ 가 섞여도 자판에 적힌 글자로 보여준다 (ㅗ, ! 가 아니라 H, 1).
    private static func keyName(_ event: NSEvent) -> String {
        let code = Int(event.keyCode)
        if let name = specialKeys[code] ?? ansiKeys[code] { return name }
        return event.characters(byApplyingModifiers: [])?.uppercased() ?? "#\(code)"
    }
}
