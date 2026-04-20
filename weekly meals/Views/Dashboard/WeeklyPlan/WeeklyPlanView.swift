import SwiftUI

struct WeeklyPlanView: View {
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.shoppingListStore) private var shoppingListStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var draft = MealPlanViewModel()
    @State private var activePickerSlot: MealSlot?
    @State private var showDeleteAlert = false
    @State private var pastDayMessage: String?
    @State private var didLoadDraft = false
    @State private var saveTask: Task<Void, Never>?

    private static let weekRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pl_PL")
        f.dateFormat = "d MMM"
        return f
    }()

    private var weekRangeText: String {
        guard let first = datesViewModel.dates.first,
              let last = datesViewModel.dates.last else {
            return "Bieżący tydzień"
        }
        return "\(Self.weekRangeFormatter.string(from: first)) – \(Self.weekRangeFormatter.string(from: last))"
    }

    private var totalCount: Int { draft.totalCount }
    private static let maxTotal = MealPlanViewModel.maxTotal

    private enum PlanStatus {
        case empty, draft, complete
        var color: Color {
            switch self {
            case .empty: return .gray
            case .draft: return .orange
            case .complete: return .green
            }
        }
    }

    private var status: PlanStatus {
        if totalCount == 0 { return .empty }
        if totalCount >= Self.maxTotal { return .complete }
        return .draft
    }

    private var isDirty: Bool {
        !sameAsSaved(draft, mealStore.savedPlan)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                DashboardSheetBackground(theme: .plan)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        headerCard

                        VStack(spacing: 14) {
                            ForEach(MealSlot.allCases) { slot in
                                slotCard(slot)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Plan tygodnia")
            .toolbar {
                if mealStore.hasSavedPlan {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Label("Usuń plan", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
            }
            .task(id: datesViewModel.weekStartISO) {
                await mealStore.loadSavedPlanFromBackend(weekStart: datesViewModel.weekStartISO)
                await mealStore.loadWeekPlanFromBackend(
                    weekStart: datesViewModel.weekStartISO,
                    dates: datesViewModel.dates
                )
                if !didLoadDraft {
                    draft.loadFromSaved(mealStore.savedPlan)
                    didLoadDraft = true
                }
                let urls = MealSlot.allCases
                    .flatMap { draft.recipes(for: $0) }
                    .compactMap(\.imageURL)
                ImagePrefetcher.prefetch(urls)
            }
            .onChange(of: planSignature(mealStore.savedPlan)) { _, _ in
                if !isDirty {
                    draft.loadFromSaved(mealStore.savedPlan)
                }
            }
            .sheet(item: $activePickerSlot) { slot in
                RecipePickerSheet(
                    slot: slot,
                    draft: draft,
                    pastDayCountForRecipe: { recipe in
                        pastDayAssignments(for: recipe, slot: slot)
                    },
                    onPastDayBlocked: { message in
                        pastDayMessage = message
                    }
                )
                .dashboardLiquidSheet()
            }
            .onChange(of: activePickerSlot) { oldValue, newValue in
                if oldValue != nil && newValue == nil {
                    scheduleSave()
                }
            }
            .alert("Usuń plan", isPresented: $showDeleteAlert) {
                Button("Usuń", role: .destructive) {
                    Task { await deletePlan() }
                }
                Button("Anuluj", role: .cancel) { }
            } message: {
                Text("Plan tygodnia zostanie usunięty razem z przypisanymi posiłkami w kalendarzu.")
            }
            .alert(
                "Nie można usunąć",
                isPresented: Binding(
                    get: { pastDayMessage != nil },
                    set: { if !$0 { pastDayMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(pastDayMessage ?? "")
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TYDZIEŃ")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.9)
                    .foregroundStyle(.secondary)

                Text(weekRangeText)
                    .font(.title2.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            statusPill
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.18)
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)

            Text("\(totalCount)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text("/ \(Self.maxTotal)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            DashboardPalette.tintFill(status.color, scheme: colorScheme, dark: 0.18, light: 0.14),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(status.color.opacity(colorScheme == .dark ? 0.3 : 0.22), lineWidth: 1)
        )
    }

    // MARK: - Slot cards

    @ViewBuilder
    private func slotCard(_ slot: MealSlot) -> some View {
        let recipes = draft.uniqueRecipes(for: slot)
        let count = draft.count(for: slot)
        let max = MealPlanViewModel.maxPerSlot

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                slotIcon(slot)

                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.title)
                        .font(.headline.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)

                    Text(slotSubtitle(count: count, max: max))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                addButton(slot: slot, atLimit: count >= max)
            }

            slotProgressBar(slot: slot, count: count, max: max)
                .frame(height: 4)

            if recipes.isEmpty {
                emptyRow(slot: slot)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(recipes) { recipe in
                            planCarouselCard(recipe: recipe, slot: slot)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(slot.accentColor.opacity(colorScheme == .dark ? 0.08 : 0.045))
        )
        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.16)
    }

    private func slotIcon(_ slot: MealSlot) -> some View {
        Image(systemName: slot.icon)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(slot.accentColor.opacity(colorScheme == .dark ? 0.96 : 0.85))
            .frame(width: 36, height: 36)
            .background(
                DashboardPalette.tintFill(slot.accentColor, scheme: colorScheme, dark: 0.2, light: 0.16),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(slot.accentColor.opacity(colorScheme == .dark ? 0.28 : 0.2), lineWidth: 1)
            )
    }

    private func slotSubtitle(count: Int, max: Int) -> String {
        count == 0 ? "Nic jeszcze nie wybrano" : "\(count) \(pluralizePozycje(count))"
    }

    private func pluralizePozycje(_ n: Int) -> String {
        if n == 1 { return "pozycja" }
        let mod10 = n % 10
        let mod100 = n % 100
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "pozycje" }
        return "pozycji"
    }

    private func addButton(slot: MealSlot, atLimit: Bool) -> some View {
        Button {
            activePickerSlot = slot
        } label: {
            Image(systemName: atLimit ? "checkmark" : "plus")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(
                        colors: [
                            slot.accentColor.opacity(colorScheme == .dark ? 0.95 : 0.88),
                            slot.secondaryAccentColor.opacity(colorScheme == .dark ? 0.82 : 0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.22), lineWidth: 1)
                )
                .shadow(color: slot.accentColor.opacity(colorScheme == .dark ? 0.32 : 0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(atLimit ? "Edytuj \(slot.title.lowercased())" : "Dodaj \(slot.title.lowercased())")
    }

    private func slotProgressBar(slot: MealSlot, count: Int, max: Int) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let progress = CGFloat(count) / CGFloat(max)
            let pw = count == 0 ? 0 : Swift.max(w * progress, 8)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DashboardPalette.surface(colorScheme, level: .tertiary))
                if count > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    slot.accentColor.opacity(colorScheme == .dark ? 0.92 : 0.82),
                                    slot.secondaryAccentColor.opacity(colorScheme == .dark ? 0.78 : 0.64)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: pw)
                }
            }
        }
    }

    private func planCarouselCard(recipe: Recipe, slot: MealSlot) -> some View {
        let count = draft.recipeCount(recipe)
        let cardWidth: CGFloat = 148
        return Menu {
            Button {
                incrementRecipe(recipe, slot: slot)
            } label: {
                Label("Dodaj porcję", systemImage: "plus")
            }
            Button {
                decrementRecipe(recipe, slot: slot)
            } label: {
                Label("Odejmij porcję", systemImage: "minus")
            }
            Divider()
            Button(role: .destructive) {
                removeRecipe(recipe, slot: slot)
            } label: {
                Label("Usuń z planu", systemImage: "trash")
            }
        } label: {
            ZStack(alignment: .topLeading) {
                RecipeCarouselCard(
                    recipe: recipe,
                    width: cardWidth,
                    selectionCount: 0,
                    showsHeart: false,
                    showsMetrics: false
                )

                HStack(spacing: 4) {
                    Text("×\(count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    slot.accentColor.opacity(colorScheme == .dark ? 0.95 : 0.88),
                                    slot.secondaryAccentColor.opacity(colorScheme == .dark ? 0.82 : 0.74)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 2)
                .padding(.top, 9)
                .padding(.leading, 9)
            }
        }
        .buttonStyle(.plain)
    }

    private func emptyRow(slot: MealSlot) -> some View {
        Button {
            activePickerSlot = slot
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(slot.accentColor.opacity(colorScheme == .dark ? 0.9 : 0.75))

                Text("Dodaj \(slot.title.lowercased())")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DashboardPalette.surface(colorScheme, level: .tertiary))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        slot.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.2),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func incrementRecipe(_ recipe: Recipe, slot: MealSlot) {
        guard draft.canAdd(to: slot) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            draft.incrementRecipe(recipe)
        }
        scheduleSave()
    }

    private func decrementRecipe(_ recipe: Recipe, slot: MealSlot) {
        let currentCount = draft.recipeCount(recipe)
        let pastUsage = pastDayAssignments(for: recipe, slot: slot)
        if currentCount - 1 < pastUsage {
            pastDayMessage = "Ten przepis jest przypisany do dnia z przeszłości (\(pastUsage) raz(y)). Najpierw usuń go z tych dni w Kalendarzu."
            return
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            draft.decrementRecipe(recipe)
        }
        scheduleSave()
    }

    private func removeRecipe(_ recipe: Recipe, slot: MealSlot) {
        let pastUsage = pastDayAssignments(for: recipe, slot: slot)
        if pastUsage > 0 {
            pastDayMessage = "Ten przepis jest przypisany do dnia z przeszłości (\(pastUsage) raz(y)). Najpierw usuń go z tych dni w Kalendarzu."
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            while draft.isSelected(recipe) {
                draft.decrementRecipe(recipe)
            }
        }
        scheduleSave()
    }

    private func pastDayAssignments(for recipe: Recipe, slot: MealSlot) -> Int {
        let pastDates = datesViewModel.dates.filter { !datesViewModel.isEditable($0) }
        guard !pastDates.isEmpty else { return 0 }
        return pastDates.reduce(into: 0) { acc, date in
            if mealStore.recipe(for: date, slot: slot)?.id == recipe.id {
                acc += 1
            }
        }
    }

    /// Debounced save — złapie serię zmian (np. stepper w pickerze) i wyśle jeden zapis.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await persistCurrentDraft()
        }
    }

    @MainActor
    private func persistCurrentDraft() async {
        guard isDirty else { return }

        let plan = SavedMealPlan(
            breakfastEntries: draft.recipes(for: .breakfast).map { PlanEntry(recipe: $0) },
            lunchEntries: draft.recipes(for: .lunch).map { PlanEntry(recipe: $0) },
            dinnerEntries: draft.recipes(for: .dinner).map { PlanEntry(recipe: $0) }
        )

        await mealStore.saveMealPlanToBackend(plan, weekStart: datesViewModel.weekStartISO)
        await shoppingListStore.load(weekStart: datesViewModel.weekStartISO, force: true)
    }

    @MainActor
    private func deletePlan() async {
        await mealStore.clearWeekFromBackend(
            weekStart: datesViewModel.weekStartISO,
            dates: datesViewModel.dates
        )
        await shoppingListStore.load(weekStart: datesViewModel.weekStartISO, force: true)
        draft.loadFromSaved(mealStore.savedPlan)
    }

    private func sameAsSaved(_ draft: MealPlanViewModel, _ saved: SavedMealPlan) -> Bool {
        func ids(_ recipes: [Recipe]) -> [UUID] { recipes.map(\.id) }
        return ids(draft.recipes(for: .breakfast)) == saved.breakfastEntries.map(\.recipe.id)
            && ids(draft.recipes(for: .lunch)) == saved.lunchEntries.map(\.recipe.id)
            && ids(draft.recipes(for: .dinner)) == saved.dinnerEntries.map(\.recipe.id)
    }

    private func planSignature(_ plan: SavedMealPlan) -> String {
        let b = plan.breakfastEntries.map { $0.recipe.id.uuidString }.joined(separator: ",")
        let l = plan.lunchEntries.map { $0.recipe.id.uuidString }.joined(separator: ",")
        let d = plan.dinnerEntries.map { $0.recipe.id.uuidString }.joined(separator: ",")
        return "\(b)|\(l)|\(d)"
    }
}

