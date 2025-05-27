
import SwiftUI
import SwiftData

@main
struct OrganazrApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [TaskItem.self, TaskList.self]) }
}
