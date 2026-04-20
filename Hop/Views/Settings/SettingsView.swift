import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general, schedule, vacations, science, about
    var id: String { rawValue }

    var label: String {
        switch self {
        case .general:   return "General"
        case .schedule:  return "Schedule"
        case .vacations: return "Vacations"
        case .science:   return "Science"
        case .about:     return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general:   return "gearshape"
        case .schedule:  return "calendar"
        case .vacations: return "airplane"
        case .science:   return "book"
        case .about:     return "info.circle"
        }
    }
}

struct SettingsView: View {
    @State private var selection: SettingsSection? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.label, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Group {
                switch selection ?? .general {
                case .general:   GeneralTab()
                case .schedule:  ScheduleTab()
                case .vacations: VacationsTab()
                case .science:   ScienceTab()
                case .about:     AboutTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 640, minHeight: 480)
    }
}