// MARK: - Picker sheet

private struct RecipePickerSheet: View {
    let slot: MealSlot
    @Bindable var draft: MealPlanViewModel
    let pastDayCountForRecipe: (Recipe) -> Int
    let onPastDayBlocked: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.recipeCatalogStore) private var recipeCatalogStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var onlyFavourites = false

    private var slotCategory: RecipesCategory {
        switch slot {
        case .breakfast: .breakfast
        case .lunch: .lunch
        case .dinner: .dinner
        }
    }

    private var theme: DashboardSheetTheme {
        switch slot {
        case .breakfast: .sunrise
        case .lunch: .ocean
        case .dinner: .plum
        }
    }

    private var filtered: [Recipe] {
        var list = recipeCatalogStore.recipes.filter { $0.category == slotCategory }
        if onlyFavourites {
            list = list.filter { $0.favourite }
        }
        if !debouncedSearch.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(debouncedSearch) ||
                $0.description.localizedCaseInsensitiveContains(debouncedSearch)
            }
        }
        return list
    }

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .compact ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: count)
    }

    private func cardWidth(for total: CGFloat) -> CGFloat {
        let count: CGFloat = horizontalSizeClass == .compact ? 2 : 3
        let horizontalPadding: CGFloat = 28
        let spacing: CGFloat = 12 * (count - 1)
        return max(150, floor((total - horizontalPadding - spacing) / count))
    }

    private var slotCount: Int { draft.count(for: slot) }
    private var slotMax: Int { MealPlanViewModel.maxPerSlot }
    private var slotFull: Bool { slotCount >= slotMax }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    DashboardSheetBackground(theme: theme)
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            headerCard

                            if filtered.isEmpty {
                                emptyState
                            } else {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(filtered) { recipe in
                                        pickerCard(recipe: recipe, width: cardWidth(for: proxy.size.width))
                                            .task {
                                                await recipeCatalogStore.loadNextPageIfNeeded(currentItemId: recipe.id, threshold: 8)
                                            }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                        .padding(.bottom, 110)
                    }

                    footerBar
                }
            }
            .navigationTitle(slot.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Gotowe") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Szukaj przepisów")
            .task {
                await recipeCatalogStore.loadIfNeeded()
            }
            .onChange(of: searchText) { _, newValue in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard !Task.isCancelled else { return }
                    debouncedSearch = newValue
                }
            }
            .onDisappear { searchDebounceTask?.cancel() }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: slot.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(slot.accentColor)
                .frame(width: 40, height: 40)
                .background(
                    DashboardPalette.tintFill(slot.accentColor, scheme: colorScheme, dark: 0.2, light: 0.16),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("\(slotCount) / \(slotMax) w planie")
                    .font(.subheadline.weight(.bold))
                Text("Stuknij kartę, żeby dodać. Kolejne stuknięcie zwiększa porcję.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            favouritesToggle
        }
        .padding(14)
        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.16)
    }

    private var favouritesToggle: some View {
        Button {
            onlyFavourites.toggle()
        } label: {
            Image(systemName: onlyFavourites ? "heart.fill" : "heart")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(onlyFavourites ? Color.pink : Color.secondary)
                .frame(width: 36, height: 36)
                .background(
                    onlyFavourites
                        ? DashboardPalette.tintFill(.pink, scheme: colorScheme, dark: 0.18, light: 0.14)
                        : DashboardPalette.surface(colorScheme, level: .secondary),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(
                            onlyFavourites
                                ? Color.pink.opacity(colorScheme == .dark ? 0.3 : 0.22)
                                : DashboardPalette.neutralBorder(colorScheme, opacity: 0.12),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pokaż tylko ulubione")
    }

    // MARK: - Card

    private func pickerCard(recipe: Recipe, width: CGFloat) -> some View {
        let count = draft.recipeCount(recipe)
        return ZStack(alignment: .topLeading) {
            Button {
                tryIncrement(recipe)
            } label: {
                RecipeCarouselCard(
                    recipe: recipe,
                    width: width,
                    selectionCount: count,
                    showsHeart: count == 0
                )
            }
            .buttonStyle(.plain)

            if count > 0 {
                selectionStepper(recipe: recipe, count: count)
                    .padding(.top, 10)
                    .padding(.leading, 10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.18), value: count)
    }

    private func selectionStepper(recipe: Recipe, count: Int) -> some View {
        let canIncrement = !slotFull
        return HStack(spacing: 0) {
            Button {
                tryDecrement(recipe)
            } label: {
                Image(systemName: count == 1 ? "trash" : "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 3) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                Text("×\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 4)

            Button {
                tryIncrement(recipe)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canIncrement)
            .opacity(canIncrement ? 1 : 0.45)
        }
        .background(
            Capsule()
                .fill(Color.green.opacity(colorScheme == .dark ? 0.9 : 0.82))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(slotCount) / \(slotMax)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(slotFull ? "Slot domknięty" : "wybrano")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Gotowe")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [
                                slot.accentColor.opacity(colorScheme == .dark ? 0.95 : 0.88),
                                slot.secondaryAccentColor.opacity(colorScheme == .dark ? 0.82 : 0.74)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.2), lineWidth: 1)
                    )
                    .shadow(color: slot.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.22), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.14), lineWidth: 1)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Brak wyników")
                .font(.headline.weight(.semibold))
            Text(debouncedSearch.isEmpty ? "Spróbuj zmienić filtr." : "Spróbuj innej frazy.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 16)
        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.16)
    }

    // MARK: - Actions

    private func tryIncrement(_ recipe: Recipe) {
        guard draft.canAdd(to: slot) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            draft.incrementRecipe(recipe)
        }
    }

    private func tryDecrement(_ recipe: Recipe) {
        let currentCount = draft.recipeCount(recipe)
        let pastUsage = pastDayCountForRecipe(recipe)
        if currentCount - 1 < pastUsage {
            onPastDayBlocked("Ten przepis jest przypisany do dnia z przeszłości (\(pastUsage) raz(y)). Najpierw usuń go z tych dni w Kalendarzu.")
            return
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            draft.decrementRecipe(recipe)
        }
    }
}

#Preview {
    WeeklyPlanView()
}
