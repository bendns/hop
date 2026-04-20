import SwiftUI

// MARK: - Spacing & radius scale

enum HopSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum HopRadius {
    static let small: CGFloat = 8
    static let container: CGFloat = 12
}

enum HopLayout {
    static let popoverWidth: CGFloat = 340
    static let stateCardHeight: CGFloat = 100
    static let stateIconSize: CGFloat = 44
    static let contentMaxWidth: CGFloat = 560
}

// MARK: - Wordmark

struct HopWordmark: View {
    var body: some View {
        Text("Hop!")
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Card style

extension View {
    /// Subtle quaternary fill, 12pt radius, 12pt padding. The house card style.
    func hopCardStyle(padding: CGFloat = HopSpacing.md) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: HopRadius.container, style: .continuous)
                    .fill(.quaternary)
            )
    }

    /// Inline banner style, 8pt radius.
    func hopInlineBannerStyle() -> some View {
        self
            .padding(HopSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: HopRadius.small, style: .continuous)
                    .fill(.quaternary)
            )
    }
}
