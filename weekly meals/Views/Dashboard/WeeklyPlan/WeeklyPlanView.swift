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
                        await mealStore.clearSavedPlanFromBackend(weekStart: datesViewModel.weekStartISO)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(weekRangeText)
                        .font(.title3)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)

                    Text(mealStore.hasSavedPlan ? "Plan gotowy do użycia w kalendarzu" : "Ułóż zestaw posiłków na ten tydzień")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                heroActions
            }
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
                    .font(.subheadline)
                    .foregroundStyle(slot.accentColor)
                    .frame(width: 30, height: 30)
                    .background(slot.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

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
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
                    AsyncImage(url: imageURL) { phase in
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
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(slot.accentColor, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(
            Capsule()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.09 : 0.2))
        )
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

    @State private var selectedCategory: RecipesCategory = .all
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?

    @State private var mealPlan = MealPlanViewModel()
    @State private var showPastDayProtectionAlert = false
    @State private var pastDayProtectionMessage = ""
    @State private var didSavePlan = false

    private var categories: [RecipesCategory] = RecipesCategory.allCases

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

    private func discardChangesAndDismiss() {
        mealPlan.loadFromSaved(mealStore.savedPlan)
        mealPlan.showSummarySheet = false
        didSavePlan = false
        dismiss()
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
                        editorStatusCard
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .padding(.bottom, 8)

                        RecipeFilters(categories: categories, selectedCategory: $selectedCategory)

                        if let errorMessage = recipeCatalogStore.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                        }

                        if shouldShowSkeleton {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 16) {
                                ForEach(0..<6, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 250)
                                        .redacted(reason: .placeholder)
                                }
                            }
                            .padding(.horizontal, 12)
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
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 16) {
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
                                    .buttonStyle(.plain)
                                    .task {
                                        await recipeCatalogStore.loadNextPageIfNeeded(currentItemId: recipe.id, threshold: 8)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zamknij") {
                        discardChangesAndDismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        mealPlan.showSummarySheet = true
                    } label: {
                        Text("Podsumowanie")
                            .fontWeight(.semibold)
                    }
                    .disabled(mealPlan.totalCount == 0)
                }
            }
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
        HStack(spacing: 10) {
            editorSlotSummaryTile(slot: .breakfast, count: mealPlan.count(for: .breakfast), tint: .orange)
            editorSlotSummaryTile(slot: .lunch, count: mealPlan.count(for: .lunch), tint: .blue)
            editorSlotSummaryTile(slot: .dinner, count: mealPlan.count(for: .dinner), tint: .purple)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func editorSlotSummaryTile(slot: MealSlot, count: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: slot.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.12), in: Circle())

                Text(slot.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Text("\(count)/\(MealPlanViewModel.maxPerSlot)")
                .font(.headline)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
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
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.15, blue: 0.18),
                    Color(red: 0.09, green: 0.11, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(0.14))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: -140, y: -220)

            Circle()
                .fill(Color.cyan.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: 160, y: 260)
        }
    }
}
