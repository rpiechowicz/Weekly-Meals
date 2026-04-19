import SwiftUI

struct WeeklyPlanView: View {
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.shoppingListStore) private var shoppingListStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var showEditor = false
    @State private var showDeletePlanAlert = false

    private static let weekRangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private var weekRangeText: String {
        guard let first = datesViewModel.dates.first,
              let last = datesViewModel.dates.last else {
            return "Bieżący tydzień"
        }
        return "\(Self.weekRangeFormatter.string(from: first)) - \(Self.weekRangeFormatter.string(from: last))"
    }

    private var plannedMealsCount: Int {
        MealSlot.allCases.reduce(into: 0) { result, slot in
            result += mealStore.savedPlan.entries(for: slot).count
        }
    }

    private var totalMealCapacity: Int {
        MealSlot.allCases.count * MealPlanViewModel.maxPerSlot
    }

    private var heroHelperText: String {
        if plannedMealsCount == 0 {
            return "Ten plan będzie później bazą do szybkiego układania dni w kalendarzu i tworzenia listy zakupów."
        }

        if plannedMealsCount == totalMealCapacity {
            return "Możesz teraz zostawić go tak, jak jest, albo wejść w edycję i podmienić przepisy przed użyciem w kalendarzu."
        }

        return "To Twój tygodniowy szablon posiłków. Możesz go dalej uzupełniać albo już teraz wykorzystać jako bazę do kalendarza i zakupów."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                liquidBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        heroCard

                        ForEach(MealSlot.allCases) { slot in
                            slotCard(slot)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 22)
                }
            }
            .navigationTitle("Plan tygodnia")
            .task(id: datesViewModel.weekStartISO) {
                await mealStore.loadSavedPlanFromBackend(weekStart: datesViewModel.weekStartISO)
                await mealStore.loadWeekPlanFromBackend(
                    weekStart: datesViewModel.weekStartISO,
                    dates: datesViewModel.dates
                )
                let urls = MealSlot.allCases
                    .flatMap { mealStore.savedPlan.entries(for: $0) }
                    .compactMap(\.recipe.imageURL)
                ImagePrefetcher.prefetch(urls)
            }
            .sheet(isPresented: $showEditor) {
                WeeklyPlanEditorView()
                    .dashboardLiquidSheet()
            }
            .alert("Usuń plan", isPresented: $showDeletePlanAlert) {
                Button("Usuń", role: .destructive) {
                    Task {
                        await mealStore.clearWeekFromBackend(
                            weekStart: datesViewModel.weekStartISO,
                            dates: datesViewModel.dates
                        )
                        await shoppingListStore.load(weekStart: datesViewModel.weekStartISO, force: true)
                    }
                }
                Button("Anuluj", role: .cancel) { }
            } message: {
                Text("Czy na pewno chcesz usunąć plan tygodnia? Usunie też przypisane posiłki z kalendarza.")
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(weekRangeText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Spacer(minLength: 8)

                heroActions
            }
            .padding(.bottom, 6)

            Text(heroHelperText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.18)
    }

    private var heroActions: some View {
        HStack(spacing: 8) {
            DashboardActionButton(
                title: mealStore.hasSavedPlan ? "Edytuj" : "Utwórz",
                systemImage: mealStore.hasSavedPlan ? "square.and.pencil" : "plus"
            ) {
                showEditor = true
            }
            .accessibilityLabel(mealStore.hasSavedPlan ? "Edytuj plan" : "Utwórz plan")

            if mealStore.hasSavedPlan {
                DashboardActionButton(
                    title: nil,
                    systemImage: "trash",
                    tone: .destructive
                ) {
                    showDeletePlanAlert = true
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.top, 2)
    }

    @ViewBuilder
    private func slotCard(_ slot: MealSlot) -> some View {
        let entries = mealStore.savedPlan.entries(for: slot)
        let slotCount = entries.count
        let recipes = uniqueRecipes(for: slot)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: slot.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(slot.accentColor)
                    .frame(width: 36, height: 36)
                    .background(
                        slot.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.18),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                Text(slot.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)

                Spacer()

                Text("\(slotCount)/\(MealPlanViewModel.maxPerSlot)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(slotCount > 0 ? slot.accentColor : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(slot.accentColor.opacity(slotCount > 0 ? 0.16 : 0.08), in: Capsule())
            }

            if recipes.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(slot.accentColor)
                        .frame(width: 24, height: 24)
                        .background(slot.accentColor.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Brak przepisów")
                            .font(.caption.weight(.semibold))
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("Dodaj pozycje w edytorze planu")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DashboardPalette.surface(colorScheme, level: .tertiary))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.1), lineWidth: 1)
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(recipes) { recipe in
                        PlanRecipeRow(
                            recipe: recipe,
                            slot: slot,
                            count: recipeCount(for: recipe, in: slot)
                        )
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.18)
    }

    private func recipeCount(for recipe: Recipe, in slot: MealSlot) -> Int {
        mealStore.savedPlan.entries(for: slot)
            .filter { $0.recipe.id == recipe.id }
            .count
    }

    private var liquidBackground: some View {
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
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: -120, y: -190)

            Circle()
                .fill(Color.purple.opacity(colorScheme == .dark ? 0.16 : 0.1))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: 140, y: 220)

            Circle()
                .fill(Color.cyan.opacity(colorScheme == .dark ? 0.12 : 0.08))
                .frame(width: 210, height: 210)
                .blur(radius: 85)
                .offset(x: 120, y: -240)
        }
    }

    private func uniqueRecipes(for slot: MealSlot) -> [Recipe] {
        var seen = Set<UUID>()
        return mealStore.savedPlan.entries(for: slot)
            .map(\.recipe)
            .filter { seen.insert($0.id).inserted }
    }
}

