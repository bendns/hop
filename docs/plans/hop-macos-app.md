# Hop! — macOS Menu Bar Sit/Stand Reminder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that sends notifications at configurable intervals to alternate between sitting and standing, backed by ergonomic research, with local history tracking.

**Architecture:** SwiftUI-first menu bar app (`MenuBarExtra`, macOS 13+) with an `ObservableObject` scheduler as the single source of truth. Wall-clock timers survive sleep/wake via `NSWorkspace` notifications. Notifications via `UNUserNotificationCenter` with category actions. Persistence split: `UserDefaults` for settings, JSON file in `~/Library/Application Support/Hop/` for history events.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit interop where needed, `UserNotifications`, `ServiceManagement` (login item), Swift Charts, XCTest, XcodeGen.

---

## File Structure

```
hop/
├── project.yml                       # XcodeGen spec
├── README.md                         # build + permissions docs
├── .gitignore
├── docs/plans/hop-macos-app.md       # this plan
├── Hop/                              # app target sources
│   ├── HopApp.swift                  # @main entry
│   ├── AppDelegate.swift             # UN delegate, workspace observers
│   ├── Info.plist                    # LSUIElement, bundle metadata
│   ├── Hop.entitlements              # app sandbox / notifications
│   ├── Assets.xcassets/              # app icon, color assets
│   ├── Menu/
│   │   └── MenuPopoverView.swift     # MenuBarExtra content
│   ├── Scheduler/
│   │   ├── PostureScheduler.swift    # ObservableObject state machine
│   │   ├── NotificationManager.swift # UN wrapper + category actions
│   │   └── ScheduleEvaluator.swift   # pure functions: is-it-work-time
│   ├── Models/
│   │   ├── Settings.swift            # Settings, Weekday, WorkDay
│   │   ├── PostureEvent.swift        # Posture, Trigger, PostureEvent
│   │   └── Presets.swift             # Mode, preset durations
│   ├── Persistence/
│   │   ├── SettingsStore.swift       # UserDefaults wrapper (@Published)
│   │   └── HistoryStore.swift        # JSON file persistence
│   ├── LoginItem/
│   │   └── LoginItemManager.swift    # SMAppService launch-at-login
│   └── Views/
│       ├── Settings/
│       │   ├── SettingsView.swift    # TabView host
│       │   ├── GeneralTab.swift      # mode selection
│       │   ├── ScheduleTab.swift     # weekday/hours/lunch/office
│       │   ├── VacationsTab.swift    # date range picker
│       │   ├── ScienceTab.swift      # the "why" panel
│       │   └── AboutTab.swift        # version, license
│       └── History/
│           ├── HistoryView.swift     # Today/Week tab host
│           ├── TodayChart.swift      # Swift Charts timeline
│           └── WeekChart.swift       # Swift Charts bar chart
└── HopTests/                         # XCTest target
    ├── ScheduleEvaluatorTests.swift
    ├── PostureSchedulerTests.swift
    ├── SettingsStoreTests.swift
    └── HistoryStoreTests.swift
```

---

## Architecture invariants

These hold across all milestones. Violating them is a bug.

1. **Single source of truth.** `PostureScheduler` owns `currentPosture` and `nextTransitionAt`. All views observe it. No other object caches these values.
2. **Wall-clock based.** The scheduler stores `nextTransitionAt: Date`, not a tick count. UI countdown is `nextTransitionAt.timeIntervalSinceNow`. Sleep/wake recomputes this from persisted settings, never from accumulated ticks.
3. **One logging path.** Every posture transition flows through `HistoryStore.record(_:)`. Notification actions, manual buttons, and auto-starts all call the same method. No transition is logged twice.
4. **Reactive to settings changes.** When `SettingsStore` publishes a change, `PostureScheduler` calls `reschedule()` — cancels pending notifications, recomputes `nextTransitionAt`, reissues.
5. **Off-hours are first-class.** When outside work hours / lunch / weekend / vacation / paused, `nextTransitionAt = nil`, icon shows off state, no notification is scheduled.

---

## Milestones

Each milestone ends with a **stop-for-review** checkpoint: the app is runnable/testable and you can eyeball progress before we move on.

---

### Milestone 1 — Scaffold & menu bar presence

**Deliverable:** `xcodegen generate; open Hop.xcodeproj` → build → icon appears in menu bar → click opens placeholder popover.

**Files:**
- Create: `project.yml`
- Create: `README.md`
- Create: `.gitignore`
- Create: `Hop/HopApp.swift`
- Create: `Hop/AppDelegate.swift`
- Create: `Hop/Info.plist`
- Create: `Hop/Hop.entitlements`
- Create: `Hop/Menu/MenuPopoverView.swift`
- Create: `Hop/Assets.xcassets/AppIcon.appiconset/Contents.json` (placeholder)

**Tasks:**

- [ ] **M1.1: Install XcodeGen if missing**

  Run: `which xcodegen; or brew install xcodegen`

- [ ] **M1.2: Write `project.yml`**

  ```yaml
  name: Hop
  options:
    bundleIdPrefix: com.bendanies.hop
    deploymentTarget:
      macOS: "13.0"
    createIntermediateGroups: true
  settings:
    base:
      SWIFT_VERSION: "5.9"
      MARKETING_VERSION: "0.1.0"
      CURRENT_PROJECT_VERSION: "1"
      ENABLE_HARDENED_RUNTIME: YES
      CODE_SIGN_STYLE: Automatic
      DEVELOPMENT_TEAM: ""
      CODE_SIGN_IDENTITY: "-"
  targets:
    Hop:
      type: application
      platform: macOS
      sources:
        - path: Hop
      resources:
        - path: Hop/Assets.xcassets
      info:
        path: Hop/Info.plist
        properties:
          LSUIElement: true
          CFBundleDisplayName: Hop!
          NSHumanReadableCopyright: ""
      entitlements:
        path: Hop/Hop.entitlements
        properties:
          com.apple.security.app-sandbox: true
          com.apple.security.files.user-selected.read-write: true
      settings:
        base:
          PRODUCT_BUNDLE_IDENTIFIER: com.bendanies.hop
          GENERATE_INFOPLIST_FILE: NO
    HopTests:
      type: bundle.unit-test
      platform: macOS
      sources:
        - path: HopTests
      dependencies:
        - target: Hop
  ```

- [ ] **M1.3: Write `.gitignore`**

  ```
  .DS_Store
  Hop.xcodeproj/
  build/
  DerivedData/
  xcuserdata/
  *.xcuserstate
  .swiftpm/
  ```

- [ ] **M1.4: Write `Hop/Info.plist`** (minimal, XcodeGen fills `LSUIElement`)

  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
  </dict>
  </plist>
  ```

- [ ] **M1.5: Write `Hop/Hop.entitlements`**

  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>com.apple.security.app-sandbox</key>
      <true/>
  </dict>
  </plist>
  ```

- [ ] **M1.6: Write `Hop/HopApp.swift`**

  ```swift
  import SwiftUI

  @main
  struct HopApp: App {
      @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

      var body: some Scene {
          MenuBarExtra {
              MenuPopoverView()
          } label: {
              Image(systemName: "figure.stand")
          }
          .menuBarExtraStyle(.window)
      }
  }
  ```

- [ ] **M1.7: Write `Hop/AppDelegate.swift`** (stub; fleshed out in M4)

  ```swift
  import AppKit

  final class AppDelegate: NSObject, NSApplicationDelegate {
      func applicationDidFinishLaunching(_ notification: Notification) {
          // Milestone 4 will wire UN delegate + workspace observers here.
      }
  }
  ```

- [ ] **M1.8: Write `Hop/Menu/MenuPopoverView.swift`** (placeholder)

  ```swift
  import SwiftUI

  struct MenuPopoverView: View {
      var body: some View {
          VStack(alignment: .leading, spacing: 12) {
              Text("Hop!").font(.headline)
              Text("Scaffold — milestone 1").foregroundStyle(.secondary)
          }
          .padding()
          .frame(width: 320)
      }
  }
  ```

- [ ] **M1.9: Placeholder AppIcon asset**

  `Hop/Assets.xcassets/AppIcon.appiconset/Contents.json` with empty image slots so the asset catalog builds:

  ```json
  {
    "images" : [
      { "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
      { "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
      { "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
      { "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
      { "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
      { "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
      { "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
      { "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
      { "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
      { "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
    ],
    "info" : { "author" : "xcode", "version" : 1 }
  }
  ```

  Also create `Hop/Assets.xcassets/Contents.json`:

  ```json
  { "info" : { "author" : "xcode", "version" : 1 } }
  ```

