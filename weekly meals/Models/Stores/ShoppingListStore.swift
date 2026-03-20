import Foundation
import Observation

struct ArchivedShoppingList: Identifiable, Codable, Hashable {
    let archiveId: String
    let weekStart: String
    let weekLabel: String
    let revision: Int
    let archivedAt: Date
    let isCurrentClosed: Bool
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
        case isCurrentClosed
        case items
    }

    init(
        archiveId: String = UUID().uuidString,
        weekStart: String,
        weekLabel: String,
        revision: Int,
        archivedAt: Date,
        isCurrentClosed: Bool,
        items: [ShoppingItem]
    ) {
        self.archiveId = archiveId
        self.weekStart = weekStart
        self.weekLabel = weekLabel
        self.revision = revision
        self.archivedAt = archivedAt
        self.isCurrentClosed = isCurrentClosed
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        archiveId = try container.decodeIfPresent(String.self, forKey: .archiveId) ?? UUID().uuidString
        weekStart = try container.decode(String.self, forKey: .weekStart)
        weekLabel = try container.decode(String.self, forKey: .weekLabel)
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 1
        archivedAt = try container.decode(Date.self, forKey: .archivedAt)
        isCurrentClosed = try container.decodeIfPresent(Bool.self, forKey: .isCurrentClosed) ?? false
        items = try container.decode([ShoppingItem].self, forKey: .items)
    }
}

private struct OpenShoppingRevision {
    let baseArchiveId: String
    let pendingAmounts: [String: Double]
}

struct ShoppingListState: Codable {
    let items: [ShoppingItem]
    let archives: [ArchivedShoppingList]
}

protocol ShoppingListRepository {
    func fetchShoppingListState(weekStart: String) async throws -> ShoppingListState
    func setChecked(weekStart: String, productKey: String, isChecked: Bool) async throws
    func archiveShoppingList(weekStart: String, weekLabel: String) async throws
    func selectArchivedList(archiveId: String) async throws
    func deleteArchivedList(archiveId: String) async throws
    func deleteAllArchivedLists(weekStart: String) async throws
    func observeShoppingListChanges(_ onChange: @escaping (_ event: BackendShoppingListChangedDTO) -> Void)
    func observeRealtimeReconnect(_ onReconnect: @escaping () -> Void)
}

