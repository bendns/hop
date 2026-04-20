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

    static let maxContinuousStandMinutes = 90
    static let maxContinuousSitMinutes = 30
    static let customStandRange = 5...90
    static let customSitRange = 5...60
}
