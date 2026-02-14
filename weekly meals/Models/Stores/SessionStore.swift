import Foundation
import Observation
import SwiftUI

private struct DevLoginRequest: Codable {
    let displayName: String
    let email: String?
    let householdName: String?
}

private struct SessionStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = SessionStore()
}

extension EnvironmentValues {
    var sessionStore: SessionStore {
        get { self[SessionStoreKey.self] }
        set { self[SessionStoreKey.self] = newValue }
    }
}

private struct DevLoginResponse: Codable {
    struct UserDTO: Codable {
        let id: String
        let displayName: String
        let email: String?
    }

    struct HouseholdDTO: Codable {
        let id: String
        let name: String
    }

    let accessToken: String
    let refreshToken: String
    let user: UserDTO
    let household: HouseholdDTO?
}

private struct HouseholdLeaveAckDTO: Codable {
    let success: Bool
}

private struct BackendInvitationDTO: Codable {
    let id: String
    let token: String
    let householdId: String
}

private struct BackendMembershipDTO: Codable {
    let id: String
    let userId: String
    let householdId: String
    let role: String
}

private struct BackendHouseholdMembersChangedDTO: Codable {
    let householdId: String
    let action: String?
    let changedByUserId: String?
    let changedByDisplayName: String?
}

private struct BackendInvitationPreviewDTO: Codable {
    struct HouseholdDTO: Codable {
        let id: String
        let name: String
    }

    let token: String
    let status: String
    let household: HouseholdDTO?
    let invitedByDisplayName: String?
    let expiresAt: String?
}

struct InvitationPromptState: Identifiable {
    let id = UUID()
    let token: String
    let householdName: String
    let invitedByDisplayName: String?
    let expiresAtText: String?

    var message: String {
        var parts: [String] = []
        if let invitedByDisplayName, !invitedByDisplayName.isEmpty {
            parts.append("\(invitedByDisplayName) zaprasza Cię do gospodarstwa „\(householdName)”.")
        } else {
            parts.append("Otrzymano zaproszenie do gospodarstwa „\(householdName)”.")
        }
        if let expiresAtText, !expiresAtText.isEmpty {
            parts.append("Ważne do: \(expiresAtText).")
        }
        return parts.joined(separator: " ")
    }
}

@MainActor
@Observable
final class SessionStore {
    private enum Keys {
        static let accessToken = "auth.accessToken"
        static let refreshToken = "auth.refreshToken"
        static let userId = "auth.userId"
        static let householdId = "auth.householdId"
        static let displayName = "settings.user.displayName"
        static let email = "settings.user.email"
        static let householdName = "settings.household.name"
    }

    private let baseURL = URL(string: "http://localhost:3000")!

    var isSigningIn = false
    var authError: String?
    var isAuthenticated = false
    var currentUserId: String?
    var currentHouseholdId: String?
    var currentHouseholdName: String?
    var invitationPrompt: InvitationPromptState?
    var householdRealtimeVersion: Int = 0

    var weeklyMealStore: WeeklyMealStore?
    var recipeCatalogStore: RecipeCatalogStore?
    var shoppingListStore: ShoppingListStore?
    var datesViewModel = DatesViewModel()
    private var realtimeSocket: RecipeSocketClient?

    init() {
        restoreSession()
    }

