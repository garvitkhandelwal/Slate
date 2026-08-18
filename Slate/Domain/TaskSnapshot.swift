import Foundation

/// An immutable, view-safe copy of a persisted task. Views never retain SwiftData model objects.
struct TaskSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let day: LocalDay
    let isCompleted: Bool
    let createdAt: Date
}
