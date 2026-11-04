import Foundation

struct TaskUseCases: Sendable {
    private let repository: any TaskRepository

    init(repository: any TaskRepository) {
        self.repository = repository
    }

    func load() async throws -> [TaskItem] {
        try await repository.fetchTasks()
    }

    func add(title: String, to current: [TaskItem]) async throws -> [TaskItem] {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return current }

        var updated = current
        updated.insert(TaskItem(title: cleanTitle), at: 0)
        try await repository.saveTasks(updated)
        return updated
    }

    func setCompleted(_ isCompleted: Bool, for id: UUID, in current: [TaskItem]) async throws -> [TaskItem] {
        var updated = current
        guard let index = updated.firstIndex(where: { $0.id == id }) else {
            return current
        }
        updated[index].isCompleted = isCompleted
        try await repository.saveTasks(updated)
        return updated
    }

    func delete(id: UUID, from current: [TaskItem]) async throws -> [TaskItem] {
        let updated = current.filter { $0.id != id }
        try await repository.saveTasks(updated)
        return updated
    }
}
