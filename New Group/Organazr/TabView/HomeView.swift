import SwiftUI
import SwiftData

/// - level: уровень вложенности (0 — корневая, 1, 2, …).
struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext
    var task: TaskItem
    var level: Int
    var onTap: (TaskItem) -> Void

    /// Ширина «отступа» (в поинтах) для текущей вложенности.
    private var indentWidth: CGFloat {
        CGFloat(level) * 20  // 20 pt на каждый уровень вложенности
    }

    var body: some View {
        HStack(spacing: 12) {
            // Отступ слева, имитирующий вложенность
            Spacer()
                .frame(width: indentWidth)

            // Чекбокс (кнопка «галочка»)
            Button {
                withAnimation {
                    task.isCompleted.toggle()
                    // Если вы хотите показывать Undo всего лишь при корневых задачах или при любых,
                    // перенесите логику showUndo / recentlyCompleted сюда.
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(task.isCompleted ? .green : .primary)
            }
            .buttonStyle(.plain)

            // Текстовый блок: название + детали (если есть)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .foregroundColor(task.isCompleted ? .gray : .primary)

                if !task.details.isEmpty {
                    Text(task.details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            // Флажок приоритета (если приоритет != .none)
            if task.priority != .none {
                Image(systemName: "flag.fill")
                    .foregroundColor(flagColor(for: task.priority))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap(task)
        }
        // Свайп справа: «Удалить»
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                // 1) Если хотите показать диалог «Подтверждение удаления» —
                //    заполните taskToDelete = task и showDeleteConfirmation = true.
                // 2) Либо сразу удалять:
                modelContext.delete(task)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
        .padding(.vertical, 8)
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

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    // Запрашиваем все TaskItem, отсортированные по title
    @Query(sort: [SortDescriptor<TaskItem>(\.title, order: .forward)])
    private var allTasks: [TaskItem]

    // MARK: — Состояние экранов и кнопок
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

    // MARK: — Фильтрация: остаются только корневые задачи (parentTask == nil)
    //           которые ещё не выполнены и не помечены «не будет выполнено»,
    //           и принадлежат либо выбранному списку, либо «без списка».
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

    // MARK: — «Плоское» представление для закреплённых корневых задач
    private var pinnedDisplayRows: [(TaskItem, Int)] {
        var result: [(TaskItem, Int)] = []
        for root in tasks.filter(\.isPinned) {
            traverse(task: root, level: 0, into: &result)
        }
        return result
    }

    // MARK: — «Плоское» представление для незакреплённых корневых задач
    private var normalDisplayRows: [(TaskItem, Int)] {
        var result: [(TaskItem, Int)] = []
        for root in tasks.filter({ !$0.isPinned }) {
            traverse(task: root, level: 0, into: &result)
        }
        return result
    }

    // Рекурсивный метод, который «раскручивает» иерархию:
    // Берёт любую задачу, добавляет (task, level) в result,
    // затем для каждого ребёнка (child) вызывает себя же с level+1.
    // При этом мы фильтруем, чтобы не брать «завершённые» и «не будет сделано».
    private func traverse(task: TaskItem, level: Int, into array: inout [(TaskItem, Int)]) {
        array.append((task, level))
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

                //==========================================
                // 1) Секция «Не будет выполнено»
                //==========================================
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
                                    TaskRowView(task: task, level: 0) { tapped in
                                        selectedTask = tapped
                                    }
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
                //==========================================
                // 2) Если вообще нет корневых задач в выбранной секции/списке
                //==========================================
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
                //==========================================
                // 3) Основной List («Закреплено» + «Задачи»)
                //==========================================
                else {
                    List {
                        //======================================
                        // 3.1) Секция «Закреплено»
                        //======================================
                        if !pinnedDisplayRows.isEmpty {
                            Section {
                                // Заголовок-кнопка, разворачивает/сворачивает «Закреплено»
                                Button {
                                    withAnimation {
                                        isPinnedExpanded.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "pin.fill")
                                            .foregroundColor(.orange)
                                        Text("Закреплено")
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

                                // Если «Закреплено» развернуто, выводим все строки:
                                if isPinnedExpanded {
                                    ForEach(pinnedDisplayRows, id: \.0.id) { pair in
                                        let task = pair.0
                                        let lvl  = pair.1
                                        TaskRowView(task: task, level: lvl) { tapped in
                                            selectedTask = tapped
                                        }
                                    }
                                }
                            }
                        }

                        //======================================
                        // 3.2) Секция «Задачи» (не закреплённые)
                        //======================================
                        if !normalDisplayRows.isEmpty {
                            Section("Задачи") {
                                ForEach(normalDisplayRows, id: \.0.id) { pair in
                                    let task = pair.0
                                    let lvl  = pair.1
                                    TaskRowView(task: task, level: lvl) { tapped in
                                        selectedTask = tapped
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                //==========================================
                // Кнопка «+» (AddTask) – не отображается в секции «Не будет выполнено»
                //==========================================
                if selectedSection != .notDone {
                    plusButton()
                }

                //==========================================
                // Undo-кнопка (если showUndo == true)
                //==========================================
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
                // Левая «гамбургер»-кнопка для меню
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showMenu = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
                // Правая «многоточие»
                ToolbarItem(placement: .topBarTrailing) {
                    Button {} label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            //==========================================
            // Sheet: TaskDetailSheet при выборе задачи
            //==========================================
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
            //==========================================
            // Sheet: AddTaskSheet при нажатии «+»
            //==========================================
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
            //==========================================
            // Sheet: MenuModalView при нажатии «гамбургера»
            //==========================================
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
            //==========================================
            // ConfirmationDialog: подтверждение удаления
            //==========================================
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

    //==============================================================================
    // MARK: — Кнопка «+» для добавления новой задачи
    //==============================================================================
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
                        .foregroundStyle(.white, .blue) // если у вас есть собственный Color, замените
                        .shadow(radius: 4, y: 2)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 40)
            }
        }
    }

    //==============================================================================
    // MARK: — Кнопка «Undo» (отмена пометки «выполнено»)
    //==============================================================================
    @ViewBuilder
    private func undoButton() -> some View {
        Button {
            undoComplete()
        } label: {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white, .orange)
                .shadow(radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    //==============================================================================
    // MARK: — Пометить задачу как выполненную и показать Undo-кнопку
    //==============================================================================
    private func complete(_ task: TaskItem) {
        task.isCompleted = true
        recentlyCompleted = task
        withAnimation {
            showUndo = true
        }
        // Через 3 сек вернем назад кнопку Undo, если пользователь не нажал
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showUndo = false
            }
            recentlyCompleted = nil
        }
    }

    //==============================================================================
    // MARK: — Отмена последнего «выполнено»
    //==============================================================================
    private func undoComplete() {
        guard let t = recentlyCompleted else { return }
        t.isCompleted = false
        withAnimation {
            showUndo = false
        }
        recentlyCompleted = nil
    }
}
