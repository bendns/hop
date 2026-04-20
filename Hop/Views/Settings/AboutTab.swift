import SwiftUI
import AppKit

struct AboutTab: View {
    var body: some View {
        VStack(spacing: HopSpacing.lg) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            VStack(spacing: HopSpacing.xs) {
                Text("Hop!")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Version \(version)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text("A gentle reminder to alternate sit and stand, backed by ergonomic research.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(HopSpacing.xxl)
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
    }
}
