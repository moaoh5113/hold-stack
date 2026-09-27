import HoldCore
import SwiftUI

final class PanelModel: ObservableObject {
    @Published var draft = ""
    @Published var quote: String?
    @Published var composing = false
    @Published var canPaste = true
    @Published var selection = 0
    @Published var focusTick = 0
    var onPick: (Int) -> Void = { _ in }
}

struct HoldView: View {
    @ObservedObject var store: HoldStore
    @ObservedObject var model: PanelModel
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let quote = model.quote {
                QuoteLine(text: quote, lineLimit: 4)
                    .padding([.horizontal, .top], 14)
            }

            TextField(placeholder, text: $model.draft)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .padding(14)
                .focused($inputFocused)

            Divider()

            if model.composing {
                Spacer(minLength: 0)
            } else if store.items.isEmpty {
                Text("보관된 의문이 없습니다")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }

            Divider()
            footer
        }
        .frame(minWidth: 360, idealWidth: 560, maxWidth: .infinity, minHeight: 220, idealHeight: 400, maxHeight: .infinity)
        .background(.regularMaterial)
        .onAppear { inputFocused = true }
        .onChange(of: model.focusTick) { inputFocused = true }
    }

    private var placeholder: String {
        if model.quote != nil { return "이 문장에 대한 의문을 적고 Enter" }
        return model.composing ? "떠오른 의문을 적고 Enter" : "새 의문을 적고 Enter, 비워두면 목록을 고릅니다"
    }

    private var footer: some View {
        VStack(spacing: 4) {
            if !model.canPaste {
                Text("손쉬운 사용 권한이 없어 불러온 내용은 클립보드에만 들어갑니다. ⌘V 로 붙여넣으세요")
                    .foregroundStyle(.orange)
            }
            Text(model.composing
                 ? "⏎ 보관   esc 취소"
                 : "↑↓ 이동   ⏎ 불러오기   ⌫ 지우기   ⌘Z 되돌리기   esc 닫기")
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
                    ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                        row(item, index: index)
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture { model.onPick(index) }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selection) { _, new in
                if store.items.indices.contains(new) { proxy.scrollTo(store.items[new].id) }
            }
        }
    }

    private func row(_ item: HoldItem, index: Int) -> some View {
        let selected = index == model.selection
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(index + 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
                .frame(width: 22, alignment: .trailing)
            VStack(alignment: .leading, spacing: 3) {
                if let quote = item.quote {
                    QuoteLine(text: quote, lineLimit: 1, onAccent: selected)
                }
                if !item.text.isEmpty {
                    Text(item.text).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.createdAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
        }
        .foregroundStyle(selected ? .white : .primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(selected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 6))
    }
}

/// 의문을 가진 문장. 왼쪽 세로줄로 인용임을 보인다.
private struct QuoteLine: View {
    let text: String
    let lineLimit: Int
    var onAccent = false

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1)
                .fill(onAccent ? Color.white.opacity(0.6) : Color.secondary.opacity(0.5))
                .frame(width: 2)
            Text(text)
                .font(.callout)
                .italic()
                .lineLimit(lineLimit)
                .foregroundStyle(onAccent ? Color.white.opacity(0.85) : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
