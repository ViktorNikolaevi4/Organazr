import SwiftUI
import SwiftData

enum MenuSection {
    case all, today, tomorrow, tasks, done, notDone, trash // Добавляем today
}

enum MenuSelection {
    case system(MenuSection)  // ваши «Все», «Сегодня», «Завтра» и т.п.
    case custom(TaskList)     // пользовательский
}

struct MenuModalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let onSelect: (MenuSelection) -> Void

    // Открыть sheet для создания списка
    @State private var showAddNew = false
    @State private var newListName = ""

    @State private var showEditList = false
    @State private var listToEdit: TaskList?
    @State private var editedListName = ""

    // Для подтверждения удаления
    @State private var showDeleteConfirmation = false
    @State private var listToDelete: TaskList?

    // Загружаем из базы все списки, отсортированные по названию
    @Query(sort: [SortDescriptor(\TaskList.title, order: .forward)])
    private var userLists: [TaskList]

    // Загружаем все задачи для возможности удаления
    @Query(sort: [SortDescriptor(\TaskItem.title, order: .forward)])
    private var allTasks: [TaskItem]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(.systemGray6).ignoresSafeArea()

            VStack(spacing: 0) {
                // Шапка
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
                                } label: {
                                    Label(list.title, systemImage: "list.bullet")
                                }
                                .swipeActions(edge: .trailing) {
                                    // Кнопка удаления
                                    Button(role: .destructive) {
                                        listToDelete = list
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                    .tint(.red)
                                    // Кнопка редактирования
                                    Button {
                                        listToEdit = list
                                        editedListName = list.title
                                        showEditList = true
                                    } label: {
                                        Label("Редактировать", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }

                    // 2) Стандартные пункты
                    Section("Системные") {
                        Button { select(.all) }      label: { Label("Все",                 systemImage: "tray.fill") }
                        Button { select(.today) }    label: { Label("Сегодня",            systemImage: "sun.max.fill") } // Добавляем "Сегодня"
                        Button { select(.tomorrow) } label: { Label("Завтра",              systemImage: "sunrise.fill") }
                        Button { select(.tasks) }    label: { Label("Задачи",              systemImage: "list.bullet") }
                        Button { select(.done) }     label: { Label("Выполнено",           systemImage: "checkmark.circle.fill") }
                        Button { select(.notDone) }  label: { Label("Не будет выполнено",  systemImage: "xmark.circle.fill") }
                        Button { select(.trash) }    label: { Label("Корзина",             systemImage: "trash.fill") }
                    }
                }
                .listStyle(.insetGrouped)
            }

            // Плавающая кнопка «Добавить»
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
        // Sheet для создания нового списка
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
                            modelContext.insert(TaskList(title: trimmed))
                            showAddNew = false
                            newListName = ""
                        }
                    }
                }
            }
        }
        // Sheet для редактирования списка
        .sheet(item: $listToEdit) { list in
            NavigationStack {
                Form {
                    Section {
                        TextField("Имя списка", text: $editedListName)
                    }
                }
                .navigationTitle("Редактировать список")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") {
                            showEditList = false
                            listToEdit = nil
                            editedListName = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") {
                            let trimmed = editedListName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            list.title = trimmed
                            showEditList = false
                            listToEdit = nil
                            editedListName = ""
                        }
                    }
                }
            }
        }
        // Диалог подтверждения удаления
        .confirmationDialog(
            "Удалить список?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                if let list = listToDelete {
                    deleteList(list)
                }
                listToDelete = nil
            }
            Button("Отмена", role: .cancel) {
                listToDelete = nil
            }
        } message: {
            Text("Все задачи в этом списке будут удалены.")
        }
    }

    private func select(_ section: MenuSection) {
        dismiss()
        onSelect(.system(section))
    }

    private func deleteList(_ list: TaskList) {
        // Получаем все задачи, связанные с этим списком
        let tasksToDelete = allTasks.filter { $0.list?.id == list.id }
        // Удаляем все связанные задачи
        for task in tasksToDelete {
            modelContext.delete(task)
        }
        // Удаляем сам список
        modelContext.delete(list)
    }
}
