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
                            Text("\(range.start.formatted(date: .abbreviated, time: .omitted)) → \(range.end.formatted(date: .abbreviated, time: .omitted))")
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
                        guard newEnd > newStart else { return }
                        store.settings.vacationRanges.append(DateInterval(start: newStart, end: newEnd))
                    }
                    .disabled(newEnd <= newStart)
                }
            }
        }
        .formStyle(.grouped)
    }
}
