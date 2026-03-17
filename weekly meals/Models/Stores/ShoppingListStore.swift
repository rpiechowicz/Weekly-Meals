import Foundation
import Observation

struct ArchivedShoppingList: Identifiable, Codable, Hashable {
    let archiveId: String
    let weekStart: String
    let weekLabel: String
    let revision: Int
    let archivedAt: Date
    let items: [ShoppingItem]

    var id: String { archiveId }

    var totalCount: Int { items.count }
    var boughtCount: Int { items.filter(\.isChecked).count }

    private enum CodingKeys: String, CodingKey {
        case archiveId
        case weekStart
        case weekLabel
        case revision
        case archivedAt
        case items
    }

    init(
        archiveId: String = UUID().uuidString,
        weekStart: String,
        weekLabel: String,
        revision: Int,
        archivedAt: Date,
        items: [ShoppingItem]
    ) {
        self.archiveId = archiveId
        self.weekStart = weekStart
        self.weekLabel = weekLabel
        self.revision = revision
        self.archivedAt = archivedAt
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        archiveId = try container.decodeIfPresent(String.self, forKey: .archiveId) ?? UUID().uuidString
        weekStart = try container.decode(String.self, forKey: .weekStart)
        weekLabel = try container.decode(String.self, forKey: .weekLabel)
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 1
        archivedAt = try container.decode(Date.self, forKey: .archivedAt)
        items = try container.decode([ShoppingItem].self, forKey: .items)
    }
}

