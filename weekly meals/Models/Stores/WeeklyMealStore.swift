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
    private let currentUserId: String?
    private var observedWeekStart: String?
    private var observedWeekDates: [Date] = []
    private var observedSavedPlanWeekStart: String?
    private var lastWeekChangeVersionByWeek: [String: Int64] = [:]
    private var lastSavedPlanChangeVersionByWeek: [String: Int64] = [:]
    private var pendingWeekReloadTask: Task<Void, Never>?
    private var pendingSavedPlanReloadTask: Task<Void, Never>?
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

    init(weeklyPlanRepository: WeeklyPlanRepository? = nil, currentUserId: String? = nil) {
        self.weeklyPlanRepository = weeklyPlanRepository
        self.currentUserId = currentUserId
        self.weeklyPlanRepository?.observeWeekPlanChanges { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                await self.handleRemoteWeekPlanChanged(event: event)
            }
        }
        self.weeklyPlanRepository?.observeSavedPlanChanges { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                await self.handleRemoteSavedPlanChanged(event: event)
            }
        }
        self.weeklyPlanRepository?.observeRealtimeReconnect { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.scheduleRefreshForObservedState()
            }
        }
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
        observedWeekStart = weekStart
        observedWeekDates = dates
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
            // Recompute availability flags based on the freshly loaded calendar state.
            // Without this, another device can keep stale "selected" entries and show 0/x as blocked.
            syncSavedPlanSelectionFlagsWithCalendar()
            errorMessage = nil
        } catch {
            errorMessage = UserFacingErrorMapper.message(from: error)
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
            errorMessage = UserFacingErrorMapper.message(from: error)
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
            errorMessage = UserFacingErrorMapper.message(from: error)
            return false
        }
    }

    @MainActor
    func clearWeekFromBackend(weekStart: String, dates: [Date]) async {
        guard let weeklyPlanRepository else {
            clearWeek(dates: dates)
            return
        }

        do {
            try await weeklyPlanRepository.clearWeekPlan(weekStart: weekStart)
            clearWeek(dates: dates)
            savedPlan = SavedMealPlan()
            saveSavedPlan()
            errorMessage = nil
        } catch {
            errorMessage = UserFacingErrorMapper.message(from: error)
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

    @MainActor
    func loadSavedPlanFromBackend(weekStart: String) async {
        guard let weeklyPlanRepository else { return }
        observedSavedPlanWeekStart = weekStart
        do {
            let dto = try await weeklyPlanRepository.fetchSavedPlan(weekStart: weekStart)
            let mapped = mapSavedPlan(dto: dto)
            savedPlan = mapped
            syncSavedPlanSelectionFlagsWithCalendar()
            errorMessage = nil
        } catch {
            errorMessage = UserFacingErrorMapper.message(from: error)
        }
    }

    @MainActor
    func saveMealPlanToBackend(_ plan: SavedMealPlan, weekStart: String) async {
        saveMealPlan(plan)
        guard let weeklyPlanRepository else { return }

        do {
            let breakfast = plan.breakfastEntries.map { $0.recipe.id.uuidString }
            let lunch = plan.lunchEntries.map { $0.recipe.id.uuidString }
            let dinner = plan.dinnerEntries.map { $0.recipe.id.uuidString }
            let dto = try await weeklyPlanRepository.saveSavedPlan(
                weekStart: weekStart,
                breakfastRecipeIds: breakfast,
                lunchRecipeIds: lunch,
                dinnerRecipeIds: dinner
            )
            let mapped = mapSavedPlan(dto: dto)
            savedPlan = mapped
            cleanupCalendarAndSync(with: mapped)
            errorMessage = nil
        } catch {
            errorMessage = UserFacingErrorMapper.message(from: error)
        }
    }

    @MainActor
    func clearSavedPlanFromBackend(weekStart: String) async {
        await saveMealPlanToBackend(SavedMealPlan(), weekStart: weekStart)
    }

    /// Resetuje lokalny cache planów i zapisany plan.
    /// Używane przy zmianie kontekstu gospodarstwa, aby nie przenosić starych danych.
    func resetLocalPlanningState() {
        plans = [:]
        savedPlan = SavedMealPlan()
        observedWeekStart = nil
        observedWeekDates = []
        observedSavedPlanWeekStart = nil
        lastWeekChangeVersionByWeek = [:]
        lastSavedPlanChangeVersionByWeek = [:]
        pendingWeekReloadTask?.cancel()
        pendingSavedPlanReloadTask?.cancel()
        pendingWeekReloadTask = nil
        pendingSavedPlanReloadTask = nil
        save()
        saveSavedPlan()
    }

    func refreshObservedState() {
        scheduleRefreshForObservedState()
    }

    @MainActor
    private func handleRemoteWeekPlanChanged(event: BackendWeekChangedDTO) async {
        let changedByOtherUser = event.changedByUserId != nil && event.changedByUserId != currentUserId
        guard event.weekStart == observedWeekStart else { return }
        guard !observedWeekDates.isEmpty else { return }
        if let changeVersion = event.changeVersion {
            let previous = lastWeekChangeVersionByWeek[event.weekStart] ?? 0
            guard changeVersion > previous else { return }
            lastWeekChangeVersionByWeek[event.weekStart] = changeVersion
        }
        scheduleWeekReload(weekStart: event.weekStart, dates: observedWeekDates)
        if changedByOtherUser {
            PlanChangeNotificationService.notifyRemotePlanChange(
                action: event.action,
                weekStart: event.weekStart,
                changedByDisplayName: event.changedByDisplayName,
                dayOfWeek: event.dayOfWeek,
                mealType: event.mealType
            )
        }
    }

    @MainActor
    private func handleRemoteSavedPlanChanged(event: BackendSavedPlanChangedDTO) async {
        let changedByOtherUser = event.changedByUserId != nil && event.changedByUserId != currentUserId
        guard event.weekStart == observedSavedPlanWeekStart else { return }
        if let changeVersion = event.changeVersion {
            let previous = lastSavedPlanChangeVersionByWeek[event.weekStart] ?? 0
            guard changeVersion > previous else { return }
            lastSavedPlanChangeVersionByWeek[event.weekStart] = changeVersion
        }
        scheduleSavedPlanReload(weekStart: event.weekStart)
        if changedByOtherUser {
            if event.action?.uppercased() == "CLEAR_PLAN" {
                return
            }
            PlanChangeNotificationService.notifyRemotePlanChange(
                action: event.action,
                weekStart: event.weekStart,
                changedByDisplayName: event.changedByDisplayName
            )
        }
    }

    private func scheduleWeekReload(weekStart: String, dates: [Date]) {
        pendingWeekReloadTask?.cancel()
        pendingWeekReloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self else { return }
            await self.loadWeekPlanFromBackend(weekStart: weekStart, dates: dates)
        }
    }

    private func scheduleSavedPlanReload(weekStart: String) {
        pendingSavedPlanReloadTask?.cancel()
        pendingSavedPlanReloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self else { return }
            await self.loadSavedPlanFromBackend(weekStart: weekStart)
        }
    }

    private func scheduleRefreshForObservedState() {
        if let observedWeekStart, !observedWeekDates.isEmpty {
            scheduleWeekReload(weekStart: observedWeekStart, dates: observedWeekDates)
        }
        if let observedSavedPlanWeekStart {
            scheduleSavedPlanReload(weekStart: observedSavedPlanWeekStart)
        }
    }

    private func mapSavedPlan(dto: BackendSharedMealPlanDTO) -> SavedMealPlan {
        func expand(mealType: String) -> [PlanEntry] {
            dto.items
                .filter { $0.mealType.uppercased() == mealType }
                .flatMap { item -> [PlanEntry] in
                    guard let recipe = item.recipe.toAppRecipe(), item.quantity > 0 else { return [] }
                    return Array(repeating: PlanEntry(recipe: recipe), count: item.quantity)
                }
        }

        return SavedMealPlan(
            breakfastEntries: expand(mealType: "BREAKFAST"),
            lunchEntries: expand(mealType: "LUNCH"),
            dinnerEntries: expand(mealType: "DINNER")
        )
    }

    private func syncSavedPlanSelectionFlagsWithCalendar() {
        var usedBreakfast: [UUID: Int] = [:]
        var usedLunch: [UUID: Int] = [:]
        var usedDinner: [UUID: Int] = [:]

        for dayPlan in plans.values {
            if let b = dayPlan.breakfast { usedBreakfast[b.id, default: 0] += 1 }
            if let l = dayPlan.lunch { usedLunch[l.id, default: 0] += 1 }
            if let d = dayPlan.dinner { usedDinner[d.id, default: 0] += 1 }
        }

        syncEntries(&savedPlan.breakfastEntries, usedCounts: usedBreakfast)
        syncEntries(&savedPlan.lunchEntries, usedCounts: usedLunch)
        syncEntries(&savedPlan.dinnerEntries, usedCounts: usedDinner)
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
    func fetchRecipes(page: Int, limit: Int) async throws -> [Recipe]
    func fetchRecipeById(_ recipeId: UUID) async throws -> Recipe
    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws
    func observeFavoritesChanges(_ onChange: @escaping (_ recipeId: UUID, _ isFavorite: Bool) -> Void)
    func observeRealtimeReconnect(_ onReconnect: @escaping () -> Void)
}

