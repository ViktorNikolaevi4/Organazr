import Foundation
import SwiftData

enum Priority: String, CaseIterable, Sendable, Codable {
    case high, medium, low, none
}

@Model
final class TaskItem: Identifiable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var details: String = ""
    var priority: Priority    // без значения по-умолчанию здесь
    var isPinned: Bool = false
    var imageData: Data? = nil

    init(
        title: String,
        details: String = "",
        isCompleted: Bool = false,
        priority: Priority = .none,
        isPinned: Bool = false,
        imageData: Data? = nil
    ) {
        self.title       = title
        self.details     = details
        self.isCompleted = isCompleted
        self.priority    = priority
        self.isPinned    = isPinned
        self.imageData   = imageData
    }
}


