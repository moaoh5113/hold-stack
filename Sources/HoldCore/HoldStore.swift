import Foundation

public struct HoldItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public var text: String   // 나의 질문. 비어 있을 수 있다
    public var quote: String? // 의문을 가진 문장
    public let createdAt: Date

    public init(text: String, quote: String? = nil, createdAt: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.quote = quote
        self.createdAt = createdAt
    }

    /// 붙여넣을 때의 모양. 문장과 질문이 둘 다 있으면 "문장" + 빈 줄 + 질문.
    public var pasteText: String {
        guard let quote else { return text }
        return text.isEmpty ? "\"\(quote)\"" : "\"\(quote)\"\n\n\(text)"
    }
}

/// items[0] 이 스택의 맨 위다.
public final class HoldStore: ObservableObject {
    @Published public private(set) var items: [HoldItem] = []
    private var lastRemoved: (item: HoldItem, index: Int)?
    private let fileURL: URL?

    public init(fileURL: URL?) {
        self.fileURL = fileURL
        load()
    }

    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("HoldStack/stack.json")
    }

    /// 질문과 문장이 둘 다 비어 있으면 넣지 않고 false 를 돌려준다.
    @discardableResult
    public func push(_ text: String, quote: String? = nil) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let quote = quote?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuote = quote?.isEmpty == false ? quote : nil
        guard !trimmed.isEmpty || trimmedQuote != nil else { return false }
        items.insert(HoldItem(text: trimmed, quote: trimmedQuote), at: 0)
        save()
        return true
    }

    @discardableResult
    public func remove(at index: Int) -> HoldItem? {
        guard items.indices.contains(index) else { return nil }
        let item = items.remove(at: index)
        lastRemoved = (item, index)
        save()
        return item
    }

    @discardableResult
    public func pop() -> HoldItem? { remove(at: 0) }

    /// 마지막으로 빠진 항목 하나를 원래 자리로 되돌린다.
    @discardableResult
    public func undo() -> Bool {
        guard let (item, index) = lastRemoved else { return false }
        items.insert(item, at: min(index, items.count))
        lastRemoved = nil
        save()
        return true
    }

    public func clear() {
        items.removeAll()
        lastRemoved = nil
        save()
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        do {
            items = try JSONDecoder().decode([HoldItem].self, from: data)
        } catch {
            // 다음 저장이 덮어쓰기 전에 옆으로 치워 둔다
            let aside = fileURL.appendingPathExtension("bad-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: fileURL, to: aside)
            NSLog("HoldStack: unreadable stack moved to \(aside.lastPathComponent): \(error)")
        }
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("HoldStack save failed: \(error)")
        }
    }
}
