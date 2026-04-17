import AuthenticationServices
import Foundation
import Observation
import SwiftUI

/// Matches backend POST /auth/apple payload exactly.
private struct AppleSignInRequest: Codable {
    let identityToken: String
    let rawNonce: String
    let givenName: String?
    let familyName: String?
    let email: String?
}

/// Matches backend response envelope for both /auth/apple and /auth/dev
/// (both funnel through AuthService.buildAuthResult → same shape).
private struct SessionResponse: Codable {
    struct UserDTO: Codable {
        let id: String
        let displayName: String
        let email: String?
        let provider: String?
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

private struct SessionStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = SessionStore()
}

extension EnvironmentValues {
    var sessionStore: SessionStore {
        get { self[SessionStoreKey.self] }
        set { self[SessionStoreKey.self] = newValue }
    }
}

private struct HouseholdLeaveAckDTO: Codable {
    let success: Bool
}

private struct PushDeviceRegisterAckDTO: Codable {
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
        static let appleUserIdentifier = "auth.appleUserIdentifier"
        static let householdId = "auth.householdId"
        static let displayName = "settings.user.displayName"
        static let email = "settings.user.email"
        static let householdName = "settings.household.name"
        static let pushDeviceToken = "notifications.pushDeviceToken"
    }

    private let baseURL = AppEnvironment.apiBaseURL

    /// Aktualny access token z Keychain. Używać do autoryzacji HTTP requestów.
    var currentAccessToken: String? {
        KeychainService.get(forKey: Keys.accessToken)
    }

    /// Aktualny refresh token z Keychain. Używać do odświeżania sesji.
    var currentRefreshToken: String? {
        KeychainService.get(forKey: Keys.refreshToken)
    }

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
    private var pendingPushDeviceToken: String?
    private let appleSignInCoordinator = AppleSignInCoordinator()

    init() {
        pendingPushDeviceToken = UserDefaults.standard.string(forKey: Keys.pushDeviceToken)
        restoreSession()
    }

    func refreshRealtimeStoresOnForeground() {
        weeklyMealStore?.refreshObservedState()
        shoppingListStore?.refreshCurrentWeek()
        if let recipeCatalogStore {
            Task {
                await recipeCatalogStore.reload()
            }
        }
    }

    // MARK: - Sign in with Apple

    /// Uruchamia natywny ekran Sign in with Apple. Po pomyślnym logowaniu wysyła
    /// identityToken + rawNonce do backendu (`POST /auth/apple`), zapisuje sesję.
    func signInWithApple() async {
        isSigningIn = true
        authError = nil
        defer { isSigningIn = false }

        do {
            let appleResult = try await appleSignInCoordinator.start()
            try await exchangeAppleCredential(appleResult)
        } catch AppleSignInError.canceled {
            // Użytkownik anulował — nie pokazuj błędu.
            return
        } catch let error as AppleSignInError {
            authError = error.errorDescription
            isAuthenticated = false
            clearRuntimeStores()
        } catch {
            authError = UserFacingErrorMapper.message(from: error)
            isAuthenticated = false
            clearRuntimeStores()
        }
    }

