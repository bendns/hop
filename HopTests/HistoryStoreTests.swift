import XCTest
@testable import Hop

@MainActor
final class HistoryStoreTests: XCTestCase {
    private var tmpURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hop-tests-\(UUID().uuidString).json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpURL)
        try await super.tearDown()
    }

    func test_recordAppendsEvent() {
        let store = HistoryStore(fileURL: tmpURL)
        store.record(PostureEvent(posture: .standing, trigger: .manual))
        XCTAssertEqual(store.events.count, 1)
    }

    func test_persistsAcrossInstances() {
        let store1 = HistoryStore(fileURL: tmpURL)
        store1.record(PostureEvent(posture: .standing, trigger: .manual))
        let exp = expectation(description: "flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

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
}
