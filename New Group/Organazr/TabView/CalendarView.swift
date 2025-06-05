import SwiftUI

struct CalendarView: View {
    @State private var selectedDate: Date = Date()

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ru_RU")
        cal.firstWeekday = 2 // неделя начинается с понедельника
        return cal
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGray6)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    monthHeader
                    Divider()
                    weekdayHeader
                    calendarGrid
                    Spacer()
                    emptyDayView
                    Spacer()
                }

                // Плюс-кнопка (без логики)
                Button {
                    // ничего не делаем
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
            .navigationTitle(monthName(of: selectedDate).capitalized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var monthHeader: some View {
        HStack {
            Text("\(monthName(of: selectedDate)) \(yearString(of: selectedDate))")
                .font(.headline)
                .padding(.leading, 16)
            Spacer()
            Button {
                if let prev = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
                    selectedDate = prev
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(.specialBlue)
                    .font(.system(size: 20, weight: .medium))
            }
            Button {
                if let next = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
                    selectedDate = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(.specialBlue)
                    .font(.system(size: 20, weight: .medium))
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private var weekdayHeader: some View {
        let symbols = calendar.shortWeekdaySymbols
        let startIndex = calendar.firstWeekday - 1 // 1 = Sunday, 2 = Monday
        let ordered = Array(symbols[startIndex...] + symbols[..<startIndex])

        return HStack {
            ForEach(ordered, id: \.self) { day in
                Text(day.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }

    private var calendarGrid: some View {
        let days = makeDaysForCalendarGrid(for: selectedDate)

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 7),
            spacing: 8
        ) {
            ForEach(days, id: \.self) { date in
                dayCell(for: date)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let dayNumber = calendar.component(.day, from: date)
        let isFromCurrentMonth = calendar.isDate(date, equalTo: selectedDate, toGranularity: .month)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)

        ZStack {
            // 1) Если дата — выбранная, рисуем «закрашенный» кружок:
            if isSelected {
                Circle()
                    .fill(Color.specialBlue)
                    .frame(width: 32, height: 32)
            }
            // 2) Если дата — сегодняшняя, но не является одновременно выбранной,
            //    рисуем тонкий контурный кружок:
            else if isToday {
                Circle()
                    .stroke(Color.specialBlue, lineWidth: 1.5)
                    .frame(width: 32, height: 32)
            }

            // 3) Сам текст числа. Цвет зависит от того, из какого месяца:
            Text("\(dayNumber)")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(isFromCurrentMonth
                    ? (isSelected ? .white : .primary)
                    : .secondary
                )
                .frame(width: 32, height: 32)
        }
        .onTapGesture {
            selectedDate = date
        }
    }

    // MARK: — “У вас есть свободный день”
    private var emptyDayView: some View {
        VStack(spacing: 8) {
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
    }

    // MARK: — Вспомогательные методы

    private func makeDaysForCalendarGrid(for referenceDate: Date) -> [Date] {
        guard let startOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: referenceDate)
        ) else {
            return []
        }
        let weekdayOfFirst = calendar.component(.weekday, from: startOfMonth)
        let offset = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -offset, to: startOfMonth) else {
            return []
        }
        return (0..<42).compactMap { delta in
            calendar.date(byAdding: .day, value: delta, to: gridStart)
        }
    }

    private func monthName(of date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "LLLL"
        return df.string(from: date)
    }

    private func yearString(of date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy"
        return df.string(from: date)
    }
}

struct CalendarTabIcon: View {
    var body: some View {
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
