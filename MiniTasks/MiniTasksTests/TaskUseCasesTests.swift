import XCTest
@testable import MiniTasks

final class TaskUseCasesTests: XCTestCase {
    func testAddTrimsTitleAndAddsTaskAtBeginning() async throws {
        let repository = InMemoryTaskRepository()
        let useCases = TaskUseCases(repository: repository)

        let result = try await useCases.add(title: "  Practicar Swift  ", to: [])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Practicar Swift")
    }

    func testAddIgnoresEmptyTitle() async throws {
        let repository = InMemoryTaskRepository()
        let useCases = TaskUseCases(repository: repository)

        let result = try await useCases.add(title: "   ", to: [])

        XCTAssertTrue(result.isEmpty)
    }

    func testToggleCompletion() async throws {
        let task = TaskItem(title: "Escribir tests")
        let repository = InMemoryTaskRepository()
        let useCases = TaskUseCases(repository: repository)

        let result = try await useCases.setCompleted(true, for: task.id, in: [task])

        XCTAssertEqual(result.first?.isCompleted, true)
    }

    func testDeleteTask() async throws {
        let task = TaskItem(title: "Eliminarme")
        let repository = InMemoryTaskRepository()
        let useCases = TaskUseCases(repository: repository)

        let result = try await useCases.delete(id: task.id, from: [task])

        XCTAssertTrue(result.isEmpty)
    }
}

private actor InMemoryTaskRepository: TaskRepository {
    private var stored: [TaskItem] = []

    func fetchTasks() async throws -> [TaskItem] { stored }

    func saveTasks(_ tasks: [TaskItem]) async throws {
        stored = tasks
    }
}
