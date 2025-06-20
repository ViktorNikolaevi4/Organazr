import SwiftUI
import SwiftData

struct MatrixView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor<TaskItem>(\.title, order: .forward)]) private var allTasks: [TaskItem]

    @State private var selectedCategory: EisenhowerCategory? = nil // Для навигации в MatrixDetailView
    @State private var addTaskCategory: EisenhowerCategory? = nil // Для определения приоритета при добавлении
    @State private var isAdding = false
    @State private var selectedDate: Date = Date()
    private let maxDepthAllowed = 5

    // Перечисление для категорий матрицы Эйзенхауэра
    enum EisenhowerCategory: String, CaseIterable, Identifiable {
        case urgentImportant = "Срочно и важно"
        case notUrgentImportant = "Не срочно, но важно"
        case urgentNotImportant = "Срочно, но не важно"
        case notUrgentNotImportant = "Не срочно и не важно"

        var id: String { self.rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGray6).ignoresSafeArea()

                GeometryReader { geometry in
                    VStack(spacing: 8) {
                        Spacer().frame(height: 8)
                        VStack(spacing: 8) {
                            HStack(spacing: 16) {
                                matrixCell(for: .urgentImportant, color: .red, availableHeight: geometry.size.height)
                                matrixCell(for: .notUrgentImportant, color: .yellow, availableHeight: geometry.size.height)
                            }
                            HStack(spacing: 16) {
                                matrixCell(for: .urgentNotImportant, color: .blue, availableHeight: geometry.size.height)
                                matrixCell(for: .notUrgentNotImportant, color: .gray, availableHeight: geometry.size.height)
                            }
                        }
                        .frame(maxHeight: geometry.size.height * 0.9)

                        Spacer()
                    }
                }.padding(.horizontal, 16)

                // Кнопка "+"
                Button {
                    addTaskCategory = selectedCategory ?? .urgentImportant // Используем последнюю категорию или по умолчанию
                    isAdding = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 48))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .blue)
                        .shadow(radius: 4, y: 2)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 40)
            }
            .navigationTitle("Матрица Эйзенхауэра")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedCategory) { category in
                NavigationStack {
                    MatrixDetailView(category: category, tasks: filteredTasks(for: category))
                        .navigationTitle(category.rawValue)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isAdding) {
                AddTaskCategorySheet(
                    initialCategory: addTaskCategory ?? .urgentImportant,
                    onAddTask: { title, priority in
                        let newTask = TaskItem(
                            title: title,
                            list: nil,
                            details: "",
                            isCompleted: false,
                            priority: priority,
                            isPinned: false,
                            imageData: nil,
                            isNotDone: false,
                            parentTask: nil,
                            dueDate: selectedDate,
                            isMatrixTask: true
                        )
                        modelContext.insert(newTask)
                        try? modelContext.save()
                        isAdding = false
                    }
                )
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
            }

        }
    }

    // Ячейка матрицы
    private func matrixCell(
        for category: EisenhowerCategory,
        color: Color,
        availableHeight: CGFloat
    ) -> some View {
        let tasks = filteredTasks(for: category)
            .sorted { lhs, rhs in
                !lhs.isCompleted && rhs.isCompleted
            }

        return Button {
            selectedCategory = category
            addTaskCategory = category // Обновляем категорию для добавления
        } label: {
            List {
                Section(header: Text(category.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.black)) {
                    ForEach(tasks) { task in
                        Text(task.title)
                            .font(.caption)
                            .foregroundColor(task.isCompleted ? .gray : .black)
                    }
                }
            }
            .frame(maxWidth: .infinity,
                   maxHeight: availableHeight * 0.4)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 2)
            )
        }
    }

    // Фильтрация задач по категории, только из матрицы
    private func filteredTasks(for category: EisenhowerCategory) -> [TaskItem] {
        allTasks.filter { task in
            guard task.isMatrixTask else { return false }
            guard !task.isNotDone else { return false }
            guard task.dueDate != nil else { return false }
            switch category {
            case .urgentImportant:      return task.priority == .high
            case .notUrgentImportant:   return task.priority == .medium
            case .urgentNotImportant:   return task.priority == .low
            case .notUrgentNotImportant: return task.priority == .none
            }
        }
    }

    // Присвоение даты в зависимости от категории
    private func assignDueDate(for category: EisenhowerCategory) -> Date? {
        let calendar = Calendar.current
        switch category {
        case .urgentImportant:
            return calendar.date(byAdding: .day, value: 1, to: Date())
        case .notUrgentImportant:
            return calendar.date(byAdding: .day, value: 7, to: Date())
        case .urgentNotImportant:
            return calendar.date(byAdding: .day, value: 2, to: Date())
        case .notUrgentNotImportant:
            return calendar.date(byAdding: .day, value: 14, to: Date())
        }
    }

    // Определение приоритета на основе категории
    private func priorityForCategory(_ category: EisenhowerCategory?) -> Priority {
        guard let category = category else { return .high } // По умолчанию "Срочно и важно", если категория не выбрана
        switch category {
        case .urgentImportant:      return .high
        case .notUrgentImportant:   return .medium
        case .urgentNotImportant:   return .low
        case .notUrgentNotImportant: return .none
        }
    }
}


