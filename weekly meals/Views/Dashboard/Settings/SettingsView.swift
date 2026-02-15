import SwiftUI

private struct HouseholdMember: Identifiable, Hashable {
    let id: String
    let displayName: String
    let email: String?
    let avatarUrl: String?
    let role: String
}

private struct BackendHouseholdMemberDTO: Decodable {
    struct UserDTO: Decodable {
        let id: String
        let displayName: String
        let email: String?
        let avatarUrl: String?
    }

    let id: String
    let userId: String
    let householdId: String
    let role: String
    let user: UserDTO
}

struct SettingsView: View {
    @Environment(\.sessionStore) private var sessionStore
    @AppStorage("settings.theme") private var themeRawValue: String = AppTheme.system.rawValue
    @AppStorage("settings.notifications.enabled") private var notificationsEnabled: Bool = true
    @AppStorage("settings.notifications.planReminders") private var planRemindersEnabled: Bool = true
    @AppStorage("settings.notifications.shoppingReminders") private var shoppingRemindersEnabled: Bool = true
    @AppStorage("settings.user.displayName") private var userDisplayName: String = "Rafał Piechowicz"
    @AppStorage("settings.user.email") private var userEmail: String = "rafal@example.com"
    @AppStorage("settings.household.name") private var persistedHouseholdName: String = ""

    @State private var householdId: String = UUID().uuidString
    @State private var showCreateHouseholdSheet = false
    @State private var showHouseholdSheet = false
    @State private var showPreferencesSheet = false
    @State private var createHouseholdName = ""
    @State private var showLogoutAlert = false
    @State private var householdMembers: [HouseholdMember] = []
    @State private var isLoadingMembers = false
    @State private var invitationLink: URL?
    @State private var isCreatingInvitation = false
    private let apiBaseURL = URL(string: "http://localhost:3000")

    private var hasHousehold: Bool {
        !persistedHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canCreateInvitations: Bool {
        guard let currentUserId = sessionStore.currentUserId else { return false }
        guard let me = householdMembers.first(where: { $0.id == currentUserId }) else { return false }
        return me.role.uppercased() == "OWNER"
    }

    private var householdSummary: String {
        if hasHousehold { return persistedHouseholdName }
        return "Brak gospodarstwa"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    accountSection
                    householdEntryCard
                    preferencesEntryCard
                    logoutSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .padding(.bottom, 16)
            }
            .navigationTitle("Ustawienia")
            .sheet(isPresented: $showCreateHouseholdSheet) {
                createHouseholdSheet
            }
            .sheet(isPresented: $showHouseholdSheet) {
                householdManagementSheet
            }
            .sheet(isPresented: $showPreferencesSheet) {
                preferencesSheet
            }
            .alert("Wylogować się?", isPresented: $showLogoutAlert) {
                Button("Anuluj", role: .cancel) {}
                Button("Wyloguj", role: .destructive) {
                    sessionStore.logout()
                }
            } message: {
                Text("Sesja zostanie zakończona na tym urządzeniu.")
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Konto")

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(userDisplayName)
                            .font(.headline)
                        Text(userEmail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(10)
                            .background(Color.red.opacity(0.12), in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .myBackground()
            .myBorderOverlay()
        }
    }

    private var householdEntryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Gospodarstwo")

            if hasHousehold {
                Button {
                    showHouseholdSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "house.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(householdSummary)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text("Otwórz szczegóły gospodarstwa")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .myBackground()
                .myBorderOverlay()
            } else {
                Button {
                    createHouseholdName = ""
                    showCreateHouseholdSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "house.badge.plus")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Utwórz gospodarstwo")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text("Brak aktywnego gospodarstwa. Utwórz je, aby planować i udostępniać listy.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .myBackground()
                .myBorderOverlay()
            }
        }
    }

    private var preferencesEntryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Preferencje")

            Button {
                showPreferencesSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ustawienia aplikacji")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("Powiadomienia i wygląd")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .myBackground()
            .myBorderOverlay()
        }
    }

    private var logoutSection: some View {
        EmptyView()
    }

