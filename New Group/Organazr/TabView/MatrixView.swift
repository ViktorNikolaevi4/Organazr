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
                                matrixCell(for: .urgentImportant, color: .red, availableHeight: geometry.size.height)
                                matrixCell(for: .notUrgentImportant, color: .blue, availableHeight: geometry.size.height)
                            }
                            HStack(spacing: 16) {
                                matrixCell(for: .urgentNotImportant, color: .yellow, availableHeight: geometry.size.height)
                                matrixCell(for: .notUrgentNotImportant, color: .gray, availableHeight: geometry.size.height)
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
                AddTaskCategorySheet { category, title, priority in
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
                        isMatrixTask: true // Устанавливаем, что задача из матрицы
                    )
                    newTask.dueDate = assignDueDate(for: category)
                    modelContext.insert(newTask)
                    do {
                        try modelContext.save()
                    } catch {
                        print("Ошибка сохранения: \(error)")
                    }
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

struct MatrixDetailView: View {
    let category: MatrixView.EisenhowerCategory
    let tasks: [TaskItem]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(tasks) { task in
                    Text(task.title)
                        .font(.subheadline)
                }
            }
            .navigationTitle(category.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Назад") {
                        dismiss()
                    }
                    .font(.subheadline)
                }
            }
        }
        .ignoresSafeArea(.all)
    }
}

struct AddTaskCategorySheet: View {
    var onAdd: (MatrixView.EisenhowerCategory, String, Priority) -> Void
    @State private var title = ""
    @State private var selectedCategory: MatrixView.EisenhowerCategory = .urgentImportant
    @State private var selectedPriority: Priority = .none
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                TextField("Что бы вы хотели сделать?", text: $title)
                    .font(.subheadline)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                Picker("Категория", selection: $selectedCategory) {
                    ForEach(MatrixView.EisenhowerCategory.allCases) { category in
                        Text(category.rawValue)
                            .font(.subheadline)
                            .tag(category)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

                HStack(spacing: 16) {
                    Button {
                        selectedPriority = .high
                    } label: {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundColor(selectedPriority == .high ? .red : .gray)
                    }
                    Button {
                        selectedPriority = .medium
                    } label: {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundColor(selectedPriority == .medium ? .yellow : .gray)
                    }
                    Button {
                        selectedPriority = .low
                    } label: {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundColor(selectedPriority == .low ? .blue : .gray)
                    }
                    Button {
                        selectedPriority = .none
                    } label: {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundColor(selectedPriority == .none ? .gray : .gray)
                    }
                    Spacer()
                    Button("Добавить") {
                        if !title.isEmpty {
                            onAdd(selectedCategory, title, selectedPriority)
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                    .font(.subheadline)
                    .padding()
                    .background(title.isEmpty ? Color.gray : Color.specialBlue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}
