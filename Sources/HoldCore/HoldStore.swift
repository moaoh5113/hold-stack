import Foundation

public struct HoldItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public var text: String   // 나의 질문. 비어 있을 수 있다
    public var quote: String? // 의문을 가진 문장
    public let createdAt: Date
    public var removedAt: Date? // 휴지통에 들어간 시각

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

/// 스택에서 빠진 항목 하나와 원래 자리. 항목 자체는 휴지통에 있다.
struct UndoMark: Codable, Equatable {
    let id: UUID
    let index: Int
}

/// ⌘Z 로 되돌릴 동작 한 번.
enum UndoOp: Codable, Equatable {
    case removed([UndoMark], evicted: [HoldItem]?) // 스택 → 휴지통. evicted 는 그때 휴지통에서 밀려난 항목
    case restored(id: UUID, trashIndex: Int)    // 휴지통 → 스택
    case purged(item: HoldItem, trashIndex: Int) // 휴지통에서 지움. 되살리려고 항목을 들고 있다
}

/// items[0] 이 스택의 맨 위다. 빠진 항목은 trash 에 최근 것부터 쌓인다.
public final class HoldStore: ObservableObject {
    public static let trashLimit = 10

    @Published public private(set) var items: [HoldItem] = []
    @Published public private(set) var trash: [HoldItem] = []
    /// 마지막 것이 가장 최근. 앱을 껐다 켜도 남는다
    private var undoHistory: [UndoOp] = []
    private let fileURL: URL?
    private var trashURL: URL? { fileURL?.deletingLastPathComponent().appendingPathComponent("trash.json") }
    private var undoURL: URL? { fileURL?.deletingLastPathComponent().appendingPathComponent("undo.json") }

    public init(fileURL: URL?) {
        self.fileURL = fileURL
        items = Self.load(fileURL)
        trash = Self.load(trashURL)
        undoHistory = Self.loadUndoHistory(undoURL)
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

    /// 불러오기와 지우기 모두 여기로 온다. 빠진 항목은 휴지통으로 간다.
    @discardableResult
    public func remove(at index: Int) -> HoldItem? {
        guard items.indices.contains(index) else { return nil }
        let item = items.remove(at: index)
        let evicted = moveToTrash([item])
        record(.removed([UndoMark(id: item.id, index: index)], evicted: evicted))
        save()
        return item
    }

    @discardableResult
    public func pop() -> HoldItem? { remove(at: 0) }

    /// 스택에서든 휴지통에서든 가장 최근 동작 하나를 되돌린다.
    /// 대상이 이미 없어진 기록(휴지통에서 밀려난 항목 등)은 건너뛰고 그 전 것을 되돌린다.
    @discardableResult
    public func undo() -> Bool {
        while let op = undoHistory.popLast() {
            if apply(op) {
                save()
                return true
            }
        }
        save()
        return false
    }

    /// 실제로 바뀐 게 있으면 true.
    private func apply(_ op: UndoOp) -> Bool {
        switch op {
        case .removed(let marks, let evicted):
            var changed = false
            for mark in marks.sorted(by: { $0.index < $1.index }) {
                guard let at = trash.firstIndex(where: { $0.id == mark.id }) else { continue }
                var item = trash.remove(at: at)
                item.removedAt = nil
                items.insert(item, at: min(mark.index, items.count))
                changed = true
            }
            // 밀려났던 옛 항목은 휴지통 끝(가장 오래된 자리)으로 돌려놓는다
            for item in evicted ?? [] where !trash.contains(where: { $0.id == item.id }) {
                trash.append(item)
            }
            return changed
        case .restored(let id, let trashIndex):
            guard let at = items.firstIndex(where: { $0.id == id }) else { return false }
            var item = items.remove(at: at)
            item.removedAt = Date()
            trash.insert(item, at: min(trashIndex, trash.count))
            return true
        case .purged(let item, let trashIndex):
            guard !trash.contains(where: { $0.id == item.id }) else { return false }
            trash.insert(item, at: min(trashIndex, trash.count))
            return true
        }
    }

    public var undoSteps: Int { undoHistory.count }

    /// 비운 것은 10개를 넘어도 전부 휴지통에 남긴다. 다음에 빠지는 항목부터 다시 10개로 줄어든다.
    public func clear() {
        guard !items.isEmpty else { return }
        let entry = items.enumerated().map { UndoMark(id: $0.element.id, index: $0.offset) }
        let evicted = moveToTrash(items, keepAtLeast: items.count)
        items.removeAll()
        record(.removed(entry, evicted: evicted))
        save()
    }

    /// 휴지통 항목을 스택 맨 위로 되돌린다.
    @discardableResult
    public func restoreFromTrash(at index: Int) -> Bool {
        guard trash.indices.contains(index) else { return false }
        var item = trash.remove(at: index)
        item.removedAt = nil
        items.insert(item, at: 0)
        record(.restored(id: item.id, trashIndex: index))
        save()
        return true
    }

    /// 지운 것도 ⌘Z 로 되살릴 수 있다. 기록이 10개를 넘겨 밀려나면 그때 사라진다.
    public func deleteFromTrash(at index: Int) {
        guard trash.indices.contains(index) else { return }
        let item = trash.remove(at: index)
        record(.purged(item: item, trashIndex: index))
        save()
    }

    /// 넘쳐서 밀려난 옛 항목을 돌려준다. undo 가 되살릴 수 있게 기록에 담는다.
    private func moveToTrash(_ removed: [HoldItem], keepAtLeast: Int = 0) -> [HoldItem] {
        let now = Date()
        let stamped = removed.map { item -> HoldItem in
            var item = item
            item.removedAt = now
            return item
        }
        let combined = stamped + trash
        let keep = max(Self.trashLimit, keepAtLeast)
        trash = Array(combined.prefix(keep))
        return Array(combined.dropFirst(keep))
    }

    private func record(_ op: UndoOp) {
        undoHistory.append(op)
        while undoHistory.count > Self.trashLimit { undoHistory.removeFirst() }
    }

    /// 예전 형식(스택에서 뺀 기록만 있던 [[UndoMark]])도 읽는다.
    private static func loadUndoHistory(_ url: URL?) -> [UndoOp] {
        if let url, let data = try? Data(contentsOf: url),
           let old = try? JSONDecoder().decode([[UndoMark]].self, from: data) {
            return Array(old.map { UndoOp.removed($0, evicted: nil) }.suffix(trashLimit))
        }
        return Array((load(url) as [UndoOp]).suffix(trashLimit))
    }

    private static func load<T: Decodable>(_ url: URL?) -> [T] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            // 다음 저장이 덮어쓰기 전에 옆으로 치워 둔다
            let aside = url.appendingPathExtension("bad-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: url, to: aside)
            NSLog("HoldStack: unreadable \(url.lastPathComponent) moved to \(aside.lastPathComponent): \(error)")
            return []
        }
    }

    private func save() {
        write(items, to: fileURL)
        write(trash, to: trashURL)
        write(undoHistory, to: undoURL)
    }

    private func write<T: Encodable>(_ value: T, to url: URL?) {
        guard let url else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
        } catch {
            NSLog("HoldStack save failed: \(error)")
        }
    }
}
