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
                    Text("Дом")
                }
                .tag(0)

            // 2. Поиск
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Поиск")
                }
                .tag(1)

            // 3. Добавить
            AddView()
                .tabItem {
                    Image(systemName: "plus.app.fill")
                    Text("Добавить")
                }
                .tag(2)

            // 4. Избранное
            FavoritesView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Избранное")
                }
                .tag(3)

            // 5. Профиль
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Профиль")
                }
                .tag(4)
        }
        // укажем цвет активного таба
        .tint(.specialBlue)
    }
}
