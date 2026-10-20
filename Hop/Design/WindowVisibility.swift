import SwiftUI
import AppKit

/// Ticks every second while `isPaused` is false, and not at all otherwise.
/// Used to stop per-second redraws while the menu bar window is hidden.
struct PausableEverySecondSchedule: TimelineSchedule {
    let isPaused: Bool

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var next: Date? = startDate
        return AnyIterator {
            defer { next = isPaused ? nil : next?.addingTimeInterval(1) }
            return next
        }
    }
}

extension View {
    /// Calls `action` with whether the hosting window is visible on screen, based on
    /// AppKit's occlusion state. Menu bar windows are ordered out rather than
    /// destroyed when closed, so `onDisappear` is not a reliable signal.
    func onWindowVisibilityChange(_ action: @escaping (Bool) -> Void) -> some View {
        background(WindowVisibilityReader(onChange: action))
    }
}

private struct WindowVisibilityReader: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: ReaderView, context: Context) {
        nsView.onChange = onChange
    }

    final class ReaderView: NSView {
        var onChange: ((Bool) -> Void)?
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            if let window {
                observer = NotificationCenter.default.addObserver(
                    forName: NSWindow.didChangeOcclusionStateNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.report() }
                }
            }
            report()
        }

        private func report() {
            let visible = window?.occlusionState.contains(.visible) ?? false
            // Deferred so SwiftUI state never changes during a view update.
            Task { @MainActor [weak self] in self?.onChange?(visible) }
        }
    }
}
