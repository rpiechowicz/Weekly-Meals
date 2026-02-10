import Foundation
import Observation
import SwiftUI

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

// MARK: - WeeklyMealStore

@Observable
class WeeklyMealStore {

    // MARK: - Storage

    private(set) var plans: [String: DayMealPlan] = [:]
    private(set) var savedPlan: SavedMealPlan = SavedMealPlan()

    var hasSavedPlan: Bool { !savedPlan.isEmpty }

    // MARK: - Date formatting

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func dateKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    // MARK: - Init

    init() {
        load()
        loadSavedPlan()
    }

    // MARK: - Read API

    func plan(for date: Date) -> DayMealPlan {
        let key = Self.dateKey(for: date)
        return plans[key] ?? DayMealPlan(dateKey: key)
    }

    func recipe(for date: Date, slot: MealSlot) -> Recipe? {
        plan(for: date).recipe(for: slot)
    }

    func allRecipes(for dates: [Date]) -> [Recipe] {
        dates.flatMap { plan(for: $0).allRecipes }
    }

    // MARK: - Write API

    func setRecipe(_ recipe: Recipe?, for date: Date, slot: MealSlot) {
        let key = Self.dateKey(for: date)
        var dayPlan = plans[key] ?? DayMealPlan(dateKey: key)
        dayPlan.setRecipe(recipe, for: slot)
        plans[key] = dayPlan
        save()
    }

    func clearRecipe(for date: Date, slot: MealSlot) {
        setRecipe(nil, for: date, slot: slot)
    }

    func clearWeek(dates: [Date]) {
        for date in dates {
            let key = Self.dateKey(for: date)
            plans.removeValue(forKey: key)
        }
        save()
    }

    // MARK: - Saved Plan API

    func saveMealPlan(_ plan: SavedMealPlan) {
        savedPlan = plan
        saveSavedPlan()
    }

    func clearSavedPlan() {
        savedPlan = SavedMealPlan()
        saveSavedPlan()
    }

    /// Czyści z kalendarza przepisy, których nie ma w nowym planie
    /// i synchronizuje flagi isSelected z aktualnym stanem kalendarza
    func cleanupCalendarAndSync(with newPlan: SavedMealPlan) {
        let newBreakfastIDs = Set(newPlan.breakfastEntries.map(\.recipe.id))
        let newLunchIDs = Set(newPlan.lunchEntries.map(\.recipe.id))
        let newDinnerIDs = Set(newPlan.dinnerEntries.map(\.recipe.id))

        // 1. Usuń z kalendarza przepisy spoza nowego planu
        var changed = false
        for (key, var dayPlan) in plans {
            var dayChanged = false

            if let b = dayPlan.breakfast, !newBreakfastIDs.contains(b.id) {
                dayPlan.breakfast = nil
                dayChanged = true
            }
            if let l = dayPlan.lunch, !newLunchIDs.contains(l.id) {
                dayPlan.lunch = nil
                dayChanged = true
            }
            if let d = dayPlan.dinner, !newDinnerIDs.contains(d.id) {
                dayPlan.dinner = nil
                dayChanged = true
            }

            if dayChanged {
                plans[key] = dayPlan
                changed = true
            }
        }
        if changed { save() }

        // 2. Policz ile razy każdy przepis jest użyty w kalendarzu per slot
        var usedBreakfast: [UUID: Int] = [:]
        var usedLunch: [UUID: Int] = [:]
        var usedDinner: [UUID: Int] = [:]

        for dayPlan in plans.values {
            if let b = dayPlan.breakfast { usedBreakfast[b.id, default: 0] += 1 }
            if let l = dayPlan.lunch { usedLunch[l.id, default: 0] += 1 }
            if let d = dayPlan.dinner { usedDinner[d.id, default: 0] += 1 }
        }

        // 3. Ustaw isSelected na podstawie faktycznego użycia w kalendarzu
        syncEntries(&savedPlan.breakfastEntries, usedCounts: usedBreakfast)
        syncEntries(&savedPlan.lunchEntries, usedCounts: usedLunch)
        syncEntries(&savedPlan.dinnerEntries, usedCounts: usedDinner)

        saveSavedPlan()
    }

    /// Synchronizuje flagi isSelected — tyle wpisów ile jest w kalendarzu ustawia na true
    private func syncEntries(_ entries: inout [PlanEntry], usedCounts: [UUID: Int]) {
        // Najpierw ustaw wszystko na false
        for i in entries.indices { entries[i].isSelected = false }

        // Potem oznacz tyle ile jest w kalendarzu
        var remaining = usedCounts
        for i in entries.indices {
            let recipeId = entries[i].recipe.id
            if let count = remaining[recipeId], count > 0 {
                entries[i].isSelected = true
                remaining[recipeId] = count - 1
            }
        }
    }

