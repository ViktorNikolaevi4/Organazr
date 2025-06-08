import SwiftUI
import PhotosUI
import VisionKit
import SwiftData
import AVFoundation

struct TaskDetailSheet: View {
    // MARK: — Окружение
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Основная задача
    @Bindable var task: TaskItem
    let onDismiss: () -> Void

    // MARK: — Состояния
    @State private var showingPriorityPopover = false
    @State private var showMoreOptions = false
    @State private var showImagePicker = false
    @State private var showPhotoPicker = false
    @State private var showDocumentScanner = false
    @State private var showTextScanner = false
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?

    // Для работы с подзадачами
    @State private var showAddSubtaskFromDetail = false
    @State private var selectedSubtask: TaskItem? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // — Кнопки «галочка» + приоритет
                    headerControls

                    // — Заголовок и описание
                    TextField("Заголовок задачи", text: $task.title, onCommit: saveChanges)
                        .font(.largeTitle.weight(.bold))
                        .padding(.horizontal, 4)

                    TextEditor(text: $task.details)
                        .padding(4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(minHeight: 150)
                        .onChange(of: task.details) { _ in saveChanges() }

                    // — Изображение, если есть
                    if let imageData = task.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                            .padding(.horizontal, 4)
                    }

                    // — Меню вложений
                    attachmentMenu

                    // — Список подзадач
                    if !task.subtasks.isEmpty {
                        Divider().padding(.vertical, 4)

                        VStack(spacing: 0) {
                            ForEach(task.subtasks) { sub in
                                Button {
                                    selectedSubtask = sub
                                } label: {
                                    HStack {
                                        Image(systemName: sub.isCompleted
                                                ? "checkmark.square.fill"
                                                : "square")
                                        Text(sub.title)
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                }
                                .buttonStyle(.plain)

                                Divider()
                            }

                            // Кнопка «+ Добавить подзадачу»
                            Button {
                                showAddSubtaskFromDetail = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Добавить подзадачу")
                                }
                                .foregroundStyle(.specialBlue)
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                            }

                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        // чуть отступаем от самого низа
                        .padding(.bottom, 24)
                    }

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .navigationTitle("Задачи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onDismiss() }
                    label: { Image(systemName: "chevron.down") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showMoreOptions = true }
                    label: { Image(systemName: "ellipsis") }
                }
            }
            // MARK: — Листы и шиты

            // moreOptions, imagePicker, photoPicker, docScanner, textScanner...
            .sheet(isPresented: $showMoreOptions) {
                MoreOptionsView(task: task) {
                    // при необходимости, можно закрыть и этот шит
                    showMoreOptions = false
                }
                .presentationDetents([.fraction(0.75)])
                .presentationDragIndicator(.visible)
            }
            .photosPicker(isPresented: $showPhotoPicker,
                          selection: $selectedPhotoItem,
                          matching: .images)
            .onChange(of: selectedPhotoItem) { newItem in
                // … загрузка фото аналогично вашему коду …
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: .camera) { image in
                    selectedImage = image
                    saveImageToTask(image)
                }
            }
            .sheet(isPresented: $showDocumentScanner) {
                DocumentScanner { images in
                    if let first = images.first { saveImageToTask(first) }
                }
            }
            .sheet(isPresented: $showTextScanner) {
                TextScanner { recognized in
                    if !recognized.isEmpty {
                        task.details += "\n\(recognized)"
                        saveChanges()
                    }
                }
            }

            // Лист для создания подзадачи прямо из детали
            .sheet(isPresented: $showAddSubtaskFromDetail) {
                AddSubtaskSheet { title in
                    let newSub = TaskItem(title: title, parentTask: task)
                    modelContext.insert(newSub)
                    saveChanges()
                    showAddSubtaskFromDetail = false
                } onAddSubtask: {
                    showAddSubtaskFromDetail = false
                }
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
            }

            // Редактирование выбранной подзадачи
            .sheet(item: $selectedSubtask) { sub in
                TaskDetailSheet(task: sub) {
                    selectedSubtask = nil
                }
            }
        }
    }

    // MARK: — Вспомогательные вью-модели

    private var headerControls: some View {
        HStack {
            Button { task.isCompleted.toggle(); saveChanges() }
            label: { Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square") }
            Spacer()
            Button { showingPriorityPopover = true }
            label: {
                Image(systemName: "flag.fill")
                    .foregroundStyle(flagColor(for: task.priority))
            }
            .popover(isPresented: $showingPriorityPopover) {
                priorityPicker
            }
        }
        .font(.title2)
    }

    private var priorityPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Priority.allCases, id: \.self) { level in
                Button {
                    task.priority = level
                    showingPriorityPopover = false
                    saveChanges()
                } label: {
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(flagColor(for: level))
                        Text(label(for: level))
                        Spacer()
                        if level == task.priority {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                if level != Priority.allCases.last { Divider() }
            }
        }
        .frame(width: 300)
    }

    private var attachmentMenu: some View {
        Menu {
            Button("Сканировать документ") { showDocumentScanner = true }
            Button("Сканировать текст")   { showTextScanner = true }
            Button("Сделать фото")         { showImagePicker = true }
            Button("Выбрать фото")         { showPhotoPicker = true }
        } label: {
            Label("Добавить вложение", systemImage: "paperclip")
                .foregroundStyle(.specialBlue)
        }
    }

    // MARK: — Сохранение и цвета

    private func saveImageToTask(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            task.imageData = data
            saveChanges()
        }
    }

    private func saveChanges() {
        do { try modelContext.save() }
        catch { print("Ошибка сохранения: \(error)") }
    }

    private func flagColor(for priority: Priority) -> Color {
        switch priority {
        case .high:   return .red
        case .medium: return .yellow
        case .low:    return .blue
        case .none:   return .gray
        }
    }

    private func label(for priority: Priority) -> String {
        switch priority {
        case .high:   return "Высокий приоритет"
        case .medium: return "Средний приоритет"
        case .low:    return "Низкий приоритет"
        case .none:   return "Без приоритета"
        }
    }
}