protocol ShoppingListTransportClient {
    func fetchShoppingListState(weekStart: String) async throws -> BackendShoppingListStateDTO
    func setChecked(weekStart: String, productKey: String, isChecked: Bool) async throws
    func archiveShoppingList(weekStart: String, weekLabel: String) async throws
    func selectArchivedList(archiveId: String) async throws
    func deleteArchivedList(archiveId: String) async throws
    func deleteAllArchivedLists(weekStart: String) async throws
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

struct BackendShoppingListArchiveItemDTO: Codable {
    let productKey: String
    let name: String
    let unit: String
    let department: String
    let totalAmount: Double
    let isChecked: Bool
}

struct BackendShoppingListArchiveDTO: Codable {
    let archiveId: String
    let weekStart: String
    let weekLabel: String
    let revision: Int
    let archivedAt: Double
    let isCurrentClosed: Bool
    let items: [BackendShoppingListArchiveItemDTO]
}

struct BackendShoppingListStateDTO: Codable {
    let items: [BackendShoppingItemDTO]
    let archives: [BackendShoppingListArchiveDTO]
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

private struct ArchiveShoppingListPayload: Encodable {
    let userId: String
    let householdId: String
    let weekStart: String
    let weekLabel: String
}

private struct ArchiveSelectionPayload: Encodable {
    let userId: String
    let householdId: String
    let archiveId: String
}

private struct DeleteAllArchivedListsPayload: Encodable {
    let userId: String
    let householdId: String
    let weekStart: String
}

private struct BackendMutationResultDTO: Codable {
    let success: Bool?
    let archiveId: String?
    let weekStart: String?
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

private extension BackendShoppingListArchiveItemDTO {
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

private extension BackendShoppingListArchiveDTO {
    func toAppModel() -> ArchivedShoppingList {
        ArchivedShoppingList(
            archiveId: archiveId,
            weekStart: weekStart,
            weekLabel: weekLabel,
            revision: revision,
            archivedAt: Date(timeIntervalSince1970: archivedAt / 1000),
            isCurrentClosed: isCurrentClosed,
            items: items.map { $0.toAppModel() }
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

    func fetchShoppingListState(weekStart: String) async throws -> BackendShoppingListStateDTO {
        let householdId = try await resolveHouseholdId()
        let payload = try makePayload(
            ShoppingListPayload(
                userId: userId,
                householdId: householdId,
                weekStart: weekStart
            )
        )
        let envelope: WsEnvelope<BackendShoppingListStateDTO> = try await socket.emitWithAck(
            event: "weeklyPlans:getShoppingListState",
            payload: payload,
            as: WsEnvelope<BackendShoppingListStateDTO>.self
        )

        if envelope.ok, let data = envelope.data {
            return data
        }
        throw RecipeDataError.serverError(message: envelope.error ?? "Nieznany błąd weeklyPlans:getShoppingListState.")
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

    func archiveShoppingList(weekStart: String, weekLabel: String) async throws {
        let householdId = try await resolveHouseholdId()
        let payload = try makePayload(
            ArchiveShoppingListPayload(
                userId: userId,
                householdId: householdId,
                weekStart: weekStart,
                weekLabel: weekLabel
            )
        )
        let envelope: WsEnvelope<BackendMutationResultDTO> = try await socket.emitWithAck(
            event: "weeklyPlans:archiveShoppingList",
            payload: payload,
            as: WsEnvelope<BackendMutationResultDTO>.self
        )

        if envelope.ok {
            return
        }
        throw RecipeDataError.serverError(message: envelope.error ?? "Nieznany błąd weeklyPlans:archiveShoppingList.")
    }

    func selectArchivedList(archiveId: String) async throws {
        let householdId = try await resolveHouseholdId()
        let payload = try makePayload(
            ArchiveSelectionPayload(
                userId: userId,
                householdId: householdId,
                archiveId: archiveId
            )
        )
        let envelope: WsEnvelope<BackendMutationResultDTO> = try await socket.emitWithAck(
            event: "weeklyPlans:selectShoppingListArchive",
            payload: payload,
            as: WsEnvelope<BackendMutationResultDTO>.self
        )

        if envelope.ok {
            return
        }
        throw RecipeDataError.serverError(message: envelope.error ?? "Nieznany błąd weeklyPlans:selectShoppingListArchive.")
    }

    func deleteArchivedList(archiveId: String) async throws {
        let householdId = try await resolveHouseholdId()
        let payload = try makePayload(
            ArchiveSelectionPayload(
                userId: userId,
                householdId: householdId,
                archiveId: archiveId
            )
        )
        let envelope: WsEnvelope<BackendMutationResultDTO> = try await socket.emitWithAck(
            event: "weeklyPlans:deleteShoppingListArchive",
            payload: payload,
            as: WsEnvelope<BackendMutationResultDTO>.self
        )

        if envelope.ok {
            return
        }
        throw RecipeDataError.serverError(message: envelope.error ?? "Nieznany błąd weeklyPlans:deleteShoppingListArchive.")
    }

    func deleteAllArchivedLists(weekStart: String) async throws {
        let householdId = try await resolveHouseholdId()
        let payload = try makePayload(
            DeleteAllArchivedListsPayload(
                userId: userId,
                householdId: householdId,
                weekStart: weekStart
            )
        )
        let envelope: WsEnvelope<BackendMutationResultDTO> = try await socket.emitWithAck(
            event: "weeklyPlans:deleteAllShoppingListArchives",
            payload: payload,
            as: WsEnvelope<BackendMutationResultDTO>.self
        )

        if envelope.ok {
            return
        }
        throw RecipeDataError.serverError(message: envelope.error ?? "Nieznany błąd weeklyPlans:deleteAllShoppingListArchives.")
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

    func fetchShoppingListState(weekStart: String) async throws -> ShoppingListState {
        let state = try await client.fetchShoppingListState(weekStart: weekStart)
        return ShoppingListState(
            items: state.items.map { $0.toAppModel() },
            archives: state.archives
                .map { $0.toAppModel() }
                .sorted { $0.archivedAt > $1.archivedAt }
        )
    }

    func setChecked(weekStart: String, productKey: String, isChecked: Bool) async throws {
        try await client.setChecked(weekStart: weekStart, productKey: productKey, isChecked: isChecked)
    }

    func archiveShoppingList(weekStart: String, weekLabel: String) async throws {
        try await client.archiveShoppingList(weekStart: weekStart, weekLabel: weekLabel)
    }

    func selectArchivedList(archiveId: String) async throws {
        try await client.selectArchivedList(archiveId: archiveId)
    }

    func deleteArchivedList(archiveId: String) async throws {
        try await client.deleteArchivedList(archiveId: archiveId)
    }

    func deleteAllArchivedLists(weekStart: String) async throws {
        try await client.deleteAllArchivedLists(weekStart: weekStart)
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
    private struct ShoppingListCachePayload: Codable {
        let weeks: [String: ShoppingListState]
    }

    private let repository: ShoppingListRepository
    private let cacheNamespace: String
    private(set) var items: [ShoppingItem] = []
    private(set) var weekStart: String?
    private(set) var archivedLists: [ArchivedShoppingList] = []
    private(set) var isBatchUpdating: Bool = false
    private var pendingReloadTask: Task<Void, Never>?
    private var lastChangeVersionByWeek: [String: Int64] = [:]
    private var openRevisionsByWeek: [String: OpenShoppingRevision] = [:]
    private var cachedStateByWeek: [String: ShoppingListState] = [:]
    private var invalidatedWeeks: Set<String> = []
    private var pendingArchiveWeekLabel: String?
    var isLoading: Bool = false
    var errorMessage: String?

    private var cacheURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("shopping_list_cache_\(cacheNamespace).json")
    }

    init(repository: ShoppingListRepository, cacheNamespace: String = "default") {
        self.repository = repository
        self.cacheNamespace = Self.sanitizedCacheNamespace(cacheNamespace)
        loadPersistedCache()
        self.repository.observeShoppingListChanges { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                guard let currentWeekStart = self.weekStart else { return }
                guard !self.isBatchUpdating else { return }
                guard event.weekStart == currentWeekStart else {
                    return
                }
                if let changeVersion = event.changeVersion {
                    let previous = self.lastChangeVersionByWeek[currentWeekStart] ?? 0
                    guard changeVersion > previous else { return }
                    self.lastChangeVersionByWeek[currentWeekStart] = changeVersion
                }
                self.invalidatedWeeks.insert(currentWeekStart)
                self.scheduleReload(weekStart: currentWeekStart)
            }
        }
        self.repository.observeRealtimeReconnect { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                guard let currentWeekStart = self.weekStart else { return }
                guard !self.isBatchUpdating else { return }
                self.invalidatedWeeks.insert(currentWeekStart)
                self.scheduleReload(weekStart: currentWeekStart)
            }
        }
    }

    func load(weekStart: String, force: Bool = false) async {
        errorMessage = nil
        self.weekStart = weekStart

        if !force,
           let cachedState = cachedStateByWeek[weekStart],
           !invalidatedWeeks.contains(weekStart) {
            await apply(state: cachedState, for: weekStart)
            return
        }

        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }
        do {
            let state = try await repository.fetchShoppingListState(weekStart: weekStart)
            await apply(state: state, for: weekStart)
            invalidatedWeeks.remove(weekStart)
        } catch {
            errorMessage = UserFacingErrorMapper.message(from: error)
            if let cachedState = cachedStateByWeek[weekStart] {
                await apply(state: cachedState, for: weekStart)
            }
        }
    }

    func refreshCurrentWeek() {
        guard let weekStart else { return }
        invalidatedWeeks.insert(weekStart)
        scheduleReload(weekStart: weekStart)
    }

    var isArchivePendingAfterBatch: Bool {
        pendingArchiveWeekLabel != nil
    }

    func markAllChecked() {
        guard let weekStart else { return }
        guard !isBatchUpdating else { return }

        let uncheckedItems = items.filter { !$0.isChecked }
        guard !uncheckedItems.isEmpty else { return }

        let originalItems = items
        isBatchUpdating = true
        for index in items.indices {
            items[index].isChecked = true
        }
        cacheCurrentState(for: weekStart)

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.syncMarkAllChecked(
                weekStart: weekStart,
                uncheckedItems: uncheckedItems,
                originalItems: originalItems
            )
        }
    }

