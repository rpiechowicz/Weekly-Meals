import Foundation

// MARK: - DayMealPlan

struct DayMealPlan: Codable, Identifiable {
    var id: String { dateKey }
    let dateKey: String // "yyyy-MM-dd"
    var breakfast: Recipe?
    var lunch: Recipe?
    var dinner: Recipe?

    func recipe(for slot: MealSlot) -> Recipe? {
        switch slot {
        case .breakfast: breakfast
        case .lunch: lunch
        case .dinner: dinner
        }
    }

    mutating func setRecipe(_ recipe: Recipe?, for slot: MealSlot) {
        switch slot {
        case .breakfast: breakfast = recipe
        case .lunch: lunch = recipe
        case .dinner: dinner = recipe
        }
    }

    var allRecipes: [Recipe] {
        [breakfast, lunch, dinner].compactMap { $0 }
    }
}

// MARK: - PlanEntry

struct PlanEntry: Codable, Identifiable {
    let id: UUID
    let recipe: Recipe
    var isSelected: Bool

    init(recipe: Recipe, isSelected: Bool = false) {
        self.id = UUID()
        self.recipe = recipe
        self.isSelected = isSelected
    }
}

// MARK: - SavedMealPlan

struct SavedMealPlan: Codable {
    var breakfastEntries: [PlanEntry] = []
    var lunchEntries: [PlanEntry] = []
    var dinnerEntries: [PlanEntry] = []

    var isEmpty: Bool {
        breakfastEntries.isEmpty && lunchEntries.isEmpty && dinnerEntries.isEmpty
    }

    func entries(for slot: MealSlot) -> [PlanEntry] {
        switch slot {
        case .breakfast: breakfastEntries
        case .lunch: lunchEntries
        case .dinner: dinnerEntries
        }
    }

    /// Wszystkie przepisy (do ProductsView - pełna lista niezależnie od isSelected)
    func allRecipes() -> [Recipe] {
        (breakfastEntries + lunchEntries + dinnerEntries).map(\.recipe)
    }

    /// Dostępne do wybrania w CalendarView (nieoznaczone jako selected)
    func availableRecipes(for slot: MealSlot) -> [Recipe] {
        entries(for: slot).filter { !$0.isSelected }.map(\.recipe)
    }

    /// Liczba dostępnych (niewybranych) dla danego przepisu
    func availableCount(for recipeId: UUID, slot: MealSlot) -> Int {
        entries(for: slot).filter { !$0.isSelected && $0.recipe.id == recipeId }.count
    }
}
