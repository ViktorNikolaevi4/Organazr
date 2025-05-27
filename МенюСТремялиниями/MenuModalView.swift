import SwiftUI

enum MenuSection {
    case all, tomorrow, tasks, done, notDone, trash
}

struct MenuModalView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (MenuSection) -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // — Кнопка настроек в шапке
                HStack {
                    Spacer()
                    Button { /* … */ } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .padding(.trailing, 16)
                            .padding(.top, 12)
                    }
                }

                // — Меню
                List {
                    Button { select(.all) }          label: { Label("Все",                systemImage: "tray.fill") }
                    Button { select(.tomorrow) }     label: { Label("Завтра",             systemImage: "sunrise.fill") }
                    Button { select(.tasks) }        label: { Label("Задачи",             systemImage: "list.bullet") }
                    Button { select(.done) }         label: { Label("Выполнено",          systemImage: "checkmark.circle.fill") }
                    Button { select(.notDone) }      label: { Label("Не будет выполнено", systemImage: "xmark.circle.fill") }
                    Button { select(.trash) }        label: { Label("Корзина",            systemImage: "trash.fill") }
                }
                .listStyle(.insetGrouped)
            }

            // — Плавающая кнопка «Добавить» —
            Button { /* … */ } label: {
                Label("Добавить", systemImage: "plus")
                    .font(.headline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .shadow(radius: 4, y: 2)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
    }

    private func select(_ section: MenuSection) {
        dismiss()               // сначала закрываем меню
        onSelect(section)       // передаём выбранную секцию в HomeView
    }
}
