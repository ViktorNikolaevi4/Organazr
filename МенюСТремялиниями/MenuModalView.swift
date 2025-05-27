import SwiftUI

enum MenuSection {
    case all, tomorrow, tasks, done, notDone, trash
}
enum MenuSelection {
  case system(MenuSection)  // ваши «Все», «Завтра» и т.п.
  case custom(TaskList)     // пользовательский
}

import SwiftUI
import SwiftData

struct MenuModalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    let onSelect: (MenuSelection) -> Void

    // Открыть sheet для создания списка
    @State private var showAddNew = false
    @State private var newListName = ""

    // Загружаем из базы все списки, отсортированные по названию
    @Query(sort: [SortDescriptor(\TaskList.title, order: .forward)])
    private var userLists: [TaskList]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(.systemGray6).ignoresSafeArea()

            VStack(spacing: 0) {
                // шапка
                HStack {
                    Spacer()
                    Button { /* … */ } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .padding(.trailing, 16)
                            .padding(.top, 12)
                    }
                }

                List {
                    // 1) Секции ваших списков из SwiftData
                    if !userLists.isEmpty {
                        Section("Мои списки") {
                            ForEach(userLists) { list in
                              Button {
                                dismiss()
                                onSelect(.custom(list))
                              } label: { Label(list.title, systemImage: "list.bullet") }
                            }
                        }
                    }

                    // 2) Стандартные пункты
                    Section("Системные") {
                        Button { select(.all) }      label: { Label("Все",                 systemImage: "tray.fill") }
                        Button { select(.tomorrow) } label: { Label("Завтра",              systemImage: "sunrise.fill") }
                        Button { select(.tasks) }    label: { Label("Задачи",              systemImage: "list.bullet") }
                        Button { select(.done) }     label: { Label("Выполнено",           systemImage: "checkmark.circle.fill") }
                        Button { select(.notDone) }  label: { Label("Не будет выполнено",  systemImage: "xmark.circle.fill") }
                        Button { select(.trash) }    label: { Label("Корзина",             systemImage: "trash.fill") }
                    }
                }
                .listStyle(.insetGrouped)
            }

            // плавающая кнопка «Добавить»
            Button {
                showAddNew = true
            } label: {
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
        // sheet для создания нового списка
        .sheet(isPresented: $showAddNew) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Имя списка", text: $newListName)
                    }
                }
                .navigationTitle("Создать список")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") {
                            showAddNew = false
                            newListName = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") {
                            let trimmed = newListName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            // Вставляем новый объект TaskList в контекст SwiftData
                            modelContext.insert(TaskList(title: trimmed))
                            showAddNew = false
                            newListName = ""
                        }
                    }
                }
            }
        }
    }

    private func select(_ section: MenuSection) {
      dismiss()
      onSelect(.system(section))
    }
}
