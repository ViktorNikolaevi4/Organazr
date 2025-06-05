import SwiftUI
import SwiftData

/// Одна строка списка (задача или подзадача).
/// Выводим её с учётом уровня вложенности (level).
/// При нажатии на квадратик вызываем переданный замыканием completeAction.
import SwiftUI
import SwiftData

/// Одна строка списка (задача или подзадача).
/// Выводим её с учётом уровня вложенности (level).
/// При нажатии на квадратик вызываем переданный замыканием completeAction.
struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext
    let task: TaskItem
    let level: Int
    let completeAction: (TaskItem) -> Void
    let onTap: (TaskItem) -> Void
    @Binding var isExpanded: Bool // Состояние сворачивания/разворачивания

    /// Отступ слева: 20 pt × level
    private var indentWidth: CGFloat {
        CGFloat(level) * 20
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Отступ для визуализации вложенности
                Spacer()
                    .frame(width: indentWidth)

                // Кнопка-чёкбокс
                Button {
                    completeAction(task)
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                        .foregroundColor(task.isCompleted ? .green : .primary)
                }
                .buttonStyle(.plain)

                // Текстовый блок: название и детали
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(task.title)
                            .font(.body)
                            .foregroundColor(task.isCompleted ? .gray : .primary)

                        // Показываем количество подзадач и кнопку сворачивания/разворачивания
                        if !task.subtasks.isEmpty {
                            Spacer()
                            Text("\(task.subtasks.filter { !$0.isCompleted && !$0.isNotDone }.count)")
                                .foregroundColor(.secondary)
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }

                    if !task.details.isEmpty {
                        Text(task.details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer()

                // Флажок приоритета (если приоритет не .none)
                if task.priority != .none {
                    Image(systemName: "flag.fill")
                        .foregroundColor(flagColor(for: task.priority))
                }
            }
            .contentShape(Rectangle())
            // При тапе на строку открываем детали, если нет подзадач, или сворачиваем/разворачиваем подзадачи
            .onTapGesture {
                if task.subtasks.isEmpty {
                    onTap(task)
                } else {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
            }
            // Свайп для удаления
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

    private func flagColor(for priority: Priority) -> Color {
        switch priority {
        case .high:   return .red
        case .medium: return .yellow
        case .low:    return .blue
        case .none:   return .gray
        }
    }
}

/// После пометки задачи «выполнено» появляется жёлтая кнопка «Undo» слева внизу.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    /// Все задачи из БД, отсортированные по title
    @Query(sort: [SortDescriptor<TaskItem>(\.title, order: .forward)])
    private var allTasks: [TaskItem]

    // MARK: — Состояние

    /// Если выбран какой-то TaskList, показываем задачи только из него. Иначе задачи без списка.
    @State private var selectedList: TaskList? = nil

    /// Показывает ли форму добавления новой задачи
    @State private var isAdding = false

    /// Последняя «выполненная» задача (для Undo)
    @State private var recentlyCompleted: TaskItem?

    /// Управляет показом жёлтой кнопки «Undo»
    @State private var showUndo = false

    /// Текущая открытая задача (для открытия TaskDetailSheet)
    @State private var selectedTask: TaskItem? = nil

    /// Показывает/скрывает закреплённую секцию
    @State private var isPinnedExpanded = true

    /// Для управления высотой детального листа
    @State private var sheetDetent: PresentationDetent = .medium

    /// Открытие меню (гамбургер)
    @State private var showMenu = false

    /// Выбранная секция в меню (All, Tomorrow, Tasks, Done, NotDone, Trash)
    @State private var selectedSection: MenuSection = .tasks

    /// Флаг, показывать ли диалог подтверждения удаления
    @State private var showDeleteConfirmation = false

    /// Задача, которую собираемся удалить (для ConfirmationDialog)
    @State private var taskToDelete: TaskItem?

    /// Состояние сворачивания/разворачивания для каждой задачи
    @State private var expandedStates: [UUID: Bool] = [:]

    /// Кодовый предел вложенности: 0…5 включительно (то есть 6 пользовательских уровней).
    private let maxDepthAllowed = 5

    // MARK: — Фильтрация «корневых» задач

    /// Корневые (parentTask == nil), не выполненные и не помеченные «не будет выполнено»,
    /// и с учётом выбранного списка (selectedList).
    private var tasks: [TaskItem] {
        allTasks.filter { item in
            let notDone = !item.isCompleted && !item.isNotDone
            if let list = selectedList {
                return notDone && item.list?.id == list.id && item.parentTask == nil
            } else {
                return notDone && item.list == nil && item.parentTask == nil
            }
        }
    }

    // MARK: — Плоские массивы для отображения вложенности

    /// «Плоский» массив (задача, уровень, состояние сворачивания) для закреплённых задач.
    private var pinnedDisplayRows: [(TaskItem, Int)] {
        var result: [(TaskItem, Int)] = []
        for root in tasks.filter(\.isPinned) {
            traverse(task: root, level: 0, into: &result)
        }
        return result
    }

    /// «Плоский» массив для обычных (не закреплённых) задач.
    private var normalDisplayRows: [(TaskItem, Int)] {
        var result: [(TaskItem, Int)] = []
        for root in tasks.filter({ !$0.isPinned }) {
            traverse(task: root, level: 0, into: &result)
        }
        return result
    }

    /// Рекурсия: добавляем текущую задачу + её уровень,
    /// потом всех её детей, если задача развернута.
    private func traverse(task: TaskItem, level: Int, into array: inout [(TaskItem, Int)]) {
        array.append((task, level))

        // Если уже дошли до 5-го уровня, дальше не спускаемся
        guard level < maxDepthAllowed else {
            return
        }

        // Проверяем, развернута ли задача
        let isExpanded = expandedStates[task.id] ?? false
        if !isExpanded {
            return
        }

        // Фильтруем только живых детей (не выполненные и не «не будет выполнено»)
        let children = task.subtasks.filter { !$0.isCompleted && !$0.isNotDone }
        for child in children {
            traverse(task: child, level: level + 1, into: &array)
        }
    }

    // MARK: — Заголовок навигации

    private var navigationTitle: String {
        if let list = selectedList {
            return list.title
        } else {
            switch selectedSection {
            case .all:       return "Все"
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
                Color(.systemGray6)
                    .ignoresSafeArea()

                // ==========================================
                // 1) «Не будет выполнено»
                // ==========================================
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
                                    TaskRowView(
                                        task: task,
                                        level: 0,
                                        completeAction: { _ in /* ничем не помечаем */ },
                                        onTap: { tapped in
                                            selectedTask = tapped
                                        },
                                        isExpanded: .constant(false) // Не разворачиваем в этой секции
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
                // ==========================================
                // 2) Если нет ни одной корневой задачи
                // ==========================================
                else if tasks.isEmpty {
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
                }
                // ==========================================
                // 3) Основной List: «Закреплённые» + «Задачи»
                // ==========================================
                else {
                    List {
                        // ------------------------------------------
                        // 3.1) Секция «Закреплённые»
                        // ------------------------------------------
                        if !pinnedDisplayRows.isEmpty {
                            Section {
                                // Заголовок-кнопка «Закреплённые»
                                Button {
                                    withAnimation {
                                        isPinnedExpanded.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "pin.fill")
                                            .foregroundColor(.orange)
                                        Text("Закреплённые")
                                            .font(.headline)
                                        Spacer()
                                        Text("\(tasks.filter(\.isPinned).count)")
                                            .foregroundColor(.secondary)
                                        Image(systemName: isPinnedExpanded ? "chevron.down" : "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)

                                // Если «Закреплённые» развернуты, выводим до 6 уровней
                                if isPinnedExpanded {
                                    ForEach(pinnedDisplayRows, id: \.0.id) { pair in
                                        let task = pair.0
                                        let lvl = pair.1
                                        TaskRowView(
                                            task: task,
                                            level: lvl,
                                            completeAction: { tapped in
                                                complete(tapped)
                                            },
                                            onTap: { tapped in
                                                selectedTask = tapped
                                            },
                                            isExpanded: Binding(
                                                get: { expandedStates[task.id] ?? false },
                                                set: { expandedStates[task.id] = $0 }
                                            )
                                        )
                                    }
                                }
                            }
                        }

                        // ------------------------------------------
                        // 3.2) Секция «Задачи» (не закреплённые)
                        // ------------------------------------------
                        if !normalDisplayRows.isEmpty {
                            Section("Задачи") {
                                ForEach(normalDisplayRows, id: \.0.id) { pair in
                                    let task = pair.0
                                    let lvl = pair.1
                                    TaskRowView(
                                        task: task,
                                        level: lvl,
                                        completeAction: { tapped in
                                            complete(tapped)
                                        },
                                        onTap: { tapped in
                                            selectedTask = tapped
                                        },
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

                // ==========================================
                // 4) Плюс-кнопка «+» для добавления новой корневой задачи
                // ==========================================
                if selectedSection != .notDone {
                    plusButton()
                }

                // ==========================================
                // 5) Жёлтая кнопка «Undo» (если showUndo == true)
                // ==========================================
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
                    Button {
                        showMenu = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { } label: {
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

    // MARK: — Кнопка «+» для добавления новой корневой задачи
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

    // MARK: — Логика пометки задачи выполненной и показа Undo
    private func complete(_ task: TaskItem) {
        task.isCompleted = true
        do {
            try modelContext.save()
        } catch {
            print("Ошибка при сохранении: \(error)")
        }
        recentlyCompleted = task
        withAnimation {
            showUndo = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showUndo = false
            }
            recentlyCompleted = nil
        }
    }

    // MARK: — Логика Undo: отменить последнее «выполнено»
    private func undoComplete() {
        guard let t = recentlyCompleted else { return }
        t.isCompleted = false
        do {
            try modelContext.save()
        } catch {
            print("Ошибка при сохранении: \(error)")
        }
        withAnimation {
            showUndo = false
        }
        recentlyCompleted = nil
    }
}
