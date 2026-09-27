import Foundation
import HoldCore

var failures = 0
func check(_ ok: Bool, _ name: String, line: Int = #line) {
    print(ok ? "PASS" : "FAIL", name, ok ? "" : "(line \(line))")
    if !ok { failures += 1 }
}

do {
    let s = HoldStore(fileURL: nil)
    s.push("a"); s.push("b")
    check(s.items.map(\.text) == ["b", "a"], "push 는 맨 위에 쌓는다")
}
do {
    let s = HoldStore(fileURL: nil)
    check(!s.push("  \n ") && s.items.isEmpty, "공백은 넣지 않는다")
}
do {
    let s = HoldStore(fileURL: nil)
    s.push("a"); s.push("b")
    check(s.pop()?.text == "b" && s.items.map(\.text) == ["a"], "pop 은 맨 위를 꺼낸다")
    check(HoldStore(fileURL: nil).pop() == nil, "빈 스택 pop 은 nil")
}
do {
    let s = HoldStore(fileURL: nil)
    ["a", "b", "c"].forEach { s.push($0) }   // c b a
    s.remove(at: 1)
    check(s.items.map(\.text) == ["c", "a"], "중간 항목 삭제")
    check(s.undo() && s.items.map(\.text) == ["c", "b", "a"], "undo 는 원래 자리로 되돌린다")
    check(!s.undo(), "undo 는 한 번만")
}
do {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString).appendingPathComponent("stack.json")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    HoldStore(fileURL: url).push("keep me")
    check(HoldStore(fileURL: url).items.map(\.text) == ["keep me"], "재시작 후에도 남는다")
}

do {
    let suite = "holdstack-check-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    defer { d.removePersistentDomain(forName: suite) }
    let s = ShortcutSettings(defaults: d)
    check(s[.hold].display == "⌃⇧H", "기본 단축키 표시")
    let ctrlShiftH = Shortcut(keyCode: 4, modifiers: Shortcut.control | Shortcut.shift, key: "H")
    check((try? s.set(ctrlShiftH, for: .pop)) == nil, "다른 동작과 겹치면 거부")
    let shiftOnly = Shortcut(keyCode: 0, modifiers: Shortcut.shift, key: "A")
    check((try? s.set(shiftOnly, for: .pop)) == nil, "⇧ 만 있는 조합은 거부")
    let cmdC = Shortcut(keyCode: 8, modifiers: Shortcut.command, key: "C")
    check((try? s.set(cmdC, for: .pop)) == nil, "⌘C 같은 편집 키는 거부")
    let cmdShiftC = Shortcut(keyCode: 8, modifiers: Shortcut.command | Shortcut.shift, key: "C")
    check((try? s.set(cmdShiftC, for: .pop)) != nil, "⌘⇧C 는 허용")
    let optJ = Shortcut(keyCode: 38, modifiers: Shortcut.option, key: "J")
    check((try? s.set(optJ, for: .pop)) != nil && s[.pop] == optJ, "유효한 조합은 저장")
    check(ShortcutSettings(defaults: d)[.pop] == optJ, "재시작 후에도 남는다 (단축키)")
    s.resetToDefaults()
    check(ShortcutSettings(defaults: d)[.pop] == HotKeyAction.pop.defaultShortcut, "기본값 복원")
}

do {
    let s = HoldStore(fileURL: nil)
    s.push("왜 그런가?", quote: "  캐시가 무효화된다  ")
    check(s.items[0].pasteText == "\"캐시가 무효화된다\"\n\n왜 그런가?", "문장+질문 붙여넣기 형식")
    s.push("", quote: "문장만")
    check(s.items[0].pasteText == "\"문장만\"", "문장만 있으면 따옴표만")
    s.push("질문만")
    check(s.items[0].pasteText == "질문만" && s.items[0].quote == nil, "질문만 있으면 그대로")
    check(!s.push(" ", quote: " "), "둘 다 비면 거부")
}
do {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString).appendingPathComponent("stack.json")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let old = #"[{"id":"7C4A8D09-CA37-4E3A-9B1D-1F0E8A2B3C4D","text":"옛 항목","createdAt":0}]"#
    try? old.data(using: .utf8)!.write(to: url)
    let s = HoldStore(fileURL: url)
    check(s.items.map(\.text) == ["옛 항목"] && s.items[0].quote == nil, "문장 없는 옛 저장 파일도 읽는다")
}
do {
    let suite = "holdstack-check-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    defer { d.removePersistentDomain(forName: suite) }
    let a = PanelAppearance(defaults: d)
    a.opacity = 0.1
    check(a.opacity == 0.3, "투명도 하한")
    a.opacity = 0.6
    check(PanelAppearance(defaults: d).opacity == 0.6, "투명도 저장")
}

do {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("stack.json")
    try? "not json".data(using: .utf8)!.write(to: url)
    let s = HoldStore(fileURL: url)
    s.push("new")
    let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
    check(s.items.map(\.text) == ["new"] && names.contains { $0.hasPrefix("stack.json.bad-") }, "깨진 파일은 덮어쓰지 않고 치워 둔다")
}
do {
    let suite = "holdstack-check-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    defer { d.removePersistentDomain(forName: suite) }
    d.set(0.05, forKey: "panelOpacity")
    check(PanelAppearance(defaults: d).opacity == 0.3, "저장된 값이 범위 밖이어도 맞춘다")
}

exit(failures == 0 ? 0 : 1)
