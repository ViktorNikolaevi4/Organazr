import SwiftUI
import PhotosUI
import UIKit
import VisionKit

struct TaskDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem
    var onDismiss: () -> Void

    @State private var showingPriorityPopover = false
    @State private var showMoreOptions = false
    @State private var showImagePicker = false
    @State private var showPhotoPicker = false
    @State private var showDocumentScanner = false
    @State private var showTextScanner = false
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            contentView
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
                .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
                .onChange(of: selectedPhotoItem) { newItem in
                    guard let item = newItem else { return }

                    Task {
                        do {
                            if let data = try await item.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                selectedImage = uiImage
                                saveImageToTask(uiImage)
                            }
                        } catch {
                            print("Ошибка загрузки фото: \(error)")
                        }
                        selectedPhotoItem = nil
                    }
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(sourceType: .camera) { image in
                        selectedImage = image
                        saveImageToTask(image)
                    }
                }
                .sheet(isPresented: $showDocumentScanner) {
                    DocumentScanner { images in
                        if let firstImage = images.first {
                            selectedImage = firstImage
                            saveImageToTask(firstImage)
                        }
                    }
                }
                .sheet(isPresented: $showTextScanner) {
                    TextScanner { recognizedText in
                        if !recognizedText.isEmpty {
                            task.details += "\n\(recognizedText)"
                            do {
                                try modelContext.save()
                            } catch {
                                print("Ошибка сохранения текста: \(error)")
                            }
                        }
                    }
                }
        }
    }

    private var contentView: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: — Кнопки управления задачей
            HStack {
                Button {
                    task.isCompleted.toggle()
                    saveChanges() // Сохраняем изменения
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                }
                Spacer()
                Button {
                    showingPriorityPopover = true
                } label: {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(flagColor(for: task.priority))
                }
                .popover(isPresented: $showingPriorityPopover, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Priority.allCases, id: \.self) { level in
                            Button(action: {
                                task.priority = level
                                showingPriorityPopover = false
                                saveChanges() // Сохраняем изменения
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
                    .frame(width: 350)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .presentationCompactAdaptation(.popover)
                }
            }
            .font(.title2)

            // MARK: редактируемый заголовок
            TextField("Заголовок задачи", text: $task.title, onCommit: {
                saveChanges() // Сохраняем при завершении редактирования
            })
            .font(.largeTitle.weight(.bold))
            .padding(.horizontal, 4)

            // MARK: редактируемое многострочное описание
            TextEditor(text: $task.details)
                .padding(4)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .frame(minHeight: 150)
                .onChange(of: task.details) { _ in
                    saveChanges() // Сохраняем при изменении текста
                }

            // MARK: Отображение прикрепленного изображения
            if let imageData = task.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                    .padding(.horizontal, 4)
            }

            // MARK: Кнопка для добавления вложения
            Menu {

                Button(action: {
                    showDocumentScanner = true
                }) {
                    Label("Сканировать документ", systemImage: "doc.text")
                }

                Button(action: {
                    showTextScanner = true
                }) {
                    Label("Сканировать текст", systemImage: "textformat")
                }

                Button(action: {
                    showImagePicker = true
                }) {
                    Label("Сделать фото", systemImage: "camera")
                }

                Button(action: {
                    showPhotoPicker = true
                }) {
                    Label("Выбрать фото", systemImage: "photo")
                }

            } label: {
                HStack {
                    Image(systemName: "paperclip")

                    Text("Добавить вложение")
                }
                .foregroundStyle(.specialBlue)
            }

            Spacer()
        }
        .padding()
    }
}

    private func flagColor(for priority: Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .yellow
        case .low: return .blue
        case .none: return .gray
        }
    }

    private func label(for priority: Priority) -> String {
        switch priority {
        case .high: return "Высокий приоритет"
        case .medium: return "Средний приоритет"
        case .low: return "Низкий приоритет"
        case .none: return "Без приоритета"
        }
    }

    private func saveImageToTask(_ image: UIImage) {
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            task.imageData = imageData
            saveChanges()
        }
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            print("Ошибка сохранения изменений: \(error)")
        }
    }
}
