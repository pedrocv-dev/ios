import SwiftUI

@main
struct MiniTasksApp: App {
    @StateObject private var viewModel: TaskViewModel

    init() {
        let repository = LocalTaskRepository()
        let useCase = TaskUseCases(repository: repository)
        _viewModel = StateObject(wrappedValue: TaskViewModel(useCases: useCase))
    }

    var body: some Scene {
        WindowGroup {
            TaskListView(viewModel: viewModel)
        }
    }
}
