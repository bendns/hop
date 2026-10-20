import Foundation
import Combine

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    /// Kept in chronological order, so date-range lookups can scan from the end.
    @Published private(set) var events: [PostureEvent] = []

    /// Events older than this are dropped at launch, which bounds memory use and
    /// the cost of rewriting the file on every event.
    static let retentionDays = 365

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.bendns.hop.history", qos: .utility)

    init(fileURL: URL? = nil, now: Date = Date()) {
        if let override = fileURL {
            self.fileURL = override
        } else {
            let base = try! FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("Hop", isDirectory: true)
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            self.fileURL = base.appendingPathComponent("history.json")
        }
        load()
        prune(now: now)
    }

    func record(_ event: PostureEvent) {
        if let last = events.last, event.timestamp < last.timestamp {
            let index = events.firstIndex { $0.timestamp > event.timestamp } ?? events.endIndex
            events.insert(event, at: index)
        } else {
            events.append(event)
        }
        persist()
    }

    func eventsForToday(now: Date = Date()) -> [PostureEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return events(from: start, to: end)
    }

    func eventsForWeek(now: Date = Date()) -> [PostureEvent] {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let end = cal.date(byAdding: .day, value: 7, to: start)!
        return events(from: start, to: end)
    }

    /// Events in `[start, end)`. Recent ranges are the common case, so scan back
    /// from the end instead of filtering the whole history.
    private func events(from start: Date, to end: Date) -> [PostureEvent] {
        let first = events.lastIndex { $0.timestamp < start }.map { $0 + 1 } ?? events.startIndex
        return events[first...].filter { $0.timestamp < end }
    }

    func reset() {
        events = []
        persist()
    }

    /// Blocks until queued writes hit the disk.
    func flush() {
        queue.sync {}
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([PostureEvent].self, from: data) {
            // Files from older versions were appended in order, but don't rely on it.
            events = decoded.sorted { $0.timestamp < $1.timestamp }
        }
    }

    private func prune(now: Date) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -Self.retentionDays, to: now) else { return }
        let firstKept = events.firstIndex { $0.timestamp >= cutoff } ?? events.endIndex
        guard firstKept > 0 else { return }
        events.removeFirst(firstKept)
        persist()
    }

    private func persist() {
        let snapshot = events
        let url = fileURL
        queue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
