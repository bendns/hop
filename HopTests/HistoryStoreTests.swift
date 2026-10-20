import XCTest
@testable import Hop

@MainActor
final class HistoryStoreTests: XCTestCase {
    private var tmpURL: URL!

    override func setUp() async throws {
        tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hop-tests-\(UUID().uuidString).json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpURL)
    }

    func test_recordAppendsEvent() {
        let store = HistoryStore(fileURL: tmpURL)
        store.record(PostureEvent(posture: .standing, trigger: .manual))
        XCTAssertEqual(store.events.count, 1)
    }

    func test_persistsAcrossInstances() {
        let store1 = HistoryStore(fileURL: tmpURL)
        store1.record(PostureEvent(posture: .standing, trigger: .manual))
        store1.flush()

        let store2 = HistoryStore(fileURL: tmpURL)
        XCTAssertEqual(store2.events.count, 1)
        XCTAssertEqual(store2.events.first?.posture, .standing)
    }

    func test_eventsForToday_filtersByDay() {
        let store = HistoryStore(fileURL: tmpURL)
        let yesterday = Date().addingTimeInterval(-25 * 3600)
        store.record(PostureEvent(timestamp: yesterday, posture: .standing, trigger: .manual))
        store.record(PostureEvent(posture: .sitting, trigger: .manual))
        XCTAssertEqual(store.eventsForToday().count, 1)
    }

    func test_record_keepsChronologicalOrder() {
        let store = HistoryStore(fileURL: tmpURL)
        let now = Date()
        store.record(PostureEvent(timestamp: now, posture: .sitting, trigger: .manual))
        store.record(PostureEvent(timestamp: now.addingTimeInterval(-60), posture: .standing, trigger: .manual))
        XCTAssertEqual(store.events.map(\.timestamp), [now.addingTimeInterval(-60), now])
    }

    func test_eventsForWeek_excludesPreviousWeeks() {
        let store = HistoryStore(fileURL: tmpURL)
        store.record(PostureEvent(timestamp: Date().addingTimeInterval(-8 * 86400), posture: .standing, trigger: .manual))
        store.record(PostureEvent(posture: .sitting, trigger: .manual))
        XCTAssertEqual(store.eventsForWeek().count, 1)
    }

    func test_load_prunesEventsOlderThanRetention() {
        let now = Date()
        let old = now.addingTimeInterval(-Double(HistoryStore.retentionDays + 1) * 86400)
        let store1 = HistoryStore(fileURL: tmpURL, now: old)
        store1.record(PostureEvent(timestamp: old, posture: .standing, trigger: .manual))
        store1.record(PostureEvent(timestamp: now, posture: .sitting, trigger: .manual))
        store1.flush()

        let store2 = HistoryStore(fileURL: tmpURL, now: now)
        XCTAssertEqual(store2.events.count, 1)
        XCTAssertEqual(store2.events.first?.posture, .sitting)
        store2.flush()
        XCTAssertEqual(HistoryStore(fileURL: tmpURL, now: now).events.count, 1)
    }

    func test_pausedSchedule_yieldsSingleEntry() {
        let start = Date()
        let paused = Array(PausableEverySecondSchedule(isPaused: true).entries(from: start, mode: .normal))
        XCTAssertEqual(paused, [start])
        let running = PausableEverySecondSchedule(isPaused: false).entries(from: start, mode: .normal).prefix(3)
        XCTAssertEqual(Array(running), [start, start.addingTimeInterval(1), start.addingTimeInterval(2)])
    }
}
