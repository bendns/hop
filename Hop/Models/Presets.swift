import Foundation

enum Mode: String, Codable, CaseIterable, Identifiable {
    case science
    case beginner
    case intermediate
    case advanced
    case custom
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .science:      return "Follow the science"
        case .beginner:     return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced:     return "Advanced"
        case .custom:       return "Custom"
        }
    }

    var systemImage: String {
        switch self {
        case .science:      return "flask"
        case .beginner:     return "leaf"
        case .intermediate: return "figure.walk"
        case .advanced:     return "flame"
        case .custom:       return "slider.horizontal.3"
        }
    }

    var blurb: String {
        switch self {
        case .science:      return "Research-backed default"
        case .beginner:     return "Ease into standing"
        case .intermediate: return "Balanced 1:1 rhythm"
        case .advanced:     return "More time on your feet"
        case .custom:       return "Your own durations"
        }
    }

    static let presets: [Mode] = [.science, .beginner, .intermediate, .advanced]
}

struct Durations: Equatable {
    let standMinutes: Int
    let sitMinutes: Int
}

enum Presets {
    static func durations(for mode: Mode, custom: Durations) -> Durations {
        switch mode {
        case .science:      return Durations(standMinutes: 30, sitMinutes: 30)
        case .beginner:     return Durations(standMinutes: 15, sitMinutes: 45)
        case .intermediate: return Durations(standMinutes: 30, sitMinutes: 30)
        case .advanced:     return Durations(standMinutes: 45, sitMinutes: 30)
        case .custom:       return custom
        }
    }

    /// Daily standing target, the middle of the 2–4 h range in the Science tab.
    static let dailyStandGoal: TimeInterval = 3 * 3600

    static let maxContinuousStandMinutes = 45
    static let maxContinuousSitMinutes = 30
    static let customStandRange = 5...90
    static let customSitRange = 5...60
}
