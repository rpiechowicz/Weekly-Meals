import SwiftUI

// Używa API zgodnego z iOS 17+ (Tab + init(selection:content:) to iOS 18+)
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
            RecipesView()
                .tabItem {
                    Label(MenuConstans.Recipes.name, systemImage: MenuConstans.Recipes.icon)
                }
                .tag(DashboardTab.recipes)

            WeeklyPlanView()
                .tabItem {
                    Label(MenuConstans.Plan.name, systemImage: MenuConstans.Plan.icon)
                }
                .tag(DashboardTab.plan)

            CalendarView()
                .tabItem {
                    Label(MenuConstans.Calendar.name, systemImage: MenuConstans.Calendar.icon)
                }
                .tag(DashboardTab.calendar)

            ProductsView()
                .tabItem {
                    Label(MenuConstans.Products.name, systemImage: MenuConstans.Products.icon)
                }
                .tag(DashboardTab.products)

            SettingsView()
                .tabItem {
                    Label(MenuConstans.Settings.name, systemImage: MenuConstans.Settings.icon)
                }
                .tag(DashboardTab.settings)
        }
        .tint(.blue)
    }
}

#Preview {
    NavigationMenu()
}