private struct PlanRecipeRow: View {
    let recipe: Recipe
    let slot: MealSlot
    let count: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let imageURL = recipe.imageURL {
                    CachedAsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            fallbackIcon
                        case .empty:
                            ProgressView()
                        @unknown default:
                            fallbackIcon
                        }
                    }
                } else {
                    fallbackIcon
                }
            }
            .frame(width: 48, height: 48)
            .background(Color(.secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(slot.accentColor.opacity(0.25), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    metaPill(icon: "clock", text: "\(recipe.prepTimeMinutes) min")
                    metaPill(icon: "flame.fill", text: "\(Int(recipe.nutritionPerServing.kcal)) kcal")
                }
            }

            Text("\(count)x")
                .font(.caption2)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(slot.accentColor.opacity(colorScheme == .dark ? 0.92 : 0.84))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    DashboardPalette.tintFill(
                        slot.accentColor,
                        scheme: colorScheme,
                        dark: 0.2,
                        light: 0.14
                    ),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(slot.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.16), lineWidth: 1)
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DashboardPalette.surface(colorScheme, level: .secondary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.14), lineWidth: 1)
        )
    }

    private func metaPill(icon: String, text: String) -> some View {
        RecipeMetricBadge(icon: icon, text: text)
    }

    private var fallbackIcon: some View {
        Image(systemName: "fork.knife.circle.fill")
            .font(.subheadline)
            .foregroundStyle(slot.accentColor)
    }
}

