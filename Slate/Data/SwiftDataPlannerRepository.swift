import Foundation
import SwiftData

@MainActor
final class SwiftDataPlannerRepository: PlannerRepository {
    /// The context only references its container unowned, so the repository keeps the container alive
    /// for as long as it can issue fetches.
    private let container: ModelContainer
    private let context: ModelContext
    private let save: @MainActor () throws -> Void

    init(container: ModelContainer, save: (@MainActor () throws -> Void)? = nil) {
        self.container = container
        let context = container.mainContext
        self.context = context
        self.save = save ?? { try context.save() }
    }

    // MARK: PlannerRepository

    func fetchTasks(in week: WeekInterval) throws -> [TaskSnapshot] {
        let lower = week.start.storageDate
        let upper = Calendar.utcGregorian.date(byAdding: .day, value: 1, to: week.end.storageDate)!
        let descriptor = FetchDescriptor<PlannerTask>(predicate: #Predicate { $0.day >= lower && $0.day < upper })
        do {
            return try context.fetch(descriptor).map(snapshot).sorted(by: Self.isOrderedBefore)
        } catch {
            throw PlannerError.persistence(operation: .fetch)
        }
    }

    func addTask(text: String, on day: LocalDay, createdAt: Date) throws -> TaskSnapshot {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw PlannerError.persistence(operation: .add) }
        let model = PlannerTask(text: value, day: day.storageDate, createdAt: createdAt)
        do {
            context.insert(model)
            try save()
            return snapshot(model)
        } catch {
            context.rollback()
            throw PlannerError.persistence(operation: .add)
        }
    }

    func updateTask(id: UUID, text: String) throws -> TaskSnapshot {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw PlannerError.persistence(operation: .update) }
        let model = try task(id: id, operation: .update)
        do {
            model.text = value
            try save()
            return snapshot(model)
        } catch {
            context.rollback()
            throw PlannerError.persistence(operation: .update)
        }
    }

    func toggleCompletion(id: UUID) throws -> TaskSnapshot {
        let model = try task(id: id, operation: .toggle)
        do {
            model.isCompleted.toggle()
            try save()
            return snapshot(model)
        } catch {
            context.rollback()
            throw PlannerError.persistence(operation: .toggle)
        }
    }

    func deleteTask(id: UUID) throws {
        let model = try task(id: id, operation: .delete)
        do {
            context.delete(model)
            try save()
        } catch {
            context.rollback()
            throw PlannerError.persistence(operation: .delete)
        }
    }

    func deleteTasks(before cutoff: LocalDay) throws -> Int {
        let bound = cutoff.storageDate
        let descriptor = FetchDescriptor<PlannerTask>(predicate: #Predicate { $0.day < bound })
        do {
            let expired = try context.fetch(descriptor)
            guard !expired.isEmpty else { return 0 }
            for model in expired { context.delete(model) }
            try save()
            return expired.count
        } catch {
            context.rollback()
            throw PlannerError.persistence(operation: .retention)
        }
    }

    // MARK: Private

    private func task(id: UUID, operation: PersistenceOperation) throws -> PlannerTask {
        var descriptor = FetchDescriptor<PlannerTask>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        let model: PlannerTask?
        do {
            model = try context.fetch(descriptor).first
        } catch {
            throw PlannerError.persistence(operation: operation)
        }
        guard let model else { throw PlannerError.persistence(operation: operation) }
        return model
    }

    private func snapshot(_ model: PlannerTask) -> TaskSnapshot {
        TaskSnapshot(
            id: model.id,
            text: model.text,
            day: LocalDay(storageDate: model.day),
            isCompleted: model.isCompleted,
            createdAt: model.createdAt
        )
    }

    /// Day ascending, then creation time, then identifier as a deterministic tie-breaker.
    private static func isOrderedBefore(_ lhs: TaskSnapshot, _ rhs: TaskSnapshot) -> Bool {
        (lhs.day, lhs.createdAt, lhs.id.uuidString) < (rhs.day, rhs.createdAt, rhs.id.uuidString)
    }
}
