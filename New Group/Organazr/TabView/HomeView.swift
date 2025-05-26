import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TaskItem> { !$0.isCompleted })
    private var tasks: [TaskItem]

    @State private var isAdding = false
    @State private var recentlyCompleted: TaskItem?
    @State private var showUndo = false
    @State private var selectedTask: TaskItem? = nil
    @State private var isPinnedExpanded = true

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomLeading) {
                Color(.systemGray6).ignoresSafeArea()

                if tasks.isEmpty {
                    VStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Image("Рисунок")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 200)
                            Text("Нет задач")
                                .font(.title2)
                            Text("Нажмите кнопку + для добавления")
                                .foregroundColor(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        Spacer()
                    }
                } else {
                    List {
                        // MARK: — Секция «Закреплено» с кастомным header —
                        let pinned = tasks.filter(\.isPinned)
                        if !pinned.isEmpty {
                            Section {
                                if isPinnedExpanded { // Показываем задачи, только если секция развернута
                                    ForEach(pinned) { task in
                                        row(for: task)
                                    }
                                    .onDelete { idxs in
                                        delete(at: idxs, in: pinned)
                                    }
                                }
                            } header: {
                                Button(action: {
                                    withAnimation {
                                        isPinnedExpanded.toggle() // Переключаем состояние
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "pin.fill")
                                            .foregroundColor(.orange)
                                        Text("Закреплено")
                                            .font(.headline)
                                        Spacer()
                                        Image(systemName: isPinnedExpanded ? "chevron.down" : "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain) // Убираем стандартный стиль кнопки
                            }
                        }

                        // MARK: — Секция «Задачи» —
                        let normal = tasks.filter { !$0.isPinned }
                        if !normal.isEmpty {
                            Section("Задачи") {
                                ForEach(normal) { task in
                                    row(for: task)
                                }
                                .onDelete { idxs in
                                    delete(at: idxs, in: normal)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

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
                TaskDetailSheet(task: task) {
                    selectedTask = nil
                }
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

    @ViewBuilder
    private func row(for task: TaskItem) -> some View {
        HStack {
            // чекбокс
            Button {
                complete(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(task.isCompleted ? .green : .primary)
            }
            .buttonStyle(.plain)

            // заголовок + описание
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                if !task.details.isEmpty {
                    Text(task.details)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // флаг приоритета
            if task.priority != .none {
                Image(systemName: "flag.fill")
                    .foregroundColor(flagColor(for: task.priority))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedTask = task }
        .padding(.vertical, 8)
    }

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

    private func addTask(title: String) {
        let newItem = TaskItem(title: title)
        modelContext.insert(newItem)
    }

    private func delete(at offsets: IndexSet, in bucket: [TaskItem]) {
        for idx in offsets {
            modelContext.delete(bucket[idx])
        }
    }

    private func complete(_ task: TaskItem) {
        task.isCompleted = true
        recentlyCompleted = task
        withAnimation { showUndo = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showUndo = false }
            recentlyCompleted = nil
        }
    }

    private func undoComplete() {
        guard let t = recentlyCompleted else { return }
        t.isCompleted = false
        withAnimation { showUndo = false }
        recentlyCompleted = nil
    }

    private func flagColor(for priority: Priority) -> Color {
        switch priority {
        case .high:   return .red
        case .medium: return .yellow
        case .low:    return .blue
        case .none:   return .gray
        }
    }
}
