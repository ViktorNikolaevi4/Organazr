import SwiftUI

struct AddTaskSheet: View {
    // Колбэк при успешном добавлении с приоритетом
    var onAdd: (String, Priority) -> Void
    @State private var title = ""
    @State private var selectedPriority: Priority = .none
    @FocusState private var isFocused: Bool
    @State private var showingPriorityPopover = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TextField("Что бы вы хотели сделать?", text: $title)
                    .focused($isFocused)
                    .padding(12)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                    .padding(.horizontal)

                HStack(spacing: 24) {
                    Image(systemName: "calendar")
                    Image(systemName: "clock")
                    // Иконка флажка для выбора приоритета (в ряду с другими иконками)
                    Button {
                        showingPriorityPopover = true
                    } label: {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(flagColor(for: selectedPriority))
                    }
                    .popover(isPresented: $showingPriorityPopover, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Priority.allCases, id: \.self) { level in
                                Button(action: {
                                    selectedPriority = level
                                    showingPriorityPopover = false
                                }) {
                                    HStack {
                                        Image(systemName: "flag.fill")
                                            .foregroundStyle(flagColor(for: level))
                                        Text(label(for: level))
                                            .foregroundStyle(.black)
                                            .font(.headline)
                                        Spacer()
                                        if level == selectedPriority {
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
                        .frame(width: 250)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .presentationCompactAdaptation(.popover)
                    }
                    Image(systemName: "tag")
                    Spacer()
                    Button("Добавить") {
                        onAdd(title, selectedPriority)
                    }
                    .disabled(title.isEmpty)
                }
                .padding(.horizontal)
                .font(.system(size: 20))

                Spacer()
            }
            .padding(.top, 12)
        }
        .onAppear {
            // При появлении сразу открываем клавиатуру
            isFocused = true
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
        case .high: return "Высокий"
        case .medium: return "Средний"
        case .low: return "Низкий"
        case .none: return "Без приоритета"
        }
    }
}
