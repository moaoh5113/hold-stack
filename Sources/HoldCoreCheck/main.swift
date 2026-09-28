import CoreGraphics
import Foundation
import HoldCore

L10n.language = .ko // 검사 문구는 한국어 기준
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
    let a = Preferences(defaults: d)
    a.opacity = 0.1
    check(a.opacity == 0.3, "투명도 하한")
    a.opacity = 0.6
    check(Preferences(defaults: d).opacity == 0.6, "투명도 저장")
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
    check(Preferences(defaults: d).opacity == 0.3, "저장된 값이 범위 밖이어도 맞춘다")
}

do {
    let s = HoldStore(fileURL: nil)
    ["a", "b", "c"].forEach { s.push($0) }   // c b a
    s.pop()
    s.remove(at: 1)                          // a
    check(s.trash.map(\.text) == ["a", "c"] && s.trash.allSatisfy { $0.removedAt != nil }, "빠진 항목은 최근 것부터 휴지통으로")
    check(s.restoreFromTrash(at: 1) && s.items.map(\.text) == ["c", "b"] && s.trash.map(\.text) == ["a"], "휴지통에서 스택 맨 위로 되돌린다")
    check(s.items[0].removedAt == nil, "되돌린 항목은 휴지통 표시가 지워진다")
    s.deleteFromTrash(at: 0)
    check(s.trash.isEmpty, "휴지통에서 지우면 휴지통에서 빠진다")
}
do {
    let s = HoldStore(fileURL: nil)
    (1...12).forEach { s.push("\($0)") }
    (1...12).forEach { _ in s.pop() }
    check(s.trash.count == HoldStore.defaultTrashLimit && s.trash.first?.text == "1" && s.trash.last?.text == "10", "휴지통은 최근 10개만")
}
do {
    let s = HoldStore(fileURL: nil)
    s.push("a"); s.push("b")
    s.remove(at: 0)
    check(s.undo() && s.trash.isEmpty, "undo 하면 휴지통에서도 빠진다")
    s.clear()
    check(s.items.isEmpty && s.trash.map(\.text) == ["b", "a"], "전체 비우기도 휴지통으로")
}
do {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("stack.json")
    let s = HoldStore(fileURL: url)
    s.push("keep"); s.pop()
    check(HoldStore(fileURL: url).trash.map(\.text) == ["keep"], "휴지통도 재시작 후 남는다")
}

do {
    let suite = "holdstack-check-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    defer { d.removePersistentDomain(forName: suite) }
    let p = Preferences(defaults: d)
    check(p.closeAfterLoad && p.showCountInMenuBar && p.hideOnFocusLoss && p.hideOnSpaceChange, "부가 기능 기본값은 켜짐")
    p.hideOnSpaceChange = false
    check(p.shouldHide(for: .otherApp) && !p.shouldHide(for: .spaceChange), "닫는 이유마다 설정을 따로 본다")
    check(p.followsAcrossDesktops, "데스크탑 전환에 닫지 않으면 창이 따라온다")
    p.hideOnSpaceChange = true
    check(!p.followsAcrossDesktops, "데스크탑 전환에 닫으면 창이 따라오지 않는다")
    p.closeAfterLoad = false
    p.showCountInMenuBar = false
    let again = Preferences(defaults: d)
    check(!again.closeAfterLoad && !again.showCountInMenuBar, "부가 기능 설정 저장")
}

do {
    let s = HoldStore(fileURL: nil)
    (1...15).forEach { s.push("\($0)") }
    s.clear()
    check(s.trash.count == 15, "전체 비우기는 10개를 넘어도 전부 휴지통에")
    s.push("x"); s.pop()
    check(s.trash.count == HoldStore.defaultTrashLimit && s.trash.first?.text == "x", "다음 이동부터 다시 10개로")
}
do {
    let s = HoldStore(fileURL: nil)
    s.push("a")
    s.remove(at: 0)
    s.deleteFromTrash(at: 0)
    check(s.trash.isEmpty && s.undo() && s.trash.map(\.text) == ["a"] && s.items.isEmpty, "휴지통에서 지운 것은 undo 하면 휴지통으로 돌아온다")
    check(s.undo() && s.items.map(\.text) == ["a"], "한 번 더 undo 하면 스택으로")
}