    /// Oznacz jeden wpis jako wybrany (po dodaniu do kalendarza)
    func markAsSelected(_ recipe: Recipe, slot: MealSlot) {
        mutateEntries(for: slot) { entries in
            if let idx = entries.firstIndex(where: { !$0.isSelected && $0.recipe.id == recipe.id }) {
                entries[idx].isSelected = true
            }
        }
    }

    /// Oznacz jeden wpis jako dostępny (po usunięciu z kalendarza)
    func markAsAvailable(_ recipe: Recipe, slot: MealSlot) {
        mutateEntries(for: slot) { entries in
            if let idx = entries.firstIndex(where: { $0.isSelected && $0.recipe.id == recipe.id }) {
                entries[idx].isSelected = false
            }
        }
    }

    private func mutateEntries(for slot: MealSlot, _ mutation: (inout [PlanEntry]) -> Void) {
        switch slot {
        case .breakfast: mutation(&savedPlan.breakfastEntries)
        case .lunch:     mutation(&savedPlan.lunchEntries)
        case .dinner:    mutation(&savedPlan.dinnerEntries)
        }
        saveSavedPlan()
    }

    // MARK: - Persistence

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("meal_plans.json")
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(plans)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("WeeklyMealStore save error: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            plans = try JSONDecoder().decode([String: DayMealPlan].self, from: data)
        } catch {
            print("WeeklyMealStore load error: \(error)")
        }
    }

    // MARK: - Saved Plan Persistence

    private var savedPlanURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("saved_plan.json")
    }

    private func saveSavedPlan() {
        do {
            let data = try JSONEncoder().encode(savedPlan)
            try data.write(to: savedPlanURL, options: .atomic)
        } catch {
            print("WeeklyMealStore saveSavedPlan error: \(error)")
        }
    }

    private func loadSavedPlan() {
        guard let data = try? Data(contentsOf: savedPlanURL) else { return }
        do {
            savedPlan = try JSONDecoder().decode(SavedMealPlan.self, from: data)
        } catch {
            print("WeeklyMealStore loadSavedPlan error: \(error)")
        }
    }
}

// MARK: - Environment Keys (bezpieczne domyślne wartości)

private struct WeeklyMealStoreKey: EnvironmentKey {
    static let defaultValue = WeeklyMealStore()
}

private struct DatesViewModelKey: EnvironmentKey {
    static let defaultValue = DatesViewModel()
}

extension EnvironmentValues {
    var weeklyMealStore: WeeklyMealStore {
        get { self[WeeklyMealStoreKey.self] }
        set { self[WeeklyMealStoreKey.self] = newValue }
    }

    var datesViewModel: DatesViewModel {
        get { self[DatesViewModelKey.self] }
        set { self[DatesViewModelKey.self] = newValue }
    }
}

// MARK: - Recipes Data Layer (MVP scaffolding)

protocol RecipeRepository {
    func fetchRecipes() async throws -> [Recipe]
    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws
}

@MainActor
final class MockRecipeRepository: RecipeRepository {
    private var recipes: [Recipe] = RecipesMock.all

    func fetchRecipes() async throws -> [Recipe] {
        recipes
    }

    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws {
        guard let index = recipes.firstIndex(where: { $0.id == recipeId }) else { return }
        recipes[index].favourite = isFavorite
    }
}

@MainActor
@Observable
final class RecipeCatalogStore {
    private let repository: RecipeRepository
    private(set) var recipes: [Recipe] = []
    private(set) var didLoad: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    init(repository: RecipeRepository = MockRecipeRepository()) {
        self.repository = repository
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            recipes = try await repository.fetchRecipes()
            didLoad = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggleFavorite(recipeId: UUID) async {
        guard let index = recipes.firstIndex(where: { $0.id == recipeId }) else { return }
        let previous = recipes[index].favourite
        let next = !previous

        recipes[index].favourite = next
        do {
            try await repository.setFavorite(recipeId: recipeId, isFavorite: next)
        } catch {
            recipes[index].favourite = previous
            errorMessage = error.localizedDescription
        }
    }
}

private struct RecipeCatalogStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = RecipeCatalogStore()
}

extension EnvironmentValues {
    var recipeCatalogStore: RecipeCatalogStore {
        get { self[RecipeCatalogStoreKey.self] }
        set { self[RecipeCatalogStoreKey.self] = newValue }
    }
}
