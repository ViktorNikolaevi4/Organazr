import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext

    let task: TaskItem
    let level: Int
    let completeAction: (TaskItem) -> Void
    let onTap: (TaskItem) -> Void
    @Binding var isExpanded: Bool   // Состояние сворачивания/разворачивания

    /// Отступ слева: 20 pt × уровень вложенности
    private var indentWidth: CGFloat {
        CGFloat(level) * 20
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Отступ для уровня вложенности
                Spacer().frame(width: indentWidth)

                // Чекбокс
                Button { completeAction(task) }
                label: {
                    Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                        .foregroundColor(task.isCompleted ? .green : .primary)
                }
                .buttonStyle(.plain)

                // Заголовок и детали
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.body)
                        .foregroundColor(task.isCompleted ? .gray : .primary)
                    if !task.details.isEmpty {
                        Text(task.details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Если есть подзадачи — показываем счётчик и кнопку-стрелку
                if !task.subtasks.isEmpty {
                    Text("\(task.subtasks.filter { !$0.isCompleted && !$0.isNotDone }.count)")
                        .foregroundColor(.secondary)

                    Button {
                        withAnimation { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Флажок приоритета
                if task.priority != .none {
                    Image(systemName: "flag.fill")
                        .foregroundColor(flagColor(for: task.priority))
                }
            }
            .contentShape(Rectangle())
            // Теперь по тапу на строку (в любом месте, кроме стрелки)
            // всегда вызываем onTap и открываем TaskDetailSheet
            .onTapGesture {
                onTap(task)
            }
            // Свайп-действие для удаления
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    modelContext.delete(task)
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
            .padding(.vertical, 8)
        }
    }

    // Вспомогательный метод для цвета флага
    private func flagColor(for priority: Priority) -> Color {
        switch priority {
        case .high:   return .red
        case .medium: return .yellow
        case .low:    return .blue
        case .none:   return .gray
        }
    }
}


struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    /// Берём ВСЕ задачи, но потом будем их фильтровать
    @Query(sort: [SortDescriptor<TaskItem>(\.title, order: .forward)])
    private var allTasks: [TaskItem]

    // MARK: — Состояния
    @State private var selectedList: TaskList? = nil
    @State private var isAdding = false
    @State private var recentlyCompleted: TaskItem?
    @State private var showUndo = false
    @State private var selectedTask: TaskItem? = nil
    @State private var isPinnedExpanded = true
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var showMenu = false
    @State private var selectedSection: MenuSection = .tasks
    @State private var showDeleteConfirmation = false
    @State private var taskToDelete: TaskItem?
    @State private var expandedStates: [UUID: Bool] = [:]
    private let maxDepthAllowed = 5

    // MARK: — Фильтрация «корневых» домашних задач (dueDate == nil)
    private var homeTasks: [TaskItem] {
        allTasks.filter { item in
            // показываем только задачи БЕЗ даты для домашнего экрана
            let notDone = !item.isCompleted && !item.isNotDone
            let noDate = (item.dueDate == nil)
            if let list = selectedList {
                return notDone && noDate && item.list?.id == list.id && item.parentTask == nil
            } else {
                return notDone && noDate && item.list == nil && item.parentTask == nil
            }
        }
    }

    // MARK: — Плоская иерархия для «закреплённых» домашних задач
    private var pinnedDisplayRows: [(TaskItem, Int)] {
        var result: [(TaskItem, Int)] = []
        for root in homeTasks.filter(\.isPinned) {
            traverse(task: root, level: 0, into: &result)
        }
        return result
    }

    // MARK: — Плоская иерархия для «остальных» домашних задач
    private var normalDisplayRows: [(TaskItem, Int)] {
        var result: [(TaskItem, Int)] = []
        for root in homeTasks.filter({ !$0.isPinned }) {
            traverse(task: root, level: 0, into: &result)
        }
        return result
    }

    /// Рекурсивная генерация (как вы уже делали) для вложенных задач
    private func traverse(task: TaskItem, level: Int, into array: inout [(TaskItem, Int)]) {
        array.append((task, level))
        guard level < maxDepthAllowed else { return }
        let isExpanded = expandedStates[task.id] ?? false
        if !isExpanded { return }
        let children = task.subtasks.filter { !$0.isCompleted && !$0.isNotDone }
        for child in children {
            // у домашних задач у дочерних dueDate тоже будет nil или совпадёт
            traverse(task: child, level: level + 1, into: &array)
        }
    }

    // MARK: — Навигационный заголовок
    private var navigationTitle: String {
        if let list = selectedList {
            return list.title
        } else {
            switch selectedSection {
            case .all:       return "Все"
            case .today:     return "Сегодня"
            case .tomorrow:  return "Завтра"
            case .tasks:     return "Задачи"
            case .done:      return "Выполнено"
            case .notDone:   return "Не будет выполнено"
            case .trash:     return "Корзина"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomLeading) {
                Color(.systemGray6).ignoresSafeArea()

                // ===================================================
                // 1) «Не будет выполнено»
                // ===================================================
                if selectedSection == .notDone {
                    let notDoneTasks = allTasks.filter { $0.isNotDone }
                    if notDoneTasks.isEmpty {
                        Spacer()
                        Text("Нет забытых задач")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Spacer()
                    } else {
                        List {
                            Section("Не будет выполнено") {
                                ForEach(notDoneTasks) { task in
                                    TaskRowView(
                                        task: task,
                                        level: 0,
                                        completeAction: { _ in /* пометить нельзя */ },
                                        onTap: { tapped in selectedTask = tapped },
                                        isExpanded: .constant(false)
                                    )
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
                }
                // ===================================================
                // 2) Если нет ни одной «домашней» корневой задачи
                // ===================================================
                else if homeTasks.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image("Рисунок")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200)
                        Text("Нет задач")
                            .font(.title2)
                        Text("Нажмите «+» для добавления")
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    Spacer()
                }
                // ===================================================
                // 3) Основной список: закреплённые домашние + остальные
                // ===================================================
                else {
                    List {
                        // 3.1) «Закреплённые» домашние
                        if !pinnedDisplayRows.isEmpty {
                            Section {
                                Button {
                                    withAnimation { isPinnedExpanded.toggle() }
                                } label: {
                                    HStack {
                                        Image(systemName: "pin.fill").foregroundColor(.orange)
                                        Text("Закреплённые")
                                            .font(.headline)
                                        Spacer()
                                        Text("\(homeTasks.filter(\.isPinned).count)")
                                            .foregroundColor(.secondary)
                                        Image(systemName: isPinnedExpanded ? "chevron.down" : "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)

                                if isPinnedExpanded {
                                    ForEach(pinnedDisplayRows, id: \.0.id) { pair in
                                        let task = pair.0
                                        let lvl = pair.1
                                        TaskRowView(
                                            task: task,
                                            level: lvl,
                                            completeAction: { tapped in complete(tapped) },
                                            onTap: { tapped in selectedTask = tapped },
                                            isExpanded: Binding(
                                                get: { expandedStates[task.id] ?? false },
                                                set: { expandedStates[task.id] = $0 }
                                            )
                                        )
                                    }
                                }
                            }
                        }

                        // 3.2) Остальные домашние задачи
                        if !normalDisplayRows.isEmpty {
                            Section("Задачи") {
                                ForEach(normalDisplayRows, id: \.0.id) { pair in
                                    let task = pair.0
                                    let lvl = pair.1
                                    TaskRowView(
                                        task: task,
                                        level: lvl,
                                        completeAction: { tapped in complete(tapped) },
                                        onTap: { tapped in selectedTask = tapped },
                                        isExpanded: Binding(
                                            get: { expandedStates[task.id] ?? false },
                                            set: { expandedStates[task.id] = $0 }
                                        )
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                // ===================================================
                // 4) Плюс «+» → открываем AddTaskSheet (только для домашней задачи)
                // ===================================================
                if selectedSection != .notDone {
                    plusButton()
                }

                // ===================================================
                // 5) Кнопка «Undo»
                // ===================================================
                if showUndo {
                    Button {
                        undoComplete()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                    }
                    .background(Circle().fill(Color.yellow))
                    .shadow(radius: 4, y: 2)
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
                    Button { showMenu = true }
                    label: { Image(systemName: "line.3.horizontal") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { } label: { Image(systemName: "ellipsis") }
                }
            }

            // ------------------------------------------
            // Лист редактирования существующей домашней задачи
            // ------------------------------------------
            .sheet(item: $selectedTask) { task in
                TaskDetailSheet(task: task) {
                    selectedTask = nil
                    sheetDetent = .medium
                }
                .presentationDetents([.medium, .large], selection: $sheetDetent)
                .presentationDragIndicator(.visible)
            }

            // ------------------------------------------
            // Лист создания новой домашней задачи
            // (AddTaskSheet — с TextField, как в HomeView)
            // ------------------------------------------
            .sheet(isPresented: $isAdding) {
                AddTaskSheet { title, priority in
                    let newItem = TaskItem(
                        title: title,
                        list: selectedList,
                        priority: priority
                        // dueDate оставляем nil → эта задача останется в HomeView
                    )
                    modelContext.insert(newItem)
                    do {
                        try modelContext.save()
                    } catch {
                        print("Ошибка сохранения новой задачи: \(error)")
                    }
                    isAdding = false
                }
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }

            // ------------------------------------------
            // Лист гамбургера, подтверждение удаления и т. д.
            // ------------------------------------------
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
            .confirmationDialog("Удалить задачу?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
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

    // Кнопка «+» для домашнего экрана
    @ViewBuilder
    private func plusButton() -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 64))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .blue)
                        .shadow(radius: 4, y: 2)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 40)
            }
        }
    }

    // Логика «пометить выполненным»
    private func complete(_ task: TaskItem) {
        task.isCompleted = true
        do {
            try modelContext.save()
        } catch {
            print("Ошибка при сохранении: \(error)")
        }
        recentlyCompleted = task
        withAnimation { showUndo = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showUndo = false }
            recentlyCompleted = nil
        }
    }

    // Логика «отменить выполненное»
    private func undoComplete() {
        guard let t = recentlyCompleted else { return }
        t.isCompleted = false
        do {
            try modelContext.save()
        } catch {
            print("Ошибка при сохранении: \(error)")
        }
        withAnimation { showUndo = false }
        recentlyCompleted = nil
    }
}
