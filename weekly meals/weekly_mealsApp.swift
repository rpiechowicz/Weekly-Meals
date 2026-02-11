//
//  weekly_mealsApp.swift
//  weekly meals
//
//  Created by Rafi on 03/02/2026.
//

import SwiftUI

@main
struct weekly_mealsApp: App {
    @State private var mealStore: WeeklyMealStore
    @State private var datesViewModel = DatesViewModel()
    @State private var recipeCatalogStore: RecipeCatalogStore
    @State private var shoppingListStore: ShoppingListStore

    init() {
        let userId = "edbc139a-636b-4aaf-953f-9b4644eb8b55"
        let householdId = "f6478b3a-5f76-47fd-94cd-e85c2564e366"
        let socketClient = SocketIORecipeSocketClient(
            baseURL: URL(string: "http://localhost:3000")!
        )
        let transport = WebSocketRecipeTransportClient(
            socket: socketClient,
            userId: userId,
            householdId: householdId
        )
        let repository = ApiRecipeRepository(client: transport)
        let weeklyPlanTransport = WebSocketWeeklyPlanTransportClient(
            socket: socketClient,
            userId: userId,
            householdId: householdId
        )
        let weeklyPlanRepository = ApiWeeklyPlanRepository(client: weeklyPlanTransport)
        let shoppingTransport = WebSocketShoppingListTransportClient(
            socket: socketClient,
            userId: userId,
            householdId: householdId
        )
        let shoppingRepository = ApiShoppingListRepository(client: shoppingTransport)
        _mealStore = State(initialValue: WeeklyMealStore(weeklyPlanRepository: weeklyPlanRepository))
        _recipeCatalogStore = State(initialValue: RecipeCatalogStore(repository: repository))
        _shoppingListStore = State(initialValue: ShoppingListStore(repository: shoppingRepository))
    }

    var body: some Scene {
        WindowGroup {
//            AuthView()
            DashboardView()
                .environment(\.weeklyMealStore, mealStore)
                .environment(\.datesViewModel, datesViewModel)
                .environment(\.recipeCatalogStore, recipeCatalogStore)
                .environment(\.shoppingListStore, shoppingListStore)
        }
    }
}
