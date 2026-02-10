//
//  weekly_mealsApp.swift
//  weekly meals
//
//  Created by Rafi on 03/02/2026.
//

import SwiftUI

@main
struct weekly_mealsApp: App {
    @State private var mealStore = WeeklyMealStore()
    @State private var datesViewModel = DatesViewModel()
    @State private var settingsStore = SettingsStore()
    @State private var recipeCatalogStore = RecipeCatalogStore()

    var body: some Scene {
        WindowGroup {
//            AuthView()
            DashboardView()
                .environment(\.weeklyMealStore, mealStore)
                .environment(\.datesViewModel, datesViewModel)
                .environment(\.settingsStore, settingsStore)
                .environment(\.recipeCatalogStore, recipeCatalogStore)
                .preferredColorScheme(settingsStore.selectedTheme.colorScheme)
        }
    }
}
