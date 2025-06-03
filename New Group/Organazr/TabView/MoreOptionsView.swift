import SwiftUI

// Модель пункта меню
private struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
}

// Статический набор пунктов для примера
private let menuItems: [MenuItem] = [
    .init(title: "Добавить подзадачу", systemImage: "plus.square.on.square"),
    .init(title: "Связать родительскую задачу", systemImage: "link"),
    .init(title: "Сфокусируйся", systemImage: "target"),
    .init(title: "Преобразовать в заметку", systemImage: "doc.text"),
    .init(title: "Прикрепить", systemImage: "paperclip"),
    .init(title: "Метки", systemImage: "tag"),
    .init(title: "Активность в задаче", systemImage: "list.bullet"),
    .init(title: "Добавить в Live Activity", systemImage: "pin")
]

struct MoreOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var task: TaskItem
    @State private var showActivityView = false
    @State private var showAddSubtaskSheet = false

    var body: some View {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Верхняя панель из четырёх кнопок
                    HStack(alignment: .top, spacing: 16) {
                        OptionButton(
                            systemName: task.isPinned ? "pin.slash" : "pin.fill",
                            title: task.isPinned ? "Открепить" : "Закрепить",
                            iconColor: .orange
                        ) {
                            task.isPinned.toggle()
                            dismiss()
                        }
                        OptionButton(
                            systemName: "square.and.arrow.up",
                            title: "Поделиться",
                            iconColor: .green
                        ) {
                            showActivityView = true
                        }
                        OptionButton(
                            systemName: task.isNotDone ? "arrow.uturn.left.circle.fill" : "xmark.circle.fill",
                            title: task.isNotDone ? "Вернуть" : "Не буду делать",
                            iconColor: task.isNotDone ? .green : .blue
                        ) {
                            if task.isNotDone {
                                task.isNotDone = false
                            } else {
                                task.isNotDone = true
                            }
                            dismiss()
                        }
                        OptionButton(
                            systemName: "trash.fill",
                            title: "Удалить",
                            iconColor: .red
                        ) {
                            modelContext.delete(task)
                            dismiss()
                        }
                    }
                    .padding(.horizontal)

                    VStack(spacing: 0) {
                        ForEach(menuItems.indices, id: \.self) { idx in
                            let item = menuItems[idx]
                            HStack {
                                Text(item.title)
                                    .font(.body)
                                Spacer()
                                Image(systemName: item.systemImage)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal)
                            .background(Color.white)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Обрабатываем нажатие на "Добавить подзадачу"
                                if item.title == "Добавить подзадачу" {
                                    showAddSubtaskSheet = true
                                }
                            }
                            if idx < menuItems.count - 1 {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(16)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top)
                .sheet(isPresented: $showActivityView) {
                    ActivityView(items: [shareText()])
                }
                // Добавляем модальное окно для создания подзадачи
                .sheet(isPresented: $showAddSubtaskSheet) {
                    AddSubtaskSheet { title in
                        let newSubtask = TaskItem(title: title, parentTask: task)
                        modelContext.insert(newSubtask)
                        task.refreshID = UUID() // Обновляем refreshID родительской задачи
                        do {
                            try modelContext.save()
                            print("Контекст сохранен успешно. Подзадача: \(newSubtask.title), родитель: \(task.title)")
                        } catch {
                            print("Ошибка сохранения подзадачи: \(error)")
                        }
                        showAddSubtaskSheet = false
                    }
                    .presentationDetents([.fraction(0.4)])
                    .presentationDragIndicator(.visible)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                }
            }
        }

        private func shareText() -> String {
            var text = "Задача: \(task.title)"
            if !task.details.isEmpty {
                text += "\nОписание: \(task.details)"
            }
            return text
        }
    }

private struct OptionButton: View {
    let systemName: String
    let title: String
    let bgColor: Color
    let action: () -> Void

    init(systemName: String,
         title: String,
         iconColor: Color,
         action: @escaping () -> Void) {
        self.systemName = systemName
        self.title = title
        self.bgColor = iconColor
        self.action = action
    }

    var body: some View {
        VStack(spacing: 8) {
            Button {
                action() // Исправляем вызов действия
            } label: {
                Image(systemName: systemName)
                    .font(.system(size: 20))
                    .foregroundColor(bgColor)
                    .frame(width: 56, height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(bgColor, lineWidth: 1)
                    )
            }

            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any] // Элементы для обмена (например, текст)
    let applicationActivities: [UIActivity]? = nil // Дополнительные активности (опционально)

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: applicationActivities
        )
        return activityViewController
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Ничего не нужно обновлять
    }
}
struct AddSubtaskSheet: View {
    @State private var title: String = ""
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Название подзадачи", text: $title)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                Button(action: {
                    if !title.isEmpty {
                        onAdd(title)
                        dismiss()
                    }
                }) {
                    Text("Добавить")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(title.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(title.isEmpty)
            }
            .padding()
            .navigationTitle("Новая подзадача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
}
