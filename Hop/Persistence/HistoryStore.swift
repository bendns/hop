import Foundation
import Combine

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var events: [PostureEvent] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.bendns.hop.history", qos: .utility)

    init(fileURL: URL? = nil) {
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
    }

    func record(_ event: PostureEvent) {
        events.append(event)
        persist()
    }

    func eventsForToday(now: Date = Date()) -> [PostureEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return events.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    func eventsForWeek(now: Date = Date()) -> [PostureEvent] {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let end = cal.date(byAdding: .day, value: 7, to: start)!
        return events.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    func reset() {
        events = []
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([PostureEvent].self, from: data) {
            events = decoded
        }
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
