import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor<TaskItem>(\.title, order: .forward)])
    private var allTasks: [TaskItem]

    @State private var selectedList: TaskList? = nil
    @State private var isAdding = false
    @State private var recentlyCompleted: TaskItem?
    @State private var showUndo = false
    @State private var selectedTask: TaskItem? = nil
    @State private var isPinnedExpanded = true
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var showMenu = false
    @State private var selectedSection: MenuSection = .tasks

    // Фильтрация задач: только незавершенные и только из текущего списка или без списка
    private var tasks: [TaskItem] {
        allTasks.filter { item in
            let notDone = !item.isCompleted
            if let list = selectedList {
                return notDone && item.list?.id == list.id
            } else {
                return notDone && item.list == nil // Показываем только задачи без списка, если список не выбран
            }
        }
    }

    // Динамический заголовок в зависимости от выбранного списка или секции
    private var navigationTitle: String {
        if let list = selectedList {
            return list.title
        } else {
            switch selectedSection {
            case .all:
                return "Все"
            case .tomorrow:
                return "Завтра"
            case .tasks:
                return "Задачи"
            case .done:
                return "Выполнено"
            case .notDone:
                return "Не будет выполнено"
            case .trash:
                return "Корзина"
            }
        }
    }

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
                        let pinned = tasks.filter(\.isPinned)
                        if !pinned.isEmpty {
                            Section {
                                if isPinnedExpanded {
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
                                        isPinnedExpanded.toggle()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "pin.fill")
                                            .foregroundColor(.orange)
                                        Text("Закреплено")
                                            .font(.headline)
                                        Spacer()
                                        HStack(spacing: 4) {
                                            Text("\(pinned.count)")
                                                .foregroundColor(.secondary)
                                            Image(systemName: isPinnedExpanded ? "chevron.down" : "chevron.right")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }

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
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showMenu = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {} label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailSheet(task: task) {
                    selectedTask = nil
                    sheetDetent = .medium
                }
                .presentationDetents([.medium, .large], selection: $sheetDetent)
                .presentationDragIndicator(.visible)
                .onChange(of: task.imageData) { newData in
                    if newData != nil {
                        sheetDetent = .large
                    }
                }
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
            .sheet(isPresented: $showMenu) {
                MenuModalView { selection in
                    switch selection {
                    case .system(let sec):
                        selectedList = nil
                        selectedSection = sec
                    case .custom(let list):
                        selectedList = list
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for task: TaskItem) -> some View {
        HStack {
            Button {
                complete(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(task.isCompleted ? .green : .primary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                if !task.details.isEmpty {
                    Text(task.details)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if task.imageData != nil {
                    HStack(spacing: 2) {
                        Image(systemName: "paperclip")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

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
        let newItem = TaskItem(title: title, list: selectedList)
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
        case .high: return .red
        case .medium: return .yellow
        case .low: return .blue
        case .none: return .gray
        }
    }
}