    /// POST /auth/apple z identityToken, rawNonce oraz (tylko na pierwszym
    /// logowaniu) imieniem i adresem email.
    private func exchangeAppleCredential(_ credential: AppleSignInResult) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/apple"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = AppleSignInRequest(
            identityToken: credential.identityToken,
            rawNonce: credential.rawNonce,
            givenName: credential.givenName,
            familyName: credential.familyName,
            email: credential.email
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RecipeDataError.serverError(message: "Brak odpowiedzi HTTP z serwera.")
        }
        guard (200...299).contains(http.statusCode) else {
            let message = Self.decodeErrorMessage(data: data) ?? "Błąd logowania Apple (HTTP \(http.statusCode))."
            throw RecipeDataError.serverError(message: message)
        }

        let decoded = try JSONDecoder().decode(SessionResponse.self, from: data)
        persistSession(decoded, appleUserIdentifier: credential.userIdentifier)
        if let household = decoded.household {
            bootstrapSession(userId: decoded.user.id, householdId: household.id, householdName: household.name)
        } else {
            currentUserId = decoded.user.id
            currentHouseholdId = nil
            currentHouseholdName = nil
        }
        await registerPushDeviceIfPossible()
        isAuthenticated = true
    }

    private static func decodeErrorMessage(data: Data) -> String? {
        struct ErrorResponse: Codable { let message: String? }
        if let obj = try? JSONDecoder().decode(ErrorResponse.self, from: data), let msg = obj.message {
            return msg
        }
        return String(data: data, encoding: .utf8)
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

    func updatePushDeviceToken(_ token: String) {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        pendingPushDeviceToken = normalized
        UserDefaults.standard.set(normalized, forKey: Keys.pushDeviceToken)
        Task { [weak self] in
            await self?.registerPushDeviceIfPossible()
        }
    }

    /// Na starcie aplikacji pytamy Apple o aktualny stan podpisanego wcześniej
    /// użytkownika. Jeżeli user cofnął dostęp w Ustawieniach iOS → Apple ID,
    /// wylogowujemy lokalną sesję.
    func validateAppleCredentialStateIfNeeded() async {
        guard
            let userIdentifier = UserDefaults.standard.string(forKey: Keys.appleUserIdentifier),
            !userIdentifier.isEmpty
        else { return }

        let state = await AppleSignInCoordinator.currentCredentialState(for: userIdentifier)
        switch state {
        case .revoked, .notFound:
            logout()
        case .authorized, .transferred:
            break
        @unknown default:
            break
        }
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
        Task { [weak self] in
            await self?.registerPushDeviceIfPossible()
            await self?.validateAppleCredentialStateIfNeeded()
        }
        isAuthenticated = true
    }

    private func bootstrapSession(userId: String, householdId: String, householdName: String? = nil) {
        currentUserId = userId
        currentHouseholdId = householdId
        currentHouseholdName = householdName
        let datesViewModel = DatesViewModel()
        self.datesViewModel = datesViewModel
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
        let shoppingListStore = ShoppingListStore(
            repository: ApiShoppingListRepository(client: shoppingTransport),
            currentUserId: userId,
            cacheNamespace: "\(userId)_\(householdId)"
        )
        self.shoppingListStore = shoppingListStore
        observeHouseholdRealtime()

        let initialWeekStart = datesViewModel.weekStartISO
        Task {
            await shoppingListStore.load(weekStart: initialWeekStart)
        }
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
            await registerPushDeviceIfPossible()
            isAuthenticated = true
        } catch {
            authError = UserFacingErrorMapper.message(from: error)
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
            authError = UserFacingErrorMapper.message(from: error)
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
        await registerPushDeviceIfPossible()
        isAuthenticated = true
    }

    func acceptPendingInvitation(token: String) async {
        invitationPrompt = nil
        do {
            try await acceptInvitation(token: token)
        } catch is CancellationError {
            return
        } catch {
            authError = UserFacingErrorMapper.message(from: error)
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
                authError = UserFacingErrorMapper.message(from: error)
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

    private func registerPushDeviceIfPossible() async {
        guard let userId = currentUserId, !userId.isEmpty else { return }
        guard let token = pendingPushDeviceToken, !token.isEmpty else { return }

        do {
            let socketClient = SocketIORecipeSocketClient(baseURL: baseURL)
            let envelope: WsEnvelope<PushDeviceRegisterAckDTO> = try await socketClient.emitWithAck(
                event: "notifications:registerDevice",
                payload: [
                    "userId": userId,
                    "data": [
                        "deviceToken": token,
                        "platform": "IOS",
                        "appBundleId": Bundle.main.bundleIdentifier ?? "weeklymeals",
                    ],
                ],
                as: WsEnvelope<PushDeviceRegisterAckDTO>.self
            )

            if !envelope.ok {
                throw RecipeDataError.serverError(message: envelope.error ?? "Nie udało się zarejestrować urządzenia.")
            }
        } catch {
            // App should continue normally even when push registration fails.
        }
    }

    private func persistSession(_ response: SessionResponse, appleUserIdentifier: String? = nil) {
        // Tokeny auth trafiają do Keychain (szyfrowany, chroniony przez Secure Enclave)
        KeychainService.save(response.accessToken, forKey: Keys.accessToken)
        KeychainService.save(response.refreshToken, forKey: Keys.refreshToken)

        if let appleUserIdentifier, !appleUserIdentifier.isEmpty {
            KeychainService.save(appleUserIdentifier, forKey: Keys.appleUserIdentifier)
            UserDefaults.standard.set(appleUserIdentifier, forKey: Keys.appleUserIdentifier)
        }

        // Dane niechronione — UserDefaults wystarczy
        let defaults = UserDefaults.standard
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
        // Usuń tokeny z Keychain
        KeychainService.delete(forKey: Keys.accessToken)
        KeychainService.delete(forKey: Keys.refreshToken)
        KeychainService.delete(forKey: Keys.appleUserIdentifier)

        // Usuń dane sesji z UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.userId)
        defaults.removeObject(forKey: Keys.householdId)
        defaults.removeObject(forKey: Keys.appleUserIdentifier)
    }
}
