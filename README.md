# Hop!

A tiny macOS menu bar app that reminds you to alternate between sitting and standing. Backed by ergonomic research, local-only, no accounts, no telemetry.

## Features

- **Menu bar presence** — SF Symbol icon changes with current posture (`figure.stand` / `figure.seated.side`) and off-hours state (`moon.zzz`).
- **Three modes**
  - *Follow the science* — 30 min stand / 30 min sit, the 1:1 ratio supported by most ergonomic literature.
  - *Levels* — Beginner (15/45), Intermediate (30/30), Advanced (45/30).
  - *Custom* — user-defined stand (5–90 min) and sit (5–60 min) with inline safety warnings.
- **Per-weekday schedule** — enable/disable each day, set work hours + lunch window, mark specific days as "office day" (no notifications).
- **Vacations** — add date ranges to pause notifications.
- **Pause for today** — one-click ad-hoc mute until midnight.
- **Native notifications** with three actions: *Switched* / *Snooze 10 min* / *Skip this one*. Handled even when the app is idle.
- **History** — local log of every posture transition; Today timeline, Week bar chart (3h/day target line), weekly compliance %, CSV export.
- **Launch at login** via `SMAppService`.
- **Survives sleep/wake** — wall-clock based scheduling; recomputes on wake.

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later with Swift 6 toolchain
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)

## Build

```fish
brew install xcodegen
make install      # generates project, builds, copies to /Applications/Hop.app
open /Applications/Hop.app
```

Or manually:

```fish
xcodegen generate
open Hop.xcodeproj     # then Cmd+R in Xcode
```

## Makefile targets

| Target      | Purpose                                              |
|-------------|------------------------------------------------------|
| `make gen`  | Regenerate `Hop.xcodeproj` from `project.yml`        |
| `make build`| Compile Debug config via `xcodebuild`                |
| `make test` | Run the XCTest suite                                 |
| `make install` | Build + copy to `/Applications/Hop.app`            |
| `make run`  | `install` then launch                                |
| `make clean`| Remove generated project + DerivedData               |

## Permissions

On first launch the app asks for **Notifications**. If you miss the prompt or deny it:

- Open **System Settings → Notifications**, scroll to **Hop**, toggle "Allow Notifications" on.
- If Hop does not appear in the list (known macOS quirk with ad-hoc signed apps), quit Hop, run `tccutil reset All com.bendns.hopapp`, then launch again.

When notifications are denied, the popover shows an inline banner with a direct link to System Settings.

## Why from `/Applications/`?

macOS silently denies notifications for ad-hoc signed apps running from `DerivedData` on recent versions. The `make install` target copies the bundle to `/Applications/` where LaunchServices trusts it and authorization works normally. See the project plan for details.

## Data location

- **Settings**: `UserDefaults` under key `hop.settings.v1`
- **History**: `~/Library/Application Support/Hop/history.json`

Clearing data: remove both (Settings from `defaults delete com.bendns.hopapp hop.settings.v1`) or use **History → Reset** for just the event log.

## Testing

```fish
make test
```

XCTest suite covers:
- `ScheduleEvaluator` — weekday, work hours, lunch, vacation, pause, global disable (14 cases)
- `PostureScheduler` — initial state, transitions via notification/manual/snooze/skip, autoStart on day rollover, pause/resume, reschedule on settings change (13 cases)
- `SettingsStore` — persistence across instances, defaults
- `HistoryStore` — append, persistence, day filtering

## The science

See the **Science** tab in the app for a plain-language summary. Primary sources:

- Buckley JP, Hedge A, Yates T, et al. (2015). *The sedentary office: an expert statement on the growing case for change towards better health and productivity.* British Journal of Sports Medicine, 49(21), 1357–1362.
- University of Waterloo CRE-MSD — Position paper on sit-stand workstations.
- Cornell University Ergonomics Web (CUErgo) — micro-break recommendations.

## License

Personal project. No license declared yet.

## Contributing / Distribution

Currently a personal MVP, not published to Homebrew. Future packaging aims for:
- Developer ID signed + notarized `.dmg` for zero-Gatekeeper-friction installs
- Homebrew cask formula
