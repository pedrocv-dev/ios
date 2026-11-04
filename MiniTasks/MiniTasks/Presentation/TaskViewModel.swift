import Foundation
import SwiftUI

@MainActor
final class TaskViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published var newTaskTitle = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let useCases: TaskUseCases

    init(useCases: TaskUseCases) {
        self.useCases = useCases
    }

    var completedCount: Int {
        tasks.filter(\.isCompleted).count
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            tasks = try await useCases.load()
        } catch {
            errorMessage = "No se pudieron cargar las tareas: \(error.localizedDescription)"
        }
    }

    func addTask() async {
        do {
            tasks = try await useCases.add(title: newTaskTitle, to: tasks)
            newTaskTitle = ""
        } catch {
            errorMessage = "No se pudo guardar la tarea: \(error.localizedDescription)"
        }
    }

    func toggle(_ task: TaskItem) async {
        do {
            tasks = try await useCases.setCompleted(
                !task.isCompleted,
                for: task.id,
                in: tasks
            )
        } catch {
            errorMessage = "No se pudo actualizar la tarea: \(error.localizedDescription)"
        }
    }

    func delete(at offsets: IndexSet) async {
        for index in offsets {
            let id = tasks[index].id
            do {
                tasks = try await useCases.delete(id: id, from: tasks)
            } catch {
                errorMessage = "No se pudo eliminar la tarea: \(error.localizedDescription)"
            }
        }
    }
}
