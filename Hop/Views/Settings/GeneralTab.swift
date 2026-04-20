import SwiftUI

struct GeneralTab: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        Form {
            Section("Mode") {
                Picker("", selection: presetBinding) {
                    ForEach(presetModes) { mode in
                        Text(mode.displayName).tag(mode)
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
                Toggle("Launch at login", isOn: Binding(
                    get: { store.settings.launchAtLogin },
                    set: { newValue in
                        store.settings.launchAtLogin = newValue
                        LoginItemManager.setEnabled(newValue)
                    }
                ))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Bindings

    private let presetModes: [Mode] = [.science, .beginner, .intermediate, .advanced]

    private var presetBinding: Binding<Mode> {
        Binding(
            get: {
                if store.settings.mode == .custom {
                    return .science
                }
                return store.settings.mode
            },
            set: { newValue in
                store.settings.mode = newValue
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
