import SwiftUI

struct TaskDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var task: TaskItem  // это ваша SwiftData-модель
    var onDismiss: () -> Void

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
          // флажок
          Button {
            // переключить флажок…
          } label: {
            Image(systemName: "flag")
          }
        }
        .font(.title2)

        // Заголовок задачи
        Text(task.title)
          .font(.largeTitle)
          .bold()

        // Здесь можно вывести описание, дату, теги и всё остальное…
        Text("Здесь будет подробное описание вашей задачи.")
          .foregroundColor(.secondary)

        Spacer()
      }
      .padding()
      .navigationTitle("Задачи")            // <- вместо «Входящие»
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
            // какие-то доп. действия…
          } label: {
            Image(systemName: "ellipsis")
          }
        }
      }
    }
  }
}