    func loginDev(displayName: String, email: String?) async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            authError = "Podaj nazwę użytkownika."
            return
        }

        isSigningIn = true
        authError = nil
        defer { isSigningIn = false }

        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("auth/dev"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = DevLoginRequest(
                displayName: trimmedName,
                email: email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
                    ? nil
                    : email?.trimmingCharacters(in: .whitespacesAndNewlines),
                householdName: "Home"
            )
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw RecipeDataError.serverError(message: "Brak odpowiedzi HTTP z serwera.")
            }
            guard (200...299).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Błąd logowania dev."
                throw RecipeDataError.serverError(message: message)
            }

            let decoded = try JSONDecoder().decode(DevLoginResponse.self, from: data)
            persistSession(decoded)
            if let household = decoded.household {
                bootstrapSession(userId: decoded.user.id, householdId: household.id, householdName: household.name)
            } else {
                currentUserId = decoded.user.id
                currentHouseholdId = nil
                currentHouseholdName = nil
            }
            isAuthenticated = true
        } catch {
            authError = error.localizedDescription
            isAuthenticated = false
            clearRuntimeStores()
        }
    }

    func logout() {
        clearPersistedSession()
        clearRuntimeStores()
        isAuthenticated = false
        authError = nil
        currentUserId = nil
        currentHouseholdId = nil
        currentHouseholdName = nil
    }

    private func restoreSession() {
        let defaults = UserDefaults.standard
        guard
            let userId = defaults.string(forKey: Keys.userId),
            !userId.isEmpty
        else {
            return
        }

        currentUserId = userId
        let householdId = defaults.string(forKey: Keys.householdId)
        let householdName = defaults.string(forKey: Keys.householdName)
        if let householdId, !householdId.isEmpty {
            bootstrapSession(
                userId: userId,
                householdId: householdId,
                householdName: (householdName?.isEmpty == false ? householdName : nil)
            )
        }
        isAuthenticated = true
    }

    private func bootstrapSession(userId: String, householdId: String, householdName: String? = nil) {
        currentUserId = userId
        currentHouseholdId = householdId
        currentHouseholdName = householdName
        let socketClient = SocketIORecipeSocketClient(baseURL: baseURL)
        self.realtimeSocket = socketClient

        let recipeTransport = WebSocketRecipeTransportClient(
            socket: socketClient,
            userId: userId,
            householdId: householdId
        )
        let weeklyPlanTransport = WebSocketWeeklyPlanTransportClient(
            socket: socketClient,
            userId: userId,
            householdId: householdId
        )
        let shoppingTransport = WebSocketShoppingListTransportClient(
            socket: socketClient,
            userId: userId,
            householdId: householdId
        )

        self.weeklyMealStore = WeeklyMealStore(
            weeklyPlanRepository: ApiWeeklyPlanRepository(client: weeklyPlanTransport),
            currentUserId: userId
        )
        self.recipeCatalogStore = RecipeCatalogStore(
            repository: ApiRecipeRepository(client: recipeTransport)
        )
        self.shoppingListStore = ShoppingListStore(
            repository: ApiShoppingListRepository(client: shoppingTransport)
        )
        self.datesViewModel = DatesViewModel()
        observeHouseholdRealtime()
    }

    private func clearRuntimeStores() {
        realtimeSocket?.off(event: "households:membersChanged")
        realtimeSocket = nil
        weeklyMealStore = nil
        recipeCatalogStore = nil
        shoppingListStore = nil
        datesViewModel = DatesViewModel()
    }

    private func observeHouseholdRealtime() {
        realtimeSocket?.off(event: "households:membersChanged")
        realtimeSocket?.on(event: "households:membersChanged") { [weak self] items in
            guard let self else { return }
            guard let first = items.first,
                  JSONSerialization.isValidJSONObject(first),
                  let data = try? JSONSerialization.data(withJSONObject: first),
                  let event = try? JSONDecoder().decode(BackendHouseholdMembersChangedDTO.self, from: data)
            else { return }

            Task { @MainActor in
                guard let currentHouseholdId = self.currentHouseholdId, !currentHouseholdId.isEmpty else { return }
                guard event.householdId == currentHouseholdId else { return }
                self.householdRealtimeVersion &+= 1
            }
        }
    }

    func createHousehold(name: String) async {
        guard let userId = currentUserId, !userId.isEmpty else {
            authError = "Brak użytkownika sesji."
            return
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            authError = "Podaj nazwę gospodarstwa."
            return
        }

        isSigningIn = true
        authError = nil
        defer { isSigningIn = false }

        do {
            let socketClient = SocketIORecipeSocketClient(baseURL: baseURL)
            let envelope: WsEnvelope<BackendHouseholdDTO> = try await socketClient.emitWithAck(
                event: "households:create",
                payload: [
                    "userId": userId,
                    "data": ["name": trimmed]
                ],
                as: WsEnvelope<BackendHouseholdDTO>.self
            )

            guard envelope.ok, let household = envelope.data else {
                throw RecipeDataError.serverError(message: envelope.error ?? "Nie udało się utworzyć gospodarstwa.")
            }

            persistHousehold(id: household.id, name: household.name)
            bootstrapSession(userId: userId, householdId: household.id, householdName: household.name)
            weeklyMealStore?.resetLocalPlanningState()
            isAuthenticated = true
        } catch {
            authError = error.localizedDescription
        }
    }

    func leaveCurrentHousehold() async {
        guard let userId = currentUserId, !userId.isEmpty,
              let householdId = currentHouseholdId, !householdId.isEmpty else { return }

        isSigningIn = true
        authError = nil
        defer { isSigningIn = false }

        do {
            let socketClient = SocketIORecipeSocketClient(baseURL: baseURL)
            let envelope: WsEnvelope<HouseholdLeaveAckDTO> = try await socketClient.emitWithAck(
                event: "households:leave",
                payload: [
                    "userId": userId,
                    "householdId": householdId
                ],
                as: WsEnvelope<HouseholdLeaveAckDTO>.self
            )

            if !envelope.ok {
                throw RecipeDataError.serverError(message: envelope.error ?? "Nie udało się opuścić gospodarstwa.")
            }

            clearPersistedHousehold()
            clearRuntimeStores()
            currentHouseholdId = nil
            currentHouseholdName = nil
            isAuthenticated = true
        } catch is CancellationError {
            // Ignore task cancellation caused by view lifecycle updates.
            return
        } catch {
            authError = error.localizedDescription
        }
    }

    func createInvitationLink() async throws -> URL {
        guard let userId = currentUserId, !userId.isEmpty,
              let householdId = currentHouseholdId, !householdId.isEmpty else {
            throw RecipeDataError.serverError(message: "Brak aktywnego gospodarstwa.")
        }

        let socketClient = SocketIORecipeSocketClient(baseURL: baseURL)
        let envelope: WsEnvelope<BackendInvitationDTO> = try await socketClient.emitWithAck(
            event: "households:createInvitation",
            payload: [
                "userId": userId,
                "householdId": householdId,
                "data": [:]
            ],
            as: WsEnvelope<BackendInvitationDTO>.self
        )

        guard envelope.ok, let invitation = envelope.data else {
            throw RecipeDataError.serverError(message: envelope.error ?? "Nie udało się utworzyć zaproszenia.")
        }

        var components = URLComponents()
        components.scheme = "weeklymeals"
        components.host = "invite"
        components.queryItems = [
            URLQueryItem(name: "token", value: invitation.token)
        ]
        guard let url = components.url else {
            throw RecipeDataError.serverError(message: "Nie udało się zbudować linku zaproszenia.")
        }
        return url
    }

    private func previewInvitation(token: String) async throws -> BackendInvitationPreviewDTO {
        guard let userId = currentUserId, !userId.isEmpty else {
            throw RecipeDataError.serverError(message: "Zaloguj się, aby dołączyć do gospodarstwa.")
        }

        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw RecipeDataError.serverError(message: "Nieprawidłowy token zaproszenia.")
        }

        let socketClient = SocketIORecipeSocketClient(baseURL: baseURL)
        let envelope: WsEnvelope<BackendInvitationPreviewDTO> = try await socketClient.emitWithAck(
            event: "households:previewInvitation",
            payload: [
                "userId": userId,
                "data": ["token": trimmedToken]
            ],
            as: WsEnvelope<BackendInvitationPreviewDTO>.self
        )

        guard envelope.ok, let data = envelope.data else {
            throw RecipeDataError.serverError(message: envelope.error ?? "Nie udało się sprawdzić zaproszenia.")
        }

        return data
    }

    func acceptInvitation(token: String) async throws {
        guard let userId = currentUserId, !userId.isEmpty else {
            throw RecipeDataError.serverError(message: "Brak użytkownika sesji.")
        }

        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw RecipeDataError.serverError(message: "Nieprawidłowy token zaproszenia.")
        }

        isSigningIn = true
        authError = nil
        defer { isSigningIn = false }

        let socketClient = SocketIORecipeSocketClient(baseURL: baseURL)
        let acceptEnvelope: WsEnvelope<BackendMembershipDTO> = try await socketClient.emitWithAck(
            event: "households:acceptInvitation",
            payload: [
                "userId": userId,
                "data": ["token": trimmedToken]
            ],
            as: WsEnvelope<BackendMembershipDTO>.self
        )

        guard acceptEnvelope.ok, let membership = acceptEnvelope.data else {
            throw RecipeDataError.serverError(message: acceptEnvelope.error ?? "Nie udało się dołączyć do gospodarstwa.")
        }

        let householdEnvelope: WsEnvelope<BackendHouseholdDTO> = try await socketClient.emitWithAck(
            event: "households:findById",
            payload: [
                "userId": userId,
                "id": membership.householdId
            ],
            as: WsEnvelope<BackendHouseholdDTO>.self
        )

        guard householdEnvelope.ok, let household = householdEnvelope.data else {
            throw RecipeDataError.serverError(message: householdEnvelope.error ?? "Dołączono, ale nie udało się pobrać danych gospodarstwa.")
        }

        persistHousehold(id: household.id, name: household.name)
        bootstrapSession(userId: userId, householdId: household.id, householdName: household.name)
        weeklyMealStore?.resetLocalPlanningState()
        isAuthenticated = true
    }

    func acceptPendingInvitation(token: String) async {
        invitationPrompt = nil
        do {
            try await acceptInvitation(token: token)
        } catch is CancellationError {
            return
        } catch {
            authError = error.localizedDescription
        }
    }

    func dismissInvitationPrompt() {
        invitationPrompt = nil
    }

    func handleIncomingURL(_ url: URL) {
        guard url.scheme == "weeklymeals", url.host == "invite" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        guard let token = components.queryItems?.first(where: { $0.name == "token" })?.value else { return }

        Task {
            do {
                let preview = try await previewInvitation(token: token)
                switch preview.status {
                case "PENDING":
                    let expiry = Self.formatInvitationExpiry(preview.expiresAt)
                    invitationPrompt = InvitationPromptState(
                        token: preview.token,
                        householdName: preview.household?.name ?? "Gospodarstwo",
                        invitedByDisplayName: preview.invitedByDisplayName,
                        expiresAtText: expiry
                    )
                case "ALREADY_MEMBER":
                    authError = "Jesteś już członkiem tego gospodarstwa."
                case "EXPIRED":
                    authError = "To zaproszenie wygasło."
                case "REDEEMED":
                    authError = "Ten link zaproszenia jest jednorazowy. Poproś o nowy link."
                case "NOT_FOUND":
                    authError = "Nie znaleziono zaproszenia. Sprawdź link."
                default:
                    authError = "Nie można użyć tego zaproszenia."
                }
            } catch is CancellationError {
                return
            } catch {
                authError = error.localizedDescription
            }
        }
    }

    private static func formatInvitationExpiry(_ iso8601: String?) -> String? {
        guard let iso8601, !iso8601.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso8601) else { return nil }
        let output = DateFormatter()
        output.locale = Locale(identifier: "pl_PL")
        output.dateStyle = .medium
        output.timeStyle = .short
        return output.string(from: date)
    }

    private func persistSession(_ response: DevLoginResponse) {
        let defaults = UserDefaults.standard
        defaults.set(response.accessToken, forKey: Keys.accessToken)
        defaults.set(response.refreshToken, forKey: Keys.refreshToken)
        defaults.set(response.user.id, forKey: Keys.userId)
        defaults.set(response.user.displayName, forKey: Keys.displayName)
        defaults.set(response.user.email ?? "", forKey: Keys.email)
        if let household = response.household {
            persistHousehold(id: household.id, name: household.name)
        } else {
            clearPersistedHousehold()
        }
    }

    private func persistHousehold(id: String, name: String) {
        let defaults = UserDefaults.standard
        defaults.set(id, forKey: Keys.householdId)
        defaults.set(name, forKey: Keys.householdName)
    }

    private func clearPersistedHousehold() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.householdId)
        defaults.removeObject(forKey: Keys.householdName)
    }

    private func clearPersistedSession() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.accessToken)
        defaults.removeObject(forKey: Keys.refreshToken)
        defaults.removeObject(forKey: Keys.userId)
        defaults.removeObject(forKey: Keys.householdId)
    }
}