struct MatrixDetailView: View {
    let category: MatrixView.EisenhowerCategory
    let tasks: [TaskItem]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // редактирование
    @State private var selectedTask: TaskItem? = nil
    @State private var sheetDetent: PresentationDetent = .medium

    // добавление подзадачи
    @State private var showAddSubtask = false
    @State private var parentForNew: TaskItem? = nil
    @State private var selectedDate: Date = Date()

    // разворачивание
    @State private var expandedStates: [UUID: Bool] = [:]

    @State private var isPinnedExpanded = true

    // MARK: –– Формируем плоский список
    private var rows: [(task: TaskItem, level: Int)] {
        var result: [(TaskItem, Int)] = []
        for task in tasks.filter({ $0.parentTask == nil }) {
            flatten(task: task, level: 0, into: &result)
        }
        return result
    }

    private func flatten(
        task: TaskItem,
        level: Int,
        into array: inout [(TaskItem, Int)]
    ) {
        array.append((task, level))
        guard expandedStates[task.id] == true else { return }
        for sub in task.subtasks {
            flatten(task: sub, level: level + 1, into: &array)
        }
    }
    private var pinnedRows: [(task: TaskItem, level: Int)] {
        rows.filter { $0.task.isPinned }
    }

    private var pendingRows: [(task: TaskItem, level: Int)] {
        rows.filter {
            !$0.task.isCompleted
            && !$0.task.isNotDone
            && !$0.task.isPinned      // Исключаем закреплённые
        }
    }

    private var doneRows: [(task: TaskItem, level: Int)] {
        var result: [(TaskItem, Int)] = []
        for root in tasks.filter({ $0.parentTask == nil }) {
            traverseDone(task: root, level: 0, into: &result)
        }
        return result
    }

    private func traverseDone(
        task: TaskItem,
        level: Int,
        into array: inout [(TaskItem, Int)]
    ) {
        if task.isCompleted {
            array.append((task, level))
        }
        for sub in task.subtasks {
            traverseDone(task: sub, level: level + 1, into: &array)
        }
    }

    private var flatDoneTasks: [TaskItem] {
        func collectDone(_ task: TaskItem, into array: inout [TaskItem]) {
            if task.isCompleted && !task.isNotDone {
                array.append(task)
            }
            for sub in task.subtasks {
                collectDone(sub, into: &array)
            }
        }

        var result: [TaskItem] = []
        for root in tasks.filter({ $0.parentTask == nil }) {
            collectDone(root, into: &result)
        }
        return result
    }