- [ ] **M1.10: Write `README.md` (stub)** — will be expanded in M9.

  ```markdown
  # Hop!

  A macOS menu bar app that reminds you to alternate between sitting and standing.

  ## Build

      brew install xcodegen
      xcodegen generate
      open Hop.xcodeproj

  Then Cmd+R in Xcode.

  Requires macOS 13+.
  ```

- [ ] **M1.11: Generate project and build**

  ```
  cd /Users/ben/Projects/perso/hop
  xcodegen generate
  xcodebuild -project Hop.xcodeproj -scheme Hop -configuration Debug build
  ```

  Expected: BUILD SUCCEEDED.

- [ ] **M1.12: Run the app**

  Open in Xcode, Cmd+R. Verify:
  - No Dock icon
  - Menu bar shows `figure.stand` SF Symbol
  - Clicking opens popover with "Scaffold — milestone 1"

- [ ] **M1.13: Commit**

  ```
  git init
  git add .
  git commit -m "chore(scaffold): xcodegen project + menu bar placeholder"
  ```

**STOP → review with user.**

---

### Milestone 2 — Data models + persistence

**Deliverable:** `xcodebuild test` passes for `SettingsStoreTests` and `HistoryStoreTests`. Launching the app creates `~/Library/Application Support/Hop/history.json` on first event.

**Files:**
- Create: `Hop/Models/PostureEvent.swift`
- Create: `Hop/Models/Presets.swift`
- Create: `Hop/Models/Settings.swift`
- Create: `Hop/Persistence/SettingsStore.swift`
- Create: `Hop/Persistence/HistoryStore.swift`
- Create: `HopTests/SettingsStoreTests.swift`
- Create: `HopTests/HistoryStoreTests.swift`

**Tasks:**

- [ ] **M2.1: Write `Hop/Models/PostureEvent.swift`**

  ```swift
  import Foundation

  enum Posture: String, Codable, CaseIterable {
      case sitting, standing
      var toggled: Posture { self == .sitting ? .standing : .sitting }
  }

  enum Trigger: String, Codable {
      case notificationAction
      case manual
      case autoStart
      case skipped
  }

  struct PostureEvent: Codable, Identifiable, Equatable {
      let id: UUID
      let timestamp: Date
      let posture: Posture
      let trigger: Trigger

      init(id: UUID = UUID(), timestamp: Date = Date(), posture: Posture, trigger: Trigger) {
          self.id = id
          self.timestamp = timestamp
          self.posture = posture
          self.trigger = trigger
      }
  }
  ```

- [ ] **M2.2: Write `Hop/Models/Presets.swift`**

  ```swift
  import Foundation

  enum Mode: String, Codable, CaseIterable, Identifiable {
      case science
      case beginner
      case intermediate
      case advanced
      case custom
      var id: String { rawValue }

      var displayName: String {
          switch self {
          case .science:      return "Follow the science"
          case .beginner:     return "Beginner"
          case .intermediate: return "Intermediate"
          case .advanced:     return "Advanced"
          case .custom:       return "Custom"
          }
      }
  }

  struct Durations: Equatable {
      let standMinutes: Int
      let sitMinutes: Int
  }

  enum Presets {
      static func durations(for mode: Mode, custom: Durations) -> Durations {
          switch mode {
          case .science:      return Durations(standMinutes: 30, sitMinutes: 30)
          case .beginner:     return Durations(standMinutes: 15, sitMinutes: 45)
          case .intermediate: return Durations(standMinutes: 30, sitMinutes: 30)
          case .advanced:     return Durations(standMinutes: 45, sitMinutes: 30)
          case .custom:       return custom
          }
      }

      static let maxContinuousStandMinutes = 90
      static let maxContinuousSitMinutes = 30
      static let customStandRange = 5...90
      static let customSitRange = 5...60
  }
  ```

- [ ] **M2.3: Write `Hop/Models/Settings.swift`**

  ```swift
  import Foundation

  enum Weekday: Int, Codable, CaseIterable, Identifiable {
      case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
      var id: Int { rawValue }
      var shortName: String {
          ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][rawValue]
      }
      static var workweek: [Weekday] { [.monday, .tuesday, .wednesday, .thursday, .friday] }
  }

  /// Minute-of-day (0..1440).
  struct TimeOfDay: Codable, Equatable, Comparable {
      var minutes: Int
      init(hour: Int, minute: Int) { self.minutes = hour * 60 + minute }
      init(minutes: Int) { self.minutes = minutes }
      var hour: Int { minutes / 60 }
      var minute: Int { minutes % 60 }
      static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool { lhs.minutes < rhs.minutes }
  }

  struct WorkDay: Codable, Equatable {
      var enabled: Bool
      var start: TimeOfDay
      var end: TimeOfDay
      var lunchStart: TimeOfDay
      var lunchEnd: TimeOfDay
      var isOfficeDay: Bool

      static let defaultWork = WorkDay(
          enabled: true,
          start: TimeOfDay(hour: 9, minute: 0),
          end: TimeOfDay(hour: 18, minute: 0),
          lunchStart: TimeOfDay(hour: 12, minute: 0),
          lunchEnd: TimeOfDay(hour: 13, minute: 0),
          isOfficeDay: false
      )
      static let defaultOff = WorkDay(
          enabled: false,
          start: TimeOfDay(hour: 9, minute: 0),
          end: TimeOfDay(hour: 18, minute: 0),
          lunchStart: TimeOfDay(hour: 12, minute: 0),
          lunchEnd: TimeOfDay(hour: 13, minute: 0),
          isOfficeDay: false
      )
  }

  struct Settings: Codable, Equatable {
      var mode: Mode
      var customStandMinutes: Int
      var customSitMinutes: Int
      var workHoursByWeekday: [Weekday: WorkDay]
      var vacationRanges: [DateInterval]
      var pausedUntil: Date?
      var notificationsEnabled: Bool
      var launchAtLogin: Bool

      static let `default`: Settings = {
          var map: [Weekday: WorkDay] = [:]
          for day in Weekday.allCases {
              map[day] = Weekday.workweek.contains(day) ? .defaultWork : .defaultOff
          }
          return Settings(
              mode: .science,
              customStandMinutes: 30,
              customSitMinutes: 30,
              workHoursByWeekday: map,
              vacationRanges: [],
              pausedUntil: nil,
              notificationsEnabled: true,
              launchAtLogin: false
          )
      }()
  }
  ```

- [ ] **M2.4: Write `Hop/Persistence/SettingsStore.swift`**

  ```swift
  import Foundation
  import Combine

  final class SettingsStore: ObservableObject {
      static let shared = SettingsStore()

      private let key = "hop.settings.v1"
      private let defaults: UserDefaults

      @Published var settings: Settings {
          didSet { save() }
      }

      init(defaults: UserDefaults = .standard) {
          self.defaults = defaults
          if let data = defaults.data(forKey: key),
             let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
              self.settings = decoded
          } else {
              self.settings = .default
          }
      }

      private func save() {
          guard let data = try? JSONEncoder().encode(settings) else { return }
          defaults.set(data, forKey: key)
      }

      func reset() { settings = .default }
  }
  ```

- [ ] **M2.5: Write `Hop/Persistence/HistoryStore.swift`**

  ```swift
  import Foundation
  import Combine

  final class HistoryStore: ObservableObject {
      static let shared = HistoryStore()

      @Published private(set) var events: [PostureEvent] = []

      private let fileURL: URL
      private let queue = DispatchQueue(label: "com.bendanies.hop.history", qos: .utility)

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
  ```

- [ ] **M2.6: Write `HopTests/SettingsStoreTests.swift`**

  ```swift
  import XCTest
  @testable import Hop

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
  ```

- [ ] **M2.7: Write `HopTests/HistoryStoreTests.swift`**

  ```swift
  import XCTest
  @testable import Hop

  final class HistoryStoreTests: XCTestCase {
      private var tmpURL: URL!

      override func setUp() {
          super.setUp()
          tmpURL = FileManager.default.temporaryDirectory
              .appendingPathComponent("hop-tests-\(UUID().uuidString).json")
      }

      override func tearDown() {
          try? FileManager.default.removeItem(at: tmpURL)
          super.tearDown()
      }

      func test_recordAppendsEvent() {
          let store = HistoryStore(fileURL: tmpURL)
          store.record(PostureEvent(posture: .standing, trigger: .manual))
          XCTAssertEqual(store.events.count, 1)
      }

      func test_persistsAcrossInstances() {
          let store1 = HistoryStore(fileURL: tmpURL)
          store1.record(PostureEvent(posture: .standing, trigger: .manual))
          // Give the async queue time to flush.
          let exp = expectation(description: "flush")
          DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
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
  ```

