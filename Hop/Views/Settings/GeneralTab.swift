import SwiftUI

struct GeneralTab: View {
    @EnvironmentObject private var store: SettingsStore
    @State private var launchAtLogin = LoginItemManager.isEnabled

    var body: some View {
        Form {
            Section("Mode") {
                Picker("", selection: presetBinding) {
                    ForEach(presetModes) { mode in
                        Text(mode.displayName).tag(Optional(mode))
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(previewLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                DisclosureGroup(isExpanded: customExpandedBinding) {
                    LabeledContent("Stand") {
                        Stepper(
                            value: $store.settings.customStandMinutes,
                            in: Presets.customStandRange
                        ) {
                            Text("\(store.settings.customStandMinutes) min").monospacedDigit()
                        }
                    }
                    LabeledContent("Sit") {
                        Stepper(
                            value: $store.settings.customSitMinutes,
                            in: Presets.customSitRange
                        ) {
                            Text("\(store.settings.customSitMinutes) min").monospacedDigit()
                        }
                    }
                    if store.settings.customStandMinutes > Presets.maxContinuousStandMinutes {
                        Label("Stand exceeds safety threshold (\(Presets.maxContinuousStandMinutes) min)", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if store.settings.customSitMinutes > Presets.maxContinuousSitMinutes {
                        Label("Sit exceeds safety threshold (\(Presets.maxContinuousSitMinutes) min)", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } label: {
                    Text("Custom durations")
                }
            }

            Section("Notifications") {
                Toggle("Enable notifications", isOn: $store.settings.notificationsEnabled)
                // SMAppService is the source of truth: registration can fail
                // or be revoked from System Settings.
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        LoginItemManager.setEnabled(newValue)
                        launchAtLogin = LoginItemManager.isEnabled
                    }
                ))
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = LoginItemManager.isEnabled }
    }

    // MARK: - Bindings

    private let presetModes: [Mode] = [.science, .beginner, .intermediate, .advanced]

    /// nil while in custom mode, so no preset segment looks selected.
    private var presetBinding: Binding<Mode?> {
        Binding(
            get: { store.settings.mode == .custom ? nil : store.settings.mode },
            set: { newValue in
                if let newValue { store.settings.mode = newValue }
            }
        )
    }

    private var customExpandedBinding: Binding<Bool> {
        Binding(
            get: { store.settings.mode == .custom },
            set: { expanded in
                if expanded {
                    store.settings.mode = .custom
                } else if store.settings.mode == .custom {
                    store.settings.mode = .science
                }
            }
        )
    }

    private var previewLine: String {
        let d = Presets.durations(
            for: store.settings.mode,
            custom: Durations(
                standMinutes: store.settings.customStandMinutes,
                sitMinutes: store.settings.customSitMinutes
            )
        )
        return "Stand \(d.standMinutes) min · Sit \(d.sitMinutes) min"
    }
}
