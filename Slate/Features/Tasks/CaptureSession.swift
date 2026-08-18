import Foundation

/// The single add/edit session. There is never more than one focused field.
///
/// Valid transitions:
/// - none → adding, none → editing
/// - adding → adding (submit nonempty and keep rapid entry)
/// - adding → none (outside tap, empty dismissal, navigation)
/// - editing → none (commit, cancel empty, navigation)
/// - adding → editing / editing → adding (commit the valid draft first)
enum CaptureSession: Equatable {
    case none
    case adding(day: LocalDay, draft: String)
    case editing(task: TaskSnapshot, draft: String)

    var draft: String {
        switch self {
        case .none: ""
        case let .adding(_, draft), let .editing(_, draft): draft
        }
    }

    var isActive: Bool { self != .none }

    func isAdding(on day: LocalDay) -> Bool {
        if case let .adding(captureDay, _) = self { return captureDay == day }
        return false
    }

    func isEditing(_ id: UUID) -> Bool {
        if case let .editing(task, _) = self { return task.id == id }
        return false
    }
}
