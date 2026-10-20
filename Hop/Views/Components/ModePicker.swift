import SwiftUI

/// Two-by-two grid of preset cards. A nil selection means custom durations,
/// so no card is highlighted.
struct ModePicker: View {
    @Binding var selection: Mode?

    private let columns = [GridItem(.flexible(), spacing: HopSpacing.sm), GridItem(.flexible(), spacing: HopSpacing.sm)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: HopSpacing.sm) {
            ForEach(Mode.presets) { mode in
                card(for: mode)
            }
        }
    }

    private func card(for mode: Mode) -> some View {
        let isSelected = selection == mode
        let durations = Presets.durations(for: mode, custom: Durations(standMinutes: 0, sitMinutes: 0))
        return Button {
            withAnimation(.snappy) { selection = mode }
        } label: {
            VStack(alignment: .leading, spacing: HopSpacing.xs) {
                HStack {
                    Image(systemName: mode.systemImage)
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                        .contentTransition(.symbolEffect(.replace))
                }
                Text(mode.displayName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("Stand \(durations.standMinutes) · Sit \(durations.sitMinutes) min")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(mode.blurb)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HopSpacing.md)
            .background(
                isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.12)) : AnyShapeStyle(.fill.quaternary),
                in: .rect(cornerRadius: HopRadius.small, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: HopRadius.small, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            }
            .contentShape(.rect(cornerRadius: HopRadius.small))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
