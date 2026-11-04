import SwiftUI

struct TaskListView: View {
    @ObservedObject var viewModel: TaskViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Cargando tareas…")
                } else if viewModel.tasks.isEmpty {
                    ContentUnavailableView(
                        "Todavía no hay tareas",
                        systemImage: "checklist",
                        description: Text("Añade una tarea para empezar.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(viewModel.tasks) { task in
                                TaskRow(task: task) {
                                    Task { await viewModel.toggle(task) }
                                }
                            }
                            .onDelete { offsets in
                                Task { await viewModel.delete(at: offsets) }
                            }
                        } header: {
                            Text("\(viewModel.completedCount) de \(viewModel.tasks.count) completadas")
                        }
                    }
                }
            }
            .navigationTitle("Mis tareas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .safeAreaInset(edge: .bottom) {
                addTaskBar
            }
            .task {
                await viewModel.load()
            }
            .alert(
                "Ha ocurrido un error",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("Aceptar", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var addTaskBar: some View {
        HStack(spacing: 12) {
            TextField("Nueva tarea…", text: $viewModel.newTaskTitle)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit { Task { await viewModel.addTask() } }

            Button {
                Task { await viewModel.addTask() }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
            }
            .disabled(viewModel.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Añadir tarea")
        }
        .padding()
        .background(.bar)
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Marcar como pendiente" : "Marcar como completada")

            Text(task.title)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
