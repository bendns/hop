import Foundation

/// Copies data written by pre-sandbox versions into the app container, once.
///
/// macOS's `container-migration.plist` only runs when the container is first created,
/// which any earlier sandboxed launch (a test run, say) pre-empts. Copying in-app is
/// deterministic. Originals are left untouched; reading them relies on the read-only
/// temporary-exception entitlement for these two paths.
enum LegacyDataMigration {
    static let doneKey = "hop.legacyMigrated.v1"

    static func runIfNeeded(
        legacyHome: URL = realHomeDirectory(),
        historyURL: URL = HistoryStore.defaultFileURL(),
        defaults: UserDefaults = .standard,
        isSandboxed: Bool = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    ) {
        guard !defaults.bool(forKey: doneKey) else { return }
        defer { defaults.set(true, forKey: doneKey) }
        // Without a sandbox, the legacy locations are the live ones.
        guard isSandboxed else { return }

        let fileManager = FileManager.default
        let legacyHistory = legacyHome.appending(path: "Library/Application Support/Hop/history.json")
        if fileManager.isReadableFile(atPath: legacyHistory.path) {
            try? fileManager.createDirectory(
                at: historyURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? fileManager.removeItem(at: historyURL)
            try? fileManager.copyItem(at: legacyHistory, to: historyURL)
        }

        let legacyPreferences = legacyHome.appending(path: "Library/Preferences/com.bendns.hopapp.plist")
        if let values = NSDictionary(contentsOf: legacyPreferences) as? [String: Any] {
            for (key, value) in values where key.hasPrefix("hop.") && key != doneKey {
                defaults.set(value, forKey: key)
            }
        }
    }

    /// The user's real home; inside the sandbox `NSHomeDirectory()` is the container.
    static func realHomeDirectory() -> URL {
        guard let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir else {
            return URL(fileURLWithPath: NSHomeDirectory())
        }
        return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
    }
}
