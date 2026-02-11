import Foundation
import Observation
import SocketIO
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
    private let weeklyPlanRepository: WeeklyPlanRepository?
    var errorMessage: String?

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

    init(weeklyPlanRepository: WeeklyPlanRepository? = nil) {
        self.weeklyPlanRepository = weeklyPlanRepository
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

    @MainActor
    func loadWeekPlanFromBackend(weekStart: String, dates: [Date]) async {
        guard let weeklyPlanRepository else { return }
        do {
            let slots = try await weeklyPlanRepository.fetchWeekPlan(weekStart: weekStart)
            clearWeek(dates: dates)
            for slot in slots {
                let key = slot.dateKey
                var dayPlan = plans[key] ?? DayMealPlan(dateKey: key)
                dayPlan.setRecipe(slot.recipe, for: slot.mealSlot)
                plans[key] = dayPlan
            }
            save()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func upsertWeekSlot(
        recipe: Recipe,
        for date: Date,
        slot: MealSlot,
        weekStart: String
    ) async -> Bool {
        let previous = self.recipe(for: date, slot: slot)
        setRecipe(recipe, for: date, slot: slot)

        guard let weeklyPlanRepository else { return true }

        do {
            try await weeklyPlanRepository.upsertWeekSlot(
                weekStart: weekStart,
                date: date,
                mealSlot: slot,
                recipeId: recipe.id
            )
            errorMessage = nil
            return true
        } catch {
            setRecipe(previous, for: date, slot: slot)
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func removeWeekSlot(for date: Date, slot: MealSlot, weekStart: String) async -> Bool {
        let previous = self.recipe(for: date, slot: slot)
        clearRecipe(for: date, slot: slot)

        guard let weeklyPlanRepository else { return true }

        do {
            try await weeklyPlanRepository.removeWeekSlot(
                weekStart: weekStart,
                date: date,
                mealSlot: slot
            )
            errorMessage = nil
            return true
        } catch {
            setRecipe(previous, for: date, slot: slot)
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func clearWeekFromBackend(weekStart: String, dates: [Date]) async {
        guard weeklyPlanRepository != nil else {
            clearWeek(dates: dates)
            return
        }

        var hadError = false
        for date in dates {
            for slot in MealSlot.allCases {
                guard recipe(for: date, slot: slot) != nil else { continue }
                let success = await removeWeekSlot(for: date, slot: slot, weekStart: weekStart)
                if !success { hadError = true }
            }
        }

        if !hadError {
            errorMessage = nil
        }
    }

    @MainActor
    func applySavedPlanToWeek(weekStart: String, dates: [Date], plan: SavedMealPlan) async {
        guard !dates.isEmpty else { return }

        // Upewnij się, że lokalny cache odzwierciedla backend przed nadpisaniem tygodnia.
        await loadWeekPlanFromBackend(weekStart: weekStart, dates: dates)

        var hadError = false

        func applySlot(_ slot: MealSlot, entries: [PlanEntry]) async {
            let recipes = entries.map(\.recipe)

            for (index, date) in dates.enumerated() {
                if index < recipes.count {
                    let targetRecipe = recipes[index]
                    if recipe(for: date, slot: slot)?.id == targetRecipe.id {
                        continue
                    }
                    let success = await upsertWeekSlot(
                        recipe: targetRecipe,
                        for: date,
                        slot: slot,
                        weekStart: weekStart
                    )
                    if !success { hadError = true }
                } else if recipe(for: date, slot: slot) != nil {
                    let success = await removeWeekSlot(
                        for: date,
                        slot: slot,
                        weekStart: weekStart
                    )
                    if !success { hadError = true }
                }
            }
        }

        await applySlot(.breakfast, entries: plan.breakfastEntries)
        await applySlot(.lunch, entries: plan.lunchEntries)
        await applySlot(.dinner, entries: plan.dinnerEntries)

        cleanupCalendarAndSync(with: plan)

        if !hadError {
            errorMessage = nil
        }
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

private struct ShoppingListStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = ShoppingListStore(
        repository: ApiShoppingListRepository(
            client: WebSocketShoppingListTransportClient(
                socket: UnconfiguredRecipeSocketClient(),
                userId: "mock-user"
            )
        )
    )
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

    var shoppingListStore: ShoppingListStore {
        get { self[ShoppingListStoreKey.self] }
        set { self[ShoppingListStoreKey.self] = newValue }
    }
}

// MARK: - Recipes Data Layer (MVP scaffolding)

protocol RecipeRepository {
    func fetchRecipes() async throws -> [Recipe]
    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws
}

protocol RecipeTransportClient {
    func fetchRecipes() async throws -> [BackendRecipeDTO]
    func setFavorite(recipeId: String, isFavorite: Bool) async throws
}

protocol RecipeSocketClient {
    func emitWithAck<T: Decodable>(event: String, payload: [String: Any], as: T.Type) async throws -> T
}

final class SocketIORecipeSocketClient: RecipeSocketClient {
    private let manager: SocketManager
    private let socket: SocketIOClient

    init(baseURL: URL) {
        self.manager = SocketManager(
            socketURL: baseURL,
            config: [
                .log(false),
                .compress,
                .forceWebsockets(true)
            ]
        )
        self.socket = manager.defaultSocket
        self.socket.connect()
    }

    private func ensureConnected() async throws {
        if socket.status == .connected { return }

        if socket.status != .connecting {
            socket.connect()
        }

        for _ in 0..<30 {
            if socket.status == .connected { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        throw RecipeDataError.serverError(message: "Brak połączenia WebSocket z serwerem.")
    }

    private func requestAck(event: String, payload: [String: Any]) async throws -> [Any] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Any], Error>) in
            socket.emitWithAck(event, payload).timingOut(after: 10) { items in
                if let first = items.first as? String, first == "NO ACK" {
                    continuation.resume(throwing: RecipeDataError.serverError(message: "Brak ACK dla eventu \(event)."))
                    return
                }
                continuation.resume(returning: items)
            }
        }
    }

    func emitWithAck<T: Decodable>(event: String, payload: [String: Any], as: T.Type) async throws -> T {
        try await ensureConnected()

        let raw: [Any]
        do {
            raw = try await requestAck(event: event, payload: payload)
        } catch {
            // Jednorazowy retry po krótkiej pauzie (częsty przypadek: event wysłany tuż po reconnect).
            try await Task.sleep(nanoseconds: 250_000_000)
            try await ensureConnected()
            raw = try await requestAck(event: event, payload: payload)
        }

        guard let first = raw.first else {
            throw RecipeDataError.serverError(message: "Pusta odpowiedź dla eventu \(event).")
        }
        guard JSONSerialization.isValidJSONObject(first) else {
            throw RecipeDataError.serverError(message: "Nieprawidłowy format odpowiedzi dla eventu \(event).")
        }

        let payloadObject = first
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let data = try JSONSerialization.data(withJSONObject: payloadObject)
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    continuation.resume(returning: decoded)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct WsEnvelope<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: String?
    let code: String?
    let status: Int?
}

enum RecipeDataError: LocalizedError {
    case invalidRecipeId
    case transportNotConfigured
    case serverError(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidRecipeId:
            return "Nieprawidłowe ID przepisu."
        case .transportNotConfigured:
            return "Transport WebSocket nie jest jeszcze skonfigurowany."
        case let .serverError(message):
            return message
        }
    }
}

// Backend contract DTOs (aligned with backend Recipe model).
struct BackendRecipeIngredientDTO: Codable {
    let id: String
    let recipeId: String
    let name: String
    let amount: Double
    let unit: String
    let department: String
}

struct BackendRecipeDTO: Codable {
    let id: String
    let title: String
    let description: String?
    let mealType: String
    let difficulty: String
    let prepTimeMinutes: Int
    let servings: Int
    let imageUrl: String?
    let nutritionKcal: Double
    let nutritionProtein: Double
    let nutritionFat: Double
    let nutritionCarbs: Double
    let nutritionFiber: Double
    let nutritionSalt: Double
    let isActive: Bool
    let isFavorite: Bool?
    let ingredients: [BackendRecipeIngredientDTO]
    let sourceInstructions: [BackendRecipeInstructionDTO]?
}

struct BackendRecipeInstructionDTO: Codable {
    let stepNumber: Int?
    let step_number: Int?
    let text: String?
    let instruction: String?
}

extension BackendRecipeDTO {
    var appCategory: RecipesCategory? {
        switch mealType.uppercased() {
        case "BREAKFAST": .breakfast
        case "LUNCH": .lunch
        case "DINNER": .dinner
        default: nil
        }
    }

    var appDifficulty: Difficulty {
        switch difficulty.uppercased() {
        case "EASY": .easy
        case "MEDIUM": .medium
        case "HARD": .hard
        default: .easy
        }
    }

    func toAppRecipe() -> Recipe? {
        guard let uuid = UUID(uuidString: id), let category = appCategory else {
            return nil
        }

        let mappedIngredients = ingredients.compactMap { item -> Ingredient? in
            let unit = IngredientUnit(rawValue: item.unit)
            guard let mappedUnit = unit else { return nil }
            return Ingredient(
                id: UUID(uuidString: item.id) ?? UUID(),
                name: item.name,
                amount: item.amount,
                unit: mappedUnit
            )
        }

        let mappedPreparationSteps: [PreparationStep] = (sourceInstructions ?? [])
            .enumerated()
            .compactMap { index, step in
                let content = (step.text ?? step.instruction ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !content.isEmpty else { return nil }
                let stepNumber = step.step_number ?? step.stepNumber ?? (index + 1)
                return PreparationStep(stepNumber: stepNumber, instruction: content)
            }
            .sorted(by: { $0.stepNumber < $1.stepNumber })

        return Recipe(
            id: uuid,
            name: title,
            description: description ?? "",
            favourite: isFavorite ?? false,
            category: category,
            servings: servings,
            prepTimeMinutes: prepTimeMinutes,
            difficulty: appDifficulty,
            imageURL: imageUrl.flatMap(URL.init(string:)),
            ingredients: mappedIngredients,
            preparationSteps: mappedPreparationSteps,
            nutrition: Nutrition(
                kcal: nutritionKcal,
                protein: nutritionProtein,
                fat: nutritionFat,
                carbs: nutritionCarbs,
                fiber: nutritionFiber,
                salt: nutritionSalt
            )
        )
    }
}

final class UnconfiguredRecipeSocketClient: RecipeSocketClient {
    func emitWithAck<T: Decodable>(event: String, payload: [String: Any], as: T.Type) async throws -> T {
        throw RecipeDataError.transportNotConfigured
    }
}

final class WebSocketRecipeTransportClient: RecipeTransportClient {
    private let socket: RecipeSocketClient
    private let userId: String
    private let householdId: String?

    init(socket: RecipeSocketClient, userId: String, householdId: String? = nil) {
        self.socket = socket
        self.userId = userId
        self.householdId = householdId
    }

    func fetchRecipes() async throws -> [BackendRecipeDTO] {
        var payload: [String: Any] = ["userId": userId]
        if let householdId {
            payload["householdId"] = householdId
        }

        let envelope: WsEnvelope<[BackendRecipeDTO]> = try await socket.emitWithAck(
            event: "recipes:findAll",
            payload: payload,
            as: WsEnvelope<[BackendRecipeDTO]>.self
        )
        if envelope.ok, let data = envelope.data {
            return data
        }
        throw RecipeDataError.serverError(message: envelope.error ?? "Nieznany błąd recipes:findAll.")
    }

    func setFavorite(recipeId: String, isFavorite: Bool) async throws {
        let envelope: WsEnvelope<BackendRecipeDTO> = try await socket.emitWithAck(
            event: "recipes:setFavorite",
            payload: [
                "userId": userId,
                "data": [
                    "recipeId": recipeId,
                    "isFavorite": isFavorite
                ]
            ],
            as: WsEnvelope<BackendRecipeDTO>.self
        )
        if envelope.ok {
            return
        }
        throw RecipeDataError.serverError(message: envelope.error ?? "Nieznany błąd recipes:setFavorite.")
    }
}

final class ApiRecipeRepository: RecipeRepository {
    private let client: RecipeTransportClient

    init(client: RecipeTransportClient) {
        self.client = client
    }

    func fetchRecipes() async throws -> [Recipe] {
        let dtos = try await client.fetchRecipes()
        return dtos.compactMap { $0.toAppRecipe() }
    }

    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws {
        let id = recipeId.uuidString
        guard !id.isEmpty else { throw RecipeDataError.invalidRecipeId }
        try await client.setFavorite(recipeId: id, isFavorite: isFavorite)
    }
}

@Observable
final class RecipeCatalogStore {
    private let repository: RecipeRepository
    private(set) var recipes: [Recipe] = []
    private(set) var didLoad: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    init(
        repository: RecipeRepository = ApiRecipeRepository(
            client: WebSocketRecipeTransportClient(
                socket: UnconfiguredRecipeSocketClient(),
                userId: "mock-user"
            )
        )
    ) {
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
