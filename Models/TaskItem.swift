import Foundation
import SwiftData

enum Priority: String, CaseIterable, Sendable, Codable {
    case high, medium, low, none
}


@Model
final class TaskList: Identifiable {
    var id: UUID = UUID()
    var title: String
    var tasks: [TaskItem] = []

    init(title: String) {
        self.title = title
    }
}

@Model
final class TaskItem: Identifiable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var details: String = ""
    var priority: Priority
    var isPinned: Bool = false
    var imageData: Data? = nil
    var list: TaskList?
    var isNotDone: Bool = false
    var parentTask: TaskItem? = nil
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.parentTask)
    var subtasks: [TaskItem] = []
    var isMatrixTask: Bool

    var dueDate: Date? // Добавляем поле для даты
    var refreshID: UUID = UUID()

    init(
        title: String,
        list: TaskList? = nil,
        details: String = "",
        isCompleted: Bool = false,
        priority: Priority = .none,
        isPinned: Bool = false,
        imageData: Data? = nil,
        isNotDone: Bool = false,
        parentTask: TaskItem? = nil,
        dueDate: Date? = nil, // Добавляем параметр для даты
        isMatrixTask: Bool = false
    ) {
        self.title = title
        self.list = list
        self.details = details
        self.isCompleted = isCompleted
        self.priority = priority
        self.isPinned = isPinned
        self.imageData = imageData
        self.isNotDone = isNotDone
        self.parentTask = parentTask
        self.dueDate = dueDate
        self.isMatrixTask = isMatrixTask
    }

    // Функция для вычисления глубины задачи (уровня вложенности)
    func depth() -> Int {
        var currentDepth = 0
        var currentTask = self
        while let parent = currentTask.parentTask {
            currentDepth += 1
            currentTask = parent
        }
        return currentDepth
    }
}
// priority: Priority = .none,
//self.priority    = priority
