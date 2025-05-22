
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                // Слой-фон на весь экран
                Color(.systemGray6)
                    .ignoresSafeArea()   // заполняет и safe-area

                VStack {            // «толкаем» кнопку вниз
                    Spacer()
                    HStack {        // …и вправо
                        Spacer()
                        Button {
                            // действие кнопки
                        } label: {
                            Image(systemName: "plus.circle.fill") // или "plus.circle.fill"
                                .font(.system(size: 56))           // диаметр ≈56 pt
                                .symbolRenderingMode(.palette)     // красим отдельно заливку и контур
                                .foregroundStyle(.white, .specialBlue)   // белая заливка, чёрный крест
                                .shadow(radius: 4, y: 2)           // лёгкая тень
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 40) // чтобы не задевать «домашнюю полоску»
                    }
                }
            }
            .navigationTitle("Задачи")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {

                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {

                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }.foregroundStyle(.black)
        }
    }
}
