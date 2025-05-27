//import Foundation
//import SwiftData
//
//@Model
//final class TaskList: Identifiable {
//    // fully-qualified default value
//    var id: UUID = UUID()
//
//    // обязательно инициализируется в init(...)
//    var title: String
//
//    // one-to-many
//    @Relationship(inverse: \TaskItem.list)
//    var tasks: [TaskItem] = []
//
//    init(title: String) {
//        self.title = title
//    }
//}