do {
    let s = HoldStore(fileURL: nil)
    ["a", "b", "c", "d"].forEach { s.push($0) }   // d c b a
    s.remove(at: 1)   // c
    s.remove(at: 2)   // a
    s.pop()           // d
    check(s.items.map(\.text) == ["b"], "여러 번 빼기")
    check(s.undo() && s.items.map(\.text) == ["d", "b"], "undo 1: 가장 최근 것부터")
    check(s.undo() && s.items.map(\.text) == ["d", "b", "a"], "undo 2: 원래 자리로")
    check(s.undo() && s.items.map(\.text) == ["d", "c", "b", "a"], "undo 3: 처음 상태로")
    check(!s.undo() && s.trash.isEmpty && s.items.allSatisfy { $0.removedAt == nil }, "기록 끝, 휴지통 표시도 지워진다")
}
do {
    let s = HoldStore(fileURL: nil)
    ["a", "b", "c"].forEach { s.push($0) }
    s.clear()
    check(s.undo() && s.items.map(\.text) == ["c", "b", "a"], "전체 비우기는 한 번의 undo 로 전부 복구")
}
do {
    let s = HoldStore(fileURL: nil)
    ["a", "b"].forEach { s.push($0) }   // b a
    s.pop()                              // b
    s.pop()                              // a
    s.restoreFromTrash(at: 0)            // a 복귀. trash [b]
    check(s.undo() && s.items.isEmpty && s.trash.map(\.text) == ["a", "b"], "스택으로 되돌린 것을 undo 하면 휴지통 제자리로")
    check(s.undo() && s.items.map(\.text) == ["a"], "그다음 undo 는 a 꺼내기를 되돌린다")
    check(s.undo() && s.items.map(\.text) == ["b", "a"] && s.trash.isEmpty && !s.undo(), "마지막으로 b 꺼내기까지, 한 동작씩 거꾸로")
}
do {
    let s = HoldStore(fileURL: nil)
    (1...12).forEach { s.push("\($0)") }
    (1...12).forEach { _ in s.pop() }
    var n = 0
    while s.undo() { n += 1 }
    check(n == HoldStore.defaultTrashLimit && s.items.count == HoldStore.defaultTrashLimit, "undo 는 최대 10단계")
}

do {
    let now = Date()
    L10n.language = .ko
    let ago = { (sec: Double) in Age.text(since: now.addingTimeInterval(-sec), now: now) }
    check(ago(0) == "방금" && ago(59) == "방금", "1분 안은 방금")
    check(ago(60) == "1분 전" && ago(11 * 60 + 4) == "11분 전", "분 단위, 초는 버린다")
    check(ago(59 * 60 + 59) == "59분 전" && ago(3600) == "1시간 전", "60분부터 시간")
    check(ago(86400 * 3) == "3일 전", "하루부터 일")
}

do {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("stack.json")
    do {
        let s = HoldStore(fileURL: url)
        ["a", "b", "c"].forEach { s.push($0) }   // c b a
        s.remove(at: 1)                          // b
        s.pop()                                  // c
    }
    let reopened = HoldStore(fileURL: url)
    check(reopened.undoSteps == 2, "undo 기록은 재시작 후에도 남는다")
    check(reopened.undo() && reopened.undo() && reopened.items.map(\.text) == ["c", "b", "a"], "재시작 후에도 원래 자리로 되돌린다")
}

do {
    let suite = "holdstack-check-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    defer { d.removePersistentDomain(forName: suite) }
    check(Preferences(defaults: d).expandStyle == .detail, "펼치기 기본값은 내용만 크게 보기")
    Preferences(defaults: d).expandStyle = .inline
    check(Preferences(defaults: d).expandStyle == .inline, "펼치기 방식 저장")
    d.set("weird", forKey: "expandStyle")
    check(Preferences(defaults: d).expandStyle == .detail, "모르는 값이면 기본값")
}

do {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("stack.json")
    do {
        let s = HoldStore(fileURL: url)
        s.push("a"); s.pop()
    }
    // 예전 형식으로 덮어쓴다
    let trash = try! JSONDecoder().decode([HoldItem].self, from: Data(contentsOf: dir.appendingPathComponent("trash.json")))
    let old = "[[{\"id\":\"\(trash[0].id.uuidString)\",\"index\":0}]]"
    try! old.data(using: .utf8)!.write(to: dir.appendingPathComponent("undo.json"))
    let s = HoldStore(fileURL: url)
    check(s.undo() && s.items.map(\.text) == ["a"], "예전 형식 undo 기록도 읽는다")
}