protocol RecipeTransportClient {
    func fetchRecipes(page: Int, limit: Int) async throws -> [BackendRecipeDTO]
    func fetchRecipeById(recipeId: String) async throws -> BackendRecipeDTO
    func setFavorite(recipeId: String, isFavorite: Bool) async throws
    func observeFavoritesChanges(_ onChange: @escaping (_ recipeId: String, _ isFavorite: Bool) -> Void)
    func observeRealtimeReconnect(_ onReconnect: @escaping () -> Void)
}

protocol RecipeSocketClient {
    func emitWithAck<T: Decodable>(event: String, payload: [String: Any], as: T.Type) async throws -> T
    func on(event: String, handler: @escaping ([Any]) -> Void)
    func off(event: String)
    func observeConnection(_ handler: @escaping (_ isConnected: Bool) -> Void)
}

final class SocketIORecipeSocketClient: RecipeSocketClient {
    private let manager: SocketManager
    private let socket: SocketIOClient
    private let socketQueue = DispatchQueue(label: "weeklymeals.socket.io.serial")
    private let ackTimeoutSeconds: Double = 6
    private let maxAckAttempts: Int = 3
    private var connectionObservers: [UUID: (Bool) -> Void] = [:]
    private let connectionObserversQueue = DispatchQueue(label: "weeklymeals.socket.connection-observers")

