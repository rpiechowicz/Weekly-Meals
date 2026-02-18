import Foundation
import Observation

protocol ShoppingListRepository {
    func fetchShoppingList(weekStart: String) async throws -> [ShoppingItem]
    func setChecked(weekStart: String, productKey: String, isChecked: Bool) async throws
    func observeShoppingListChanges(_ onChange: @escaping (_ event: BackendShoppingListChangedDTO) -> Void)
    func observeRealtimeReconnect(_ onReconnect: @escaping () -> Void)
}

protocol ShoppingListTransportClient {
    func fetchShoppingList(weekStart: String) async throws -> [BackendShoppingItemDTO]
    func setChecked(weekStart: String, productKey: String, isChecked: Bool) async throws
    func observeShoppingListChanges(_ onChange: @escaping (_ event: BackendShoppingListChangedDTO) -> Void)
    func observeRealtimeReconnect(_ onReconnect: @escaping () -> Void)
}

struct BackendShoppingItemDTO: Codable {
    let productKey: String
    let name: String
    let unit: String
    let department: String
    let totalAmount: Double
    let isChecked: Bool
}

struct BackendHouseholdDTO: Codable {
    let id: String
    let name: String
}

struct BackendShoppingItemCheckDTO: Codable {
    let id: String
    let productKey: String
    let isChecked: Bool
}

struct BackendShoppingListChangedDTO: Codable {
    let householdId: String
    let weekStart: String
    let productKey: String?
    let isChecked: Bool?
    let changeVersion: Int64?
}

private struct HouseholdListPayload: Encodable {
    let userId: String
}

private struct ShoppingListPayload: Encodable {
    let userId: String
    let householdId: String
    let weekStart: String
}

private struct SetCheckedDataPayload: Encodable {
    let productKey: String
    let isChecked: Bool
}

private struct SetCheckedPayload: Encodable {
    let userId: String
    let householdId: String
    let weekStart: String
    let data: SetCheckedDataPayload
}

private extension BackendShoppingItemDTO {
    func toAppModel() -> ShoppingItem {
        ShoppingItem(
            productKey: productKey,
            name: name,
            totalAmount: totalAmount,
            unit: unit,
            department: department,
            isChecked: isChecked
        )
    }
}

final class WebSocketShoppingListTransportClient: ShoppingListTransportClient {
    private let socket: RecipeSocketClient
    private let userId: String
    private let householdId: String?
    private let preferredHouseholdName: String?
    private var resolvedHouseholdId: String?
    private let stateLock = NSLock()

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

    private func makePayload<T: Encodable>(_ value: T) throws -> [String: Any] {
        let encoded = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: encoded, options: [])
        guard let dictionary = object as? [String: Any] else {
            throw RecipeDataError.serverError(message: "Nie udało się zbudować payloadu JSON.")
        }
        return dictionary
    }

    private func resolveHouseholdId() async throws -> String {
        stateLock.lock()
        let currentResolved = resolvedHouseholdId
        stateLock.unlock()

        if let currentResolved {
            return currentResolved
        }
        if let householdId, !householdId.isEmpty {
            stateLock.lock()
            resolvedHouseholdId = householdId
            stateLock.unlock()
            return householdId
        }

        let payload = try makePayload(HouseholdListPayload(userId: userId))
        let envelope: WsEnvelope<[BackendHouseholdDTO]> = try await socket.emitWithAck(
            event: "households:findAll",
            payload: payload,
            as: WsEnvelope<[BackendHouseholdDTO]>.self
        )

        guard envelope.ok, let households = envelope.data else {
            throw RecipeDataError.serverError(message: envelope.error ?? "Nie udało się pobrać gospodarstw.")
        }

        if let preferredHouseholdName,
           let matched = households.first(where: { $0.name.lowercased() == preferredHouseholdName.lowercased() }) {
            stateLock.lock()
            resolvedHouseholdId = matched.id
            stateLock.unlock()
            return matched.id
        }

        guard let first = households.first else {
            throw RecipeDataError.serverError(message: "Brak gospodarstwa dla użytkownika.")
        }
        stateLock.lock()
        resolvedHouseholdId = first.id
        stateLock.unlock()
        return first.id
    }

    func fetchShoppingList(weekStart: String) async throws -> [BackendShoppingItemDTO] {
        let householdId = try await resolveHouseholdId()
        let payload = try makePayload(
            ShoppingListPayload(
                userId: userId,
                householdId: householdId,
                weekStart: weekStart
            )
        )
        let envelope: WsEnvelope<[BackendShoppingItemDTO]> = try await socket.emitWithAck(
            event: "weeklyPlans:getShoppingList",
            payload: payload,
            as: WsEnvelope<[BackendShoppingItemDTO]>.self
        )

        if envelope.ok, let data = envelope.data {
            return data
        }
        throw RecipeDataError.serverError(message: envelope.error ?? "Nieznany błąd weeklyPlans:getShoppingList.")
    }

    func setChecked(weekStart: String, productKey: String, isChecked: Bool) async throws {
        let householdId = try await resolveHouseholdId()
        let payload = try makePayload(
            SetCheckedPayload(
                userId: userId,
                householdId: householdId,
                weekStart: weekStart,
                data: SetCheckedDataPayload(
                    productKey: productKey,
                    isChecked: isChecked
                )
            )
        )
        let envelope: WsEnvelope<BackendShoppingItemCheckDTO> = try await socket.emitWithAck(
            event: "weeklyPlans:setShoppingItemChecked",
            payload: payload,
            as: WsEnvelope<BackendShoppingItemCheckDTO>.self
        )

        if envelope.ok {
            return
        }
        throw RecipeDataError.serverError(message: envelope.error ?? "Nieznany błąd weeklyPlans:setShoppingItemChecked.")
    }

    func observeShoppingListChanges(_ onChange: @escaping (_ event: BackendShoppingListChangedDTO) -> Void) {
        socket.off(event: "weeklyPlans:shoppingListChanged")
        socket.on(event: "weeklyPlans:shoppingListChanged") { [weak self] items in
            guard let self else { return }
            guard let first = items.first,
                  JSONSerialization.isValidJSONObject(first),
                  let data = try? JSONSerialization.data(withJSONObject: first),
                  let event = try? JSONDecoder().decode(BackendShoppingListChangedDTO.self, from: data)
            else { return }

            self.stateLock.lock()
            let cachedHouseholdId = self.resolvedHouseholdId
            self.stateLock.unlock()
            let expectedHouseholdId = cachedHouseholdId ?? self.householdId
            if let expectedHouseholdId, event.householdId != expectedHouseholdId {
                return
            }

            onChange(event)
        }
    }

    func observeRealtimeReconnect(_ onReconnect: @escaping () -> Void) {
        socket.observeConnection { isConnected in
            guard isConnected else { return }
            onReconnect()
        }
    }
}

