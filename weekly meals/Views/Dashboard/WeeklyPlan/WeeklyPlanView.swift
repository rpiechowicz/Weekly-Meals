import SwiftUI

struct WeeklyPlanView: View {
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.shoppingListStore) private var shoppingListStore

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

    private var totalPlannedCount: Int {
        mealStore.savedPlan.breakfastEntries.count + mealStore.savedPlan.lunchEntries.count + mealStore.savedPlan.dinnerEntries.count
    }

    private var progressValue: Double {
        guard MealPlanViewModel.maxTotal > 0 else { return 0 }
        return min(1, Double(totalPlannedCount) / Double(MealPlanViewModel.maxTotal))
    }

    private var heroStatusText: String {
        mealStore.hasSavedPlan ? "Gotowe do przypisywania w Kalendarzu." : "Dodaj plan na ten tydzień."
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tydzień")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text(weekRangeText)
                        .font(.title3)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                }

                Spacer()

                heroActions
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let clamped = min(max(progressValue, 0), 1)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.85), .blue.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width * clamped)
                }
            }
            .frame(height: 10)

            HStack(alignment: .center, spacing: 10) {
                Text(heroStatusText)
                    .lineLimit(1)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(totalPlannedCount)/\(MealPlanViewModel.maxTotal)")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.thickMaterial, in: Capsule())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var heroActions: some View {
        HStack(spacing: 0) {
            Button {
                showEditor = true
            } label: {
                Image(systemName: mealStore.hasSavedPlan ? "square.and.pencil" : "plus")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(mealStore.hasSavedPlan ? "Edytuj plan" : "Utwórz plan")
            .buttonStyle(.plain)

            if mealStore.hasSavedPlan {
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 2)

                Button(role: .destructive) {
                    showDeletePlanAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.thinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
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
                    .background(slot.accentColor.opacity(0.16), in: Circle())

                Text(slot.title)
                    .font(.headline)
                    .fontDesign(.rounded)

                Spacer()

                Text("\(slotCount)/\(MealPlanViewModel.maxPerSlot)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(slotCount > 0 ? slot.accentColor : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(slot.accentColor.opacity(slotCount > 0 ? 0.16 : 0.08), in: Capsule())
            }

            if !recipes.isEmpty {
                VStack(spacing: 10) {
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
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
                    Color.blue.opacity(0.22),
                    Color.cyan.opacity(0.16),
                    Color.indigo.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.cyan.opacity(0.35))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: -120, y: -200)

            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: 140, y: 220)
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
            .frame(width: 52, height: 52)
            .background(Color(.secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("\(recipe.prepTimeMinutes) min")
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                        Text("\(Int(recipe.nutritionPerServing.kcal)) kcal")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
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
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var fallbackIcon: some View {
        Image(systemName: "fork.knife.circle.fill")
            .font(.title3)
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
                DashboardLiquidBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
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

                                Text("Brak przepisów")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Text("Spróbuj wybrać inną kategorię")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
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
            }
            .searchable(text: $searchText, prompt: "Szukaj przepisów")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zamknij") {
                        dismiss()
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
}

#Preview {
    WeeklyPlanView()
}
