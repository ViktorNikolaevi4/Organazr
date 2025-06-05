import SwiftUI

struct CalendarView: View {
    /// Текусщая выбранная дата в календаре.
    @State private var selectedDate: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // Фон
                Color(.systemGray6)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Системный DatePicker в графическом стиле, он отрисует
                    // текущий месяц, стрелки, сетку из дней. Мы прячем текстовое поле,
                    // так как показывать нам достаточно только графический календарь.
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .accentColor(.specialBlue) // цвет выделения сегодняшнего дня
                    .environment(\.locale, Locale(identifier: "ru_RU")) // русский локал
                    .padding(.horizontal, 16)

                    // ----------------------------------
                    // Ниже – место, где показываем сообщение «У вас есть свободный день»
                    // (если на выбранную дату нет задач).
                    // Для примера всегда показываем, можно по условию прятать.
                    // ----------------------------------
                    Spacer()

                    VStack(spacing: 8) {
                        // Иллюстрация (можете заменить на свой ассет или SF Symbol)
                        // Если у вас есть картинка-иконка календаря, добавьте её в Assets
                        Image(systemName: "calendar.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.specialBlue)

                        Text("У вас есть свободный день")
                            .font(.title2.weight(.semibold))

                        Text("Расслабьтесь")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                    Spacer()
                }

                // ----------------------------------
                // Плюс-кнопка в правом нижнем углу (без логики)
                // Такой же стиль, как в HomeView
                // ----------------------------------
                Button {
                    // Ничего не делаем — только визуал
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 64))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .specialBlue)
                        .shadow(radius: 4, y: 2)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 40)
            }
            // ----------------------------------
            // Навигационный заголовок: выводим название месяца (например, "май")
            // Можно динамически вычислять из selectedDate.
            // ----------------------------------
            .navigationTitle(monthName(from: selectedDate))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// Возвращает название месяца для переданной даты (по-русски, с заглавной буквы).
    private func monthName(from date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "LLLL"   // полное название месяца
        let name = df.string(from: date)
        return name.capitalized  // чтобы первая буква была заглавной
    }
}

struct CalendarTabIcon: View {
    var body: some View {
        // Пересчитываем представление раз в минуту
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let day = Calendar.current.component(.day, from: context.date)
            ZStack {
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .regular))
                Text("\(day)")
                    .font(.system(size: 12, weight: .bold))
                    .offset(y: -1)
            }
        }
    }
}
