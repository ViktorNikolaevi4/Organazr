import SwiftUI
import SwiftData

struct MatrixView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor<TaskItem>(\.title, order: .forward)]) private var allTasks: [TaskItem]

    @State private var selectedCategory: EisenhowerCategory? = nil
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
                                        matrixCell(for: .urgentImportant,   color: .red,    availableHeight: geometry.size.height)
                                       matrixCell(for: .notUrgentImportant, color: .yellow, availableHeight: geometry.size.height) // ← было .blue
                                   }
                            HStack(spacing: 16) {
                                 matrixCell(for: .urgentNotImportant,    color: .blue,  availableHeight: geometry.size.height) // ← было .yellow
                                 matrixCell(for: .notUrgentNotImportant, color: .gray,  availableHeight: geometry.size.height)
                             }
                        }
                        .frame(maxHeight: geometry.size.height * 0.9)

                        Spacer()
                    }
                }.padding(.horizontal, 16)

                // Кнопка "+"
                Button {
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
//                        .toolbar {
//                            ToolbarItem(placement: .topBarLeading) {
//                                Button("Закрыть") { dismiss() }
//                            }
//                        }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isAdding) {
                AddTaskCategorySheet { title, priority in
                    // Здесь у нас нет категории, поэтому просто создаём задачу с выбранным приоритетом
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
                    // Если нужно, можете сами вычислить дату или что угодно
                    newTask.dueDate = selectedDate
                    modelContext.insert(newTask)
                    try? modelContext.save()
                    isAdding = false
                }
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // Ячейка матрицы
    private func matrixCell(for category: EisenhowerCategory, color: Color, availableHeight: CGFloat) -> some View {
        let tasks = filteredTasks(for: category)
        return Button(action: {
            selectedCategory = category
        }) {
            List {
                Section(header: Text(category.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.black)) {
                    ForEach(tasks) { task in
                        Text(task.title)
                            .font(.caption)
                            .foregroundColor(.black)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: availableHeight * 0.4)
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
            // 1) Только матричные
            guard task.isMatrixTask else { return false }
            // 2) Не «Не буду делать»
            guard !task.isNotDone else { return false }
            // 3) Должна быть дата (у вас уже есть)
            guard task.dueDate != nil else { return false }
            // 4) Категория по приоритету
            switch category {
            case .urgentImportant:      return task.priority == .high
            case .notUrgentImportant:   return task.priority == .medium
            case .urgentNotImportant:   return task.priority == .low
            case .notUrgentNotImportant:return task.priority == .none
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

    private var pendingRows: [(task: TaskItem, level: Int)] {
        rows.filter { row in
            let t = row.task
            return !t.isCompleted && !t.isNotDone
        }
    }

     private var doneRows: [(task: TaskItem, level: Int)] {
        var result: [(TaskItem, Int)] = []
        // Проходим по всем корневым задачам (parent == nil)
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
         // если эта задача завершена — добавляем её
         if task.isCompleted {
             array.append((task, level))
         }
         // всегда идём дальше по всем подзадачам
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
                                level: 0,                    // все на одном уровне
                                completeAction: unmarkCompleted,
                                onTap: { selectedTask = $0 },
                                isExpanded: .constant(false) // без стрелки
                            )
//                            .swipeActions {
//                                Button(role: .destructive) {
//                                    modelContext.delete(task)
//                                    try? modelContext.save()
//                                } label: {
//                                    Label("Удалить", systemImage: "trash")
//                                }
//                            }
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
            AddTaskCategorySheet { title, priority in
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
            .presentationDetents([.fraction(0.4)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: –– Actions

    /// Помечает задачу и все её подзадачи выполненными
    private func markCompleted(_ task: TaskItem) {
        func cascadeComplete(_ t: TaskItem) {
            t.isCompleted = true
            // рекурсивно для каждого прямого потомка
            for sub in t.subtasks {
                cascadeComplete(sub)
            }
        }
        cascadeComplete(task)
        try? modelContext.save()
    }

    /// Снимает отметку completed с этой задачи и со всех её родителей
    private func unmarkCompleted(_ task: TaskItem) {
        // рекурсивно идём вверх по дереву
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
    /// начальный приоритет (чтобы меню сразу подсветило)
    let initialPriority: Priority

    /// коллбэк, возвращает название + выбранный приоритет
    var onAddTask: (String, Priority) -> Void

    @State private var title = ""
    @State private var selectedPriority: Priority
    @Environment(\.dismiss) private var dismiss

    /// свой собственный инициализатор, чтобы покинуть `selectedPriority` в нужном значении
    init(
        initialPriority: Priority = .high,
        onAddTask: @escaping (String, Priority) -> Void
    ) {
        self.initialPriority = initialPriority
        self.onAddTask = onAddTask
        // инициализируем @State из аргумента
        _selectedPriority = State(initialValue: initialPriority)
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

//extension Priority: Identifiable {
//    var id: String { rawValue }
//}
