import SwiftUI

struct SearchView: View {
    var body: some View {
        NavigationStack {
            Text("Экран Поиска")
                .navigationTitle("Поиск")
        }
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
