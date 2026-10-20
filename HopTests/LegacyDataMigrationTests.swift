import XCTest
@testable import Hop

final class LegacyDataMigrationTests: XCTestCase {
    private var root: URL!
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("hop-migration-\(UUID().uuidString)")
        suiteName = "hop.tests.migration.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        defaults.removePersistentDomain(forName: suiteName)
    }

    private var legacyHome: URL { root.appending(path: "home") }
    private var historyURL: URL { root.appending(path: "container/Hop/history.json") }

    private func writeLegacy(history: String, preferences: [String: Any]) throws {
        let historyDir = legacyHome.appending(path: "Library/Application Support/Hop")
        let prefsDir = legacyHome.appending(path: "Library/Preferences")
        try FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: prefsDir, withIntermediateDirectories: true)
        try Data(history.utf8).write(to: historyDir.appending(path: "history.json"))
        XCTAssertTrue((preferences as NSDictionary).write(to: prefsDir.appending(path: "com.bendns.hopapp.plist"), atomically: true))
    }

    private func migrate(isSandboxed: Bool = true) {
        LegacyDataMigration.runIfNeeded(
            legacyHome: legacyHome,
            historyURL: historyURL,
            defaults: defaults,
            isSandboxed: isSandboxed
        )
    }

    func test_copiesHistoryAndHopPreferences_andKeepsOriginals() throws {
        try writeLegacy(history: "[legacy]", preferences: ["hop.settings.v1": Data("s".utf8), "NSOther": 1])
        try Data("[stale]".utf8).write(to: { try? FileManager.default.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true); return historyURL }())

        migrate()

        XCTAssertEqual(try String(contentsOf: historyURL, encoding: .utf8), "[legacy]")
        XCTAssertEqual(defaults.data(forKey: "hop.settings.v1"), Data("s".utf8))
        XCTAssertNil(defaults.object(forKey: "NSOther"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyHome.appending(path: "Library/Application Support/Hop/history.json").path))
        XCTAssertTrue(defaults.bool(forKey: LegacyDataMigration.doneKey))
    }

    func test_runsOnlyOnce() throws {
        try writeLegacy(history: "[first]", preferences: [:])
        migrate()
        try Data("[second]".utf8).write(to: legacyHome.appending(path: "Library/Application Support/Hop/history.json"))
        migrate()
        XCTAssertEqual(try String(contentsOf: historyURL, encoding: .utf8), "[first]")
    }

    func test_withoutLegacyData_onlyMarksDone() {
        migrate()
        XCTAssertFalse(FileManager.default.fileExists(atPath: historyURL.path))
        XCTAssertTrue(defaults.bool(forKey: LegacyDataMigration.doneKey))
    }

    func test_notSandboxed_copiesNothing() throws {
        try writeLegacy(history: "[legacy]", preferences: ["hop.settings.v1": Data("s".utf8)])
        migrate(isSandboxed: false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: historyURL.path))
        XCTAssertNil(defaults.object(forKey: "hop.settings.v1"))
    }
}
