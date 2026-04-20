import XCTest
@testable import Hop

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "hop.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_defaults_whenEmpty() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings.mode, .science)
        XCTAssertTrue(store.settings.notificationsEnabled)
    }

    func test_persistsAcrossInstances() {
        let store1 = SettingsStore(defaults: defaults)
        store1.settings.mode = .advanced
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.settings.mode, .advanced)
    }

    func test_workdayDefaults_weekdaysEnabled_weekendsDisabled() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.settings.workHoursByWeekday[.monday]!.enabled)
        XCTAssertFalse(store.settings.workHoursByWeekday[.saturday]!.enabled)
    }
}