    private var createHouseholdSheet: some View {
        NavigationStack {
            Form {
                Section("Nazwa gospodarstwa") {
                    TextField("Np. Dom", text: $createHouseholdName)
                }
            }
            .navigationTitle("Nowe gospodarstwo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { showCreateHouseholdSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Utwórz") {
                        let value = createHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !value.isEmpty else { return }
                        Task {
                            await sessionStore.createHousehold(name: value)
                            if let currentId = sessionStore.currentHouseholdId {
                                persistedHouseholdName = value
                                householdId = currentId
                                showCreateHouseholdSheet = false
                            }
                        }
                    }
                    .disabled(createHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var householdManagementSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if hasHousehold {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(persistedHouseholdName)
                                        .font(.headline)
                                    Text(canCreateInvitations ? "Udostępnij zaproszenie do gospodarstwa." : "Tylko właściciel może udostępniać zaproszenia.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if canCreateInvitations, let invitationLink {
                                    ShareLink(item: invitationLink) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.subheadline)
                                    }
                                    .buttonStyle(.bordered)
                                } else if canCreateInvitations, isCreatingInvitation {
                                    ProgressView()
                                        .controlSize(.small)
                                } else if canCreateInvitations {
                                    Button {
                                        Task { await createInvitationLink() }
                                    } label: {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.subheadline)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            Divider()

                            Button(role: .destructive) {
                                Task {
                                    await sessionStore.leaveCurrentHousehold()
                                    if sessionStore.currentHouseholdId == nil {
                                        persistedHouseholdName = ""
                                        householdId = UUID().uuidString
                                        showHouseholdSheet = false
                                    }
                                }
                            } label: {
                                HStack {
                                    if sessionStore.isSigningIn {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                    }
                                    Text(sessionStore.isSigningIn ? "Opuszczanie..." : "Opuść")
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.red)
                            .disabled(sessionStore.isSigningIn)

                            if let error = sessionStore.authError, !error.isEmpty {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(14)
                        .myBackground()
                        .myBorderOverlay()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Członkowie")
                                .font(.subheadline.weight(.semibold))

                            if isLoadingMembers {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Ładowanie...")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            } else if householdMembers.isEmpty {
                                Text("Brak członków do wyświetlenia.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(householdMembers) { member in
                                    HStack(spacing: 10) {
                                        memberAvatar(for: member)
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(member.displayName)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                if member.id == sessionStore.currentUserId {
                                                    Text("Ty")
                                                        .font(.caption2)
                                                        .fontWeight(.semibold)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.blue.opacity(0.15), in: Capsule())
                                                        .foregroundStyle(.blue)
                                                }
                                            }
                                            Text(member.email ?? "Brak e-maila")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .padding(14)
                        .myBackground()
                        .myBorderOverlay()
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nie masz jeszcze gospodarstwa.")
                                .font(.subheadline)
                            Text("Utwórz gospodarstwo i zaproś domowników linkiem.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                createHouseholdName = ""
                                showCreateHouseholdSheet = true
                            } label: {
                                Label("Utwórz gospodarstwo", systemImage: "house.badge.plus")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .myBackground()
                        .myBorderOverlay()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .navigationTitle("Gospodarstwo")
            .task(id: showHouseholdSheet) {
                if showHouseholdSheet {
                    await loadHouseholdMembers()
                    if canCreateInvitations {
                        await createInvitationLink()
                    } else {
                        invitationLink = nil
                    }
                }
            }
            .task(id: sessionStore.householdRealtimeVersion) {
                if showHouseholdSheet {
                    await loadHouseholdMembers()
                    if canCreateInvitations, invitationLink == nil {
                        await createInvitationLink()
                    } else if !canCreateInvitations {
                        invitationLink = nil
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij") { showHouseholdSheet = false }
                }
            }
        }
    }

    private var preferencesSheet: some View {
        NavigationStack {
            Form {
                Section("Powiadomienia") {
                    Toggle("Powiadomienia", isOn: $notificationsEnabled)
                    Toggle("Przypomnienia o planie", isOn: $planRemindersEnabled)
                        .disabled(!notificationsEnabled)
                    Toggle("Przypomnienia o zakupach", isOn: $shoppingRemindersEnabled)
                        .disabled(!notificationsEnabled)
                }

                Section("Wygląd") {
                    Picker("Motyw", selection: $themeRawValue) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title).tag(theme.rawValue)
                        }
                    }
                }
            }
            .navigationTitle("Preferencje")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Gotowe") { showPreferencesSheet = false }
                }
            }
        }
    }

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private func loadHouseholdMembers() async {
        guard let userId = sessionStore.currentUserId, !userId.isEmpty,
              let householdId = sessionStore.currentHouseholdId, !householdId.isEmpty else {
            householdMembers = []
            return
        }

        isLoadingMembers = true
        defer { isLoadingMembers = false }

        do {
            guard let apiBaseURL else {
                throw RecipeDataError.serverError(message: "Brak poprawnego adresu API.")
            }
            let socketClient = SocketIORecipeSocketClient(baseURL: apiBaseURL)
            let envelope: WsEnvelope<[BackendHouseholdMemberDTO]> = try await socketClient.emitWithAck(
                event: "households:listMembers",
                payload: [
                    "userId": userId,
                    "householdId": householdId
                ],
                as: WsEnvelope<[BackendHouseholdMemberDTO]>.self
            )

            guard envelope.ok, let data = envelope.data else {
                throw RecipeDataError.serverError(message: envelope.error ?? "Nie udało się pobrać członków gospodarstwa.")
            }

            householdMembers = data.map {
                HouseholdMember(
                    id: $0.user.id,
                    displayName: $0.user.displayName,
                    email: $0.user.email,
                    avatarUrl: $0.user.avatarUrl,
                    role: $0.role
                )
            }
            if !canCreateInvitations {
                sessionStore.authError = nil
            }
        } catch is CancellationError {
            // Sheet/task lifecycle cancellation is expected; do not surface as UI error.
            return
        } catch {
            sessionStore.authError = UserFacingErrorMapper.message(from: error)
            householdMembers = []
        }
    }

    @ViewBuilder
    private func memberAvatar(for member: HouseholdMember) -> some View {
        if let avatarUrl = member.avatarUrl, let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.25))
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 34, height: 34)
                .overlay(
                    Text(initials(for: member.displayName))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                )
        }
    }

    private func initials(for name: String) -> String {
        let parts = name
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        return parts.joined()
    }

    private func createInvitationLink() async {
        guard hasHousehold else {
            invitationLink = nil
            return
        }
        isCreatingInvitation = true
        defer { isCreatingInvitation = false }
        do {
            invitationLink = try await sessionStore.createInvitationLink()
        } catch is CancellationError {
            return
        } catch {
            sessionStore.authError = UserFacingErrorMapper.message(from: error)
            invitationLink = nil
        }
    }

}

#Preview {
    SettingsView()
}