    func toggleChecked(_ item: ShoppingItem) async {
        guard !isBatchUpdating else { return }
        guard let index = items.firstIndex(where: { $0.productKey == item.productKey }),
              let weekStart else { return }

        let previous = items[index].isChecked
        let next = !previous
        items[index].isChecked = next
        cacheCurrentState(for: weekStart)

        do {
            try await repository.setChecked(weekStart: weekStart, productKey: item.productKey, isChecked: next)
        } catch {
            items[index].isChecked = previous
            cacheCurrentState(for: weekStart)
            errorMessage = UserFacingErrorMapper.message(from: error)
        }
    }

    func archiveCurrentList(weekLabel: String) {
        guard let weekStart,
              !items.isEmpty,
              items.allSatisfy(\.isChecked)
        else { return }
        if isBatchUpdating {
            pendingArchiveWeekLabel = weekLabel
            return
        }
        Task {
            do {
                try await repository.archiveShoppingList(weekStart: weekStart, weekLabel: weekLabel)
                openRevisionsByWeek.removeValue(forKey: weekStart)
                await load(weekStart: weekStart, force: true)
            } catch {
                errorMessage = UserFacingErrorMapper.message(from: error)
            }
        }
    }

    func selectArchivedList(archiveId: String) {
        guard let currentWeekStart = weekStart else { return }
        Task {
            do {
                try await repository.selectArchivedList(archiveId: archiveId)
                openRevisionsByWeek.removeValue(forKey: currentWeekStart)
                await load(weekStart: currentWeekStart, force: true)
            } catch {
                errorMessage = UserFacingErrorMapper.message(from: error)
            }
        }
    }

