
import Foundation
import SwiftData

@Model
final class TaskItem: Identifiable {
    var id = UUID()
    var title: String

    init(title: String) {
        self.title = title
    }
}