- [ ] **M2.8: Regenerate project and run tests**

  ```
  xcodegen generate
  xcodebuild -project Hop.xcodeproj -scheme Hop -destination 'platform=macOS' test
  ```

  Expected: all tests pass.

- [ ] **M2.9: Commit**

  ```
  git add .
  git commit -m "feat(models): add Settings/PostureEvent/Presets + stores with tests"
  ```

**STOP → review.**

---

### Milestone 3 — ScheduleEvaluator (pure work-time logic)

**Deliverable:** Exhaustive unit tests for "is this `Date` a work moment?" covering weekends, office days, lunch, vacation, pause, disabled days.

**Files:**
- Create: `Hop/Scheduler/ScheduleEvaluator.swift`
- Create: `HopTests/ScheduleEvaluatorTests.swift`

**Tasks:**

- [ ] **M3.1: Write `Hop/Scheduler/ScheduleEvaluator.swift`**

  ```swift
  import Foundation

  enum ScheduleStatus: Equatable {
      case working
      case outsideWorkHours
      case onLunchBreak
      case weekend
      case officeDay
      case onVacation
      case paused
      case disabled            // day toggled off
      case notificationsOff    // global toggle
  }

  struct ScheduleEvaluator {
      let calendar: Calendar

      init(calendar: Calendar = .current) { self.calendar = calendar }

      func status(at date: Date, settings: Settings) -> ScheduleStatus {
          if !settings.notificationsEnabled { return .notificationsOff }
          if let until = settings.pausedUntil, date < until { return .paused }
          if settings.vacationRanges.contains(where: { $0.contains(date) }) { return .onVacation }

          let weekday = Weekday(rawValue: calendar.component(.weekday, from: date))!
          guard let day = settings.workHoursByWeekday[weekday] else { return .disabled }
          if !day.enabled { return .disabled }
          if day.isOfficeDay { return .officeDay }

          let tod = TimeOfDay(
              hour: calendar.component(.hour, from: date),
              minute: calendar.component(.minute, from: date)
          )
          if tod < day.start || tod >= day.end { return .outsideWorkHours }
          if tod >= day.lunchStart && tod < day.lunchEnd { return .onLunchBreak }
          return .working
      }

      func isWorking(at date: Date, settings: Settings) -> Bool {
          status(at: date, settings: settings) == .working
      }

      /// Returns the next `Date` where status becomes `.working`, searching forward up to 14 days.
      /// Returns nil if none found (all days disabled, etc.).
      func nextWorkingMoment(after date: Date, settings: Settings) -> Date? {
          var cursor = date
          let horizon = calendar.date(byAdding: .day, value: 14, to: date)!
          while cursor < horizon {
              if isWorking(at: cursor, settings: settings) { return cursor }
              cursor = cursor.addingTimeInterval(60)  // minute-granularity is fine
          }
          return nil
      }
  }
  ```

- [ ] **M3.2: Write `HopTests/ScheduleEvaluatorTests.swift`**

  ```swift
  import XCTest
  @testable import Hop

  final class ScheduleEvaluatorTests: XCTestCase {
      private let evaluator = ScheduleEvaluator()
      private var settings: Settings!

      override func setUp() {
          super.setUp()
          settings = .default
      }

      private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
          var c = DateComponents()
          c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
          return Calendar.current.date(from: c)!
      }

      func test_weekday_withinHours_isWorking() {
          // 2026-04-20 is a Monday.
          XCTAssertEqual(evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 10, minute: 0), settings: settings), .working)
      }

      func test_weekday_beforeStart_outsideHours() {
          XCTAssertEqual(evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 8, minute: 0), settings: settings), .outsideWorkHours)
      }

      func test_weekday_duringLunch() {
          XCTAssertEqual(evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 12, minute: 30), settings: settings), .onLunchBreak)
      }

      func test_saturday_isDisabled() {
          XCTAssertEqual(evaluator.status(at: date(year: 2026, month: 4, day: 25, hour: 10, minute: 0), settings: settings), .disabled)
      }

      func test_officeDay_blocksNotifications() {
          settings.workHoursByWeekday[.monday]!.isOfficeDay = true
          XCTAssertEqual(evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 10, minute: 0), settings: settings), .officeDay)
      }

      func test_vacationRange_blocks() {
          let start = date(year: 2026, month: 4, day: 20, hour: 0, minute: 0)
          let end = date(year: 2026, month: 4, day: 27, hour: 0, minute: 0)
          settings.vacationRanges = [DateInterval(start: start, end: end)]
          XCTAssertEqual(evaluator.status(at: date(year: 2026, month: 4, day: 21, hour: 10, minute: 0), settings: settings), .onVacation)
      }

      func test_pause_blocks_untilExpiry() {
          let now = date(year: 2026, month: 4, day: 20, hour: 10, minute: 0)
          settings.pausedUntil = now.addingTimeInterval(3600)
          XCTAssertEqual(evaluator.status(at: now, settings: settings), .paused)
          XCTAssertEqual(evaluator.status(at: now.addingTimeInterval(3601), settings: settings), .working)
      }

      func test_globalDisabled_overridesAll() {
          settings.notificationsEnabled = false
          XCTAssertEqual(evaluator.status(at: date(year: 2026, month: 4, day: 20, hour: 10, minute: 0), settings: settings), .notificationsOff)
      }

      func test_nextWorkingMoment_skipsLunch() {
          let noon = date(year: 2026, month: 4, day: 20, hour: 12, minute: 30)
          let next = evaluator.nextWorkingMoment(after: noon, settings: settings)
          XCTAssertNotNil(next)
          XCTAssertEqual(Calendar.current.component(.hour, from: next!), 13)
      }

      func test_nextWorkingMoment_fromSaturday_returnsMonday() {
          let sat = date(year: 2026, month: 4, day: 25, hour: 10, minute: 0)
          let next = evaluator.nextWorkingMoment(after: sat, settings: settings)
          XCTAssertEqual(Calendar.current.component(.weekday, from: next!), 2) // Monday
      }
  }
  ```

- [ ] **M3.3: Regenerate & test**

  ```
  xcodegen generate
  xcodebuild -project Hop.xcodeproj -scheme Hop -destination 'platform=macOS' test
  ```

  Expected: all tests pass including the new suite.

- [ ] **M3.4: Commit**

  ```
  git add .
  git commit -m "feat(scheduler): ScheduleEvaluator with full status coverage + tests"
  ```

**STOP → review.**

---

### Milestone 4 — NotificationManager

**Deliverable:** App requests notification permission on first launch; a debug "Test notification" button (temporarily in popover) fires a real macOS notification with actions that log to console.

**Files:**
- Create: `Hop/Scheduler/NotificationManager.swift`
- Modify: `Hop/AppDelegate.swift` (UN delegate wiring)
- Modify: `Hop/Menu/MenuPopoverView.swift` (temporary test button)

**Tasks:**

- [ ] **M4.1: Write `Hop/Scheduler/NotificationManager.swift`**

  ```swift
  import Foundation
  import UserNotifications

  enum NotificationAction: String {
      case switched = "hop.action.switched"
      case snooze = "hop.action.snooze"
      case skip = "hop.action.skip"
  }

  enum NotificationCategory: String {
      case postureSwitch = "hop.category.postureSwitch"
  }

  final class NotificationManager {
      static let shared = NotificationManager()

      private let center = UNUserNotificationCenter.current()
      private let identifierPrefix = "hop.notification."

      func registerCategories() {
          let switched = UNNotificationAction(
              identifier: NotificationAction.switched.rawValue,
              title: "Switched",
              options: []
          )
          let snooze = UNNotificationAction(
              identifier: NotificationAction.snooze.rawValue,
              title: "Snooze 10 min",
              options: []
          )
          let skip = UNNotificationAction(
              identifier: NotificationAction.skip.rawValue,
              title: "Skip this one",
              options: [.destructive]
          )
          let category = UNNotificationCategory(
              identifier: NotificationCategory.postureSwitch.rawValue,
              actions: [switched, snooze, skip],
              intentIdentifiers: [],
              options: []
          )
          center.setNotificationCategories([category])
      }

      func requestAuthorization() async -> Bool {
          do {
              return try await center.requestAuthorization(options: [.alert, .sound, .badge])
          } catch {
              return false
          }
      }

      func authorizationStatus() async -> UNAuthorizationStatus {
          await center.notificationSettings().authorizationStatus
      }

      /// Schedules exactly one posture-switch notification at `fireAt`.
      /// Replaces any previously-scheduled notification.
      func schedule(nextPosture: Posture, fireAt: Date) {
          cancelAll()
          let content = UNMutableNotificationContent()
          switch nextPosture {
          case .standing:
              content.title = "Time to stand up 🧍"
              content.body = "You've been sitting for a while."
          case .sitting:
              content.title = "Time to sit down 🪑"
              content.body = "Nice standing streak. Time for a break."
          }
          content.sound = .default
          content.categoryIdentifier = NotificationCategory.postureSwitch.rawValue
          content.userInfo = ["nextPosture": nextPosture.rawValue]

          let interval = max(fireAt.timeIntervalSinceNow, 1)
          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
          let request = UNNotificationRequest(
              identifier: "\(identifierPrefix)\(UUID().uuidString)",
              content: content,
              trigger: trigger
          )
          center.add(request)
      }

      func cancelAll() {
          center.removeAllPendingNotificationRequests()
      }
  }
  ```

