import SwiftUI

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

    @State private var showCreateHouseholdSheet = false
    @State private var showHouseholdSheet = false
    @State private var showPreferencesSheet = false
    @State private var createHouseholdName = ""
    @State private var householdNameError: String? = nil
    @State private var showLogoutAlert = false
    @State private var showLeaveHouseholdAlert = false
    @State private var invitationLink: URL?
    @State private var isCreatingInvitation = false

    private var hasHousehold: Bool {
        !persistedHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var trimmedCreateHouseholdName: String {
        createHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var appVersionLabel: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, buildNumber) {
        case let (version?, build?) where !version.isEmpty && !build.isEmpty:
            return "\(version) (\(build))"
        case let (version?, _) where !version.isEmpty:
            return version
        case let (_, build?) where !build.isEmpty:
            return "Build \(build)"
        default:
            return "Niedostępna"
        }
    }

    private static let householdNameMinLength = 2
    private static let householdNameMaxLength = 50

    private var householdNameValidationError: String? {
        let name = trimmedCreateHouseholdName
        if name.isEmpty { return "Nazwa jest wymagana." }
        if name.count < Self.householdNameMinLength {
            return "Nazwa musi mieć co najmniej \(Self.householdNameMinLength) znaki."
        }
        if name.count > Self.householdNameMaxLength {
            return "Nazwa może mieć maksymalnie \(Self.householdNameMaxLength) znaków."
        }
        return nil
    }

    private var canSubmitCreateHousehold: Bool {
        householdNameValidationError == nil && !trimmedCreateHouseholdName.isEmpty
    }

    private var householdMembers: [HouseholdMemberSnapshot] {
        sessionStore.householdMembers
    }

    private var isLoadingMembers: Bool {
        sessionStore.isLoadingHouseholdMembers && householdMembers.isEmpty
    }

    private var canCreateInvitations: Bool {
        guard let currentUserId = sessionStore.currentUserId else { return false }
        guard let me = householdMembers.first(where: { $0.id == currentUserId }) else { return false }
        return me.role.uppercased() == "OWNER"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsLiquidBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Zarządzaj kontem, gospodarstwem domowym oraz ustawieniami aplikacji w jednym miejscu.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        profileCard
                        menuCard
                        appVersionCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Ustawienia")
            .navigationBarTitleDisplayMode(.large)
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
            .alert("Czy na pewno chcesz się wylogować?", isPresented: $showLogoutAlert) {
                Button("Anuluj", role: .cancel) {}
                Button("Wyloguj", role: .destructive) {
                    sessionStore.logout()
                }
            } message: {
                Text("Sesja zostanie zakończona na tym urządzeniu.")
            }
            .task(id: sessionStore.householdRealtimeVersion) {
                guard sessionStore.householdRealtimeVersion > 0 else { return }
                await handleHouseholdRealtimeUpdate()
            }
            .task {
                // Wejście w ustawienia — dociągnij świeży snapshot jeśli brak.
                // Przy ciepłym starcie cache z SessionStore startupu wystarczy.
                await preloadHouseholdContextIfNeeded(force: false)
            }
        }
    }

    private var profileCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.18 : 0.12))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.blue)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(userDisplayName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(userEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            DashboardActionButton(
                title: nil,
                systemImage: "rectangle.portrait.and.arrow.right",
                tone: .destructive,
                controlSize: 30
            ) {
                showLogoutAlert = true
            }
            .accessibilityLabel("Wyloguj")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.14)
    }

    private var menuCard: some View {
        VStack(spacing: 0) {
            settingsRowButton(
                title: "Gospodarstwo",
                subtitle: hasHousehold ? "Domownicy i zaproszenia" : "Utwórz wspólne gospodarstwo",
                icon: hasHousehold ? "house.fill" : "house.badge.plus",
                accent: hasHousehold ? .teal : .blue
            ) {
                if hasHousehold {
                    // Sheet otwiera się z danymi, które już są w sessionStore.
                    // Dopychamy w tle świeży pull (nie blokuje UI; jeśli snapshot
                    // z cache jest aktualny, to działa jak no-op).
                    showHouseholdSheet = true
                    Task { await preloadHouseholdContextIfNeeded(force: false) }
                } else {
                    createHouseholdName = ""
                    showCreateHouseholdSheet = true
                }
            }

            Divider()
                .padding(.leading, 58)

            settingsRowButton(
                title: "Preferencje",
                subtitle: "Powiadomienia i wygląd aplikacji",
                icon: "slider.horizontal.3",
                accent: .indigo
            ) {
                showPreferencesSheet = true
            }
        }
        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.16)
    }

    private var appVersionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Wersja aplikacji")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(appVersionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.12)
    }

    private func settingsRowButton(
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)
                    .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var createHouseholdSheet: some View {
        NavigationStack {
            ZStack {
                DashboardSheetBackground(theme: .indigo)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nowe gospodarstwo")
                                .font(.title2.weight(.semibold))
                            Text("Nadaj nazwę wspólnej przestrzeni do planowania i zakupów.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Nazwa")
                                .font(.footnote.weight(.semibold))

                            TextField("Np. Dom", text: $createHouseholdName)
                                .textInputAutocapitalization(.words)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(DashboardPalette.surface(colorScheme, level: .secondary), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            householdNameError != nil
                                                ? Color.red.opacity(0.6)
                                                : DashboardPalette.neutralBorder(colorScheme, opacity: 0.12),
                                            lineWidth: householdNameError != nil ? 1.5 : 1
                                        )
                                )
                                .onChange(of: createHouseholdName) { _, _ in
                                    // Wyczyść błąd gdy użytkownik zaczyna pisać
                                    if householdNameError != nil { householdNameError = nil }
                                }

                            if let error = householdNameError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 4)
                            }

                            HStack {
                                Spacer()
                                Text("\(trimmedCreateHouseholdName.count)/\(Self.householdNameMaxLength)")
                                    .font(.caption2)
                                    .foregroundStyle(
                                        trimmedCreateHouseholdName.count > Self.householdNameMaxLength
                                            ? .red
                                            : .secondary
                                    )
                            }
                        }
                        .padding(18)
                        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.16)

                        Button {
                            submitCreateHousehold()
                        } label: {
                            Text("Utwórz gospodarstwo")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
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
                                    : AnyShapeStyle(DashboardPalette.surface(colorScheme, level: .secondary)),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            canSubmitCreateHousehold
                                                ? DashboardPalette.neutralBorder(colorScheme, opacity: 0.18)
                                                : DashboardPalette.neutralBorder(colorScheme, opacity: 0.12),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSubmitCreateHousehold)

                        if let error = sessionStore.authError, !error.isEmpty {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Gospodarstwo")
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
                DashboardSheetBackground(theme: .spring)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Zarządzaj domownikami, zaproszeniami i wspólną przestrzenią do planowania posiłków oraz zakupów.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if hasHousehold {
                            householdOverviewCard
                            householdMembersCard
                        } else {
                            householdEmptyCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Gospodarstwo")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Opuścić gospodarstwo?", isPresented: $showLeaveHouseholdAlert) {
                Button("Anuluj", role: .cancel) {}
                Button("Opuść", role: .destructive) {
                    Task {
                        await sessionStore.leaveCurrentHousehold()
                        if sessionStore.currentHouseholdId == nil {
                            persistedHouseholdName = ""
                            showHouseholdSheet = false
                        }
                    }
                }
            } message: {
                Text("Stracisz dostęp do wspólnego planu i listy zakupów.")
            }
        }
    }

    private var householdOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(persistedHouseholdName)
                        .font(.title2.weight(.semibold))
                    Text("\(householdMembers.count) \(membersLabel(for: householdMembers.count)) w gospodarstwie")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                DashboardActionButton(
                    title: nil,
                    systemImage: "rectangle.portrait.and.arrow.right",
                    tone: colorScheme == .dark ? .destructive : .neutral,
                    foregroundColor: colorScheme == .dark ? nil : .red,
                    controlSize: 30
                ) {
                    showLeaveHouseholdAlert = true
                }
                .disabled(sessionStore.isSigningIn)
                .accessibilityLabel("Opuść gospodarstwo")
            }
        }
        .padding(18)
        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.18)
    }

    private var householdMembersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Członkowie")
                    .font(.headline.weight(.semibold))

                Spacer(minLength: 0)

                if canCreateInvitations {
                    if let invitationLink {
                        ShareLink(item: invitationLink) {
                            DashboardActionLabel(
                                title: nil,
                                systemImage: "plus",
                                tone: colorScheme == .dark ? .accent(.blue) : .neutral,
                                foregroundColor: colorScheme == .dark ? nil : .blue,
                                controlSize: 30
                            )
                        }
                        .accessibilityLabel("Udostępnij zaproszenie")
                    } else if isCreatingInvitation {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        DashboardActionButton(
                            title: nil,
                            systemImage: "plus",
                            tone: colorScheme == .dark ? .accent(.blue) : .neutral,
                            foregroundColor: colorScheme == .dark ? nil : .blue,
                            controlSize: 30
                        ) {
                            Task { await createInvitationLink() }
                        }
                        .accessibilityLabel("Przygotuj zaproszenie")
                    }
                }
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
                VStack(spacing: 8) {
                    ForEach(householdMembers, id: \.id) { member in
                        memberRow(member)
                    }
                }
            }

            if let error = sessionStore.authError, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(18)
        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.18)
    }

    private var householdEmptyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Brak gospodarstwa")
                .font(.title2.weight(.semibold))
            Text("Utwórz wspólne miejsce do planowania posiłków i listy zakupów.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                createHouseholdName = ""
                showCreateHouseholdSheet = true
            } label: {
                householdPrimaryButton(title: "Utwórz gospodarstwo", icon: "house.badge.plus")
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.16)
    }

    private var preferencesSheet: some View {
        NavigationStack {
            ZStack {
                DashboardSheetBackground(theme: .twilight)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Preferencje")
                                .font(.title2.weight(.semibold))
                            Text("Dopasuj powiadomienia, przypomnienia i wygląd aplikacji tak, żeby lepiej pasowały do Twojego rytmu korzystania.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 0) {
                            preferenceToggleRow(
                                title: "Powiadomienia",
                                subtitle: "Włącz główne powiadomienia aplikacji, aby dostawać przypomnienia o planie tygodnia i liście zakupów.",
                                isOn: $notificationsEnabled
                            )

                            Divider().padding(.leading, 16)

                            preferenceToggleRow(
                                title: "Plan tygodniowy",
                                subtitle: "Przypomnienia o planie posiłków",
                                isOn: $planRemindersEnabled
                            )
                            .disabled(!notificationsEnabled)
                            .opacity(notificationsEnabled ? 1 : 0.5)

                            Divider().padding(.leading, 16)

                            preferenceToggleRow(
                                title: "Lista zakupów",
                                subtitle: "Przypomnienia o zakupach",
                                isOn: $shoppingRemindersEnabled
                            )
                            .disabled(!notificationsEnabled)
                            .opacity(notificationsEnabled ? 1 : 0.5)
                        }
                        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.16)

                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wygląd")
                                    .font(.headline.weight(.semibold))

                                Text("Wybierz motyw, który będzie domyślnie używany podczas przeglądania aplikacji.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            VStack(spacing: 8) {
                                ForEach(AppTheme.allCases) { theme in
                                    themeRow(theme)
                                }
                            }
                        }
                        .padding(18)
                        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Preferencje")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func preferenceToggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.blue)
                .scaleEffect(0.9)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func themeRow(_ theme: AppTheme) -> some View {
        let selected = theme.rawValue == themeRawValue

        return Button {
            themeRawValue = theme.rawValue
        } label: {
            HStack(spacing: 12) {
                Image(systemName: themeIcon(for: theme))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(selected ? .blue : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill((selected ? Color.blue : Color.white).opacity(selected ? 0.16 : 0.08))
                    )

                Text(theme.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                selected
                    ? DashboardPalette.surface(colorScheme, level: .emphasized)
                    : DashboardPalette.surface(colorScheme, level: .secondary),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        selected
                            ? Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.32)
                            : DashboardPalette.neutralBorder(colorScheme, opacity: 0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func preloadHouseholdContextIfNeeded(force: Bool = false) async {
        guard hasHousehold else {
            invitationLink = nil
            return
        }

        await sessionStore.refreshHouseholdMembers(force: force)

        guard canCreateInvitations else {
            invitationLink = nil
            return
        }

        if force || invitationLink == nil {
            await createInvitationLink()
        }
    }

    @MainActor
    private func handleHouseholdRealtimeUpdate() async {
        // SessionStore sam odświeża members po realtime event. Tu tylko
        // synchronizujemy invitation link, jeśli zmiana roli jej wymaga.
        guard hasHousehold else {
            invitationLink = nil
            return
        }

        guard canCreateInvitations else {
            invitationLink = nil
            return
        }

        if invitationLink == nil {
            await createInvitationLink()
        }
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

    private func householdPrimaryButton(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.9), .cyan.opacity(0.78)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.14), lineWidth: 1)
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
        if let error = householdNameValidationError {
            householdNameError = error
            return
        }
        let value = trimmedCreateHouseholdName
        Task {
            await sessionStore.createHousehold(name: value)
            if sessionStore.currentHouseholdId != nil {
                persistedHouseholdName = value
                showCreateHouseholdSheet = false
                createHouseholdName = ""
                householdNameError = nil
            }
        }
    }

    private func memberRow(_ member: HouseholdMemberSnapshot) -> some View {
        HStack(spacing: 12) {
            memberAvatar(for: member)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.footnote.weight(.semibold))

                    if member.id == sessionStore.currentUserId {
                        Text("Ty")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    }
                }
                Text(member.email ?? "Brak e-maila")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            DashboardPalette.surface(
                colorScheme,
                level: colorScheme == .dark ? .secondary : .tertiary
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: colorScheme == .dark ? 0.08 : 0.11), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func memberAvatar(for member: HouseholdMemberSnapshot) -> some View {
        if let avatarUrl = member.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    Circle().fill(Color.gray.opacity(0.22))
                @unknown default:
                    Circle().fill(Color.gray.opacity(0.22))
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.blue.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay(
                    Text(initials(for: member.displayName))
                        .font(.caption2.weight(.semibold))
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
                    DashboardPalette.backgroundTop(for: colorScheme),
                    DashboardPalette.backgroundBottom(for: colorScheme)
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