    init(baseURL: URL) {
        self.manager = SocketManager(
            socketURL: baseURL,
            config: [
                .log(false),
                .compress,
                .forceWebsockets(true),
                .handleQueue(socketQueue)
            ]
        )
        self.socket = manager.defaultSocket
        registerConnectionLifecycleEvents()
        socketQueue.async { [weak self] in
            self?.socket.connect()
        }
    }

    private func registerConnectionLifecycleEvents() {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            self?.notifyConnectionObservers(isConnected: true)
        }
        socket.on(clientEvent: .reconnect) { [weak self] _, _ in
            self?.notifyConnectionObservers(isConnected: true)
        }
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            self?.notifyConnectionObservers(isConnected: false)
        }
        socket.on(clientEvent: .error) { [weak self] _, _ in
            self?.notifyConnectionObservers(isConnected: false)
        }
    }

    private func notifyConnectionObservers(isConnected: Bool) {
        connectionObserversQueue.async { [weak self] in
            guard let self else { return }
            let handlers = self.connectionObservers.values
            for handler in handlers {
                handler(isConnected)
            }
        }
    }

    private func socketStatus() -> SocketIOStatus {
        socketQueue.sync {
            socket.status
        }
    }

    private func connectIfNeeded() {
        socketQueue.async { [weak self] in
            guard let self else { return }
            if self.socket.status != .connected && self.socket.status != .connecting {
                self.socket.connect()
            }
        }
    }

    private func ensureConnected() async throws {
        if socketStatus() == .connected { return }

        connectIfNeeded()

        for _ in 0..<30 {
            if socketStatus() == .connected { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        throw RecipeDataError.serverError(message: "Brak połączenia WebSocket z serwerem.")
    }

    private func requestAck(event: String, payload: [String: Any], timeout: Double) async throws -> [Any] {
        let safePayload = try makeSafePayload(payload, event: event)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Any], Error>) in
            let continuationLock = NSLock()
            var didResume = false

            func resumeOnce(_ result: Result<[Any], Error>) {
                continuationLock.lock()
                if didResume {
                    continuationLock.unlock()
                    return
                }
                didResume = true
                continuationLock.unlock()

                switch result {
                case .success(let items):
                    continuation.resume(returning: items)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            socketQueue.async { [weak self] in
                guard let self else {
                    resumeOnce(.failure(RecipeDataError.serverError(message: "Brak klienta WebSocket.")))
                    return
                }

                self.socket.emitWithAck(event, safePayload).timingOut(after: timeout) { items in
                    if let first = items.first as? String, first == "NO ACK" {
                        resumeOnce(.failure(RecipeDataError.serverError(message: "Brak ACK dla eventu \(event).")))
                        return
                    }
                    resumeOnce(.success(items))
                }
            }
        }
    }

    private func makeSafePayload(_ payload: [String: Any], event: String) throws -> [String: Any] {
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw RecipeDataError.serverError(
                message: "Nieprawidłowy payload JSON dla eventu \(event)."
            )
        }

        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = object as? [String: Any] else {
            throw RecipeDataError.serverError(
                message: "Nie udało się zbudować payloadu JSON dla eventu \(event)."
            )
        }
        return dictionary
    }

    func emitWithAck<T: Decodable>(event: String, payload: [String: Any], as: T.Type) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAckAttempts {
            do {
                try await ensureConnected()
                let raw = try await requestAck(event: event, payload: payload, timeout: ackTimeoutSeconds)

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
            } catch {
                lastError = error
                if attempt < maxAckAttempts {
                    let backoffMs = UInt64(250 * attempt)
                    try await Task.sleep(nanoseconds: backoffMs * 1_000_000)
                    continue
                }
            }
        }

        if let lastError {
            throw lastError
        }
        throw RecipeDataError.serverError(message: "Nie udało się wykonać eventu \(event).")
    }

    func on(event: String, handler: @escaping ([Any]) -> Void) {
        socketQueue.async { [weak self] in
            guard let self else { return }
            self.socket.on(event) { data, _ in
                handler(data)
            }
        }
    }

    func off(event: String) {
        socketQueue.async { [weak self] in
            self?.socket.off(event)
        }
    }

    func observeConnection(_ handler: @escaping (Bool) -> Void) {
        let id = UUID()
        connectionObserversQueue.async { [weak self] in
            self?.connectionObservers[id] = handler
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

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case mealType
        case difficulty
        case prepTimeMinutes
        case servings
        case imageUrl
        case nutritionKcal
        case nutritionProtein
        case nutritionFat
        case nutritionCarbs
        case nutritionFiber
        case nutritionSalt
        case isActive
        case isFavorite
        case ingredients
        case sourceInstructions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        mealType = try container.decode(String.self, forKey: .mealType)
        difficulty = try container.decode(String.self, forKey: .difficulty)
        prepTimeMinutes = try container.decode(Int.self, forKey: .prepTimeMinutes)
        servings = try container.decode(Int.self, forKey: .servings)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        nutritionKcal = try container.decode(Double.self, forKey: .nutritionKcal)
        nutritionProtein = try container.decode(Double.self, forKey: .nutritionProtein)
        nutritionFat = try container.decode(Double.self, forKey: .nutritionFat)
        nutritionCarbs = try container.decode(Double.self, forKey: .nutritionCarbs)
        nutritionFiber = try container.decode(Double.self, forKey: .nutritionFiber)
        nutritionSalt = try container.decode(Double.self, forKey: .nutritionSalt)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite)
        ingredients = try container.decodeIfPresent([BackendRecipeIngredientDTO].self, forKey: .ingredients) ?? []
        sourceInstructions = try container.decodeIfPresent([BackendRecipeInstructionDTO].self, forKey: .sourceInstructions)
    }
}

