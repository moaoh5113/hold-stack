import HoldCore
import SwiftUI

final class PanelModel: ObservableObject {
    @Published var draft = ""
    @Published var showingTrash = false
    @Published var notice: String?
    @Published var canPaste = true
    @Published var selection = 0 { didSet { expanded = false } }
    @Published var expanded = false
    @Published var focusTick = 0
    var onPick: (Int) -> Void = { _ in }
    var onTab: (Bool) -> Void = { _ in }   // true = 휴지통
    var onDelete: (Int) -> Void = { _ in }
    var onEdit: (Int) -> Void = { _ in }
    @Published var editingID: UUID?  // 질문을 고치는 중인 항목
    @Published var editDraft = ""
    @Published var editFocusTick = 0
    @Published var showingKeys = false
    var globalKeys: [(String, String)] = [] // 켜 둔 전역 단축키. 카드를 열 때 채운다
}

struct HoldView: View {
    @ObservedObject var store: HoldStore
    @ObservedObject var model: PanelModel
    @ObservedObject var prefs: Preferences
    @FocusState private var inputFocused: Bool
    @FocusState private var editFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if model.showingTrash {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("휴지통")).font(.headline)
                    Text(L("최근 %d개까지 보관", prefs.trashLimit)).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            } else {
                TextField(placeholder, text: $model.draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .padding(14)
                    .focused($inputFocused)
            }

            tabs

            Divider()

            if let item = detailItem {
                detail(item)
            } else if shownItems.isEmpty {
                Text(model.showingTrash ? L("휴지통이 비어 있습니다") : L("보관된 의문이 없습니다"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }

            Divider()
            footer
        }
        .overlay { if model.showingKeys { KeysCard(globalKeys: model.globalKeys) } }
        .frame(minWidth: 360, idealWidth: 560, maxWidth: .infinity, minHeight: 220, idealHeight: 400, maxHeight: .infinity)
        .background(.regularMaterial)
        .onAppear { inputFocused = true }
        .onChange(of: model.focusTick) { inputFocused = true }
        .onChange(of: model.editFocusTick) { editFocused = true }
    }

    private var shownItems: [HoldItem] { model.showingTrash ? store.trash : store.items }

    private var detailItem: HoldItem? {
        guard model.expanded, prefs.expandStyle == .detail, shownItems.indices.contains(model.selection) else { return nil }
        return shownItems[model.selection]
    }

    private func detail(_ item: HoldItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("\(model.selection + 1) / \(shownItems.count)")
                        .font(.system(.caption, design: .monospaced))
                    Spacer()
                    Text(Age.text(since: item.removedAt ?? item.createdAt)).font(.caption)
                }
                .foregroundStyle(.secondary)
                if let quote = item.quote {
                    QuoteLine(text: quote, size: prefs.quoteFontSize + 1, lineLimit: nil)
                        .textSelection(.enabled)
                }
                if model.editingID == item.id {
                    editor(size: prefs.questionFontSize + 3, onAccent: false)
                } else if !item.text.isEmpty {
                    Text(item.text)
                        .font(.system(size: prefs.questionFontSize + 3))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 고치는 중인 질문. 테두리와 안내 줄로 보통 상태와 구분한다.
    private func editor(size: Double, onAccent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(L("질문 고치는 중"), systemImage: "pencil")
                .font(.caption.weight(.semibold))
                .foregroundStyle(onAccent ? Color.white : Color.accentColor)
            TextField(L("질문"), text: $model.editDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: size))
                .foregroundStyle(Color.primary)
                .lineLimit(1...8)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(onAccent ? Color.white : Color.accentColor, lineWidth: 1.5))
                .focused($editFocused)
        }
    }

    private var tabs: some View {
        HStack(spacing: 16) {
            tab(L("스택 %d", store.items.count), on: !model.showingTrash) { model.onTab(false) }
            tab(L("휴지통 %d", store.trash.count), on: model.showingTrash) { model.onTab(true) }
            Spacer()
            Text(L("⇥ 전환")).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private func tab(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(.callout.weight(on ? .semibold : .regular))
            .foregroundStyle(on ? .primary : .secondary)
            .padding(.bottom, 3)
            .overlay(alignment: .bottom) {
                if on { Rectangle().fill(Color.accentColor).frame(height: 2) }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    private var placeholder: String { L("새 의문을 적고 Enter, 비워두면 목록을 고릅니다") } // 언어를 바꾸면 다시 읽는다

    private var footer: some View {
        VStack(spacing: 4) {
            if let notice = model.notice {
                Text(notice).foregroundStyle(.orange)
            } else if !model.canPaste {
                Text(L("손쉬운 사용 권한이 없어 불러온 내용은 클립보드에만 들어갑니다. ⌘V 로 붙여넣으세요"))
                    .foregroundStyle(.orange)
            }
            Text(model.editingID != nil ? L("⏎ 저장   ⇧⏎ 줄바꿈   esc 취소")
                 : detailItem != nil
                 ? (model.showingTrash ? L("↑↓ 앞뒤 항목   ← 목록으로   ⏎ 스택으로 되돌리기   ⌫ 지우기")
                                       : L("↑↓ 앞뒤 항목   ← 목록으로   ⏎ 불러오기   ⌘E 고치기   ⌫ 휴지통으로"))
                 : model.showingTrash ? L("↑↓ 이동   → 펼치기   ⏎ 스택으로 되돌리기   ⌫ 지우기   ⌘Z 되돌리기")
                 : L("↑↓ 이동   → 펼치기   ⏎ 불러오기   ⌘E 고치기   ⌫ 휴지통으로   ⌘Z 되돌리기"))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .multilineTextAlignment(.center)
        .padding(8)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(shownItems.enumerated()), id: \.element.id) { index, item in
                        Row(item: item, index: index, selected: index == model.selection,
                            expanded: index == model.selection && model.expanded,
                            questionSize: prefs.questionFontSize, quoteSize: prefs.quoteFontSize,
                            deleteHelp: model.showingTrash ? L("지우기") : L("휴지통으로"),
                            onEdit: model.showingTrash ? nil : { model.onEdit(index) },
                            editor: model.editingID == item.id
                                ? AnyView(editor(size: prefs.questionFontSize, onAccent: index == model.selection)) : nil,
                            onDelete: { model.onDelete(index) })
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture { model.onPick(index) }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
            .onChange(of: model.selection) { _, new in
                if shownItems.indices.contains(new) { proxy.scrollTo(shownItems[new].id) }
            }
        }
    }
}

/// 목록 한 줄. 마우스를 올리면 오른쪽에 ✕ 가 나온다.
private struct Row: View {
    let item: HoldItem
    let index: Int
    let selected: Bool
    let expanded: Bool
    let questionSize: Double
    let quoteSize: Double
    let deleteHelp: String
    let onEdit: (() -> Void)?
    let editor: AnyView?  // 고치는 중이면 질문 자리에 들어간다
    let onDelete: () -> Void
    @StateObject private var hover = HoverState()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(index + 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                if let quote = item.quote {
                    QuoteLine(text: quote, size: quoteSize, lineLimit: expanded ? nil : 1, onAccent: selected)
                }
                if let editor {
                    editor
                } else if !item.text.isEmpty {
                    Text(item.text)
                        .font(.system(size: questionSize))
                        .lineLimit(expanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: expanded)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if hover.on && editor == nil {
                if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(selected ? .white.opacity(0.85) : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L("고치기 (⌘E)"))
                }
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(selected ? .white.opacity(0.85) : .secondary)
                }
                .buttonStyle(.plain)
                .help(deleteHelp)
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(Age.text(since: item.removedAt ?? item.createdAt, now: context.date))
                }
                .font(.caption2)
                .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
            }
        }
        .foregroundStyle(selected ? .white : .primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(selected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 6))
        .onHover { hover.on = $0 }
    }
}

