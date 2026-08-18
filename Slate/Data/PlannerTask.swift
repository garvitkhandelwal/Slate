import Foundation
import SwiftData

/// The sole SwiftData model. `day` stores a `LocalDay.storageDate` (UTC noon), never a moment or due time.
@Model
final class PlannerTask {
    @Attribute(.unique) var id: UUID
    var text: String
    var day: Date
    var isCompleted: Bool
    var createdAt: Date

    init(id: UUID = UUID(), text: String, day: Date, isCompleted: Bool = false, createdAt: Date) {
        self.id = id
        self.text = text
        self.day = day
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}
