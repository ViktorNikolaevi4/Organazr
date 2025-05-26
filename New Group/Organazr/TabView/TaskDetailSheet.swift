import SwiftUI

struct TaskDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem  // это ваша SwiftData-модель
    var onDismiss: () -> Void

    @State private var showingPriorityPopover = false
    @State private var showMoreOptions = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Пример: отображаем дату (если есть) и кнопку отметить/флаг и т.п.
                HStack {
                    // чекбокс
                    Button {
                        task.isCompleted.toggle()
                    } label: {
                        Image(systemName: task.isCompleted
                              ? "checkmark.square.fill"
                              : "square")
                    }
                    Spacer()
                    // флажок с popover
                    Button {
                        showingPriorityPopover = true
                    } label: {
                        // цвет флажка зависит от уровня
                        Image(systemName: "flag.fill")
                            .foregroundStyle(flagColor(for: task.priority))
                    }
                    .popover(isPresented: $showingPriorityPopover, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                        // Содержимое popover
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Priority.allCases, id: \.self) { level in
                                Button(action: {
                                    task.priority = level
                                    showingPriorityPopover = false // Закрываем popover после выбора
                                }) {
                                    HStack {
                                        Image(systemName: "flag.fill")
                                            .foregroundStyle(flagColor(for: level))
                                        Text(label(for: level))
                                            .foregroundStyle(.black)
                                            .font(.headline)
                                        Spacer()
                                        if level == task.priority {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.black)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                if level != Priority.allCases.last {
                                    Divider()
                                }
                            }
                        }
                        .frame(width: 350) // Ширина popover, как на скриншоте
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .presentationCompactAdaptation(.popover) // Адаптация для iPhone
                    }
                }
                .font(.title2)

                // MARK: редактируемый заголовок
                TextField("Заголовок задачи", text: $task.title)
                    .font(.largeTitle.weight(.bold))
                    .padding(.horizontal, 4)

                // MARK: редактируемое многострочное описание
                TextEditor(text: $task.details)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .frame(minHeight: 150)  // минимум, подкорректируйте под ваш дизайн

                Spacer()
            }
            .padding()
            .navigationTitle("Задачи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMoreOptions = true
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .sheet(isPresented: $showMoreOptions) {
                MoreOptionsView(task: task)
                   .presentationDetents([.fraction(0.75)])
                   .presentationDragIndicator(.visible)
            }
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

    // текст метки
    private func label(for priority: Priority) -> String {
        switch priority {
        case .high:   return "Высокий приоритет"
        case .medium: return "Средний приоритет"
        case .low:    return "Низкий приоритет"
        case .none:   return "Без приоритета"
        }
    }
}

