import Foundation

struct WeekPlanSlot {
    let dateKey: String
    let mealSlot: MealSlot
    let recipe: Recipe
}

protocol WeeklyPlanRepository {
    func fetchWeekPlan(weekStart: String) async throws -> [WeekPlanSlot]
    func upsertWeekSlot(weekStart: String, date: Date, mealSlot: MealSlot, recipeId: UUID) async throws
    func removeWeekSlot(weekStart: String, date: Date, mealSlot: MealSlot) async throws
}

protocol WeeklyPlanTransportClient {
    func fetchWeekPlan(weekStart: String) async throws -> [BackendWeeklyPlanItemDTO]
    func upsertWeekSlot(weekStart: String, dayOfWeek: String, mealType: String, recipeId: String) async throws
    func removeWeekSlot(weekStart: String, dayOfWeek: String, mealType: String) async throws
}

struct BackendWeeklyPlanDTO: Codable {
    let id: String
    let weekStart: String
    let items: [BackendWeeklyPlanItemDTO]
}

struct BackendWeeklyPlanItemDTO: Codable {
    let id: String
    let dayOfWeek: String
    let mealType: String
    let recipe: BackendRecipeDTO
}

private struct BackendPlanItemAckDTO: Codable {
    let id: String
}

private final class WeekDateMapper {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dayOffsets: [String: Int] = [
        "MON": 0,
        "TUE": 1,
        "WED": 2,
        "THU": 3,
        "FRI": 4,
        "SAT": 5,
        "SUN": 6
    ]

    static func dateKey(weekStart: String, dayOfWeek: String) -> String? {
        guard let monday = formatter.date(from: weekStart),
              let offset = dayOffsets[dayOfWeek.uppercased()],
              let date = Calendar.current.date(byAdding: .day, value: offset, to: monday) else {
            return nil
        }
        return formatter.string(from: date)
    }

    static func dayOfWeek(from date: Date, weekStart: String) -> String? {
        guard let monday = formatter.date(from: weekStart) else { return nil }
        let startOfMonday = Calendar.current.startOfDay(for: monday)
        let startOfDate = Calendar.current.startOfDay(for: date)
        let diff = Calendar.current.dateComponents([.day], from: startOfMonday, to: startOfDate).day ?? 0
        switch diff {
        case 0: return "MON"
        case 1: return "TUE"
        case 2: return "WED"
        case 3: return "THU"
        case 4: return "FRI"
        case 5: return "SAT"
        case 6: return "SUN"
        default: return nil
        }
    }
}

private extension MealSlot {
    var backendMealType: String {
        switch self {
        case .breakfast: return "BREAKFAST"
        case .lunch: return "LUNCH"
        case .dinner: return "DINNER"
        }
    }
}

private extension BackendWeeklyPlanItemDTO {
    var appMealSlot: MealSlot? {
        switch mealType.uppercased() {
        case "BREAKFAST": return .breakfast
        case "LUNCH": return .lunch
        case "DINNER": return .dinner
        default: return nil
        }
    }
}

final class WebSocketWeeklyPlanTransportClient: WeeklyPlanTransportClient {
    private let socket: RecipeSocketClient
    private let userId: String
    private let householdId: String?
    private let preferredHouseholdName: String?
    private var resolvedHouseholdId: String?

    init(
        socket: RecipeSocketClient,
        userId: String,
        householdId: String? = nil,
        preferredHouseholdName: String? = "Home"
    ) {
        self.socket = socket
        self.userId = userId
        self.householdId = householdId
        self.preferredHouseholdName = preferredHouseholdName
    }

    private func resolveHouseholdId() async throws -> String {
        if let resolvedHouseholdId {
            return resolvedHouseholdId
        }
        if let householdId, !householdId.isEmpty {
            resolvedHouseholdId = householdId
            return householdId
        }

        let envelope: WsEnvelope<[BackendHouseholdDTO]> = try await socket.emitWithAck(
            event: "households:findAll",
            payload: ["userId": userId],
            as: WsEnvelope<[BackendHouseholdDTO]>.self
        )

        guard envelope.ok, let households = envelope.data else {
            throw RecipeDataError.serverError(message: envelope.error ?? "Nie udało się pobrać gospodarstw.")
        }

        if let preferredHouseholdName,
           let matched = households.first(where: { $0.name.lowercased() == preferredHouseholdName.lowercased() }) {
            resolvedHouseholdId = matched.id
            return matched.id
        }

        guard let first = households.first else {
            throw RecipeDataError.serverError(message: "Brak gospodarstwa dla użytkownika.")
        }
        resolvedHouseholdId = first.id
        return first.id
    }