- [ ] **M4.2: Update `Hop/AppDelegate.swift`** — UN delegate + action routing

  ```swift
  import AppKit
  import UserNotifications

  final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
      func applicationDidFinishLaunching(_ notification: Notification) {
          let center = UNUserNotificationCenter.current()
          center.delegate = self
          NotificationManager.shared.registerCategories()

          Task {
              let granted = await NotificationManager.shared.requestAuthorization()
              print("[Hop] Notification auth granted: \(granted)")
          }
      }

      func userNotificationCenter(
          _ center: UNUserNotificationCenter,
          willPresent notification: UNNotification,
          withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
      ) {
          completionHandler([.banner, .sound])
      }

      func userNotificationCenter(
          _ center: UNUserNotificationCenter,
          didReceive response: UNNotificationResponse,
          withCompletionHandler completionHandler: @escaping () -> Void
      ) {
          let actionId = response.actionIdentifier
          let userInfo = response.notification.request.content.userInfo
          let nextPostureRaw = userInfo["nextPosture"] as? String ?? ""
          print("[Hop] Notification action=\(actionId) nextPosture=\(nextPostureRaw)")
          // Milestone 5 will route this to PostureScheduler.
          completionHandler()
      }
  }
  ```

- [ ] **M4.3: Add a debug "Test notification" button in `MenuPopoverView`** (to be removed in M6)

  ```swift
  import SwiftUI

  struct MenuPopoverView: View {
      var body: some View {
          VStack(alignment: .leading, spacing: 12) {
              Text("Hop!").font(.headline)
              Button("Test notification (fire in 5s)") {
                  NotificationManager.shared.schedule(nextPosture: .standing, fireAt: Date().addingTimeInterval(5))
              }
          }
          .padding()
          .frame(width: 320)
      }
  }
  ```

- [ ] **M4.4: Build + manual test**

  ```
  xcodegen generate
  xcodebuild -project Hop.xcodeproj -scheme Hop -configuration Debug build
  ```

  Run in Xcode. On first launch, macOS asks for notification permission → approve. Click the test button; 5 seconds later a banner appears. Click "Switched" / "Snooze" / "Skip" — each logs to Xcode console.

- [ ] **M4.5: Commit**

  ```
  git add .
  git commit -m "feat(notifications): UN manager with category actions + auth request"
  ```

**STOP → review. Confirm notifications actually show up on your machine.**

---

### Milestone 5 — PostureScheduler (core state machine)

**Deliverable:** An `ObservableObject` that owns `currentPosture` and `nextTransitionAt`, transitions on notification actions or manual taps, schedules the next notification, reacts to `Settings` changes, and survives sleep/wake. Unit tests for transitions using an injected clock.

**Files:**
- Create: `Hop/Scheduler/PostureScheduler.swift`
- Create: `HopTests/PostureSchedulerTests.swift`
- Modify: `Hop/AppDelegate.swift` (inject scheduler, route notification actions, observe workspace sleep/wake)
- Modify: `Hop/HopApp.swift` (construct and inject scheduler)

**Tasks:**

- [ ] **M5.1: Write `Hop/Scheduler/PostureScheduler.swift`**

  ```swift
  import Foundation
  import Combine
  import AppKit

  protocol Clock {
      func now() -> Date
  }
  struct SystemClock: Clock { func now() -> Date { Date() } }

  @MainActor
  final class PostureScheduler: ObservableObject {
      @Published private(set) var currentPosture: Posture = .sitting
      @Published private(set) var nextTransitionAt: Date?
      @Published private(set) var status: ScheduleStatus = .outsideWorkHours

      private let settingsStore: SettingsStore
      private let history: HistoryStore
      private let notifications: NotificationManager
      private let evaluator: ScheduleEvaluator
      private let clock: Clock

      private var cancellables = Set<AnyCancellable>()
      private let lastPostureKey = "hop.lastPosture.v1"
      private let lastPostureDateKey = "hop.lastPostureDate.v1"

      init(
          settingsStore: SettingsStore = .shared,
          history: HistoryStore = .shared,
          notifications: NotificationManager = .shared,
          evaluator: ScheduleEvaluator = ScheduleEvaluator(),
          clock: Clock = SystemClock()
      ) {
          self.settingsStore = settingsStore
          self.history = history
          self.notifications = notifications
          self.evaluator = evaluator
          self.clock = clock
          restorePosture()
          observeSettings()
          reschedule()
      }

      // MARK: - Public actions

      func markManualTransition(to posture: Posture) {
          currentPosture = posture
          history.record(PostureEvent(timestamp: clock.now(), posture: posture, trigger: .manual))
          persistPosture()
          reschedule()
      }

      func handleNotificationAction(_ action: NotificationAction, nextPosture: Posture) {
          switch action {
          case .switched:
              currentPosture = nextPosture
              history.record(PostureEvent(timestamp: clock.now(), posture: nextPosture, trigger: .notificationAction))
              persistPosture()
              reschedule()
          case .snooze:
              scheduleNext(at: clock.now().addingTimeInterval(10 * 60), nextPosture: nextPosture)
          case .skip:
              history.record(PostureEvent(timestamp: clock.now(), posture: currentPosture, trigger: .skipped))
              reschedule()
          }
      }

      func pauseForToday() {
          let cal = Calendar.current
          let endOfDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: clock.now()))!
          settingsStore.settings.pausedUntil = endOfDay
      }

      func clearPause() {
          settingsStore.settings.pausedUntil = nil
      }

      /// Call on wake from sleep.
      func handleWake() { reschedule() }

      // MARK: - Internal

      func reschedule() {
          let now = clock.now()
          status = evaluator.status(at: now, settings: settingsStore.settings)

          resetPostureIfNewDay(now: now)

          guard status == .working else {
              nextTransitionAt = nil
              notifications.cancelAll()
              return
          }

          let durations = Presets.durations(for: settingsStore.settings.mode, custom: Durations(
              standMinutes: settingsStore.settings.customStandMinutes,
              sitMinutes: settingsStore.settings.customSitMinutes
          ))
          let minutes = currentPosture == .sitting ? durations.sitMinutes : durations.standMinutes
          let target = now.addingTimeInterval(TimeInterval(minutes * 60))
          scheduleNext(at: target, nextPosture: currentPosture.toggled)
      }

      private func scheduleNext(at date: Date, nextPosture: Posture) {
          nextTransitionAt = date
          notifications.schedule(nextPosture: nextPosture, fireAt: date)
      }

      private func observeSettings() {
          settingsStore.$settings
              .dropFirst()
              .sink { [weak self] _ in self?.reschedule() }
              .store(in: &cancellables)
      }

      private func resetPostureIfNewDay(now: Date) {
          let defaults = UserDefaults.standard
          let cal = Calendar.current
          let lastDate = defaults.object(forKey: lastPostureDateKey) as? Date
          if lastDate == nil || !cal.isDate(lastDate!, inSameDayAs: now) {
              currentPosture = .sitting
              history.record(PostureEvent(timestamp: now, posture: .sitting, trigger: .autoStart))
              persistPosture()
          }
      }

      private func restorePosture() {
          let defaults = UserDefaults.standard
          if let raw = defaults.string(forKey: lastPostureKey),
             let posture = Posture(rawValue: raw) {
              currentPosture = posture
          }
      }

      private func persistPosture() {
          let defaults = UserDefaults.standard
          defaults.set(currentPosture.rawValue, forKey: lastPostureKey)
          defaults.set(clock.now(), forKey: lastPostureDateKey)
      }
  }
  ```

