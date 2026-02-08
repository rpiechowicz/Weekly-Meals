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

    var body: some Scene {
        WindowGroup {
//            AuthView()
            DashboardView()
                .environment(\.weeklyMealStore, mealStore)
                .environment(\.datesViewModel, datesViewModel)
        }
    }
}