do {
    let suite = "holdstack-check-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    defer { d.removePersistentDomain(forName: suite) }
    let s = ShortcutSettings(defaults: d)
    check(HotKeyAction.allCases.allSatisfy(s.isEnabled), "단축키는 기본으로 모두 켜짐")
    s.setEnabled(false, for: .pop)
    check(!ShortcutSettings(defaults: d).isEnabled(.pop) && ShortcutSettings(defaults: d).isEnabled(.hold), "끈 단축키 저장")
    check((try? s.set(HotKeyAction.pop.defaultShortcut, for: .hold)) == nil, "꺼진 단축키 조합도 겹치면 거부")
}

do {
    let suite = "holdstack-check-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    defer { d.removePersistentDomain(forName: suite) }
    let p = Preferences(defaults: d)
    check(p.questionFontSize == 13 && p.quoteFontSize == 12, "글자 크기 기본값은 지금 크기")
    p.questionFontSize = 30
    p.quoteFontSize = 16.4
    let again = Preferences(defaults: d)
    check(again.questionFontSize == 24 && again.quoteFontSize == 16, "글자 크기는 10~24 정수로 저장")
}

do {
    let s = HoldStore(fileURL: nil)
    (0..<5).forEach { s.push("t\($0)") }
    (0..<5).forEach { _ in s.pop() }                 // 휴지통 t0…t4 (최근이 앞)
    let before = s.trash.map(\.text)
    (0..<8).forEach { s.push("s\($0)") }
    s.clear()                                        // 8개가 들어오며 옛 휴지통 일부가 밀려난다
    check(s.undo() && s.items.count == 8 && s.trash.map(\.text) == before, "전체 비우기 undo 는 밀려난 휴지통도 되살린다")
}
do {
    let s = HoldStore(fileURL: nil)
    (0..<10).forEach { s.push("\($0)") }
    (0..<10).forEach { _ in s.pop() }                // 휴지통 가득. 가장 오래된 "9" 가 끝
    s.push("new"); s.pop()                           // "9" 가 밀려난다
    check(s.undo() && s.trash.count == 10 && s.trash.last?.text == "9" && s.items.map(\.text) == ["new"], "가득 찬 휴지통에서 밀려난 것도 undo 로 돌아온다")
}

do {
    // 2026-09-27 실제 앱에서 읽은 값
    let ghostty = FocusInfo(role: "AXTextArea", valueSettable: false, hasEditableAncestor: false)
    let chromeInput = FocusInfo(role: "AXTextArea", valueSettable: true, hasEditableAncestor: true)
    let chromeBody = FocusInfo(role: "AXWebArea", valueSettable: false, hasEditableAncestor: false)
    let finder = FocusInfo(role: "AXOutline", valueSettable: false, hasEditableAncestor: false)
    check(!FocusInfo.shouldBlockPaste(ghostty) && !FocusInfo.shouldBlockPaste(chromeInput), "터미널과 웹 입력칸에는 붙여넣는다")
    check(FocusInfo.shouldBlockPaste(chromeBody) && FocusInfo.shouldBlockPaste(finder), "웹 본문과 Finder 목록에는 막는다")
    check(!FocusInfo.shouldBlockPaste(nil), "초점을 못 읽으면 막지 않는다")
    let contentEditable = FocusInfo(role: "AXGroup", valueSettable: false, hasEditableAncestor: true)
    check(!FocusInfo.shouldBlockPaste(contentEditable), "편집 가능한 조상이 있으면 입력칸으로 본다")
    let suite = "holdstack-check-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    defer { d.removePersistentDomain(forName: suite) }
    check(Preferences(defaults: d).pasteOnlyIntoText, "입력칸 확인은 기본으로 켜짐")
}

do {
    let s = HoldStore(fileURL: nil)
    s.push("처음 질문", quote: "원문")
    s.push("위")
    let id = s.items[1].id
    check(s.update(id: id, text: "  고친 질문 ") && s.items[1].text == "고친 질문" && s.items[1].quote == "원문", "질문만 고치고 자리와 문장은 그대로")
    check(!s.update(id: id, text: "고친 질문"), "바뀐 게 없으면 기록하지 않는다")
    check(s.update(id: id, text: "") && s.items[1].pasteText == "\"원문\"", "문장이 있으면 질문을 비울 수 있다")
    check(!s.update(id: s.items[0].id, text: " "), "문장 없는 항목은 질문을 비울 수 없다")
    check(s.undo() && s.items[1].text == "고친 질문" && s.undo() && s.items[1].text == "처음 질문", "고친 것도 한 단계씩 되돌린다")
}