/// @State 를 못 쓰는 환경이라 줄마다 작은 객체로 둔다.
private final class HoverState: ObservableObject {
    @Published var on = false
}

/// 의문을 가진 문장. 왼쪽 세로줄로 인용임을 보인다.
struct QuoteLine: View {
    let text: String
    let size: Double
    let lineLimit: Int?
    var onAccent = false

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1)
                .fill(onAccent ? Color.white.opacity(0.6) : Color.secondary.opacity(0.5))
                .frame(width: 2)
            Text(text)
                .font(.system(size: size))
                .italic()
                .lineLimit(lineLimit)
                .foregroundStyle(onAccent ? Color.white.opacity(0.85) : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// ⌘/ 로 여는 단축키 카드. 목록 위에 떠서 목록을 가린다.
private struct KeysCard: View {
    let globalKeys: [(String, String)]

    private var groups: [(String, [(String, String)])] {
        ([(L("어디서든"), globalKeys)] + ShortcutGuide.listWindow).filter { !$0.1.isEmpty }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L("단축키")).font(.headline)
                    ForEach(groups, id: \.0) { title, keys in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                                ForEach(keys, id: \.0) { key, meaning in
                                    GridRow {
                                        Text(key).font(.system(.callout, design: .monospaced))
                                            .frame(width: 48, alignment: .leading) // 묶음마다 설명 칸을 맞춘다
                                        Text(meaning).font(.callout)
                                    }
                                }
                            }
                        }
                    }
                    Text(L("esc 또는 ⌘/ 로 닫기")).font(.caption).foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: 380, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12)) // 뒤 목록이 비치지 않게
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3)))
            .padding(24)
        }
    }
}

/// 목록 창 안의 키. ⌘/ 카드와 설정 창이 같은 목록을 쓴다.
enum ShortcutGuide {
    static var listWindow: [(String, [(String, String)])] {
        [
            (L("목록"), [
                ("↑ ↓", L("이동")), ("→ ←", L("크게 보기와 목록")), ("⏎", L("붙여넣기")),
                ("⌘E", L("질문 고치기")), ("⌫", L("휴지통으로")), ("⇥", L("스택과 휴지통 전환")),
                ("⌘Z", L("되돌리기")), ("⌘/", L("단축키 보기")), ("⌘,", L("설정")), ("esc", L("닫기")),
            ]),
            (L("휴지통"), [("⏎", L("스택으로 되돌리기")), ("⌫", L("지우기"))]),
            (L("고치는 중"), [("⏎", L("저장")), ("⇧⏎", L("줄바꿈")), ("esc", L("취소"))]),
        ]
    }
}