private struct WeeklyPlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.recipeCatalogStore) private var recipeCatalogStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedCategory: RecipesCategory = .all
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?

    @State private var mealPlan = MealPlanViewModel()
    @State private var showPastDayProtectionAlert = false
    @State private var pastDayProtectionMessage = ""
    @State private var didSavePlan = false

    private var categories: [RecipesCategory] = RecipesCategory.allCases
    private let editorGridSpacing: CGFloat = 12

    private var editorGridColumns: [GridItem] {
        let columnCount = horizontalSizeClass == .compact ? 2 : 3
        return Array(
            repeating: GridItem(.flexible(), spacing: editorGridSpacing, alignment: .top),
            count: columnCount
        )
    }

    private var filteredRecipes: [Recipe] {
        var filtered = recipeCatalogStore.recipes

        switch selectedCategory {
        case .all:
            break
        case .favourite:
            filtered = filtered.filter { $0.favourite }
        default:
            filtered = filtered.filter { $0.category == selectedCategory }
        }

        if !debouncedSearchText.isEmpty {
            filtered = filtered.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(debouncedSearchText) ||
                recipe.description.localizedCaseInsensitiveContains(debouncedSearchText)
            }
        }

        return filtered
    }

    private var shouldShowSkeleton: Bool {
        recipeCatalogStore.isLoading && recipeCatalogStore.recipes.isEmpty
    }

    private func pastDayAssignmentsCount(for recipe: Recipe) -> Int {
        let pastDates = datesViewModel.dates.filter { !datesViewModel.isEditable($0) }
        guard !pastDates.isEmpty else { return 0 }

        return pastDates.reduce(into: 0) { result, date in
            for slot in MealSlot.allCases {
                if mealStore.recipe(for: date, slot: slot)?.id == recipe.id {
                    result += 1
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                WeeklyPlanEditorBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        editorSelectionOverview
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .padding(.bottom, 20)

                        if let errorMessage = recipeCatalogStore.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                        }

                        if shouldShowSkeleton {
                            LazyVGrid(columns: editorGridColumns, spacing: editorGridSpacing) {
                                ForEach(0..<6, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(DashboardPalette.surface(colorScheme, level: .tertiary))
                                        .frame(height: 250)
                                        .redacted(reason: .placeholder)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                        } else if filteredRecipes.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "list.clipboard")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.secondary)

                                Text("Brak wyników")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Text(emptyStateMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                            .padding(.horizontal)
                        } else {
                            LazyVGrid(columns: editorGridColumns, spacing: editorGridSpacing) {
                                ForEach(filteredRecipes) { recipe in
                                    Button {
                                        if mealPlan.isSelected(recipe) {
                                            let pastAssignments = pastDayAssignmentsCount(for: recipe)
                                            if pastAssignments > 0 {
                                                pastDayProtectionMessage = "Nie możesz odznaczyć tego przepisu, bo jest przypisany do dnia z przeszłości (\(pastAssignments) raz(y)). Najpierw usuń go z tych dni w Kalendarzu."
                                                showPastDayProtectionAlert = true
                                                return
                                            }
                                        }
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            mealPlan.toggleRecipe(recipe)
                                        }
                                    } label: {
                                        RecipeItemView(
                                            recipe: recipe,
                                            isInPlanningMode: true,
                                            isSelected: mealPlan.selectedRecipeIDs.contains(recipe.id)
                                        )
                                    }
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .buttonStyle(.plain)
                                    .task {
                                        await recipeCatalogStore.loadNextPageIfNeeded(currentItemId: recipe.id, threshold: 8)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 0)
                            .padding(.bottom, 92)

                            if recipeCatalogStore.isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom, 16)
                            }
                        }
                    }
                }

                MealPlanFloatingBar(
                    totalCount: mealPlan.totalCount,
                    maxCount: MealPlanViewModel.maxTotal
                ) {
                    mealPlan.showSummarySheet = true
                }
                .padding(.bottom, 4)
            }
            .navigationTitle("Edytuj plan")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                didSavePlan = false
                mealPlan.loadFromSaved(mealStore.savedPlan)
            }
            .task {
                debouncedSearchText = searchText
                await recipeCatalogStore.loadIfNeeded()
            }
            .onChange(of: recipeCatalogStore.recipes.count) { _, _ in
                ImagePrefetcher.prefetch(recipeCatalogStore.recipes.compactMap(\.imageURL))
            }
            .task(id: datesViewModel.weekStartISO) {
                await mealStore.loadSavedPlanFromBackend(weekStart: datesViewModel.weekStartISO)
                await mealStore.loadWeekPlanFromBackend(
                    weekStart: datesViewModel.weekStartISO,
                    dates: datesViewModel.dates
                )
                mealPlan.loadFromSaved(mealStore.savedPlan)
            }
            .onChange(of: searchText) { _, newValue in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard !Task.isCancelled else { return }
                    debouncedSearchText = newValue
                }
            }
            .onDisappear {
                searchDebounceTask?.cancel()
                if !didSavePlan && !mealPlan.showSummarySheet {
                    mealPlan.loadFromSaved(mealStore.savedPlan)
                }
                didSavePlan = false
            }
            .searchable(text: $searchText, prompt: "Szukaj przepisów")
            .sheet(isPresented: $mealPlan.showSummarySheet) {
                MealPlanSummarySheet(mealPlan: mealPlan) {
                    didSavePlan = true
                    dismiss()
                }
                .dashboardLiquidSheet()
            }
            .alert(
                "Limit osiągnięty",
                isPresented: Binding(
                    get: { mealPlan.slotFullAlert != nil },
                    set: { if !$0 { mealPlan.slotFullAlert = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                if let slot = mealPlan.slotFullAlert {
                    Text("Możesz dodać maksymalnie 7 przepisów do kategorii \(slot.title).")
                }
            }
            .alert("Nie można odznaczyć przepisu", isPresented: $showPastDayProtectionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(pastDayProtectionMessage)
            }
        }
    }

    private var editorStatusCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(MealSlot.allCases.enumerated()), id: \.element.id) { index, slot in
                editorSlotProgressRow(slot: slot, tint: slot.accentColor)

                if index < MealSlot.allCases.count - 1 {
                    Rectangle()
                        .fill(DashboardPalette.neutralBorder(colorScheme, opacity: 0.08))
                        .frame(height: 1)
                        .padding(.leading, 52)
                        .padding(.vertical, 2)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DashboardPalette.surface(colorScheme, level: .tertiary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.12), lineWidth: 1)
        )
    }

    private var editorSelectionOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wybierz przepisy")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .fontDesign(.rounded)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Dobierz przepisy na cały tydzień i użyj filtra po prawej, żeby szybciej zbudować śniadania, obiady oraz kolacje. Ten wybór od razu układa rytm całego planu poniżej.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                RecipeFilters(categories: categories, selectedCategory: $selectedCategory)
                    .padding(.top, 4)
            }

            editorStatusCard
        }
    }

    private func editorSlotProgressRow(slot: MealSlot, tint: Color) -> some View {
        let count = mealPlan.count(for: slot)
        let remaining = max(MealPlanViewModel.maxPerSlot - count, 0)
        let progress = CGFloat(count) / CGFloat(MealPlanViewModel.maxPerSlot)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: slot.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(colorScheme == .dark ? 0.16 : 0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.title)
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)

                    Text(editorSlotProgressDescription(count: count, remaining: remaining))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text("\(count)/\(MealPlanViewModel.maxPerSlot)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(DashboardPalette.surface(colorScheme, level: .secondary), in: Capsule())
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                let progressWidth = count == 0 ? 0 : max(width * progress, 8)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DashboardPalette.surface(colorScheme, level: .secondary))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(colorScheme == .dark ? 0.92 : 0.86),
                                    slot.secondaryAccentColor.opacity(colorScheme == .dark ? 0.74 : 0.62)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .accessibilityLabel("\(slot.title): \(count) z \(MealPlanViewModel.maxPerSlot)")
    }

    private func editorSlotProgressDescription(count: Int, remaining: Int) -> String {
        if count == 0 {
            return "Jeszcze nic tu nie wybrano."
        }

        if remaining == 0 {
            return "Ta pora dnia jest już domknięta na cały tydzień."
        }

        if remaining == 1 {
            return "Brakuje jeszcze 1 przepisu."
        }

        return "Brakuje jeszcze \(remaining) przepisów."
    }

    private var emptyStateMessage: String {
        if !debouncedSearchText.isEmpty {
            return "Spróbuj zmienić frazę wyszukiwania albo wyczyścić filtr."
        }

        if selectedCategory != .all {
            return "Spróbuj wybrać inną kategorię."
        }

        return "Lista przepisów jest jeszcze pusta."
    }
}

#Preview {
    WeeklyPlanView()
}

private struct WeeklyPlanEditorBackground: View {
    var body: some View {
        DashboardSheetBackground(theme: .plan)
    }
}
