
import SwiftUI

struct AddTaskSheet: View {
    // колбэк при успешном добавлении
    var onAdd: (String) -> Void
    @State private var title = ""
    @FocusState private var isFocused: Bool

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
                       Image(systemName: "flag")
                       Image(systemName: "tag")
                       Spacer()
                       Button("Добавить") {
                           onAdd(title)
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
               // при появлении сразу открываем клавиатуру
               isFocused = true
           }
       }
   }