do {
    let s = HoldStore(fileURL: nil)
    s.trashLimit = 5
    (1...7).forEach { s.push("\($0)") }
    (1...7).forEach { _ in s.pop() }
    check(s.trash.count == 5, "휴지통 개수 설정을 따른다")
    var n = 0
    while s.undo() { n += 1 }
    check(n == 5, "되돌리기 기록도 같은 개수")
    s.trashLimit = 1
    check(s.trashLimit == HoldStore.trashLimitRange.lowerBound, "휴지통 개수 하한")
    s.trashLimit = 100
    check(s.trashLimit == HoldStore.trashLimitRange.upperBound, "휴지통 개수는 범위 안으로")
    let t = HoldStore(fileURL: nil)
    (1...10).forEach { t.push("\($0)") }
    (1...10).forEach { _ in t.pop() }
    t.trashLimit = 5
    check(t.trash.count == 10, "개수를 줄여도 바로 지우지 않는다")
    t.push("x"); t.pop()
    check(t.trash.count == 5, "다음에 버릴 때 줄어든다")
    let suite = "holdstack-check-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    defer { d.removePersistentDomain(forName: suite) }
    check(Preferences(defaults: d).trashLimit == 10, "휴지통 개수 기본값 10")
    Preferences(defaults: d).trashLimit = 20
    check(Preferences(defaults: d).trashLimit == 20, "휴지통 개수 저장")
}

do {
    L10n.language = .en
    let now = Date()
    check(Age.text(since: now, now: now) == "just now" && Age.text(since: now.addingTimeInterval(-600), now: now) == "10m ago", "영어로 경과 시간")
    check(L("휴지통") == "Trash" && L("최근 %d개까지 보관", 20) == "Keeps the latest 20", "영어 번역과 값 넣기")
    check(L("번역표에 없는 문구") == "번역표에 없는 문구", "표에 없으면 한국어 그대로")
    L10n.language = .ko
    check(L("휴지통") == "휴지통" && L("최근 %d개까지 보관", 20) == "최근 20개까지 보관", "한국어는 그대로")
    let suite = "holdstack-check-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    defer { d.removePersistentDomain(forName: suite) }
    check(Preferences(defaults: d).language == .system, "언어 기본값은 시스템 따르기")
    Preferences(defaults: d).language = .en
    check(Preferences(defaults: d).language == .en && L10n.language == .en, "언어 설정 저장과 즉시 반영")
    L10n.language = .ko
}

do {
    // 내장 디스플레이 왼쪽, 그 오른쪽에 붙인 큰 외부 모니터
    let small = CGRect(x: 0, y: 0, width: 1728, height: 1080)
    let big = CGRect(x: 1728, y: 0, width: 3008, height: 1692)
    let size = CGSize(width: 560, height: 400)
    func at(_ x: CGFloat, _ y: CGFloat) -> CGRect { CGRect(origin: CGPoint(x: x, y: y), size: size) }

    let topLeft = at(small.minX, small.maxY - size.height)
    check(ScreenFit.carried(topLeft, from: small, to: big) == at(big.minX, big.maxY - size.height),
          "왼쪽 위 구석은 옮긴 화면에서도 왼쪽 위 구석")

    let middle = at(small.midX - size.width / 2, small.midY - size.height / 2)
    check(ScreenFit.carried(middle, from: small, to: big) == at(big.midX - size.width / 2, big.midY - size.height / 2),
          "가운데는 옮긴 화면에서도 가운데")

    let bottomRight = at(small.maxX - size.width, small.minY)
    check(ScreenFit.carried(bottomRight, from: small, to: big) == at(big.maxX - size.width, big.minY),
          "오른쪽 아래 구석은 옮긴 화면에서도 오른쪽 아래 구석")

    let huge = CGRect(x: big.minX, y: big.minY, width: 2000, height: 1600)
    let shrunk = ScreenFit.carried(huge, from: big, to: small)
    check(small.contains(shrunk), "화면보다 큰 창은 줄여서 화면 안에 넣는다")

    let centered = ScreenFit.centered(at(0, 0), in: big)
    check(big.contains(centered) && centered.midX == big.midX && centered.midY > big.midY,
          "가운데 놓기는 가로 한가운데, 세로는 조금 위")
}

exit(failures == 0 ? 0 : 1)
