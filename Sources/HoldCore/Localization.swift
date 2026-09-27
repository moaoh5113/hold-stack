import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system, ko, en

    public var id: String { rawValue }

    /// 어느 언어로 보고 있든 알아볼 수 있게 각 언어 이름은 그 언어로 쓴다.
    public var title: String {
        switch self {
        case .system: L("시스템 설정 따르기")
        case .ko: "한국어"
        case .en: "English"
        }
    }
}

/// 한국어 문구를 키로 쓰는 번역표. 표에 없는 문구는 한국어로 나온다.
public enum L10n {
    public static var language: AppLanguage = .system

    /// 시스템 언어가 한국어가 아니면 영어.
    public static var isKorean: Bool {
        switch language {
        case .ko: true
        case .en: false
        case .system: Locale.preferredLanguages.first?.hasPrefix("ko") ?? false
        }
    }

    public static func text(_ ko: String) -> String {
        isKorean ? ko : (english[ko] ?? ko)
    }

    public static let keys: Set<String> = Set(english.keys)
}

public func L(_ ko: String) -> String { L10n.text(ko) }

/// %d, %@ 자리에 값을 넣는다. 영어 문장은 어순이 달라 값 자리도 번역표에서 정한다.
public func L(_ ko: String, _ args: CVarArg...) -> String {
    String(format: L10n.text(ko), arguments: args)
}