    func deleteArchivedList(archiveId: String) {
        guard let currentWeekStart = weekStart else { return }
        Task {
            do {
                let deletedArchiveIds = Set(
                    archivedLists
                        .filter { $0.archiveId == archiveId }
                        .map(\.archiveId)
                )
                try await repository.deleteArchivedList(archiveId: archiveId)
                if !deletedArchiveIds.isEmpty {
                    openRevisionsByWeek = openRevisionsByWeek.filter { !deletedArchiveIds.contains($0.value.baseArchiveId) }
                }
                await load(weekStart: currentWeekStart, force: true)
            } catch {
                errorMessage = UserFacingErrorMapper.message(from: error)
            }
        }
    }

    func deleteAllArchivedLists() {
        guard let currentWeekStart = weekStart else { return }
        Task {
            do {
                try await repository.deleteAllArchivedLists(weekStart: currentWeekStart)
                openRevisionsByWeek.removeAll()
                await load(weekStart: currentWeekStart, force: true)
            } catch {
                errorMessage = UserFacingErrorMapper.message(from: error)
            }
        }
    }

    func currentClosedArchive(for weekStart: String) -> ArchivedShoppingList? {
        archivedLists.first { $0.weekStart == weekStart && $0.isCurrentClosed }
    }

    func archiveDisplayItems(archiveId: String) -> [ShoppingItem] {
        guard let archive = archivedLists.first(where: { $0.archiveId == archiveId }) else {
            return []
        }

        guard let previousArchive = previousArchive(for: archive) else {
            return archive.items
        }

        return makePendingItems(currentItems: archive.items, archivedItems: previousArchive.items)
    }

    func archiveDisplayCounts(archiveId: String) -> (bought: Int, total: Int) {
        let items = archiveDisplayItems(archiveId: archiveId)
        return (items.filter(\.isChecked).count, items.count)
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

    private func syncMarkAllChecked(
        weekStart: String,
        uncheckedItems: [ShoppingItem],
        originalItems: [ShoppingItem]
    ) async {
        do {
            for item in uncheckedItems {
                try await repository.setChecked(
                    weekStart: weekStart,
                    productKey: item.productKey,
                    isChecked: true
                )
            }

            let pendingArchiveLabel = pendingArchiveWeekLabel
            pendingArchiveWeekLabel = nil
            isBatchUpdating = false

            if let pendingArchiveLabel {
                try await repository.archiveShoppingList(weekStart: weekStart, weekLabel: pendingArchiveLabel)
                openRevisionsByWeek.removeValue(forKey: weekStart)
            }

            await load(weekStart: weekStart, force: true)
        } catch {
            pendingArchiveWeekLabel = nil
            isBatchUpdating = false
            items = originalItems
            cacheCurrentState(for: weekStart)
            errorMessage = UserFacingErrorMapper.message(from: error)
        }
    }

    private func apply(state: ShoppingListState, for weekStart: String) async {
        archivedLists = state.archives
        items = state.items
        await syncPendingItemCheckState(for: weekStart, currentItems: state.items)
        cacheCurrentState(for: weekStart)
    }

    private func cacheCurrentState(for weekStart: String) {
        cachedStateByWeek[weekStart] = ShoppingListState(items: items, archives: archivedLists)
        persistCache()
    }

    private func loadPersistedCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let payload = try? JSONDecoder().decode(ShoppingListCachePayload.self, from: data) else {
            return
        }

        cachedStateByWeek = payload.weeks
    }

    private func persistCache() {
        do {
            let payload = ShoppingListCachePayload(weeks: cachedStateByWeek)
            let data = try JSONEncoder().encode(payload)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            // intentionally ignore cache write failures
        }
    }

    private static func sanitizedCacheNamespace(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let sanitized = String(scalars)
        return sanitized.isEmpty ? "default" : sanitized
    }

    private func syncPendingItemCheckState(for weekStart: String, currentItems: [ShoppingItem]) async {
        guard let archive = currentClosedArchive(for: weekStart) else {
            openRevisionsByWeek.removeValue(forKey: weekStart)
            return
        }

        guard itemSignature(for: currentItems) != itemSignature(for: archive.items) else {
            openRevisionsByWeek.removeValue(forKey: weekStart)
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

    private func previousArchive(for archive: ArchivedShoppingList) -> ArchivedShoppingList? {
        archivedLists
            .filter { candidate in
                candidate.weekStart == archive.weekStart && candidate.revision < archive.revision
            }
            .max { lhs, rhs in
                lhs.revision < rhs.revision
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
