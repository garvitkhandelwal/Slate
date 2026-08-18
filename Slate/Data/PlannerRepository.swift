import Foundation

/// The single persistence boundary. Every mutation saves before returning success and maps
/// storage failures to `PlannerError.persistence(operation:)`.
@MainActor
protocol PlannerRepository {
    func fetchTasks(in week: WeekInterval) throws -> [TaskSnapshot]
    func addTask(text: String, on day: LocalDay, createdAt: Date) throws -> TaskSnapshot
    func updateTask(id: UUID, text: String) throws -> TaskSnapshot
    func toggleCompletion(id: UUID) throws -> TaskSnapshot
    func deleteTask(id: UUID) throws
    func deleteTasks(before cutoff: LocalDay) throws -> Int
}