final class ApiShoppingListRepository: ShoppingListRepository {
    private let client: ShoppingListTransportClient

    init(client: ShoppingListTransportClient) {
        self.client = client
    }

    func fetchShoppingList(weekStart: String) async throws -> [ShoppingItem] {
        let dtos = try await client.fetchShoppingList(weekStart: weekStart)
        return dtos.map { $0.toAppModel() }
    }

    func setChecked(weekStart: String, productKey: String, isChecked: Bool) async throws {
        try await client.setChecked(weekStart: weekStart, productKey: productKey, isChecked: isChecked)
    }

    func observeShoppingListChanges(_ onChange: @escaping (_ event: BackendShoppingListChangedDTO) -> Void) {
        client.observeShoppingListChanges(onChange)
    }

    func observeRealtimeReconnect(_ onReconnect: @escaping () -> Void) {
        client.observeRealtimeReconnect(onReconnect)
    }
}

@MainActor
@Observable
final class ShoppingListStore {
    private let repository: ShoppingListRepository
    private(set) var items: [ShoppingItem] = []
    private(set) var weekStart: String?
    private var pendingReloadTask: Task<Void, Never>?
    private var lastChangeVersionByWeek: [String: Int64] = [:]
    var isLoading: Bool = false
    var errorMessage: String?

    init(repository: ShoppingListRepository) {
        self.repository = repository
        self.repository.observeShoppingListChanges { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                guard let currentWeekStart = self.weekStart, currentWeekStart == event.weekStart else { return }
                if let changeVersion = event.changeVersion {
                    let previous = self.lastChangeVersionByWeek[currentWeekStart] ?? 0
                    guard changeVersion > previous else { return }
                    self.lastChangeVersionByWeek[currentWeekStart] = changeVersion
                }
                self.scheduleReload(weekStart: currentWeekStart)
            }
        }
        self.repository.observeRealtimeReconnect { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                guard let currentWeekStart = self.weekStart else { return }
                self.scheduleReload(weekStart: currentWeekStart)
            }
        }
    }

    func load(weekStart: String, force: Bool = false) async {
        isLoading = true
        errorMessage = nil
        self.weekStart = weekStart
        do {
            items = try await repository.fetchShoppingList(weekStart: weekStart)
        } catch {
            errorMessage = UserFacingErrorMapper.message(from: error)
        }
        isLoading = false
    }

    func refreshCurrentWeek() {
        guard let weekStart else { return }
        scheduleReload(weekStart: weekStart)
    }

    func toggleChecked(_ item: ShoppingItem) async {
        guard let index = items.firstIndex(where: { $0.productKey == item.productKey }),
              let weekStart else { return }

        let previous = items[index].isChecked
        let next = !previous
        items[index].isChecked = next

        do {
            try await repository.setChecked(weekStart: weekStart, productKey: item.productKey, isChecked: next)
        } catch {
            items[index].isChecked = previous
            errorMessage = UserFacingErrorMapper.message(from: error)
        }
    }

    private func scheduleReload(weekStart: String) {
        pendingReloadTask?.cancel()
        pendingReloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self else { return }
            await self.load(weekStart: weekStart, force: true)
        }
    }
}
