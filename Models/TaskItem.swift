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

    init(
        title: String,
        list: TaskList? = nil,
        details: String = "",
        isCompleted: Bool = false,
        priority: Priority = .none,
        isPinned: Bool = false,
        imageData: Data? = nil,
        isNotDone: Bool = false
    ) {
        self.title = title
        self.list = list
        self.details = details
        self.isCompleted = isCompleted
        self.priority = priority
        self.isPinned = isPinned
        self.imageData = imageData
        self.isNotDone = isNotDone
    }
}
// priority: Priority = .none,
//self.priority    = priority
