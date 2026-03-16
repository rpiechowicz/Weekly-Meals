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
    @Environment(\.colorScheme) private var colorScheme
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

    private var householdEntrySubtitle: String {
        if isLoadingMembers { return "Ładowanie domowników..." }
        let count = householdMembers.count
        if count > 0 {
            return "\(count) \(membersLabel(for: count)) i zaproszenia"
        }
        return "Domownicy i zaproszenia"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsLiquidBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        accountSection
                        householdEntryCard
                        preferencesEntryCard
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .padding(.bottom, 14)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.14))
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 1) {
                    Text(userDisplayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(userEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.red.opacity(0.14))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.red.opacity(0.24), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Wyloguj")
            }

            HStack(spacing: 6) {
                accountInfoPill(icon: "house.fill", title: householdSummary, tint: hasHousehold ? .green : .secondary)
                accountInfoPill(icon: "circle.lefthalf.filled", title: (AppTheme(rawValue: themeRawValue) ?? .system).title, tint: .blue)
            }
        }
        .padding(14)
        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.2)
    }

    private var householdEntryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "house.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.green.opacity(colorScheme == .dark ? 0.22 : 0.14))
                    )

                Text("Gospodarstwo")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer(minLength: 0)

                Text(hasHousehold ? "Aktywne" : "Brak")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(hasHousehold ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((hasHousehold ? Color.green : Color.white).opacity(hasHousehold ? 0.15 : 0.12), in: Capsule())
            }

            Text(hasHousehold ? "Zapraszaj domowników i zarządzaj rolami." : "Utwórz wspólne gospodarstwo do planowania i zakupów.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if hasHousehold {
                settingsRowButton(
                    title: householdSummary,
                    subtitle: householdEntrySubtitle,
                    icon: "house.and.flag.fill",
                    accent: .teal
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
        .padding(14)
        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.18)
    }

    private var preferencesEntryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.indigo.opacity(colorScheme == .dark ? 0.22 : 0.14))
                    )

                Text("Preferencje")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer(minLength: 0)
                Text((AppTheme(rawValue: themeRawValue) ?? .system).title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12), in: Capsule())
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
        .padding(14)
        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.18)
    }

    private func settingsRowButton(
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)
                    .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14), in: Capsule())
    }

    private var createHouseholdSheet: some View {
        NavigationStack {
            ZStack {
                SettingsLiquidBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        sheetIntroCard(
                            icon: "house.badge.plus.fill",
                            title: "Nowe gospodarstwo",
                            subtitle: "Utwórz wspólną przestrzeń do planowania posiłków i zakupów.",
                            accent: .blue
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nazwa gospodarstwa")
                                .font(.footnote)
                                .fontWeight(.semibold)

                            HStack(spacing: 8) {
                                Image(systemName: "house")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.blue)
                                    .frame(width: 24, height: 24)
                                    .background(Color.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                TextField("Np. Dom", text: $createHouseholdName)
                                    .textInputAutocapitalization(.words)
                            }
                            .padding(.vertical, 9)
                            .padding(.horizontal, 10)
                            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )

                            Text("Nazwa będzie widoczna dla wszystkich członków.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .dashboardLiquidCard(cornerRadius: 16, strokeOpacity: 0.18)

                        Button {
                            submitCreateHousehold()
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Utwórz gospodarstwo")
                                    .fontWeight(.semibold)
                            }
                            .font(.footnote)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(canSubmitCreateHousehold ? .white : .secondary)
                            .background(
                                canSubmitCreateHousehold
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.92), .cyan.opacity(0.84)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                : AnyShapeStyle(Color.white.opacity(0.1)),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                    .padding(.vertical, 10)
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
                SettingsLiquidBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if hasHousehold {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 9) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.teal.opacity(colorScheme == .dark ? 0.22 : 0.14))
                                        Image(systemName: "house.fill")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.teal)
                                    }
                                    .frame(width: 28, height: 28)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(persistedHouseholdName)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text(canCreateInvitations ? "Zarządzaj zaproszeniem i członkami." : "Tryb podglądu dla członka gospodarstwa.")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 8)

                                    householdRoleBadge(
                                        title: canCreateInvitations ? "Właściciel" : "Członek",
                                        tint: canCreateInvitations ? .green : .blue
                                    )
                                }

                                HStack(spacing: 8) {
                                    householdMetaChip(
                                        icon: "person.2.fill",
                                        text: "\(householdMembers.count) \(membersLabel(for: householdMembers.count))",
                                        tint: .blue
                                    )
                                    householdMetaChip(
                                        icon: canCreateInvitations ? "key.fill" : "person.fill",
                                        text: canCreateInvitations ? "Pełny dostęp" : "Dostęp podstawowy",
                                        tint: canCreateInvitations ? .green : .secondary
                                    )
                                }

                                if canCreateInvitations {
                                    HStack(spacing: 8) {
                                        if let invitationLink {
                                            ShareLink(item: invitationLink) {
                                                householdActionLabel(
                                                    title: "Udostępnij",
                                                    icon: "square.and.arrow.up",
                                                    tint: .blue
                                                )
                                            }
                                            .buttonStyle(.plain)

                                            Button {
                                                Task { await createInvitationLink() }
                                            } label: {
                                                householdActionLabel(
                                                    title: "Odśwież link",
                                                    icon: "arrow.clockwise",
                                                    tint: .teal
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        } else if isCreatingInvitation {
                                            HStack(spacing: 7) {
                                                ProgressView()
                                                    .controlSize(.small)
                                                Text("Tworzenie linku...")
                                                    .font(.caption2)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 9)
                                            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                            )
                                        } else {
                                            Button {
                                                Task { await createInvitationLink() }
                                            } label: {
                                                householdActionLabel(
                                                    title: "Utwórz link zaproszenia",
                                                    icon: "link.badge.plus",
                                                    tint: .blue
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                } else {
                                    HStack(spacing: 6) {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundStyle(.secondary)
                                        Text("Tylko właściciel może tworzyć zaproszenia.")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                    )
                                }

                                if let invitationLink {
                                    HStack(spacing: 7) {
                                        Image(systemName: "link.circle.fill")
                                            .foregroundStyle(.blue)
                                        Text(invitationLink.absoluteString)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)

                                        Spacer(minLength: 8)

                                        ShareLink(item: invitationLink) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.blue)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                    )
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
                                    HStack(spacing: 7) {
                                        if sessionStore.isSigningIn {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                        }
                                        Text(sessionStore.isSigningIn ? "Opuszczanie..." : "Opuść gospodarstwo")
                                            .fontWeight(.semibold)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.12), in: Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.red.opacity(0.22), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(sessionStore.isSigningIn)

                                if let error = sessionStore.authError, !error.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.red)
                                        Text(error)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(14)
                            .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.18)

                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("Członkowie", systemImage: "person.2.fill")
                                        .font(.footnote.weight(.semibold))
                                    Spacer(minLength: 8)
                                    Text("\(householdMembers.count)")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.14), in: Capsule())
                                }

                                if isLoadingMembers {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("Ładowanie...")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                } else if householdMembers.isEmpty {
                                    Text("Brak członków do wyświetlenia.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(Array(householdMembers.enumerated()), id: \.element.id) { index, member in
                                        HStack(spacing: 9) {
                                            memberAvatar(for: member)
                                            VStack(alignment: .leading, spacing: 1) {
                                                HStack(spacing: 6) {
                                                    Text(member.displayName)
                                                        .font(.footnote)
                                                        .fontWeight(.medium)
                                                    if member.id == sessionStore.currentUserId {
                                                        Text("Ty")
                                                            .font(.caption2)
                                                            .fontWeight(.semibold)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.blue.opacity(0.16), in: Capsule())
                                                            .foregroundStyle(.blue)
                                                    }
                                                }
                                                Text(member.email ?? "Brak e-maila")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()

                                            Text(roleTitle(for: member.role))
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(roleTint(for: member.role))
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(roleTint(for: member.role).opacity(0.16), in: Capsule())
                                        }
                                        .padding(.vertical, 6)

                                        if index < householdMembers.count - 1 {
                                            Divider()
                                                .padding(.leading, 38)
                                        }
                                    }
                                }
                            }
                            .padding(14)
                            .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.18)
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
                                .font(.footnote)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(.white)
                                .background(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.92), .cyan.opacity(0.84)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                SettingsLiquidBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        sheetIntroCard(
                            icon: "slider.horizontal.3",
                            title: "Preferencje aplikacji",
                            subtitle: "Dopasuj powiadomienia i motyw.",
                            accent: .indigo
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Label("Powiadomienia", systemImage: "bell.badge.fill")
                                .font(.footnote.weight(.semibold))

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
                            .dashboardLiquidCard(cornerRadius: 16, strokeOpacity: 0.16)
                        }
                        .padding(14)
                        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.18)

                        VStack(alignment: .leading, spacing: 10) {
                            Label("Wygląd", systemImage: "paintbrush.fill")
                                .font(.footnote.weight(.semibold))

                            HStack(spacing: 8) {
                                ForEach(AppTheme.allCases) { theme in
                                    let selected = theme.rawValue == themeRawValue
                                    Button {
                                        themeRawValue = theme.rawValue
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: themeIcon(for: theme))
                                                .font(.caption.weight(.semibold))
                                            Text(theme.title)
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .lineLimit(1)
                                        }
                                        .foregroundStyle(selected ? .primary : .secondary)
                                        .padding(.vertical, 7)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            selected
                                            ? AnyShapeStyle(
                                                LinearGradient(
                                                    colors: [.blue.opacity(0.3), .cyan.opacity(0.2)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            : AnyShapeStyle(Color.white.opacity(0.1)),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(
                                                    selected ? Color.blue.opacity(0.34) : Color.white.opacity(0.14),
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(14)
                        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.18)
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
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.blue)
                .scaleEffect(0.88)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 26, height: 26)
                .background(accent.opacity(colorScheme == .dark ? 0.2 : 0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .dashboardLiquidCard(cornerRadius: 16, strokeOpacity: 0.17)
    }

    private func membersLabel(for count: Int) -> String {
        switch count {
        case 1:
            return "osoba"
        case 2...4:
            return "osoby"
        default:
            return "osób"
        }
    }

    private func roleTitle(for role: String) -> String {
        role.uppercased() == "OWNER" ? "Właściciel" : "Członek"
    }

    private func roleTint(for role: String) -> Color {
        role.uppercased() == "OWNER" ? .green : .blue
    }

    private func householdRoleBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
    }

    private func householdMetaChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.13), in: Capsule())
    }

    private func householdActionLabel(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.25), tint.opacity(0.14)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.3), lineWidth: 1)
        )
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
                Circle().fill(Color.gray.opacity(0.22))
            }
            .frame(width: 30, height: 30)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(initials(for: member.displayName))
                        .font(.caption2)
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

private struct SettingsLiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    colorScheme == .dark
                        ? Color(red: 0.08, green: 0.09, blue: 0.11)
                        : Color(red: 0.95, green: 0.96, blue: 0.98),
                    colorScheme == .dark
                        ? Color(red: 0.05, green: 0.06, blue: 0.07)
                        : Color(red: 0.92, green: 0.94, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.teal.opacity(colorScheme == .dark ? 0.18 : 0.1))
                .frame(width: 240, height: 240)
                .blur(radius: 88)
                .offset(x: -140, y: -220)

            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.11))
                .frame(width: 260, height: 260)
                .blur(radius: 92)
                .offset(x: 130, y: -230)

            Circle()
                .fill(Color.indigo.opacity(colorScheme == .dark ? 0.16 : 0.09))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: 140, y: 260)
        }
    }
}

#Preview {
    SettingsView()
}
