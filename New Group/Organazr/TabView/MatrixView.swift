import SwiftUI
import SwiftData

struct MatrixView: View {
    @Environment(\.modelContext) private var modelContext
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
                MatrixDetailView(category: category, tasks: filteredTasks(for: category))
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
            task.isMatrixTask && { // Фильтруем только задачи матрицы
                guard task.dueDate != nil else { return false }
                switch category {
                case .urgentImportant:
                    return task.priority == .high
                case .notUrgentImportant:
                    return task.priority == .medium
                case .urgentNotImportant:
                    return task.priority == .low
                case .notUrgentNotImportant:
                    return task.priority == .none
                }
            }()
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

// MARK: –– MatrixDetailView.swift

struct MatrixDetailView: View {
  let category: MatrixView.EisenhowerCategory
  let tasks: [TaskItem]

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  // для открытия редактора задачи (TaskDetailSheet)
  @State private var selectedTask: TaskItem? = nil
  @State private var sheetDetent: PresentationDetent = .medium

  // для показа шита добавления новой подзадачи
  @State private var showAddSubtask = false
  @State private var parentForNew: TaskItem? = nil

 //   @State private var isAdding = false
    @State private var selectedDate: Date = Date()

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      List {
        ForEach(tasks) { task in
          // здесь мы переиспользуем ваш TaskRowView из HomeView
          TaskRowView(
            task: task,
            level: 0,                     // глубина = 0, т.к. это корни
            completeAction: markCompleted,
            onTap: { tapped in
              selectedTask = tapped
            },
            isExpanded: .constant(false)  // или ваша логика разворачивания
          )
          .swipeActions(edge: .trailing) {
            Button {
              parentForNew = task
              showAddSubtask = true
            } label: {
              Label("Подзадача", systemImage: "plus")
            }
            .tint(.green)
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle(category.rawValue)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Назад") { dismiss() }
        }
      }

      // Плавающая кнопка «+», чтобы добавить новую корневую задачу именно в этот квадрант
      Button {
    //    parentForNew = nil
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
    // редактирование существующей задачи
    .sheet(item: $selectedTask) { task in
      TaskDetailSheet(task: task) {
        selectedTask = nil
        sheetDetent = .medium
      }
      .presentationDetents([.medium, .large], selection: $sheetDetent)
      .presentationDragIndicator(.visible)
    }
    // создание новой (или под-)задачи
    .sheet(isPresented: $showAddSubtask) {
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
            showAddSubtask = false
        }
      .presentationDetents([.fraction(0.4)])
      .presentationDragIndicator(.visible)
    }
  }

  private func markCompleted(_ task: TaskItem) {
    task.isCompleted = true
    try? modelContext.save()
  }
}





// MARK: –– AddTaskCategorySheet.swift

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
