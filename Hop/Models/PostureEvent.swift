import Foundation

enum Posture: String, Codable, CaseIterable {
    case sitting, standing
    var toggled: Posture { self == .sitting ? .standing : .sitting }
}

enum Trigger: String, Codable {
    case notificationAction
    case manual
    case autoStart
    case skipped
}

struct PostureEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let posture: Posture
    let trigger: Trigger

    init(id: UUID = UUID(), timestamp: Date = Date(), posture: Posture, trigger: Trigger) {
        self.id = id
        self.timestamp = timestamp
        self.posture = posture
        self.trigger = trigger
    }
}