- [ ] **M5.2: Write `HopTests/PostureSchedulerTests.swift`**

  ```swift
  import XCTest
  @testable import Hop

  final class MockClock: Clock {
      var current: Date
      init(_ d: Date) { self.current = d }
      func now() -> Date { current }
  }

  @MainActor
  final class PostureSchedulerTests: XCTestCase {
      private var settingsStore: SettingsStore!
      private var history: HistoryStore!
      private var notif: StubNotificationManager!
      private var clock: MockClock!
      private var scheduler: PostureScheduler!

      override func setUp() async throws {
          let suite = "hop.tests.\(UUID().uuidString)"
          settingsStore = SettingsStore(defaults: UserDefaults(suiteName: suite)!)
          let url = FileManager.default.temporaryDirectory.appendingPathComponent("hop-\(UUID()).json")
          history = HistoryStore(fileURL: url)
          notif = StubNotificationManager()
          // 2026-04-20 Monday 10:00
          var c = DateComponents(); c.year = 2026; c.month = 4; c.day = 20; c.hour = 10
          clock = MockClock(Calendar.current.date(from: c)!)
          scheduler = PostureScheduler(
              settingsStore: settingsStore,
              history: history,
              notifications: notif,
              clock: clock
          )
      }

      func test_initialPostureIsSitting() {
          XCTAssertEqual(scheduler.currentPosture, .sitting)
      }

      func test_switchedAction_flipsPosture_andLogs() {
          scheduler.handleNotificationAction(.switched, nextPosture: .standing)
          XCTAssertEqual(scheduler.currentPosture, .standing)
          XCTAssertTrue(history.events.contains { $0.trigger == .notificationAction && $0.posture == .standing })
      }

      func test_skipAction_doesNotChangePosture_butLogsSkip() {
          scheduler.handleNotificationAction(.skip, nextPosture: .standing)
          XCTAssertEqual(scheduler.currentPosture, .sitting)
          XCTAssertTrue(history.events.contains { $0.trigger == .skipped })
      }

      func test_snoozeAction_reschedules10Minutes() {
          scheduler.handleNotificationAction(.snooze, nextPosture: .standing)
          let delta = scheduler.nextTransitionAt!.timeIntervalSince(clock.now())
          XCTAssertEqual(delta, 600, accuracy: 2)
      }

      func test_manualTransition_logsAndReschedules() {
          scheduler.markManualTransition(to: .standing)
          XCTAssertEqual(scheduler.currentPosture, .standing)
          XCTAssertTrue(history.events.contains { $0.trigger == .manual })
      }

      func test_offHours_noNextTransition() async {
          var c = DateComponents(); c.year = 2026; c.month = 4; c.day = 20; c.hour = 23
          clock.current = Calendar.current.date(from: c)!
          scheduler.reschedule()
          XCTAssertNil(scheduler.nextTransitionAt)
      }

      func test_pauseForToday_setsPauseUntilEndOfDay() {
          scheduler.pauseForToday()
          let paused = settingsStore.settings.pausedUntil
          XCTAssertNotNil(paused)
          XCTAssertTrue(paused! > clock.now())
      }
  }

  /// Mirror NotificationManager's public surface without calling UN.
  final class StubNotificationManager: NotificationManager {
      var scheduled: [(Posture, Date)] = []
      var cancelCount = 0
      override func schedule(nextPosture: Posture, fireAt: Date) {
          scheduled.append((nextPosture, fireAt))
      }
      override func cancelAll() { cancelCount += 1 }
  }
  ```

  **Note:** `StubNotificationManager` overrides methods, so mark them `open`/non-final and `override`-able. If that's inconvenient, extract a `NotificationScheduling` protocol with `schedule(nextPosture:fireAt:)` / `cancelAll()` and have `NotificationManager` conform. Prefer the protocol approach — do it now:

  Change `PostureScheduler` to accept `any NotificationScheduling` and make `NotificationManager` conform. `StubNotificationManager` becomes a plain struct/class conforming to the protocol, no overriding.

  ```swift
  // Add to NotificationManager.swift:
  protocol NotificationScheduling {
      func schedule(nextPosture: Posture, fireAt: Date)
      func cancelAll()
  }
  extension NotificationManager: NotificationScheduling {}
  ```

  Update `PostureScheduler.init(notifications:)` signature to `any NotificationScheduling = NotificationManager.shared`.

- [ ] **M5.3: Update `Hop/AppDelegate.swift`** — route actions into scheduler, observe wake

  ```swift
  import AppKit
  import UserNotifications

  final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
      var scheduler: PostureScheduler?

      func applicationDidFinishLaunching(_ notification: Notification) {
          let center = UNUserNotificationCenter.current()
          center.delegate = self
          NotificationManager.shared.registerCategories()

          Task { _ = await NotificationManager.shared.requestAuthorization() }

          NSWorkspace.shared.notificationCenter.addObserver(
              self, selector: #selector(didWake),
              name: NSWorkspace.didWakeNotification, object: nil
          )
      }

      @objc private func didWake() {
          Task { @MainActor in scheduler?.handleWake() }
      }

      func userNotificationCenter(
          _ center: UNUserNotificationCenter,
          willPresent notification: UNNotification,
          withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
      ) {
          completionHandler([.banner, .sound])
      }

      func userNotificationCenter(
          _ center: UNUserNotificationCenter,
          didReceive response: UNNotificationResponse,
          withCompletionHandler completionHandler: @escaping () -> Void
      ) {
          let actionId = response.actionIdentifier
          let userInfo = response.notification.request.content.userInfo
          let nextPosture = (userInfo["nextPosture"] as? String).flatMap(Posture.init(rawValue:)) ?? .standing

          let mapped: NotificationAction? = {
              switch actionId {
              case NotificationAction.switched.rawValue: return .switched
              case NotificationAction.snooze.rawValue: return .snooze
              case NotificationAction.skip.rawValue: return .skip
              case UNNotificationDefaultActionIdentifier: return .switched
              default: return nil
              }
          }()

          if let mapped {
              Task { @MainActor in scheduler?.handleNotificationAction(mapped, nextPosture: nextPosture) }
          }
          completionHandler()
      }
  }
  ```

- [ ] **M5.4: Update `Hop/HopApp.swift`** — construct scheduler, inject

  ```swift
  import SwiftUI

  @main
  struct HopApp: App {
      @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
      @StateObject private var scheduler = PostureScheduler()

      var body: some Scene {
          MenuBarExtra {
              MenuPopoverView()
                  .environmentObject(scheduler)
                  .environmentObject(SettingsStore.shared)
                  .environmentObject(HistoryStore.shared)
                  .onAppear { appDelegate.scheduler = scheduler }
          } label: {
              Image(systemName: iconName(for: scheduler.status, posture: scheduler.currentPosture))
          }
          .menuBarExtraStyle(.window)
      }

      private func iconName(for status: ScheduleStatus, posture: Posture) -> String {
          switch status {
          case .working:
              return posture == .standing ? "figure.stand" : "figure.seated.side"
          default:
              return "moon.zzz"
          }
      }
  }
  ```

- [ ] **M5.5: Regenerate & test**

  ```
  xcodegen generate
  xcodebuild -project Hop.xcodeproj -scheme Hop -destination 'platform=macOS' test
  ```

  Expected: `PostureSchedulerTests` all pass.

- [ ] **M5.6: Manual smoke test**

  In `ScheduleTab` this doesn't exist yet; temporarily in `MenuPopoverView` show `scheduler.nextTransitionAt` and a "Force next in 10s" button that calls a debug method. Or shorten durations via custom mode later. Confirm that a real notification fires on schedule and actions flip the observed posture.

- [ ] **M5.7: Commit**

  ```
  git add .
  git commit -m "feat(scheduler): PostureScheduler state machine with sleep/wake + tests"
  ```

**STOP → review. This is the heart of the app.**

---

### Milestone 6 — Menu bar popover UI

**Deliverable:** Polished popover replacing the debug view: current state, live countdown, quick actions, today's stats. Dynamic menu bar icon.

**Files:**
- Modify: `Hop/Menu/MenuPopoverView.swift`
- Create: (if needed) small view helpers inline

**Tasks:**

