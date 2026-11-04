import Foundation

/// Actor aislado: serializa las lecturas y escrituras del archivo JSON.
actor LocalTaskRepository: TaskRepository {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let documents = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]
            self.fileURL = documents.appendingPathComponent("tasks.json")
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func fetchTasks() async throws -> [TaskItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([TaskItem].self, from: data)
    }

    func saveTasks(_ tasks: [TaskItem]) async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(tasks)
        try data.write(to: fileURL, options: .atomic)
    }
}