    func fetchWeekPlan(weekStart: String) async throws -> [BackendWeeklyPlanItemDTO] {
        let householdId = try await resolveHouseholdId()
        let envelope: WsEnvelope<BackendWeeklyPlanDTO> = try await socket.emitWithAck(
            event: "weeklyPlans:getByWeek",
            payload: [
                "userId": userId,
                "householdId": householdId,
                "weekStart": weekStart
            ],
            as: WsEnvelope<BackendWeeklyPlanDTO>.self
        )

        if envelope.ok, let data = envelope.data {
            return data.items
        }

        if envelope.code == "NOT_FOUND" || envelope.error?.localizedCaseInsensitiveContains("not found") == true {
            return []
        }

        throw RecipeDataError.serverError(message: envelope.error ?? "Nieznany błąd weeklyPlans:getByWeek.")
    }

    func upsertWeekSlot(weekStart: String, dayOfWeek: String, mealType: String, recipeId: String) async throws {
        let householdId = try await resolveHouseholdId()
        let envelope: WsEnvelope<BackendPlanItemAckDTO> = try await socket.emitWithAck(
            event: "weeklyPlans:upsertWeekSlot",
            payload: [
                "userId": userId,
                "householdId": householdId,
                "weekStart": weekStart,
                "data": [
                    "dayOfWeek": dayOfWeek,
                    "mealType": mealType,
                    "recipeId": recipeId
                ]
            ],
            as: WsEnvelope<BackendPlanItemAckDTO>.self
        )

        if envelope.ok {
            return
        }

        throw RecipeDataError.serverError(message: envelope.error ?? "Nieznany błąd weeklyPlans:upsertWeekSlot.")
    }

    func removeWeekSlot(weekStart: String, dayOfWeek: String, mealType: String) async throws {
        let householdId = try await resolveHouseholdId()
        let envelope: WsEnvelope<BackendPlanItemAckDTO> = try await socket.emitWithAck(
            event: "weeklyPlans:removeWeekSlot",
            payload: [
                "userId": userId,
                "householdId": householdId,
                "weekStart": weekStart,
                "data": [
                    "dayOfWeek": dayOfWeek,
                    "mealType": mealType
                ]
            ],
            as: WsEnvelope<BackendPlanItemAckDTO>.self
        )

        if envelope.ok {
            return
        }
        throw RecipeDataError.serverError(message: envelope.error ?? "Nieznany błąd weeklyPlans:removeWeekSlot.")
    }
}

final class ApiWeeklyPlanRepository: WeeklyPlanRepository {
    private let client: WeeklyPlanTransportClient

    init(client: WeeklyPlanTransportClient) {
        self.client = client
    }

    func fetchWeekPlan(weekStart: String) async throws -> [WeekPlanSlot] {
        let items = try await client.fetchWeekPlan(weekStart: weekStart)
        return items.compactMap { item in
            guard let dateKey = WeekDateMapper.dateKey(weekStart: weekStart, dayOfWeek: item.dayOfWeek),
                  let mealSlot = item.appMealSlot,
                  let recipe = item.recipe.toAppRecipe() else {
                return nil
            }
            return WeekPlanSlot(dateKey: dateKey, mealSlot: mealSlot, recipe: recipe)
        }
    }

    func upsertWeekSlot(weekStart: String, date: Date, mealSlot: MealSlot, recipeId: UUID) async throws {
        guard let dayOfWeek = WeekDateMapper.dayOfWeek(from: date, weekStart: weekStart) else {
            throw RecipeDataError.serverError(message: "Nie można wyznaczyć dnia tygodnia dla slotu.")
        }
        try await client.upsertWeekSlot(
            weekStart: weekStart,
            dayOfWeek: dayOfWeek,
            mealType: mealSlot.backendMealType,
            recipeId: recipeId.uuidString
        )
    }

    func removeWeekSlot(weekStart: String, date: Date, mealSlot: MealSlot) async throws {
        guard let dayOfWeek = WeekDateMapper.dayOfWeek(from: date, weekStart: weekStart) else {
            throw RecipeDataError.serverError(message: "Nie można wyznaczyć dnia tygodnia dla slotu.")
        }
        try await client.removeWeekSlot(
            weekStart: weekStart,
            dayOfWeek: dayOfWeek,
            mealType: mealSlot.backendMealType
        )
    }
}
