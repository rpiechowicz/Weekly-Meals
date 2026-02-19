import SwiftUI

struct NavigationMenu: View {
    private enum DashboardTab: Hashable {
        case recipes
        case plan
        case calendar
        case products
        case settings
    }

    @State private var selectedTab: DashboardTab = .calendar

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(MenuConstans.Recipes.name, systemImage: MenuConstans.Recipes.icon, value: DashboardTab.recipes) {
                RecipesView()
            }
            
            Tab(MenuConstans.Plan.name, systemImage: MenuConstans.Plan.icon, value: DashboardTab.plan) {
                WeeklyPlanView()
            }
            
            Tab(MenuConstans.Calendar.name, systemImage: MenuConstans.Calendar.icon, value: DashboardTab.calendar) {
                CalendarView()
            }
            
            Tab(MenuConstans.Products.name, systemImage: MenuConstans.Products.icon, value: DashboardTab.products) {
                ProductsView()
            }
            
            Tab(MenuConstans.Settings.name, systemImage: MenuConstans.Settings.icon, value: DashboardTab.settings) {
                SettingsView()
            }
        }
        .tint(.blue)
        .onAppear {
            selectedTab = .calendar
        }
    }
}

#Preview {
    NavigationMenu()
}
