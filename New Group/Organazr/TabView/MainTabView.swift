import SwiftUI

// MARK: –– Ваш главный таб-бар
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. Дом
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Задачи")
                }
                .tag(0)

            // 2. Поиск
            CalendarView()
                .tabItem {
                    // только календарь, без подписи
                    CalendarTabIcon()
                }.tag(1)

            // 3. Добавить
            AddView()
                .tabItem {
                    Image(systemName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
                    Text("Привычка")
                }
                .tag(2)

            // 4. Избранное
            FavoritesView()
                .tabItem {
                    Image(systemName: "circle.circle.fill")
                    Text("Помодоро")
                }
                .tag(3)

            // 5. Профиль
            ProfileView()
                .tabItem {
                    Image(systemName: "die.face.4")
                    Text("Матрица")
                }
                .tag(4)
        }
        // укажем цвет активного таба
        .tint(.specialBlue)
    }
}
