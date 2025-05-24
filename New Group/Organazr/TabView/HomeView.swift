import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    // Теперь запрашиваем только задачи где isCompleted == false
    @Query(filter: #Predicate<TaskItem> { !$0.isCompleted })
    private var tasks: [TaskItem]

    @State private var isAdding = false
    @State private var recentlyCompleted: TaskItem?
    @State private var showUndo = false
    @State private var selectedTask: TaskItem? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomLeading) {
                Color(.systemGray6).ignoresSafeArea()

                List {
                    ForEach(tasks) { task in
                        HStack {
                            Button {
                                complete(task)
                            } label: {
                                Image(systemName: "square")
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)

                            Text(task.title)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTask = task
                        }
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)

                plusButton()

                if showUndo {
                    undoButton()
                        .padding(.leading, 24)
                        .padding(.bottom, 80)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .animation(.easeOut, value: showUndo)
                }
            }
            .navigationTitle("Задачи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {} label: { Image(systemName: "line.3.horizontal") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {} label: { Image(systemName: "ellipsis") }
                }
            }
            .sheet(item: $selectedTask) { task in
              TaskDetailSheet(
                task: task,
                onDismiss: { selectedTask = nil }
              )
              .presentationDetents([.medium])
              .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isAdding) {
                AddTaskSheet { newTitle in
                    addTask(title: newTitle)
                    isAdding = false
                }
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
    }

    // MARK: –– UI Helpers

    private func plusButton() -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button { isAdding = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 64))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .specialBlue)
                        .shadow(radius: 4, y: 2)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func undoButton() -> some View {
        Button { undoComplete() } label: {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white, .orange)
                .shadow(radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: –– Data operations

    private func addTask(title: String) {
        let newItem = TaskItem(title: title)
        modelContext.insert(newItem)
    }

    private func delete(at offsets: IndexSet) {
        for idx in offsets {
            modelContext.delete(tasks[idx])
        }
    }

    private func complete(_ task: TaskItem) {
        // помечаем задачу завершённой,
        // и поскольку @Query фильтрует только !isCompleted — она сразу исчезнет из списка
        task.isCompleted = true
        recentlyCompleted = task

        withAnimation { showUndo = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showUndo = false }
            recentlyCompleted = nil
        }
    }

    private func undoComplete() {
        guard let task = recentlyCompleted else { return }
        task.isCompleted = false
        withAnimation { showUndo = false }
        recentlyCompleted = nil
    }
}