- [ ] **M6.1: Replace `MenuPopoverView` with production content**

  ```swift
  import SwiftUI

  struct MenuPopoverView: View {
      @EnvironmentObject private var scheduler: PostureScheduler
      @EnvironmentObject private var history: HistoryStore
      @EnvironmentObject private var settings: SettingsStore
      @Environment(\.openWindow) private var openWindow

      @State private var tick: Date = Date()
      private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

      var body: some View {
          VStack(alignment: .leading, spacing: 14) {
              header
              Divider()
              countdownSection
              Divider()
              actionsSection
              Divider()
              statsSection
              Divider()
              footer
          }
          .padding(16)
          .frame(width: 320)
          .onReceive(timer) { tick = $0 }
      }

      private var header: some View {
          HStack {
              Image(systemName: scheduler.currentPosture == .standing ? "figure.stand" : "figure.seated.side")
                  .font(.title2)
              VStack(alignment: .leading) {
                  Text("Currently \(scheduler.currentPosture == .standing ? "standing" : "sitting")")
                      .font(.headline)
                  Text(statusLabel).font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
          }
      }

      private var statusLabel: String {
          switch scheduler.status {
          case .working:          return "Work hours"
          case .onLunchBreak:     return "Lunch break"
          case .outsideWorkHours: return "Outside work hours"
          case .weekend, .disabled: return "Day off"
          case .officeDay:        return "Office day"
          case .onVacation:       return "On vacation"
          case .paused:           return "Paused"
          case .notificationsOff: return "Notifications off"
          }
      }

      private var countdownSection: some View {
          Group {
              if let next = scheduler.nextTransitionAt {
                  let remaining = max(0, next.timeIntervalSince(tick))
                  HStack {
                      Text("Next switch in")
                      Spacer()
                      Text(format(remaining)).monospacedDigit().font(.title3.weight(.semibold))
                  }
              } else {
                  Text("No scheduled switch").foregroundStyle(.secondary)
              }
          }
      }

      private var actionsSection: some View {
          VStack(spacing: 8) {
              HStack(spacing: 8) {
                  Button("Mark standing") { scheduler.markManualTransition(to: .standing) }
                      .disabled(scheduler.currentPosture == .standing)
                  Button("Mark sitting") { scheduler.markManualTransition(to: .sitting) }
                      .disabled(scheduler.currentPosture == .sitting)
              }
              HStack(spacing: 8) {
                  Button("Snooze 10 min") {
                      scheduler.handleNotificationAction(.snooze, nextPosture: scheduler.currentPosture.toggled)
                  }
                  if settings.settings.pausedUntil != nil {
                      Button("Resume") { scheduler.clearPause() }
                  } else {
                      Button("Pause for today") { scheduler.pauseForToday() }
                  }
              }
          }
          .buttonStyle(.bordered)
      }

      private var statsSection: some View {
          let events = history.eventsForToday()
          let (sit, stand) = Self.totals(for: events, now: tick, current: scheduler.currentPosture)
          return VStack(alignment: .leading, spacing: 4) {
              Text("Today").font(.headline)
              HStack {
                  Label(format(stand), systemImage: "figure.stand")
                  Spacer()
                  Label(format(sit), systemImage: "figure.seated.side")
              }.font(.subheadline)
          }
      }

      private var footer: some View {
          HStack {
              Button("Settings…") { openWindow(id: "settings") }
              Button("History…") { openWindow(id: "history") }
              Spacer()
              Button("Quit") { NSApplication.shared.terminate(nil) }
          }
          .buttonStyle(.link)
      }

      private func format(_ seconds: TimeInterval) -> String {
          let total = Int(seconds)
          let h = total / 3600, m = (total % 3600) / 60, s = total % 60
          return h > 0 ? String(format: "%dh %02dm", h, m) : String(format: "%02d:%02d", m, s)
      }

      /// Collapses events into total sit / stand seconds up to `now`.
      static func totals(for events: [PostureEvent], now: Date, current: Posture) -> (sit: TimeInterval, stand: TimeInterval) {
          var sit: TimeInterval = 0
          var stand: TimeInterval = 0
          let sorted = events.sorted { $0.timestamp < $1.timestamp }
          for (i, e) in sorted.enumerated() {
              let end = i + 1 < sorted.count ? sorted[i + 1].timestamp : now
              let delta = end.timeIntervalSince(e.timestamp)
              if e.posture == .sitting { sit += delta } else { stand += delta }
          }
          return (sit, stand)
      }
  }
  ```

- [ ] **M6.2: Register `WindowGroup`s in `HopApp`** for Settings and History windows (empty placeholders, filled in M7/M8)

  ```swift
  // Add inside HopApp.body, alongside MenuBarExtra:
  Window("Settings", id: "settings") { Text("Settings (M7)") .frame(minWidth: 480, minHeight: 360).padding() }
  Window("History", id: "history") { Text("History (M8)") .frame(minWidth: 560, minHeight: 400).padding() }
  ```

- [ ] **M6.3: Icon state confirmed**

  `HopApp.iconName(for:posture:)` already returns `figure.stand` / `figure.seated.side` / `moon.zzz`. Verify by switching the clock between weekend and weekday via temporary override, or just flip Monday's `enabled` toggle later in Settings.

- [ ] **M6.4: Build & run manually**

  ```
  xcodegen generate
  xcodebuild -project Hop.xcodeproj -scheme Hop -configuration Debug build
  ```

  Open, click icon, observe live countdown, press each button, watch values update.

- [ ] **M6.5: Commit**

  ```
  git add .
  git commit -m "feat(menu): production popover with countdown, actions, today totals"
  ```

**STOP → review.**

---

### Milestone 7 — Settings window (General / Schedule / Vacations / Science / About)

**Deliverable:** Full settings window, tabbed, all fields bound to `SettingsStore.settings` via `@EnvironmentObject` / `@Binding`. Launch-at-login toggle works via `SMAppService`.

**Files:**
- Create: `Hop/Views/Settings/SettingsView.swift`
- Create: `Hop/Views/Settings/GeneralTab.swift`
- Create: `Hop/Views/Settings/ScheduleTab.swift`
- Create: `Hop/Views/Settings/VacationsTab.swift`
- Create: `Hop/Views/Settings/ScienceTab.swift`
- Create: `Hop/Views/Settings/AboutTab.swift`
- Create: `Hop/LoginItem/LoginItemManager.swift`
- Modify: `Hop/HopApp.swift` (replace placeholder settings window)

**Tasks:**

- [ ] **M7.1: `LoginItemManager.swift`**

  ```swift
  import Foundation
  import ServiceManagement

  enum LoginItemManager {
      static func setEnabled(_ enabled: Bool) {
          do {
              if enabled {
                  try SMAppService.mainApp.register()
              } else {
                  try SMAppService.mainApp.unregister()
              }
          } catch {
              print("[Hop] Login item error: \(error)")
          }
      }

      static var isEnabled: Bool {
          SMAppService.mainApp.status == .enabled
      }
  }
  ```

- [ ] **M7.2: `SettingsView.swift`**

  ```swift
  import SwiftUI

  struct SettingsView: View {
      var body: some View {
          TabView {
              GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
              ScheduleTab().tabItem { Label("Schedule", systemImage: "calendar") }
              VacationsTab().tabItem { Label("Vacations", systemImage: "airplane") }
              ScienceTab().tabItem { Label("Science", systemImage: "book") }
              AboutTab().tabItem { Label("About", systemImage: "info.circle") }
          }
          .frame(width: 540, height: 440)
          .padding()
      }
  }
  ```

- [ ] **M7.3: `GeneralTab.swift`** — mode picker, custom durations, launch-at-login, global notifications toggle

  ```swift
  import SwiftUI

  struct GeneralTab: View {
      @EnvironmentObject private var store: SettingsStore

      var body: some View {
          Form {
              Picker("Mode", selection: $store.settings.mode) {
                  ForEach(Mode.allCases) { Text($0.displayName).tag($0) }
              }
              .pickerStyle(.radioGroup)

              Section("Preset") {
                  Text(previewLine).foregroundStyle(.secondary)
              }

              if store.settings.mode == .custom {
                  Section("Custom durations") {
                      Stepper("Stand: \(store.settings.customStandMinutes) min",
                              value: $store.settings.customStandMinutes,
                              in: Presets.customStandRange)
                      Stepper("Sit: \(store.settings.customSitMinutes) min",
                              value: $store.settings.customSitMinutes,
                              in: Presets.customSitRange)
                      if store.settings.customStandMinutes > Presets.maxContinuousStandMinutes {
                          Label("Exceeds safety threshold (\(Presets.maxContinuousStandMinutes) min)",
                                systemImage: "exclamationmark.triangle")
                              .foregroundStyle(.orange)
                      }
                  }
              }

              Section {
                  Toggle("Enable notifications", isOn: $store.settings.notificationsEnabled)
                  Toggle("Launch at login", isOn: Binding(
                      get: { store.settings.launchAtLogin },
                      set: { new in
                          store.settings.launchAtLogin = new
                          LoginItemManager.setEnabled(new)
                      }
                  ))
              }
          }
          .padding()
      }

      private var previewLine: String {
          let d = Presets.durations(for: store.settings.mode, custom: Durations(
              standMinutes: store.settings.customStandMinutes,
              sitMinutes: store.settings.customSitMinutes
          ))
          return "Stand \(d.standMinutes) min / Sit \(d.sitMinutes) min"
      }
  }
  ```