private struct OpenShoppingRevision: Codable {
    let baseArchiveId: String
    let pendingAmounts: [String: Double]
}

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
    private enum ArchiveKeys {
        static let archivedLists = "shopping.archivedLists"
        static let closedArchiveByWeek = "shopping.closedArchiveByWeek"
        static let openRevisions = "shopping.openRevisions"
    }

    private let repository: ShoppingListRepository
    private(set) var items: [ShoppingItem] = []
    private(set) var weekStart: String?
    private(set) var archivedLists: [ArchivedShoppingList] = []
    private(set) var isBatchUpdating: Bool = false
    private var pendingReloadTask: Task<Void, Never>?
    private var lastChangeVersionByWeek: [String: Int64] = [:]
    private var closedArchiveByWeek: [String: String] = [:]
    private var openRevisionsByWeek: [String: OpenShoppingRevision] = [:]
    var isLoading: Bool = false
    var errorMessage: String?

    init(repository: ShoppingListRepository) {
        self.repository = repository
        self.archivedLists = Self.loadArchivedLists()
        self.closedArchiveByWeek = Self.loadClosedArchiveByWeek()
        self.openRevisionsByWeek = Self.loadOpenRevisions()
        self.repository.observeShoppingListChanges { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                guard let currentWeekStart = self.weekStart, currentWeekStart == event.weekStart else { return }
                guard !self.isBatchUpdating else { return }
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
                guard !self.isBatchUpdating else { return }
                self.scheduleReload(weekStart: currentWeekStart)
            }
        }
    }

    func load(weekStart: String, force: Bool = false) async {
        isLoading = true
        errorMessage = nil
        self.weekStart = weekStart
        do {
            let fetchedItems = try await repository.fetchShoppingList(weekStart: weekStart)
            items = fetchedItems
            await syncPendingItemCheckState(for: weekStart, currentItems: fetchedItems)
        } catch {
            errorMessage = UserFacingErrorMapper.message(from: error)
        }
        isLoading = false
    }

    func refreshCurrentWeek() {
        guard let weekStart else { return }
        scheduleReload(weekStart: weekStart)
    }

    func markAllChecked() async {
        guard let weekStart else { return }

        let uncheckedItems = items.filter { !$0.isChecked }
        guard !uncheckedItems.isEmpty else { return }

        let originalItems = items
        isBatchUpdating = true
        for index in items.indices {
            items[index].isChecked = true
        }

        do {
            for item in uncheckedItems {
                try await repository.setChecked(
                    weekStart: weekStart,
                    productKey: item.productKey,
                    isChecked: true
                )
            }
            isBatchUpdating = false
            await load(weekStart: weekStart, force: true)
        } catch {
            isBatchUpdating = false
            items = originalItems
            errorMessage = UserFacingErrorMapper.message(from: error)
        }
    }

    func toggleChecked(_ item: ShoppingItem) async {
        guard !isBatchUpdating else { return }
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

    func archiveCurrentList(weekLabel: String) {
        guard let weekStart,
              !items.isEmpty,
              items.allSatisfy(\.isChecked)
        else { return }

        let nextRevision = (archivedLists.filter { $0.weekStart == weekStart }.map(\.revision).max() ?? 0) + 1
        let snapshot = ArchivedShoppingList(
            weekStart: weekStart,
            weekLabel: weekLabel,
            revision: nextRevision,
            archivedAt: Date(),
            items: items
        )

        archivedLists.insert(snapshot, at: 0)
        closedArchiveByWeek[weekStart] = snapshot.id
        openRevisionsByWeek.removeValue(forKey: weekStart)
        persistArchivedLists()
        persistClosedArchiveByWeek()
        persistOpenRevisions()
    }

    func restoreArchivedList(weekStart: String) {
        closedArchiveByWeek.removeValue(forKey: weekStart)
        openRevisionsByWeek.removeValue(forKey: weekStart)
        persistClosedArchiveByWeek()
        persistOpenRevisions()
    }

    func deleteArchivedList(archiveId: String) {
        archivedLists.removeAll { $0.id == archiveId }
        closedArchiveByWeek = closedArchiveByWeek.filter { $0.value != archiveId }
        openRevisionsByWeek = openRevisionsByWeek.filter { $0.value.baseArchiveId != archiveId }
        persistArchivedLists()
        persistClosedArchiveByWeek()
        persistOpenRevisions()
    }

    func isArchived(weekStart: String) -> Bool {
        closedArchiveByWeek[weekStart] != nil
    }

    func currentClosedArchive(for weekStart: String) -> ArchivedShoppingList? {
        guard let archiveId = closedArchiveByWeek[weekStart] else { return nil }
        return archivedLists.first { $0.id == archiveId }
    }

    func hasOpenRevision(for weekStart: String) -> Bool {
        guard self.weekStart == weekStart,
              let archive = currentClosedArchive(for: weekStart)
        else {
            return false
        }

        return itemSignature(for: items) != itemSignature(for: archive.items)
    }

    func pendingItems(for weekStart: String) -> [ShoppingItem] {
        guard self.weekStart == weekStart,
              let archive = currentClosedArchive(for: weekStart)
        else {
            return items
        }

        return makePendingItems(currentItems: items, archivedItems: archive.items)
    }

    func readonlyItems(for weekStart: String) -> [ShoppingItem] {
        guard hasOpenRevision(for: weekStart),
              let archive = currentClosedArchive(for: weekStart)
        else {
            return []
        }

        return archive.items
    }

    private func scheduleReload(weekStart: String) {
        pendingReloadTask?.cancel()
        pendingReloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self else { return }
            await self.load(weekStart: weekStart, force: true)
        }
    }

    private func persistArchivedLists() {
        if let data = try? JSONEncoder().encode(archivedLists) {
            UserDefaults.standard.set(data, forKey: ArchiveKeys.archivedLists)
        }
    }

    private func persistClosedArchiveByWeek() {
        UserDefaults.standard.set(closedArchiveByWeek, forKey: ArchiveKeys.closedArchiveByWeek)
    }

    private func persistOpenRevisions() {
        if let data = try? JSONEncoder().encode(openRevisionsByWeek) {
            UserDefaults.standard.set(data, forKey: ArchiveKeys.openRevisions)
        }
    }

    private static func loadArchivedLists() -> [ArchivedShoppingList] {
        guard let data = UserDefaults.standard.data(forKey: ArchiveKeys.archivedLists),
              let decoded = try? JSONDecoder().decode([ArchivedShoppingList].self, from: data)
        else {
            return []
        }

        return decoded.sorted { $0.archivedAt > $1.archivedAt }
    }

    private static func loadClosedArchiveByWeek() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: ArchiveKeys.closedArchiveByWeek) as? [String: String] ?? [:]
    }

    private static func loadOpenRevisions() -> [String: OpenShoppingRevision] {
        guard let data = UserDefaults.standard.data(forKey: ArchiveKeys.openRevisions),
              let decoded = try? JSONDecoder().decode([String: OpenShoppingRevision].self, from: data)
        else {
            return [:]
        }

        return decoded
    }

    private func syncPendingItemCheckState(for weekStart: String, currentItems: [ShoppingItem]) async {
        guard let archive = currentClosedArchive(for: weekStart) else {
            openRevisionsByWeek.removeValue(forKey: weekStart)
            persistOpenRevisions()
            return
        }

        guard itemSignature(for: currentItems) != itemSignature(for: archive.items) else {
            openRevisionsByWeek.removeValue(forKey: weekStart)
            persistOpenRevisions()
            return
        }

        let pendingItems = makePendingItems(currentItems: currentItems, archivedItems: archive.items)
        let pendingAmounts = Dictionary(uniqueKeysWithValues: pendingItems.map { ($0.productKey, $0.totalAmount) })
        let previousState = openRevisionsByWeek[weekStart].flatMap { state in
            state.baseArchiveId == archive.id ? state : nil
        }

        let checkedPendingItems = items.filter { item in
            guard let pendingAmount = pendingAmounts[item.productKey], item.isChecked else {
                return false
            }

            guard let previousAmount = previousState?.pendingAmounts[item.productKey] else {
                return true
            }

            return pendingAmount > previousAmount + 0.000_001
        }

        if !checkedPendingItems.isEmpty {
            let originalItems = items
            isBatchUpdating = true

            let keysToReset = Set(checkedPendingItems.map(\.productKey))
            for index in items.indices where keysToReset.contains(items[index].productKey) {
                items[index].isChecked = false
            }

            do {
                for item in checkedPendingItems {
                    try await repository.setChecked(
                        weekStart: weekStart,
                        productKey: item.productKey,
                        isChecked: false
                    )
                }
            } catch {
                items = originalItems
                errorMessage = UserFacingErrorMapper.message(from: error)
            }

            isBatchUpdating = false
        }

        openRevisionsByWeek[weekStart] = OpenShoppingRevision(
            baseArchiveId: archive.id,
            pendingAmounts: pendingAmounts
        )
        persistOpenRevisions()
    }

    private func makePendingItems(currentItems: [ShoppingItem], archivedItems: [ShoppingItem]) -> [ShoppingItem] {
        let archivedByKey = Dictionary(uniqueKeysWithValues: archivedItems.map { ($0.productKey, $0) })

        return currentItems.compactMap { currentItem in
            guard let archivedItem = archivedByKey[currentItem.productKey] else {
                return currentItem
            }

            let additionalAmount = currentItem.totalAmount - archivedItem.totalAmount
            guard additionalAmount > 0.000_001 else {
                return nil
            }

            var pendingItem = currentItem
            pendingItem.totalAmount = additionalAmount
            return pendingItem
        }
    }

    private func itemSignature(for items: [ShoppingItem]) -> [String] {
        items
            .map {
                [
                    $0.productKey,
                    String(format: "%.6f", $0.totalAmount),
                    $0.unit,
                    $0.department,
                    $0.name
                ].joined(separator: "|")
            }
            .sorted()
    }
}
