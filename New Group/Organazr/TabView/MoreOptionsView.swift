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
                        systemName: "xmark.circle.fill",
                        title: "Не буду делать",
                        iconColor: .blue
                    ) {
                        task.isNotDone = true // Помечаем задачу как "не будет сделана"
                        dismiss() // Закрываем меню
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

