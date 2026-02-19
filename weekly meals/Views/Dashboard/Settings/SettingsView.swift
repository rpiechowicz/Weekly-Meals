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
    @AppStorage("settings.user.displayName") private var userDisplayName: String = "user1"
    @AppStorage("settings.user.email") private var userEmail: String = "user1@example.com"
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
    private let apiBaseURL = AppEnvironment.apiBaseURL

    private var hasHousehold: Bool {
        !persistedHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var trimmedCreateHouseholdName: String {
        createHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmitCreateHousehold: Bool {
        !trimmedCreateHouseholdName.isEmpty
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
            ZStack {
                DashboardLiquidBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        accountSection
                        householdEntryCard
                        preferencesEntryCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Ustawienia")
            .sheet(isPresented: $showCreateHouseholdSheet) {
                createHouseholdSheet
                    .dashboardLiquidSheet()
            }
            .sheet(isPresented: $showHouseholdSheet) {
                householdManagementSheet
                    .dashboardLiquidSheet()
            }
            .sheet(isPresented: $showPreferencesSheet) {
                preferencesSheet
                    .dashboardLiquidSheet()
            }
            .alert("Wylogować się?", isPresented: $showLogoutAlert) {
                Button("Anuluj", role: .cancel) {}
                Button("Wyloguj", role: .destructive) {
                    sessionStore.logout()
                }
            } message: {
                Text("Sesja zostanie zakończona na tym urządzeniu.")
            }
            .task(id: sessionStore.householdRealtimeVersion) {
                await preloadHouseholdContextIfNeeded()
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.18))
                    Image(systemName: "person.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text(userDisplayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                    Text(userEmail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(width: 34, height: 34)
                        .background(Color.red.opacity(0.14), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.24), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Wyloguj")
            }

            HStack(spacing: 8) {
                accountInfoPill(icon: "house.fill", title: householdSummary, tint: hasHousehold ? .green : .secondary)
                accountInfoPill(icon: "circle.lefthalf.filled", title: (AppTheme(rawValue: themeRawValue) ?? .system).title, tint: .blue)
            }
        }
        .padding(18)
        .dashboardLiquidCard(cornerRadius: 26, strokeOpacity: 0.24)
    }

    private var householdEntryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "house.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .frame(width: 30, height: 30)
                    .background(Color.green.opacity(0.16), in: Circle())

                Text("Gospodarstwo")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)

                Spacer(minLength: 0)

                Text(hasHousehold ? "Aktywne" : "Brak")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(hasHousehold ? .green : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((hasHousehold ? Color.green : Color.white).opacity(hasHousehold ? 0.15 : 0.12), in: Capsule())
            }

            if hasHousehold {
                settingsRowButton(
                    title: householdSummary,
                    subtitle: "Domownicy i zaproszenia",
                    icon: "person.2.fill",
                    accent: .blue
                ) {
                    Task { await preloadHouseholdContextIfNeeded() }
                    showHouseholdSheet = true
                }
            } else {
                settingsRowButton(
                    title: "Utwórz gospodarstwo",
                    subtitle: "Brak aktywnego gospodarstwa",
                    icon: "house.badge.plus",
                    accent: .blue
                ) {
                    createHouseholdName = ""
                    showCreateHouseholdSheet = true
                }
            }
        }
        .padding(18)
        .dashboardLiquidCard(cornerRadius: 24, strokeOpacity: 0.22)
    }

    private var preferencesEntryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 30, height: 30)
                    .background(Color.indigo.opacity(0.16), in: Circle())

                Text("Preferencje")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)

                Spacer(minLength: 0)
                Text((AppTheme(rawValue: themeRawValue) ?? .system).title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, in: Capsule())
            }

            settingsRowButton(
                title: "Ustawienia aplikacji",
                subtitle: "Powiadomienia i wygląd",
                icon: "paintbrush.fill",
                accent: .indigo
            ) {
                showPreferencesSheet = true
            }
        }
        .padding(18)
        .dashboardLiquidCard(cornerRadius: 24, strokeOpacity: 0.22)
    }

    private func settingsRowButton(
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(accent.opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func accountInfoPill(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.14), in: Capsule())
    }

    private var createHouseholdSheet: some View {
        NavigationStack {
            ZStack {
                DashboardLiquidBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        sheetIntroCard(
                            icon: "house.badge.plus.fill",
                            title: "Nowe gospodarstwo",
                            subtitle: "Utwórz wspólną przestrzeń do planowania posiłków i zakupów.",
                            accent: .blue
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Nazwa gospodarstwa")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            TextField("Np. Dom", text: $createHouseholdName)
                                .textInputAutocapitalization(.words)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(16)
                        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.22)

                        Button {
                            submitCreateHousehold()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Utwórz gospodarstwo")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(canSubmitCreateHousehold ? .white : .secondary)
                            .background(
                                canSubmitCreateHousehold
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.94), .cyan.opacity(0.88)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                : AnyShapeStyle(Color.white.opacity(0.1)),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(canSubmitCreateHousehold ? 0.2 : 0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSubmitCreateHousehold)

                        if let error = sessionStore.authError, !error.isEmpty {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Nowe gospodarstwo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { showCreateHouseholdSheet = false }
                }
            }
        }
    }

    private var householdManagementSheet: some View {
        NavigationStack {
            ZStack {
                DashboardLiquidBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if hasHousehold {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(persistedHouseholdName)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                        Text(canCreateInvitations ? "Zarządzaj zaproszeniem i członkami." : "Tylko właściciel może tworzyć zaproszenia.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 8)

                                    if canCreateInvitations, let invitationLink {
                                        ShareLink(item: invitationLink) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.subheadline.weight(.semibold))
                                                .frame(width: 34, height: 34)
                                                .background(Color.blue.opacity(0.16), in: Circle())
                                        }
                                        .buttonStyle(.plain)
                                    } else if canCreateInvitations, isCreatingInvitation {
                                        ProgressView()
                                            .controlSize(.small)
                                            .frame(width: 34, height: 34)
                                            .background(Color.white.opacity(0.14), in: Circle())
                                    } else if canCreateInvitations {
                                        Button {
                                            Task { await createInvitationLink() }
                                        } label: {
                                            Image(systemName: "link.badge.plus")
                                                .font(.subheadline.weight(.semibold))
                                                .frame(width: 34, height: 34)
                                                .background(Color.blue.opacity(0.16), in: Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                if let invitationLink {
                                    HStack(spacing: 6) {
                                        Image(systemName: "link")
                                            .foregroundStyle(.secondary)
                                        Text(invitationLink.absoluteString)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }

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
                                    HStack(spacing: 8) {
                                        if sessionStore.isSigningIn {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                        }
                                        Text(sessionStore.isSigningIn ? "Opuszczanie..." : "Opuść gospodarstwo")
                                            .fontWeight(.semibold)
                                    }
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(Color.red.opacity(0.12), in: Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.red.opacity(0.22), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(sessionStore.isSigningIn)

                                if let error = sessionStore.authError, !error.isEmpty {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(16)
                            .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.2)

                            VStack(alignment: .leading, spacing: 10) {
                                Label("Członkowie", systemImage: "person.2.fill")
                                    .font(.subheadline.weight(.semibold))

                                if isLoadingMembers {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("Ładowanie...")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                } else if householdMembers.isEmpty {
                                    Text("Brak członków do wyświetlenia.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(Array(householdMembers.enumerated()), id: \.element.id) { index, member in
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
                                        .padding(.vertical, 3)

                                        if index < householdMembers.count - 1 {
                                            Divider()
                                                .padding(.leading, 44)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.2)
                        } else {
                            sheetIntroCard(
                                icon: "house.fill",
                                title: "Brak gospodarstwa",
                                subtitle: "Utwórz gospodarstwo, aby wspólnie planować i dzielić listę zakupów.",
                                accent: .blue
                            )

                            Button {
                                createHouseholdName = ""
                                showCreateHouseholdSheet = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "house.badge.plus")
                                    Text("Utwórz gospodarstwo")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .foregroundStyle(.white)
                                .background(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.94), .cyan.opacity(0.88)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle("Gospodarstwo")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: showHouseholdSheet) {
                if showHouseholdSheet {
                    await preloadHouseholdContextIfNeeded(force: true)
                }
            }
            .task(id: sessionStore.householdRealtimeVersion) {
                if showHouseholdSheet {
                    await preloadHouseholdContextIfNeeded(force: true)
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
            ZStack {
                DashboardLiquidBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        sheetIntroCard(
                            icon: "slider.horizontal.3",
                            title: "Preferencje aplikacji",
                            subtitle: "Dopasuj powiadomienia i motyw.",
                            accent: .indigo
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Powiadomienia", systemImage: "bell.badge.fill")
                                .font(.headline)

                            VStack(spacing: 0) {
                                preferenceToggleRow(
                                    title: "Powiadomienia",
                                    subtitle: "Włącz główne powiadomienia aplikacji",
                                    isOn: $notificationsEnabled
                                )

                                Divider().padding(.leading, 12)

                                preferenceToggleRow(
                                    title: "Przypomnienia o planie",
                                    subtitle: "Informacje o tygodniowym planie",
                                    isOn: $planRemindersEnabled
                                )
                                .disabled(!notificationsEnabled)
                                .opacity(notificationsEnabled ? 1 : 0.55)

                                Divider().padding(.leading, 12)

                                preferenceToggleRow(
                                    title: "Przypomnienia o zakupach",
                                    subtitle: "Powiadomienia o liście zakupów",
                                    isOn: $shoppingRemindersEnabled
                                )
                                .disabled(!notificationsEnabled)
                                .opacity(notificationsEnabled ? 1 : 0.55)
                            }
                            .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.18)
                        }
                        .padding(16)
                        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.22)

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Wygląd", systemImage: "paintbrush.fill")
                                .font(.headline)

                            HStack(spacing: 8) {
                                ForEach(AppTheme.allCases) { theme in
                                    let selected = theme.rawValue == themeRawValue
                                    Button {
                                        themeRawValue = theme.rawValue
                                    } label: {
                                        VStack(spacing: 5) {
                                            Image(systemName: themeIcon(for: theme))
                                                .font(.subheadline)
                                            Text(theme.title)
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .lineLimit(1)
                                        }
                                        .foregroundStyle(selected ? .white : .primary)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            selected
                                            ? AnyShapeStyle(
                                                LinearGradient(
                                                    colors: [.blue.opacity(0.92), .cyan.opacity(0.85)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            : AnyShapeStyle(Color.white.opacity(0.14)),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(selected ? 0.26 : 0.14), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.22)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
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

    private func preferenceToggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                        .font(.footnote.weight(.semibold))
                    Text(isOn.wrappedValue ? "Wł." : "Wył.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .foregroundStyle(isOn.wrappedValue ? .blue : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isOn.wrappedValue ? Color.blue.opacity(0.15) : Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            isOn.wrappedValue ? Color.blue.opacity(0.3) : Color.white.opacity(0.14),
                            lineWidth: 1
                        )
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @MainActor
    private func preloadHouseholdContextIfNeeded(force: Bool = false) async {
        guard hasHousehold else {
            householdMembers = []
            invitationLink = nil
            return
        }

        if force || householdMembers.isEmpty {
            await loadHouseholdMembers()
        }

        guard canCreateInvitations else {
            invitationLink = nil
            return
        }

        if force || invitationLink == nil {
            await createInvitationLink()
        }
    }

    private func sheetIntroCard(
        icon: String,
        title: String,
        subtitle: String,
        accent: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(accent.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.2)
    }

    private func themeIcon(for theme: AppTheme) -> String {
        switch theme {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    private func submitCreateHousehold() {
        guard canSubmitCreateHousehold else { return }
        let value = trimmedCreateHouseholdName
        Task {
            await sessionStore.createHousehold(name: value)
            if let currentId = sessionStore.currentHouseholdId {
                persistedHouseholdName = value
                householdId = currentId
                showCreateHouseholdSheet = false
            }
        }
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