- [ ] **M7.4: `ScheduleTab.swift`** — per-weekday grid

  ```swift
  import SwiftUI

  struct ScheduleTab: View {
      @EnvironmentObject private var store: SettingsStore

      var body: some View {
          ScrollView {
              VStack(alignment: .leading, spacing: 12) {
                  ForEach(Weekday.allCases) { day in
                      weekdayRow(day)
                      Divider()
                  }
              }
              .padding()
          }
      }

      @ViewBuilder private func weekdayRow(_ day: Weekday) -> some View {
          let binding = Binding<WorkDay>(
              get: { store.settings.workHoursByWeekday[day] ?? .defaultOff },
              set: { store.settings.workHoursByWeekday[day] = $0 }
          )
          VStack(alignment: .leading) {
              HStack {
                  Toggle(day.shortName, isOn: binding.enabled).toggleStyle(.checkbox)
                  Spacer()
                  Toggle("Office day", isOn: binding.isOfficeDay).disabled(!binding.enabled.wrappedValue)
              }
              if binding.enabled.wrappedValue {
                  HStack {
                      TimeOfDayPicker(label: "Start", value: binding.start)
                      TimeOfDayPicker(label: "End",   value: binding.end)
                  }
                  HStack {
                      TimeOfDayPicker(label: "Lunch start", value: binding.lunchStart)
                      TimeOfDayPicker(label: "Lunch end",   value: binding.lunchEnd)
                  }
              }
          }
      }
  }

  struct TimeOfDayPicker: View {
      let label: String
      @Binding var value: TimeOfDay
      var body: some View {
          HStack {
              Text(label).frame(width: 90, alignment: .leading)
              DatePicker("", selection: Binding(
                  get: { Self.date(from: value) },
                  set: { value = Self.time(from: $0) }
              ), displayedComponents: .hourAndMinute)
              .labelsHidden()
          }
      }
      private static func date(from tod: TimeOfDay) -> Date {
          var c = DateComponents(); c.hour = tod.hour; c.minute = tod.minute
          return Calendar.current.date(from: c) ?? Date()
      }
      private static func time(from date: Date) -> TimeOfDay {
          let c = Calendar.current.dateComponents([.hour, .minute], from: date)
          return TimeOfDay(hour: c.hour ?? 0, minute: c.minute ?? 0)
      }
  }
  ```

- [ ] **M7.5: `VacationsTab.swift`** — list + add/delete date range

  ```swift
  import SwiftUI

  struct VacationsTab: View {
      @EnvironmentObject private var store: SettingsStore
      @State private var newStart: Date = Date()
      @State private var newEnd: Date = Date().addingTimeInterval(7 * 86400)

      var body: some View {
          VStack(alignment: .leading, spacing: 12) {
              Text("Vacations").font(.headline)
              List {
                  ForEach(store.settings.vacationRanges.indices, id: \.self) { i in
                      let r = store.settings.vacationRanges[i]
                      HStack {
                          Text("\(r.start.formatted(date: .abbreviated, time: .omitted)) → \(r.end.formatted(date: .abbreviated, time: .omitted))")
                          Spacer()
                          Button(role: .destructive) {
                              store.settings.vacationRanges.remove(at: i)
                          } label: { Image(systemName: "trash") }
                              .buttonStyle(.borderless)
                      }
                  }
              }
              .frame(minHeight: 120)

              Divider()
              Text("Add a vacation").font(.subheadline)
              HStack {
                  DatePicker("From", selection: $newStart, displayedComponents: .date)
                  DatePicker("To",   selection: $newEnd,   displayedComponents: .date)
              }
              Button("Add") {
                  guard newEnd > newStart else { return }
                  store.settings.vacationRanges.append(DateInterval(start: newStart, end: newEnd))
              }
          }
          .padding()
      }
  }
  ```

- [ ] **M7.6: `ScienceTab.swift`** — plain-language summary + citations

  ```swift
  import SwiftUI

  struct ScienceTab: View {
      var body: some View {
          ScrollView {
              VStack(alignment: .leading, spacing: 14) {
                  Text("Why alternate?").font(.title2).bold()
                  Text("Prolonged sitting is an independent risk factor for musculoskeletal issues, cardiometabolic disease, and reduced concentration. Prolonged standing is not a fix — it introduces lower-limb fatigue and varicose risk. The goal is alternation, plus regular micro-breaks to move.")
                  Text("Recommended ratios").font(.headline)
                  VStack(alignment: .leading, spacing: 6) {
                      Text("• Total: 2–4 h of cumulative standing per 8-h workday")
                      Text("• Continuous standing: keep under ~45 min; ideally 20–30 min")
                      Text("• Continuous sitting: keep under ~30 min before a change of position")
                      Text("• Add a 1–2 min micro-break every 30 min regardless of posture")
                  }
                  Text("Sources").font(.headline)
                  VStack(alignment: .leading, spacing: 4) {
                      Text("Buckley JP, Hedge A, Yates T, et al. (2015). The sedentary office: an expert statement on the growing case for change towards better health and productivity. British Journal of Sports Medicine, 49(21), 1357–1362.")
                      Text("University of Waterloo CRE-MSD — Position paper on the use of sit-stand workstations.")
                      Text("Cornell University Ergonomics Web (CUErgo) — micro-break recommendations.")
                  }.font(.footnote).foregroundStyle(.secondary)
              }
              .padding()
          }
      }
  }
  ```

- [ ] **M7.7: `AboutTab.swift`**

  ```swift
  import SwiftUI

  struct AboutTab: View {
      var body: some View {
          VStack(spacing: 12) {
              Image(systemName: "figure.stand").font(.system(size: 48))
              Text("Hop!").font(.largeTitle).bold()
              Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1")")
                  .foregroundStyle(.secondary)
              Text("A gentle reminder to alternate sit and stand.")
                  .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding()
      }
  }
  ```

- [ ] **M7.8: Wire the Settings window in `HopApp`**

  Replace the M6 placeholder:

  ```swift
  Window("Settings", id: "settings") {
      SettingsView()
          .environmentObject(SettingsStore.shared)
  }
  .defaultSize(width: 540, height: 440)
  ```

- [ ] **M7.9: Manual test**

  Change mode, flip Monday off, adjust Tuesday's hours, mark Thursday as office day, add a vacation, toggle launch-at-login. Verify popover countdown updates immediately after each change (proves `observeSettings` wiring from M5).

- [ ] **M7.10: Commit**

  ```
  git add .
  git commit -m "feat(settings): full settings window with General/Schedule/Vacations/Science/About"
  ```

**STOP → review.**

---

### Milestone 8 — History window + CSV export

**Deliverable:** Today timeline and Week bar chart via Swift Charts. Compliance rate. CSV export. Reset with confirmation.

**Files:**
- Create: `Hop/Views/History/HistoryView.swift`
- Create: `Hop/Views/History/TodayChart.swift`
- Create: `Hop/Views/History/WeekChart.swift`
- Modify: `Hop/HopApp.swift` (replace placeholder history window)

**Tasks:**

- [ ] **M8.1: `TodayChart.swift`**

  ```swift
  import SwiftUI
  import Charts

  struct TodayChart: View {
      let events: [PostureEvent]
      let now: Date

      struct Segment: Identifiable {
          let id = UUID()
          let start: Date
          let end: Date
          let posture: Posture
      }

      var segments: [Segment] {
          let sorted = events.sorted { $0.timestamp < $1.timestamp }
          var out: [Segment] = []
          for (i, e) in sorted.enumerated() {
              let end = i + 1 < sorted.count ? sorted[i + 1].timestamp : now
              out.append(Segment(start: e.timestamp, end: end, posture: e.posture))
          }
          return out
      }

      var body: some View {
          Chart(segments) { s in
              BarMark(
                  xStart: .value("Start", s.start),
                  xEnd: .value("End", s.end),
                  y: .value("Posture", s.posture == .standing ? "Standing" : "Sitting")
              )
              .foregroundStyle(s.posture == .standing ? .green : .orange)
          }
          .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) }
          .frame(height: 140)
      }
  }
  ```

