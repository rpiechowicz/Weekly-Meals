import SwiftUI

struct NavigationMenu: View {
    var body: some View {
        TabView() {
            Tab(MenuConstans.CalendarMenuName, systemImage: MenuConstans.CalendarMenuIcon) {
                CalendarView()
            }
            
            Tab(MenuConstans.RecipesMenuName, systemImage: MenuConstans.RecipesMenuIcon) {
                RecipesView()
            }
            
            Tab(MenuConstans.ProductsMenuName, systemImage: MenuConstans.ProductsMenuIcon) {
                ProductsView()
            }
            
            Tab(MenuConstans.SettingsMenuName, systemImage: MenuConstans.SettingsMenuIcon) {
                SettingsView()
            }
        }.tint(.green)
    }
}

#Preview {
    NavigationMenu()
}
