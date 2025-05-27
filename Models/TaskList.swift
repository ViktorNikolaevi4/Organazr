import Foundation
import SwiftData

@Model
final class TaskList: Identifiable {
    var id: UUID = UUID()
    var title: String

    init(title: String) {
        self.title = title
    }
}
