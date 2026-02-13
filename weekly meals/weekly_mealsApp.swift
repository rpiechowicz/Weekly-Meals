//
//  weekly_mealsApp.swift
//  weekly meals
//
//  Created by Rafi on 03/02/2026.
//

import SwiftUI

@main
struct weekly_mealsApp: App {
    @State private var sessionStore = SessionStore()
    @AppStorage("settings.theme") private var themeRawValue: String = AppTheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            Group {
                if sessionStore.isAuthenticated,
                   let mealStore = sessionStore.weeklyMealStore,
                   let recipeCatalogStore = sessionStore.recipeCatalogStore,
                   let shoppingListStore = sessionStore.shoppingListStore {
                    DashboardView()
                        .environment(\.weeklyMealStore, mealStore)
                        .environment(\.datesViewModel, sessionStore.datesViewModel)
                        .environment(\.recipeCatalogStore, recipeCatalogStore)
                        .environment(\.shoppingListStore, shoppingListStore)
                } else if sessionStore.isAuthenticated {
                    NoHouseholdView(
                        isLoading: sessionStore.isSigningIn,
                        errorMessage: sessionStore.authError,
                        onCreate: { name in
                            Task {
                                await sessionStore.createHousehold(name: name)
                            }
                        },
                        onLogout: {
                            sessionStore.logout()
                        }
                    )
                } else {
                    AuthView(
                        isLoading: sessionStore.isSigningIn,
                        errorMessage: sessionStore.authError,
                        onLoginTap: { displayName, email in
                            Task {
                                await sessionStore.loginDev(displayName: displayName, email: email)
                            }
                        }
                    )
                }
            }
            .environment(\.sessionStore, sessionStore)
            .preferredColorScheme((AppTheme(rawValue: themeRawValue) ?? .system).colorScheme)
            .onOpenURL { url in
                sessionStore.handleIncomingURL(url)
            }
        }
    }
}