struct BackendRecipeInstructionDTO: Codable {
    let stepNumber: Int?
    let step_number: Int?
    let text: String?
    let instruction: String?
}

private struct BackendFavoritesChangedDTO: Codable {
    let householdId: String
    let recipeId: String
    let isFavorite: Bool
    let changedByUserId: String?
}

extension BackendRecipeDTO {
    private static let apiBaseURL = URL(string: "http://localhost:3000")!

    private func displayIngredientName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return trimmed }
        return String(first).uppercased(with: Locale(identifier: "pl_PL")) + trimmed.dropFirst()
    }

    private func resolvedImageURL() -> URL? {
        guard let raw = imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        if let absolute = URL(string: raw), absolute.scheme != nil {
            return absolute
        }

        if raw.hasPrefix("/") {
            return URL(string: raw, relativeTo: Self.apiBaseURL)?.absoluteURL
        }

        return URL(string: "/" + raw, relativeTo: Self.apiBaseURL)?.absoluteURL
    }

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
                name: displayIngredientName(item.name),
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
            imageURL: resolvedImageURL(),
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

    func on(event: String, handler: @escaping ([Any]) -> Void) {}

    func off(event: String) {}

    func observeConnection(_ handler: @escaping (Bool) -> Void) {}
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

    func fetchRecipes(page: Int, limit: Int) async throws -> [BackendRecipeDTO] {
        var payload: [String: Any] = [
            "userId": userId,
            "filters": [
                "page": page,
                "limit": limit
            ]
        ]
        if let householdId, var filters = payload["filters"] as? [String: Any] {
            filters["householdId"] = householdId
            payload["filters"] = filters
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

    func fetchRecipeById(recipeId: String) async throws -> BackendRecipeDTO {
        var payload: [String: Any] = [
            "userId": userId,
            "id": recipeId
        ]
        if let householdId {
            payload["householdId"] = householdId
        }

        let envelope: WsEnvelope<BackendRecipeDTO> = try await socket.emitWithAck(
            event: "recipes:findById",
            payload: payload,
            as: WsEnvelope<BackendRecipeDTO>.self
        )
        if envelope.ok, let data = envelope.data {
            return data
        }
        throw RecipeDataError.serverError(message: envelope.error ?? "Nieznany błąd recipes:findById.")
    }

    func setFavorite(recipeId: String, isFavorite: Bool) async throws {
        guard let householdId, !householdId.isEmpty else {
            throw RecipeDataError.serverError(message: "Brak gospodarstwa do zapisu ulubionych.")
        }
        let envelope: WsEnvelope<BackendRecipeDTO> = try await socket.emitWithAck(
            event: "recipes:setFavorite",
            payload: [
                "userId": userId,
                "data": [
                    "recipeId": recipeId,
                    "householdId": householdId,
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

    func observeFavoritesChanges(_ onChange: @escaping (_ recipeId: String, _ isFavorite: Bool) -> Void) {
        socket.off(event: "recipes:favoritesChanged")
        socket.on(event: "recipes:favoritesChanged") { [weak self] items in
            guard let self else { return }
            guard let first = items.first,
                  JSONSerialization.isValidJSONObject(first),
                  let data = try? JSONSerialization.data(withJSONObject: first),
                  let event = try? JSONDecoder().decode(BackendFavoritesChangedDTO.self, from: data)
            else { return }

            if let householdId = self.householdId, event.householdId != householdId {
                return
            }
            onChange(event.recipeId, event.isFavorite)
        }
    }

    func observeRealtimeReconnect(_ onReconnect: @escaping () -> Void) {
        socket.observeConnection { isConnected in
            guard isConnected else { return }
            onReconnect()
        }
    }
}

final class ApiRecipeRepository: RecipeRepository {
    private let client: RecipeTransportClient

    init(client: RecipeTransportClient) {
        self.client = client
    }

    func fetchRecipes(page: Int, limit: Int) async throws -> [Recipe] {
        let dtos = try await client.fetchRecipes(page: page, limit: limit)
        return dtos.compactMap { $0.toAppRecipe() }
    }

    func fetchRecipeById(_ recipeId: UUID) async throws -> Recipe {
        let id = recipeId.uuidString
        guard !id.isEmpty else { throw RecipeDataError.invalidRecipeId }
        let dto = try await client.fetchRecipeById(recipeId: id)
        guard let mapped = dto.toAppRecipe() else {
            throw RecipeDataError.serverError(message: "Nie udało się zmapować recipes:findById.")
        }
        return mapped
    }

    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws {
        let id = recipeId.uuidString
        guard !id.isEmpty else { throw RecipeDataError.invalidRecipeId }
        try await client.setFavorite(recipeId: id, isFavorite: isFavorite)
    }

    func observeFavoritesChanges(_ onChange: @escaping (_ recipeId: UUID, _ isFavorite: Bool) -> Void) {
        client.observeFavoritesChanges { recipeId, isFavorite in
            guard let uuid = UUID(uuidString: recipeId) else { return }
            onChange(uuid, isFavorite)
        }
    }

    func observeRealtimeReconnect(_ onReconnect: @escaping () -> Void) {
        client.observeRealtimeReconnect(onReconnect)
    }
}

@Observable
final class RecipeCatalogStore {
    private struct RecipeCatalogCachePayload: Codable {
        let recipes: [Recipe]
        let savedAt: Date
    }

    private let repository: RecipeRepository
    private(set) var recipes: [Recipe] = []
    private(set) var didLoad: Bool = false
    var isLoading: Bool = false
    var isLoadingMore: Bool = false
    var hasMore: Bool = true
    var errorMessage: String?
    private var currentPage: Int = 0
    private let pageSize: Int = 24
    private let cacheMaxAge: TimeInterval = 60 * 30 // 30 min
    private let maxFetchAttempts: Int = 3
    private var pendingRealtimeReloadTask: Task<Void, Never>?

    private var cacheURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recipes_catalog_cache_v2.json")
    }

    init(
        repository: RecipeRepository = ApiRecipeRepository(
            client: WebSocketRecipeTransportClient(
                socket: UnconfiguredRecipeSocketClient(),
                userId: "mock-user"
            )
        )
    ) {
        self.repository = repository
        self.repository.observeFavoritesChanges { [weak self] recipeId, isFavorite in
            guard let self else { return }
            Task { @MainActor in
                if let index = self.recipes.firstIndex(where: { $0.id == recipeId }) {
                    self.recipes[index].favourite = isFavorite
                    self.saveCache()
                }
            }
        }
        self.repository.observeRealtimeReconnect { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                guard self.didLoad else { return }
                self.pendingRealtimeReloadTask?.cancel()
                self.pendingRealtimeReloadTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard let self else { return }
                    await self.reload()
                }
            }
        }
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        if loadCacheIfFresh() {
            didLoad = true
            Task { await reload() }
            return
        }
        await reload()
    }

    func reload() async {
        isLoading = true
        isLoadingMore = false
        errorMessage = nil
        do {
            let firstPage = try await fetchPageWithRetry(page: 1)
            recipes = firstPage
            currentPage = 1
            hasMore = firstPage.count >= pageSize
            didLoad = true
            saveCache()
        } catch {
            errorMessage = UserFacingErrorMapper.message(from: error)
        }
        isLoading = false
    }

    func loadNextPageIfNeeded(currentItemId: UUID?, threshold: Int = 6) async {
        guard let currentItemId else { return }
        guard hasMore, !isLoading, !isLoadingMore, didLoad else { return }
        guard let index = recipes.firstIndex(where: { $0.id == currentItemId }) else { return }
        let triggerIndex = max(0, recipes.count - max(1, threshold))
        guard index >= triggerIndex else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let nextPage = currentPage + 1
            let items = try await fetchPageWithRetry(page: nextPage)
            recipes.append(contentsOf: items)
            currentPage = nextPage
            hasMore = items.count >= pageSize
            saveCache()
        } catch {
            errorMessage = UserFacingErrorMapper.message(from: error)
        }
    }

    @MainActor
    func loadRecipeDetail(recipeId: UUID) async -> Recipe? {
        guard let index = recipes.firstIndex(where: { $0.id == recipeId }) else { return nil }
        let current = recipes[index]
        if !current.ingredients.isEmpty || !current.preparationSteps.isEmpty {
            return current
        }

        do {
            let detailed = try await repository.fetchRecipeById(recipeId)
            recipes[index] = detailed
            return detailed
        } catch {
            errorMessage = UserFacingErrorMapper.message(from: error)
            return current
        }
    }

    func toggleFavorite(recipeId: UUID) async {
        guard let index = recipes.firstIndex(where: { $0.id == recipeId }) else { return }
        let previous = recipes[index].favourite
        let next = !previous

        recipes[index].favourite = next
        do {
            try await repository.setFavorite(recipeId: recipeId, isFavorite: next)
            saveCache()
        } catch {
            recipes[index].favourite = previous
            errorMessage = UserFacingErrorMapper.message(from: error)
        }
    }

    private func saveCache() {
        do {
            let payload = RecipeCatalogCachePayload(recipes: recipes, savedAt: Date())
            let data = try JSONEncoder().encode(payload)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            // intentionally ignore cache write failures
        }
    }

    private func loadCacheIfFresh() -> Bool {
        guard let data = try? Data(contentsOf: cacheURL) else { return false }
        guard let payload = try? JSONDecoder().decode(RecipeCatalogCachePayload.self, from: data) else { return false }
        guard Date().timeIntervalSince(payload.savedAt) <= cacheMaxAge else { return false }
        recipes = payload.recipes
        currentPage = max(1, Int(ceil(Double(payload.recipes.count) / Double(pageSize))))
        hasMore = payload.recipes.count % pageSize == 0
        return !payload.recipes.isEmpty
    }

    private func fetchPageWithRetry(page: Int) async throws -> [Recipe] {
        var lastError: Error?
        for attempt in 1...maxFetchAttempts {
            do {
                return try await repository.fetchRecipes(page: page, limit: pageSize)
            } catch {
                lastError = error
                if attempt < maxFetchAttempts {
                    let backoffMs = UInt64(200 * attempt)
                    try await Task.sleep(nanoseconds: backoffMs * 1_000_000)
                }
            }
        }
        throw lastError ?? RecipeDataError.serverError(message: "Nie udało się pobrać listy przepisów.")
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
