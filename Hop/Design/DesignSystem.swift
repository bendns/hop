import SwiftUI
import AppKit

// MARK: - Spacing & radius scale

enum HopSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// Larger radii to sit comfortably inside macOS 26 windows and popovers.
enum HopRadius {
    static let small: CGFloat = 12
    static let container: CGFloat = 18
}

enum HopLayout {
    static let popoverWidth: CGFloat = 320
    static let ringSize: CGFloat = 112
    static let ringLineWidth: CGFloat = 8
    static let stateIconSize: CGFloat = 40
    static let contentMaxWidth: CGFloat = 560
}

// MARK: - Posture styling

extension Posture {
    var label: String { self == .standing ? "Standing" : "Sitting" }
    var systemImage: String { self == .standing ? "figure.stand" : "figure.seated.side" }
    /// Standing is the behavior Hop encourages, so it gets the accent color.
    var tint: Color { self == .standing ? .accentColor : .secondary }
}

// MARK: - Formatting

enum HopFormat {
    /// "1h 05m", "3h" or "12m".
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds)) / 60
        let h = total / 60
        let m = total % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : String(format: "%dh %02dm", h, m)
    }

    /// "12:34" (minutes:seconds), or "1:02:03" past an hour.
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Wordmark

struct HopWordmark: View {
    var body: some View {
        // Matches the brand mark: neutral "Hop", accent "!".
        Text("Hop\(Text("!").foregroundStyle(Color.accentColor))")
            .font(.system(.title3, design: .rounded, weight: .bold))
            .accessibilityLabel("Hop")
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Progress ring

struct ProgressRing<Content: View>: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = HopLayout.ringLineWidth
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.6), value: progress)
            content
        }
    }
}

// MARK: - Card style

extension View {
    /// Subtle fill with a continuous corner. Content surfaces stay opaque-ish;
    /// Liquid Glass is reserved for controls, per the macOS 26 HIG.
    func hopCardStyle(padding: CGFloat = HopSpacing.md) -> some View {
        self
            .padding(padding)
            .background(.fill.quaternary, in: .rect(cornerRadius: HopRadius.container, style: .continuous))
    }

    /// Inline banner style, tinted to stand out from regular cards.
    func hopInlineBannerStyle(tint: Color = .orange) -> some View {
        self
            .padding(HopSpacing.md)
            .background(tint.opacity(0.12), in: .rect(cornerRadius: HopRadius.small, style: .continuous))
    }
}

// MARK: - Window activation

enum HopWindow {
    static let settings = "settings"
    static let history = "history"
    static let welcome = "welcome"

    /// Menu-bar-only apps (`LSUIElement = true`) don't auto-activate, so newly-opened
    /// windows would otherwise land behind whatever else is on screen.
    @MainActor
    static func open(_ id: String, using openWindow: OpenWindowAction) {
        openWindow(id: id)
        NSApp.activate()
    }
}
