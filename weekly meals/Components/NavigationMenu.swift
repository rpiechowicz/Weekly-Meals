import SwiftUI

struct NavigationMenu: View {
    var body: some View {
        TabView() {
            Tab(MenuConstans.Calendar.name, systemImage: MenuConstans.Calendar.icon) {
                CalendarView()
            }
            
            Tab(MenuConstans.Recipes.name, systemImage: MenuConstans.Recipes.icon) {
                RecipesView()
            }
            
            Tab(MenuConstans.Products.name, systemImage: MenuConstans.Products.icon) {
                ProductsView()
            }
            
            Tab(MenuConstans.Settings.name, systemImage: MenuConstans.Settings.icon) {
                SettingsView()
            }
        }.tint(.green)
    }
}

#Preview {
    NavigationMenu()
}