extension L10n {
    static let english: [String: String] = [
        // 목록 창
        "새 의문을 적고 Enter, 비워두면 목록을 고릅니다": "New question, or ⏎ to pick one",
        "스택 %d": "Stack %d",
        "휴지통 %d": "Trash %d",
        "휴지통": "Trash",
        "최근 %d개까지 보관": "Keeps the latest %d",
        "⇥ 전환": "⇥ Switch",
        "보관된 의문이 없습니다": "No questions held",
        "휴지통이 비어 있습니다": "Trash is empty",
        "질문": "Question",
        "질문 고치는 중": "Editing question",
        "고치기 (⌘E)": "Edit (⌘E)",
        "지우기": "Delete",
        "휴지통으로": "Move to Trash",
        "입력칸을 먼저 클릭하세요. 의문은 그대로 남아 있습니다": "Click a text field first. Your question is still here",
        "작성 창을 닫은 뒤 다시 고르세요. 의문은 그대로 남아 있습니다": "Close the compose window and pick again. Your question is still here",
        "손쉬운 사용 권한이 없어 불러온 내용은 클립보드에만 들어갑니다. ⌘V 로 붙여넣으세요": "Without Accessibility permission, questions only go to the clipboard. Paste with ⌘V",
        "⏎ 저장   ⇧⏎ 줄바꿈   esc 취소": "⏎ Save   ⇧⏎ New line   esc Cancel",
        // 작성 창
        "의문 보관": "Hold a question",
        "이 문장에 대한 의문": "Your question about this sentence",
        "떠오른 의문": "Your question",
        "선택한 문장 없이 의문만 보관합니다": "No sentence selected. Only your question is kept",
        "질문을 비우면 문장만 보관합니다": "Leave the question empty to keep just the sentence",
        "⇧⏎ 줄바꿈   ⏎ 보관   esc 취소": "⇧⏎ New line   ⏎ Hold   esc Cancel",
        // 경과 시간
        "방금": "just now",
        "%d분 전": "%dm ago",
        "%d시간 전": "%dh ago",
        "%d일 전": "%dd ago",
        // 메뉴 막대
        "설정…": "Settings…",
        "종료": "Quit",
        "휴지통 열기": "Open Trash",
        "전체 비우기": "Clear All",
        "손쉬운 사용 권한 요청…": "Request Accessibility Permission…",
        "보관된 의문 %d개를 모두 휴지통으로 옮길까요?": "Move all %d held questions to the Trash?",
        "휴지통에서 ⏎ 로 다시 되돌릴 수 있습니다.": "You can bring them back from the Trash with ⏎.",
        "취소": "Cancel",
        // 동작 이름
        "의문 적기": "Hold a question",
        "목록 열기": "Open list",
        "맨 위 꺼내기": "Paste top question",
        // 설정
        "HoldStack 설정": "HoldStack Settings",
        "일반": "General",
        "언어": "Language",
        "시스템 설정 따르기": "Follow system",
        "로그인할 때 자동으로 실행": "Launch at login",
        "메뉴 막대에 보관 개수 표시": "Show count in menu bar",
        "시스템 설정 → 일반 → 로그인 항목에서 허용해 주세요": "Allow it in System Settings → General → Login Items",
        "바꾸지 못했습니다: %@": "Couldn't change it: %@",
        "목록 창": "List window",
        "투명도": "Opacity",
        "휴지통에 둘 개수": "Items kept in Trash",
        "개": "",
        "불러온 뒤 창 닫기": "Close after pasting",
        "입력칸이 아니면 붙여넣지 않기": "Paste only into text fields",
        "다른 앱을 누르면 창 닫기": "Close when another app is clicked",
        "데스크탑을 옮기면 창 닫기": "Close on desktop switch",
        "→ 로 펼칠 때": "When expanding with →",
        "그 자리에서 펼치기": "Expand in place",
        "내용만 크게 보기": "Show full view",
        "글자 크기": "Font size",
        "의문을 가진 문장": "Held sentence",
        "나의 질문": "Your question",
        "빌드할 때마다 서명이 바뀌어 권한이 풀린다.": "The signature changes on every build, so the permission is lost.",
        "왜 그래야 하는 걸까": "Why does that happen?",
        "전역 단축키": "Global shortcuts",
        "키 조합을 누르세요…": "Press a key combination…",
        "단축키 기본값으로": "Reset shortcuts",
        "%@ 는 다른 앱이나 시스템이 이미 쓰고 있습니다": "%@ is already used by another app or the system",
        "%@ 는 다른 앱이나 시스템이 이미 쓰고 있어 켜지 못했습니다": "%@ is already used by another app or the system, so it couldn't be turned on",
        "⌃, ⌥, ⌘ 중 하나는 함께 눌러야 합니다": "Include at least one of ⌃, ⌥, or ⌘",
        "복사, 붙여넣기 같은 편집 단축키는 쓸 수 없습니다": "Editing shortcuts like copy and paste can't be used",
        "「%@」에서 이미 쓰는 조합입니다": "Already used by \"%@\"",
        // 키 안내
        "이동": "Move",
        "스택과 휴지통 전환": "Switch between stack and Trash",
        "닫기": "Close",
        "↑↓ 이동   → 펼치기   ⏎ 불러오기   ⌘E 고치기   ⌫ 휴지통으로   ⌘Z 되돌리기": "↑↓ Move   → Expand   ⏎ Paste   ⌘E Edit   ⌫ Trash   ⌘Z Undo",
        "↑↓ 이동   → 펼치기   ⏎ 스택으로 되돌리기   ⌫ 지우기   ⌘Z 되돌리기": "↑↓ Move   → Expand   ⏎ Restore   ⌫ Delete   ⌘Z Undo",
        "↑↓ 앞뒤 항목   ← 목록으로   ⏎ 불러오기   ⌘E 고치기   ⌫ 휴지통으로": "↑↓ Prev/Next   ← List   ⏎ Paste   ⌘E Edit   ⌫ Trash",
        "↑↓ 앞뒤 항목   ← 목록으로   ⏎ 스택으로 되돌리기   ⌫ 지우기": "↑↓ Prev/Next   ← List   ⏎ Restore   ⌫ Delete",
        "단축키": "Shortcuts",
        "어디서든": "Anywhere",
        "목록": "List",
        "크게 보기와 목록": "Full view and back to list",
        "붙여넣기": "Paste",
        "질문 고치기": "Edit question",
        "되돌리기": "Undo",
        "설정": "Settings",
        "스택으로 되돌리기": "Restore to stack",
        "고치는 중": "While editing",
        "저장": "Save",
        "줄바꿈": "New line",
        "esc 또는 ⌘/ 로 닫기": "Press esc or ⌘/ to close",
        "목록 창에서 ⌘/ 를 누르면 단축키를 볼 수 있습니다": "Press ⌘/ in the list window to see all shortcuts",
    ]
}