- [ ] **M8.2: `WeekChart.swift`**

  ```swift
  import SwiftUI
  import Charts

  struct WeekChart: View {
      let events: [PostureEvent]
      let now: Date

      struct Day: Identifiable {
          let id: Date
          let standingSeconds: TimeInterval
      }

      var data: [Day] {
          let cal = Calendar.current
          let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
          var days: [Day] = []
          for offset in 0..<7 {
              let dayStart = cal.date(byAdding: .day, value: offset, to: weekStart)!
              let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
              let dayEvents = events.filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
              let (_, stand) = MenuPopoverView.totals(for: dayEvents, now: min(now, dayEnd), current: .sitting)
              days.append(Day(id: dayStart, standingSeconds: stand))
          }
          return days
      }

      var body: some View {
          Chart(data) { day in
              BarMark(
                  x: .value("Day", day.id, unit: .day),
                  y: .value("Standing (hours)", day.standingSeconds / 3600)
              )
              RuleMark(y: .value("Target", 3))
                  .foregroundStyle(.secondary)
                  .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                  .annotation(position: .top, alignment: .trailing) { Text("Target 3h").font(.caption2) }
          }
          .frame(height: 200)
      }
  }
  ```

- [ ] **M8.3: `HistoryView.swift`**

  ```swift
  import SwiftUI
  import AppKit
  import UniformTypeIdentifiers

  struct HistoryView: View {
      @EnvironmentObject private var history: HistoryStore
      @State private var tab = 0
      @State private var showResetConfirm = false
      @State private var now = Date()
      private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

      var body: some View {
          VStack {
              Picker("", selection: $tab) {
                  Text("Today").tag(0); Text("Week").tag(1)
              }.pickerStyle(.segmented).padding(.horizontal)

              if tab == 0 {
                  TodayChart(events: history.eventsForToday(now: now), now: now)
              } else {
                  WeekChart(events: history.eventsForWeek(now: now), now: now)
              }

              Divider()
              complianceRow
              Divider()
              HStack {
                  Button("Export CSV…") { exportCSV() }
                  Spacer()
                  Button("Reset…", role: .destructive) { showResetConfirm = true }
              }.padding(.horizontal)
          }
          .padding()
          .onReceive(timer) { now = $0 }
          .confirmationDialog("Reset all history?", isPresented: $showResetConfirm, titleVisibility: .visible) {
              Button("Reset", role: .destructive) { history.reset() }
              Button("Cancel", role: .cancel) {}
          } message: {
              Text("This permanently deletes your sit/stand log.")
          }
      }

      private var complianceRow: some View {
          let week = history.eventsForWeek(now: now)
          let actionable = week.filter { $0.trigger == .notificationAction || $0.trigger == .skipped }
          let switched = actionable.filter { $0.trigger == .notificationAction }.count
          let pct = actionable.isEmpty ? 0 : Int(Double(switched) / Double(actionable.count) * 100)
          return HStack {
              Text("This week compliance:")
              Spacer()
              Text("\(pct)% (\(switched) of \(actionable.count))").monospacedDigit()
          }.padding(.horizontal)
      }

      private func exportCSV() {
          let panel = NSSavePanel()
          panel.allowedContentTypes = [.commaSeparatedText]
          panel.nameFieldStringValue = "hop-history.csv"
          guard panel.runModal() == .OK, let url = panel.url else { return }
          var csv = "timestamp,posture,trigger\n"
          for e in history.events.sorted(by: { $0.timestamp < $1.timestamp }) {
              let iso = ISO8601DateFormatter().string(from: e.timestamp)
              csv += "\(iso),\(e.posture.rawValue),\(e.trigger.rawValue)\n"
          }
          try? csv.write(to: url, atomically: true, encoding: .utf8)
      }
  }
  ```

- [ ] **M8.4: Wire in `HopApp`** — replace placeholder:

  ```swift
  Window("History", id: "history") {
      HistoryView()
          .environmentObject(HistoryStore.shared)
  }
  .defaultSize(width: 640, height: 480)
  ```

- [ ] **M8.5: Manual test**

  Generate events by using the app for a few minutes (or temporarily set custom durations to 1 min). Open History, verify today chart renders, week chart shows today's bar. Export CSV and inspect in a text editor. Reset with confirmation.

- [ ] **M8.6: Commit**

  ```
  git add .
  git commit -m "feat(history): Today/Week charts, compliance rate, CSV export, reset"
  ```

**STOP → review.**

---

### Milestone 9 — Polish, app icon, README, final pass

**Deliverable:** Real app icon (generated or placeholder with Hop! wordmark); complete README; final bug sweep.

**Files:**
- Modify: `Hop/Assets.xcassets/AppIcon.appiconset/` (add real pngs)
- Modify: `README.md`

**Tasks:**

- [ ] **M9.1: App icon**

  Either (a) user provides a 1024×1024 PNG → I generate the variants with `sips`, or (b) produce a placeholder using SF Symbol rendering. Decide together. Drop files into `AppIcon.appiconset/` and update `Contents.json` with filenames.

- [ ] **M9.2: Complete README**

  ```markdown
  # Hop!

  A macOS menu bar app that reminds you to alternate between sitting and standing, backed by ergonomic research.

  ## Features
  - Menu bar icon that reflects current posture
  - Three modes: science-backed default, progressive levels, or fully custom
  - Per-weekday schedule, lunch window, office days, vacation ranges
  - Native notifications with Switched / Snooze / Skip actions
  - Local history with daily and weekly charts, CSV export
  - No network, no telemetry — everything stays on your Mac

  ## Build

      brew install xcodegen
      xcodegen generate
      open Hop.xcodeproj

  Then Cmd+R. macOS 13+ required.

  ## Permissions
  On first launch, macOS will ask for permission to show notifications. If you deny it, the app shows a banner and a link to System Settings → Notifications → Hop.

  ## Data location
  - Settings: UserDefaults under `hop.settings.v1`
  - History: `~/Library/Application Support/Hop/history.json`

  ## Testing

      xcodebuild -project Hop.xcodeproj -scheme Hop -destination 'platform=macOS' test

  ## The science
  See the Science tab inside the app for sources and recommended ratios.
  ```

- [ ] **M9.3: Denied-permission banner**

  In `MenuPopoverView`, if `NotificationManager.authorizationStatus()` returns `.denied`, show a banner with "Open Notification Settings" that calls:

  ```swift
  NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
  ```

- [ ] **M9.4: Full-build smoke test**

  ```
  xcodegen generate
  xcodebuild -project Hop.xcodeproj -scheme Hop -destination 'platform=macOS' clean test
  ```

  Expected: clean build, all tests pass, app runs, all surfaces work.

- [ ] **M9.5: Commit**

  ```
  git add .
  git commit -m "chore(polish): app icon, README, permission-denied banner"
  ```

**STOP → review, then this is v0.1.**

---

## Spec coverage check

| Spec item | Covered in |
|-----------|------------|
| `LSUIElement = true`, no dock icon | M1 (project.yml) |
| Menu bar SF Symbol state icon | M5 (iconName) |
| Popover: state, countdown, quick actions, today stats, settings/history buttons | M6 |
| `UNUserNotificationCenter` with Switched/Snooze/Skip actions | M4 |
| Emoji notification text | M4 (content) |
| Permission request + graceful denial | M4 + M9.3 |
| Mode A: Follow the science | M2 (Presets.durations) |
| Mode B: Beginner/Intermediate/Advanced | M2 |
| Mode C: Custom with safety thresholds | M2 + M7.3 |
| Science panel with citations | M7.6 |
| Per-weekday enable + hours + lunch | M7.4 |
| Office days toggle | M7.4 |
| Pause for today | M5 (pauseForToday) + M6 |
| Vacation date ranges | M7.5 |
| History storage in App Support | M2.5 |
| Today timeline, Week chart | M8 |
| Compliance rate | M8.3 |
| CSV export | M8.3 |
| Reset history with confirmation | M8.3 |
| Unit tests for ScheduleEvaluator + PostureScheduler | M3 + M5 |
| Wall-clock based + sleep/wake | M5 |
| Reactive to settings changes | M5 (observeSettings) |
| Sitting at start of work day | M5 (resetPostureIfNewDay) |
| Resume last posture otherwise | M5 (restorePosture) |
| Launch at login | M7 (LoginItemManager) |
| README with build + permissions | M9 |

All spec items accounted for.
