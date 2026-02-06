import Foundation
import Observation

@Observable
class MealPlanViewModel {
    // MARK: - State

    var isActive: Bool = false

    var breakfastRecipes: [Recipe] = []
    var lunchRecipes: [Recipe] = []
    var dinnerRecipes: [Recipe] = []

    var slotFullAlert: MealSlot? = nil
    var showSummarySheet: Bool = false

    // MARK: - Constants

    static let maxPerSlot = 7
    static let maxTotal = 21

    // MARK: - Computed

    var totalCount: Int {
        breakfastRecipes.count + lunchRecipes.count + dinnerRecipes.count
    }

    // MARK: - Actions

    func isSelected(_ recipe: Recipe) -> Bool {
        recipes(for: recipe).contains { $0.id == recipe.id }
    }

    func recipeCount(_ recipe: Recipe) -> Int {
        recipes(for: recipe).filter { $0.id == recipe.id }.count
    }

    func toggleRecipe(_ recipe: Recipe) {
        guard recipe.category.toMealSlot != nil else { return }

        if isSelected(recipe) {
            removeAllOfRecipe(recipe)
        } else {
            addRecipe(recipe)
        }
    }

    func incrementRecipe(_ recipe: Recipe) {
        addRecipe(recipe)
    }

    func decrementRecipe(_ recipe: Recipe) {
        removeOneOfRecipe(recipe)
    }

    func canAdd(to slot: MealSlot) -> Bool {
        count(for: slot) < Self.maxPerSlot
    }

    func count(for slot: MealSlot) -> Int {
        switch slot {
        case .breakfast: breakfastRecipes.count
        case .lunch:     lunchRecipes.count
        case .dinner:    dinnerRecipes.count
        }
    }

    func recipes(for slot: MealSlot) -> [Recipe] {
        switch slot {
        case .breakfast: breakfastRecipes
        case .lunch:     lunchRecipes
        case .dinner:    dinnerRecipes
        }
    }

    /// Unikalne przepisy dla danego slotu (bez duplikatów)
    func uniqueRecipes(for slot: MealSlot) -> [Recipe] {
        var seen = Set<UUID>()
        return recipes(for: slot).filter { seen.insert($0.id).inserted }
    }

    func enterPlanningMode() {
        isActive = true
    }

    func exitPlanningMode() {
        isActive = false
        resetPlan()
    }
    
    func savePlan() {
        isActive = false
        resetPlan()
    }

    func resetPlan() {
        breakfastRecipes = []
        lunchRecipes = []
        dinnerRecipes = []
    }

    // MARK: - Private

    private func recipes(for recipe: Recipe) -> [Recipe] {
        guard let slot = recipe.category.toMealSlot else { return [] }
        return recipes(for: slot)
    }

    private func addRecipe(_ recipe: Recipe) {
        guard let slot = recipe.category.toMealSlot else { return }

        guard canAdd(to: slot) else {
            slotFullAlert = slot
            return
        }

        switch slot {
        case .breakfast: breakfastRecipes.append(recipe)
        case .lunch:     lunchRecipes.append(recipe)
        case .dinner:    dinnerRecipes.append(recipe)
        }
    }

    private func removeAllOfRecipe(_ recipe: Recipe) {
        guard let slot = recipe.category.toMealSlot else { return }

        switch slot {
        case .breakfast: breakfastRecipes.removeAll { $0.id == recipe.id }
        case .lunch:     lunchRecipes.removeAll { $0.id == recipe.id }
        case .dinner:    dinnerRecipes.removeAll { $0.id == recipe.id }
        }
    }

    private func removeOneOfRecipe(_ recipe: Recipe) {
        guard let slot = recipe.category.toMealSlot else { return }

        switch slot {
        case .breakfast:
            if let idx = breakfastRecipes.lastIndex(where: { $0.id == recipe.id }) {
                breakfastRecipes.remove(at: idx)
            }
        case .lunch:
            if let idx = lunchRecipes.lastIndex(where: { $0.id == recipe.id }) {
                lunchRecipes.remove(at: idx)
            }
        case .dinner:
            if let idx = dinnerRecipes.lastIndex(where: { $0.id == recipe.id }) {
                dinnerRecipes.remove(at: idx)
            }
        }
    }
}
