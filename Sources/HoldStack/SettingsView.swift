import AppKit
import Carbon
import HoldCore
import SwiftUI

/// 설정 창의 키 처리. 녹화 중이면 누른 조합을 단축키로 받고, 아니면 esc 로 창을 닫는다.
/// 감시를 하나로 두어야 esc 를 누가 먼저 받는지 헷갈리지 않는다.
final class ShortcutRecorder: ObservableObject {
    @Published private(set) var recording: HotKeyAction?
    @Published var message: String?
    private var monitor: Any?
    private var resignObserver: Any?
    private weak var window: NSWindow?
    private let apply: (Shortcut, HotKeyAction) -> String?
    private let applyEnabled: (Bool, HotKeyAction) -> String?
    private let setRecording: (Bool) -> Void

    /// apply, applyEnabled 는 실패하면 사용자에게 보여줄 문구를 돌려준다.
    init(apply: @escaping (Shortcut, HotKeyAction) -> String?,
         applyEnabled: @escaping (Bool, HotKeyAction) -> String?,
         setRecording: @escaping (Bool) -> Void) {
        self.apply = apply
        self.applyEnabled = applyEnabled
        self.setRecording = setRecording
    }

    /// 녹화 중이면 먼저 멈춘다. 녹화는 전역 단축키를 풀어 둔 상태라 섞이면 안 된다.
    func setEnabled(_ on: Bool, for action: HotKeyAction) {
        stop()
        message = applyEnabled(on, action)
    }

    func attach(to window: NSWindow, onEscape: @escaping () -> Void) {
        self.window = window
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            let isEscape = Int(event.keyCode) == kVK_Escape
            if let action = self.recording {
                self.stop()
                if !isEscape { self.message = self.apply(Shortcut(event: event), action) }
                return nil
            }
            guard isEscape else { return event }
            onEscape()
            return nil
        }
    }

    func start(_ action: HotKeyAction) {
        stop()
        recording = action
        message = nil
        setRecording(true)
        // 다른 앱으로 넘어가면 녹화를 끝내야 전역 단축키가 돌아온다
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.stop() }
    }

    func stop() {
        guard recording != nil else { return }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        recording = nil
        setRecording(false)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: ShortcutSettings
    @ObservedObject var prefs: Preferences
    @ObservedObject var loginItem: LoginItem
    @ObservedObject var recorder: ShortcutRecorder

    var body: some View {
        Form {
            Section("일반") {
                Toggle("로그인할 때 자동으로 실행", isOn: Binding(get: { loginItem.enabled }, set: { loginItem.set($0) }))
                if let message = loginItem.message {
                    Text(message).foregroundStyle(.orange).font(.callout)
                }
                Toggle("메뉴 막대에 보관 개수 표시", isOn: $prefs.showCountInMenuBar)
            }
            Section("목록 창") {
                LabeledContent("투명도") {
                    HStack {
                        Slider(value: $prefs.opacity, in: Preferences.opacityRange)
                        Text("\(Int((prefs.opacity * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                    .frame(width: 220)
                }
                Toggle("불러온 뒤 창 닫기", isOn: $prefs.closeAfterLoad)
                Toggle("입력칸이 아니면 붙여넣지 않기", isOn: $prefs.pasteOnlyIntoText)
                Toggle("다른 앱을 누르면 창 닫기", isOn: $prefs.hideOnFocusLoss)
                Toggle("데스크탑을 옮기면 창 닫기", isOn: $prefs.hideOnSpaceChange)
                Picker("→ 로 펼칠 때", selection: $prefs.expandStyle) {
                    ForEach(ExpandStyle.allCases) { Text($0.title).tag($0) }
                }
                Text("창을 옮기거나 크기를 바꾸면 다음에도 그 자리, 그 크기로 열립니다")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("글자 크기") {
                fontRow("의문을 가진 문장", value: $prefs.quoteFontSize)
                fontRow("나의 질문", value: $prefs.questionFontSize)
                VStack(alignment: .leading, spacing: 4) {
                    QuoteLine(text: "빌드할 때마다 서명이 바뀌어 권한이 풀린다.", size: prefs.quoteFontSize, lineLimit: 1)
                    Text("왜 그래야 하는 걸까").font(.system(size: prefs.questionFontSize))
                }
                .padding(.vertical, 4)
            }
            Section("전역 단축키") {
                ForEach(HotKeyAction.allCases) { action in
                    LabeledContent(action.title) {
                        HStack(spacing: 10) {
                            Button(recorder.recording == action ? "키 조합을 누르세요…" : settings[action].display) {
                                recorder.start(action)
                            }
                            .frame(minWidth: 140)
                            .disabled(!settings.isEnabled(action))
                            Toggle("", isOn: Binding(get: { settings.isEnabled(action) },
                                                     set: { recorder.setEnabled($0, for: action) }))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                    }
                }
                if let message = recorder.message {
                    Text(message).foregroundStyle(.red).font(.callout)
                }
                HStack {
                    Spacer()
                    Button("단축키 기본값으로") {
                        recorder.stop()
                        settings.resetToDefaults()
                        recorder.message = nil
                    }
                }
            }
            Section("목록 창 안의 키 (고정)") {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                    ForEach(Self.panelKeys, id: \.0) { key, meaning in
                        GridRow {
                            Text(key).monospaced()
                            Text(meaning).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 760) // Form 은 스스로 높이를 갖지 않는다
        .onDisappear { recorder.stop() }
    }

    private func fontRow(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            Stepper(value: value, in: Preferences.fontSizeRange, step: 1) {
                Text("\(Int(value.wrappedValue))pt").monospacedDigit()
            }
        }
    }

    private static let panelKeys = [
        ("↑ ↓", "이동"), ("→ ←", "선택한 항목 펼치기, 접기 (방식은 위에서 고른다)"), ("⏎", "불러오기 (휴지통에서는 스택으로 되돌리기)"),
        ("⌫", "휴지통으로 (휴지통에서는 지우기)"), ("⇥", "스택과 휴지통 전환"), ("⌘Z", "마지막 동작 되돌리기, 최대 10단계"),
        ("⌘,", "설정 열기"), ("esc", "닫기"),
    ]
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