    // MARK: –– UI
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                // ——— Закреплённые ———
                if !pinnedRows.isEmpty {
                    Section(
                        header:
                            HStack(spacing: 8) {
                                Image(systemName: "pin.fill")
                                    .foregroundColor(.orange)

                                Text("Закреплённые")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Spacer()

                                Text("\(pinnedRows.count)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                // Кнопка только на стрелочку
                                Button {
                                    withAnimation {
                                        isPinnedExpanded.toggle()
                                    }
                                } label: {
                                    Image(systemName: isPinnedExpanded ? "chevron.down" : "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain) // чтобы не было лишних эффектов
                            }
                    ) {
                        if isPinnedExpanded {
                            ForEach(pinnedRows, id: \.task.id) { row in
                                TaskRowView(
                                    task: row.task,
                                    level: row.level,
                                    completeAction: markCompleted,
                                    onTap: { selectedTask = $0 },
                                    isExpanded: Binding(
                                        get: { expandedStates[row.task.id] ?? false },
                                        set: { expandedStates[row.task.id] = $0 }
                                    )
                                )
                                .swipeActions {
                                    Button("Открепить", systemImage: "pin.slash") {
                                        row.task.isPinned = false
                                        try? modelContext.save()
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    }
                }
                // ——— Открытые ———
                if !pendingRows.isEmpty {
                    Section(header: Text("Открытые")) {
                        ForEach(pendingRows, id: \.task.id) { row in
                            TaskRowView(
                                task: row.task,
                                level: row.level,
                                completeAction: markCompleted,
                                onTap: { selectedTask = $0 },
                                isExpanded: Binding(
                                    get: { expandedStates[row.task.id] ?? false },
                                    set: { expandedStates[row.task.id] = $0 }
                                )
                            )
                            .swipeActions(edge: .trailing) {
                                Button {
                                    parentForNew = row.task
                                    showAddSubtask = true
                                } label: {
                                    Label("Подзадача", systemImage: "plus")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }

                // ——— Выполнено ———
                let done = flatDoneTasks
                if !done.isEmpty {
                    Section(header: Text("Выполнено")) {
                        ForEach(done) { task in
                            TaskRowView(
                                task: task,
                                level: 0,
                                completeAction: unmarkCompleted,
                                onTap: { selectedTask = $0 },
                                isExpanded: .constant(false)
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            // плавающий «+»
            Button {
                parentForNew = nil
                showAddSubtask = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 48))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .blue)
                    .shadow(radius: 4, y: 2)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 40)
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Назад", action: { dismiss() })
            }
        }
        // редактирование
        .sheet(item: $selectedTask) { task in
            TaskDetailSheet(task: task) {
                selectedTask = nil
                sheetDetent = .medium
            }
            .presentationDetents([.medium, .large], selection: $sheetDetent)
            .presentationDragIndicator(.visible)
        }
        // добавление
        .sheet(isPresented: $showAddSubtask) {
            AddTaskCategorySheet(
                initialCategory: category, // Передаем категорию напрямую
                onAddTask: { title, priority in
                    let newTask = TaskItem(
                        title: title,
                        list: nil,
                        details: "",
                        isCompleted: false,
                        priority: priority,
                        isPinned: false,
                        imageData: nil,
                        isNotDone: false,
                        parentTask: parentForNew,
                        dueDate: selectedDate,
                        isMatrixTask: true
                    )
                    modelContext.insert(newTask)
                    try? modelContext.save()
                    showAddSubtask = false
                }
            )
            .presentationDetents([.fraction(0.4)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: –– Actions
    private func markCompleted(_ task: TaskItem) {
        func cascadeComplete(_ t: TaskItem) {
            t.isCompleted = true
            for sub in t.subtasks {
                cascadeComplete(sub)
            }
        }
        cascadeComplete(task)
        try? modelContext.save()
    }

    private func unmarkCompleted(_ task: TaskItem) {
        func cascadeUndone(_ t: TaskItem?) {
            guard let t = t, t.isCompleted else { return }
            t.isCompleted = false
            cascadeUndone(t.parentTask)
        }
        cascadeUndone(task)
        try? modelContext.save()
    }
}

struct AddTaskCategorySheet: View {
    /// начальная категория (для определения приоритета)
    let initialCategory: MatrixView.EisenhowerCategory

    /// коллбэк, возвращает название + выбранный приоритет
    var onAddTask: (String, Priority) -> Void

    @State private var title = ""
    @State private var selectedPriority: Priority
    @Environment(\.dismiss) private var dismiss

    /// свой собственный инициализатор, чтобы установить `selectedPriority` на основе категории
    init(
        initialCategory: MatrixView.EisenhowerCategory,
        onAddTask: @escaping (String, Priority) -> Void
    ) {
        self.initialCategory = initialCategory
        self.onAddTask = onAddTask
        // Инициализируем @State на основе initialCategory
        _selectedPriority = State(initialValue: Self.priorityForCategory(initialCategory))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 1) Название задачи
                TextField("Что бы вы хотели сделать?", text: $title)
                    .font(.subheadline)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                // 2) Меню выбора приоритета
                HStack {
                    Spacer()
                    Menu {
                        ForEach([Priority.high, .medium, .low, .none], id: \.self) { p in
                            Button {
                                selectedPriority = p
                            } label: {
                                Text(p.title)
                                    .foregroundColor(p.color)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedPriority.title)
                                .foregroundColor(selectedPriority.color)
                            Image(systemName: "chevron.down")
                                .foregroundColor(selectedPriority.color)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }

                // 3) Кнопка «Добавить»
                Button(action: {
                    guard !title.isEmpty else { return }
                    onAddTask(title, selectedPriority)
                    dismiss()
                }) {
                    Text("Добавить")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(title.isEmpty ? Color.gray : Color.specialBlue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(title.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    // Статический метод для определения приоритета на основе категории
    private static func priorityForCategory(_ category: MatrixView.EisenhowerCategory) -> Priority {
        switch category {
        case .urgentImportant:      return .high
        case .notUrgentImportant:   return .medium
        case .urgentNotImportant:   return .low
        case .notUrgentNotImportant: return .none
        }
    }
}




extension Priority {
    /// Человекочитаемое название
    var title: String {
        switch self {
        case .high:   return "Срочно и важно"
        case .medium: return "Не срочно, но важно"
        case .low:    return "Срочно, но не важно"
        case .none:   return "Не срочно и не важно"
        }
    }

    /// Цвет для каждого приоритета
    var color: Color {
        switch self {
        case .high:   return .red
        case .medium: return .yellow
        case .low:    return .blue
        case .none:   return .gray
        }
    }
}

//TaskRowView(
//    task: row.task,
//    level: row.level,
//    completeAction: markCompleted,
//    onTap: { selectedTask = $0 },
//    isExpanded: Binding(
//        get: { expandedStates[row.task.id] ?? false },
//        set: { expandedStates[row.task.id] = $0 }
//    )
//)
