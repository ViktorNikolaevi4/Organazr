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

    // Для подтверждения удаления задачи
    @State private var showDeleteConfirmation = false
    @State private var taskToDelete: TaskItem?

    // Фильтрация задач: только незавершенные, не помеченные как "не будет сделано", и из текущего списка или без списка
    private var tasks: [TaskItem] {
        allTasks.filter { item in
            let notDone = !item.isCompleted && !item.isNotDone
            let isNotSubtask = item.parentTask == nil // Исключаем подзадачи
            if let list = selectedList {
                return notDone && item.list?.id == list.id && isNotSubtask
            } else {
                return notDone && item.list == nil && isNotSubtask
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

                // Отображение для секции "Не будет выполнено"
                if selectedSection == .notDone {
                    let notDoneTasks = allTasks.filter { $0.isNotDone }
                    if notDoneTasks.isEmpty {
                        VStack {
                            Spacer()
                            Text("Нет забытых задач")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            Spacer()
                        }
                    } else {
                        List {
                            Section("Не будет выполнено") {
                                ForEach(notDoneTasks) { task in
                                    row(for: task)
                                }
                                .onDelete { idxs in
                                    if let index = idxs.first {
                                        taskToDelete = notDoneTasks[index]
                                        showDeleteConfirmation = true
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                } else if tasks.isEmpty {
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
                                        if let index = idxs.first {
                                            taskToDelete = pinned[index]
                                            showDeleteConfirmation = true
                                        }
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
                                    if let index = idxs.first {
                                        taskToDelete = normal[index]
                                        showDeleteConfirmation = true
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                // Условное отображение кнопки "Плюс" — скрываем в секции "Не будет выполнено"
                if selectedSection != .notDone {
                    plusButton()
                }

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
                AddTaskSheet { title, priority in
                    let newItem = TaskItem(title: title, list: selectedList, priority: priority)
                    modelContext.insert(newItem)
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
            // Диалог подтверждения удаления задачи
            .confirmationDialog(
                "Удалить задачу?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    if let task = taskToDelete {
                        modelContext.delete(task)
                    }
                    taskToDelete = nil
                }
                Button("Отмена", role: .cancel) {
                    taskToDelete = nil
                }
            } message: {
                Text("Задача будет удалена без возможности восстановления.")
            }
        }
    }


    @ViewBuilder
    private func row(for task: TaskItem) -> some View {
        // Отображение родительской задачи
        HStack {
            // Проверяем, находится ли задача в секции "Не будет выполнено"
            if selectedSection == .notDone {
                Image(systemName: "square.slash")
                    .foregroundColor(.gray)
                    .padding(.trailing, 4)
            } else {
                Button {
                    complete(task)
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                        .foregroundColor(task.isCompleted ? .green : .primary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(selectedSection == .notDone ? .gray : .primary)
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
        .swipeActions(edge: .trailing) {
            Button {
                taskToDelete = task
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
        }
        .padding(.vertical, 8)

        // Отображение незавершённых подзадач
        let incompleteSubtasks = task.subtasks.filter { !$0.isCompleted }
        if !incompleteSubtasks.isEmpty {
            ForEach(incompleteSubtasks) { subtask in
                HStack {
                    Spacer().frame(width: 40) // Отступ для подзадачи
                    Button {
                        complete(subtask)
                    } label: {
                        Image(systemName: subtask.isCompleted ? "checkmark.square.fill" : "square")
                            .foregroundColor(subtask.isCompleted ? .green : .primary)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(subtask.title)
                            .font(.subheadline)
                            .foregroundColor(selectedSection == .notDone ? .gray : .primary)
                        if !subtask.details.isEmpty {
                            Text(subtask.details.prefix(30))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    Spacer()

                    if subtask.priority != .none {
                        Image(systemName: "flag.fill")
                            .foregroundColor(flagColor(for: subtask.priority))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedTask = subtask }
                .swipeActions(edge: .trailing) {
                    Button {
                        taskToDelete = subtask
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.red)
                }
                .padding(.vertical, 4)
            }
        }
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
                .font(.system(size: 64))
                .foregroundStyle(.white, .orange)
                .shadow(radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func addTask(title: String, priority: Priority) {
        let newItem = TaskItem(title: title, list: selectedList, priority: priority)
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
