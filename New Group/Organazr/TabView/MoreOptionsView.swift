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
    var body: some View {
        ZStack {
            // фон на весь экран
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Верхняя панель из четырёх кнопок
                HStack(alignment: .top, spacing: 16) {
                    OptionButton(
                        systemName: "pin.fill",
                        title: "Закрепить",
                        bgColor: .yellow
                    )
                    OptionButton(
                        systemName: "square.and.arrow.up",
                        title: "Поделиться",
                        bgColor: .green
                    )
                    OptionButton(
                        systemName: "xmark.circle.fill",
                        title: "Не буду делать",
                        bgColor: .blue
                    )
                    OptionButton(
                        systemName: "trash.fill",
                        title: "Удалить",
                        bgColor: .red
                    )
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
                         // разделитель между ячейками
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
         }
     }
 }

private struct OptionButton: View {
    let systemName: String
    let title: String
    let bgColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Button {
                // TODO
            } label: {
                Image(systemName: systemName)
                    .font(.system(size: 20))
                    .foregroundColor(bgColor)          // иконка — в цвете bgColor
                    .frame(width: 56, height: 56)
                    .background(Color.white)           // фон — белый
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(                          // тонкая граница
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

