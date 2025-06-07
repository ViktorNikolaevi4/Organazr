import SwiftUI
import SwiftData
import Speech
import AVFoundation

struct CalendarTabIcon: View {
    var body: some View {
        // TimelineView обновляется каждые 60 секунд
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let day = Calendar.current.component(.day, from: context.date)
            ZStack {
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .regular))
                Text("\(day)")
                    .font(.system(size: 12, weight: .bold))
                    .offset(y: -1)
            }
        }
    }
}

struct CalendarView: View {
    // MARK: — SwiftData
    @Environment(\.modelContext) private var modelContext

    /// Берём все задачи, будем фильтровать по dueDate
    @Query(sort: [SortDescriptor<TaskItem>(\.title, order: .forward)])
    private var allTasks: [TaskItem]

    // MARK: — Состояние
    @State private var selectedDate: Date = Date()
    @State private var selectedTask: TaskItem? = nil     // для редактирования существующей
    @State private var isAdding = false                   // для открытия AddTaskSheet
    @State private var expandedStates: [UUID: Bool] = [:] // не особо нужен, т. к. в календаре мы обычно не показываем вложенности
    @State private var recentlyCompleted: TaskItem? = nil
    @State private var showUndo = false
    @State private var sheetDetent: PresentationDetent = .medium

    private let maxCalendarDepth = 5

