import SwiftUI

struct VacationsTab: View {
    @EnvironmentObject private var store: SettingsStore
    @State private var newStart: Date = Date()
    @State private var newEnd: Date = Date().addingTimeInterval(7 * 86400)

    var body: some View {
        Form {
            Section("Scheduled vacations") {
                if store.settings.vacationRanges.isEmpty {
                    Text("No vacations scheduled.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.settings.vacationRanges.indices, id: \.self) { i in
                        let range = store.settings.vacationRanges[i]
                        LabeledContent {
                            Button(role: .destructive) {
                                store.settings.vacationRanges.remove(at: i)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove vacation")
                        } label: {
                            // `end` is the midnight after the last day off.
                            Text("\(range.start.formatted(date: .abbreviated, time: .omitted)) → \(range.end.addingTimeInterval(-1).formatted(date: .abbreviated, time: .omitted))")
                                .font(.body)
                        }
                    }
                }
            }

            Section("Add a vacation") {
                LabeledContent("From") {
                    DatePicker("", selection: $newStart, displayedComponents: .date)
                        .labelsHidden()
                }
                LabeledContent("To") {
                    DatePicker("", selection: $newEnd, displayedComponents: .date)
                        .labelsHidden()
                }
                HStack {
                    Spacer()
                    Button("Add vacation") {
                        guard let range = newRange else { return }
                        store.settings.vacationRanges.append(range)
                    }
                    .disabled(newRange == nil)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var newRange: DateInterval? {
        DateInterval.wholeDays(from: newStart, through: newEnd)
    }
}