    // MARK: — Календарь (русский, неделя с понедельника)
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ru_RU")
        cal.firstWeekday = 2
        return cal
    }

    private var calendarDisplayRows: [(task: TaskItem, level: Int)] {
        var result: [(TaskItem, Int)] = []
        for root in tasksForSelectedDate {
            traverseCalendar(task: root, level: 0, into: &result)
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGray6).ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1) Верхняя панель: месяц + год + стрелки
                    monthHeader

                    Divider()

                    // 2) Ряд с короткими названиями дней недели (ПН, ВТ, СР…)
                    weekdayHeader

                    // 3) Сетка календаря
                    calendarGrid

                    // 4) Если на выбранную дату есть задачи (невып и вып)
                    //    – показываем список, иначе – «У вас свободный день»
                    if tasksForSelectedDate.isEmpty && completedForSelectedDate.isEmpty {
                        Spacer()
                        emptyDayView
                        Spacer()
                    } else {
                        taskListView
                    }
                }

                // 5) Плюс «+»: открываем AddTaskSheet,
                //    и при «Добавить» из AddTaskSheet создаём задачу с dueDate = selectedDate
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 64))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .specialBlue)
                        .shadow(radius: 4, y: 2)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 40)
            }
            .navigationTitle(monthName(of: selectedDate).capitalized)
            .navigationBarTitleDisplayMode(.inline)

            // --------------------------------------
            // Лист редактирования уже созданной задачи
            // --------------------------------------
            .sheet(item: $selectedTask) { task in
                TaskDetailSheet(task: task) {
                    selectedTask = nil
                    sheetDetent = .medium
                }
                .presentationDetents([.medium, .large], selection: $sheetDetent)
                .presentationDragIndicator(.visible)
            }

            // --------------------------------------
            // Лист создания новой «календарной» задачи
            // (аналог AddTaskSheet, только обязательно помещаем dueDate = selectedDate)
            // --------------------------------------
            .sheet(isPresented: $isAdding) {
                AddTaskSheet { title, priority in
                    // Создаём новую задачу, но с dueDate = selectedDate
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
                        dueDate: selectedDate  // <— вот здесь
                    )
                    modelContext.insert(newTask)
                    do {
                        try modelContext.save()
                    } catch {
                        print("Ошибка сохранения новой календарной задачи: \(error)")
                    }
                    isAdding = false
                }
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
    }

    // ----------------------------------------
    // Верхняя панель: «Июнь 2025» + ← / →
    // ----------------------------------------
    private var monthHeader: some View {
        HStack {
            Text("\(monthName(of: selectedDate)) \(yearString(of: selectedDate))")
                .font(.headline)
                .padding(.leading, 16)
            Spacer()
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(.specialBlue)
                    .font(.system(size: 20, weight: .medium))
            }
            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(.specialBlue)
                    .font(.system(size: 20, weight: .medium))
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    private func traverseCalendar(task: TaskItem, level: Int, into array: inout [(TaskItem, Int)]) {
        array.append((task, level))
        guard level < maxCalendarDepth else { return }
        guard expandedStates[task.id] == true else { return }
        let children = task.subtasks.filter { sub in
            // показываем либо без даты, либо с той же, что и selectedDate
            sub.dueDate == nil
                || calendar.isDate(sub.dueDate!, inSameDayAs: selectedDate)
        }
        for child in children {
            traverseCalendar(task: child, level: level + 1, into: &array)
        }
    }


    private func moveMonth(by offset: Int) {
        if let nextMonth = calendar.date(byAdding: .month, value: offset, to: selectedDate),
           let newDate   = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth))
        {
            selectedDate = newDate
        }
    }

    // ----------------------------------------
    // Ряд кратких названий дней недели (ПН, ВТ, СР…)
    // ----------------------------------------
    private var weekdayHeader: some View {
        let symbols    = calendar.shortWeekdaySymbols     // ["вс","пн","вт","ср","чт","пт","сб"]
        let startIndex = calendar.firstWeekday - 1         // = 1 → "пн"
        let ordered    = Array(symbols[startIndex...] + symbols[..<startIndex])
        return HStack {
            ForEach(ordered, id: \.self) { day in
                Text(day.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }

    // ----------------------------------------
    // Сетка календаря (6×7 = 42 ячейки)
    // ----------------------------------------
    private var calendarGrid: some View {
        let days = makeDaysForCalendarGrid(for: selectedDate)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 7),
            spacing: 8
        ) {
            ForEach(days, id: \.self) { date in
                dayCell(for: date)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // Одна ячейка «число» в календаре
    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let dayNumber          = calendar.component(.day, from: date)
        let isFromCurrentMonth = calendar.isDate(date, equalTo: selectedDate, toGranularity: .month)
        let isSelected         = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday            = calendar.isDateInToday(date)

        ZStack {
            // Если дата — выбранная → рисуем круг-заливку
            if isSelected {
                Circle()
                    .fill(Color.specialBlue)
                    .frame(width: 32, height: 32)
            }
            // Если «сегодня», но не совпадает с выбранной → контур
            else if isToday {
                Circle()
                    .stroke(Color.specialBlue, lineWidth: 1.5)
                    .frame(width: 32, height: 32)
            }

            // Сам текст числа
            Text("\(dayNumber)")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(
                    isFromCurrentMonth
                        ? (isSelected ? .white : .primary)
                        : .secondary
                )
                .frame(width: 32, height: 32)
        }
        .onTapGesture {
            selectedDate = date
        }
    }

    // ----------------------------------------
    // Если на выбранную дату нет задач: «У вас есть свободный день»
    // ----------------------------------------
    private var emptyDayView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(.specialBlue)

            Text("У вас есть свободный день")
                .font(.title2.weight(.semibold))

            Text("Расслабьтесь")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
    }
    private var calendarRoots: [TaskItem] {
        allTasks.filter { task in
            guard let d = task.dueDate else { return false }
            return calendar.isDate(d, inSameDayAs: selectedDate)
                && task.parentTask == nil
        }
    }

    // Плоский список всех задач и подзадач для выбранного дня
    private var calendarAllRows: [(task: TaskItem, level: Int)] {
        var result: [(TaskItem, Int)] = []
        for root in calendarRoots {
            flatten(task: root, level: 0, into: &result)
        }
        return result
    }

    // Рекурсивный обход: он добавляет сначала саму задачу, а если она развернута — и её потомков
    private func flatten(task: TaskItem, level: Int, into array: inout [(TaskItem, Int)]) {
        array.append((task, level))
        guard level < maxCalendarDepth else { return }
        // если задача не развернута — дальше не углубляемся
        guard expandedStates[task.id] == true else { return }

        // все её прямые подзадачи, у которых либо нет своей даты, либо дата совпадает
        let children = task.subtasks.filter { sub in
            sub.dueDate == nil ||
            calendar.isDate(sub.dueDate!, inSameDayAs: selectedDate)
        }
        for child in children {
            flatten(task: child, level: level + 1, into: &array)
        }
    }
    private func collectCompleted(_ task: TaskItem, into array: inout [TaskItem]) {
        if task.isCompleted {
            array.append(task)
        }
        for child in task.subtasks {
            // только те, что относятся к этой дате (или у которых нет даты)
            if child.dueDate == nil || calendar.isDate(child.dueDate!, inSameDayAs: selectedDate) {
                collectCompleted(child, into: &array)
            }
        }
    }
    private var allDoneForDate: [TaskItem] {
        var result: [TaskItem] = []
        for root in calendarRoots {
            collectCompleted(root, into: &result)
        }
        return result
    }
    // ----------------------------------------
    // Список задач под календарём
    // ----------------------------------------
    private var pendingRows: [(TaskItem, Int)] {
        calendarAllRows.filter { !$0.0.isCompleted }
    }
    private var doneRows: [(TaskItem, Int)] {
        calendarAllRows.filter { $0.0.isCompleted }
    }

    private var taskListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Невыполненные остаются как есть
                if !pendingRows.isEmpty {
                    Section(header: headerView(text: "Сегодня")) {
                        ForEach(pendingRows, id: \.0.id) { pair in
                            TaskRowView(
                                task: pair.0,
                                level: pair.1,
                                completeAction: markCompleted,
                                onTap: { selectedTask = $0 },
                                isExpanded: Binding(
                                    get: { expandedStates[pair.0.id] ?? false },
                                    set: { expandedStates[pair.0.id] = $0 }
                                )
                            )
                        }
                    }
                }

                     if !allDoneForDate.isEmpty {
                    Section(header: headerView(text: "Выполнено")) {
                        ForEach(allDoneForDate, id: \.id) { task in
                            HStack {
                                Image(systemName: "checkmark.square.fill")
                                    .foregroundColor(.gray)
                                Text(task.title)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .background(Color.white.cornerRadius(12))
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }


    /// Заголовок для секции («СЕГОДНЯ», «ВЫПОЛНЕНО» и т. п.)
    private func headerView(text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
    }

    private func completeRecursively(_ task: TaskItem) {
        task.isCompleted = true
        for sub in task.subtasks {
            completeRecursively(sub)
        }
    }

    /// Помечает задачу выполненной и сохраняет
    private func markCompleted(_ task: TaskItem) {
        // сначала рекурсивно помечаем саму задачу и все её потомки
        completeRecursively(task)
        // сохраняем контекст один раз
        do {
            try modelContext.save()
        } catch {
            print("Ошибка сохранения: \(error)")
        }
        // дальше ваша логика Undo
        recentlyCompleted = task
        withAnimation { showUndo = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showUndo = false }
            recentlyCompleted = nil
        }
    }

    // Список «невыполненных» задач для выбранной даты
    private var tasksForSelectedDate: [TaskItem] {
        allTasks.filter { task in
            guard let d = task.dueDate else { return false }
            return calendar.isDate(d, inSameDayAs: selectedDate)
                && !task.isCompleted
        }
    }

    // Список «выполненных» задач для выбранной даты
    private var completedForSelectedDate: [TaskItem] {
        allTasks.filter { task in
            guard let d = task.dueDate else { return false }
            return calendar.isDate(d, inSameDayAs: selectedDate)
                && task.isCompleted
        }
    }

    // Построение массива из 42 дат (6×7) для календаря
    private func makeDaysForCalendarGrid(for referenceDate: Date) -> [Date] {
        guard let startOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: referenceDate)
        ) else {
            return []
        }
        let weekdayOfFirst = calendar.component(.weekday, from: startOfMonth)
        let offset = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -offset, to: startOfMonth) else {
            return []
        }
        return (0..<42).compactMap { delta in
            calendar.date(byAdding: .day, value: delta, to: gridStart)
        }
    }

    /// Название месяца по-русски, например “июнь”
    private func monthName(of date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "LLLL"
        return df.string(from: date)
    }

    /// Год, например “2025”
    private func yearString(of date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy"
        return df.string(from: date)
    }
}
