import SwiftUI

struct RecipesView: View {
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.recipeCatalogStore) private var recipeCatalogStore
    @Environment(\.shoppingListStore) private var shoppingListStore
    @State private var selectedCategory: RecipesCategory = .all
    @State private var searchText = ""
    @State private var selectedRecipe: Recipe?
    @State private var mealPlan = MealPlanViewModel()
    @State private var showDeletePlanAlert = false
    @State private var showPastDayProtectionAlert = false
    @State private var pastDayProtectionMessage = ""
    @State private var debouncedSearchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?

    private var categories: [RecipesCategory] = RecipesCategory.allCases

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

    // Filtered recipes based on category and search
    private var filteredRecipes: [Recipe] {
        var filtered = recipeCatalogStore.recipes

        // Filter by category (handle favourites separately)
        switch selectedCategory {
        case .all:
            break
        case .favourite:
            filtered = filtered.filter { $0.favourite }
        default:
            filtered = filtered.filter { $0.category == selectedCategory }
        }

        // Filter by search text
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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Recipes List
                    ScrollView {
                        // Category Filters
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
                                Image(systemName: "fork.knife.circle")
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
                                        if mealPlan.isActive {
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
                                        } else {
                                            Task { @MainActor in
                                                selectedRecipe = await recipeCatalogStore.loadRecipeDetail(recipeId: recipe.id) ?? recipe
                                            }
                                        }
                                    } label: {
                                        RecipeItemView(
                                            recipe: recipe,
                                            isInPlanningMode: mealPlan.isActive,
                                            isSelected: mealPlan.isActive && mealPlan.selectedRecipeIDs.contains(recipe.id)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .task {
                                        await recipeCatalogStore.loadNextPageIfNeeded(currentItemId: recipe.id, threshold: 8)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
//                            .padding(.vertical, 16)
                            .padding(.top, 0)
                            .padding(.bottom, 18)
                            .padding(.bottom, mealPlan.isActive ? 60 : 0)

                            if recipeCatalogStore.isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom, 16)
                            }
                        }
                    }
                }

                if mealPlan.isActive {
                    MealPlanFloatingBar(
                        totalCount: mealPlan.totalCount,
                        maxCount: MealPlanViewModel.maxTotal
                    ) {
                        mealPlan.showSummarySheet = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Przepisy")
            .task {
                debouncedSearchText = searchText
                await recipeCatalogStore.loadIfNeeded()
                await mealStore.loadSavedPlanFromBackend(weekStart: datesViewModel.weekStartISO)
            }
            .task(id: datesViewModel.weekStartISO) {
                await mealStore.loadSavedPlanFromBackend(weekStart: datesViewModel.weekStartISO)
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
                ToolbarItem(placement: .topBarTrailing) {
                    if mealPlan.isActive {
                        Button {
                            withAnimation { mealPlan.exitPlanningMode() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Anuluj")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.red)
                        }
                    } else if mealStore.hasSavedPlan {
                        // Jest plan → menu z edycją/usuwaniem
                        Menu {
                            Button {
                                withAnimation { mealPlan.loadFromSaved(mealStore.savedPlan) }
                            } label: {
                                Label("Edytuj plan", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                showDeletePlanAlert = true
                            } label: {
                                Label("Usuń plan", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "list.bullet.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                    } else {
                        // Brak planu → bezpośrednio twórz
                        Button {
                            withAnimation { mealPlan.enterPlanningMode() }
                        } label: {
                            Image(systemName: "calendar.badge.plus")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .sheet(item: $selectedRecipe) { selected in
                NavigationStack {
                    RecipeDetailView(
                        recipe: selected,
                        onToggleFavorite: {
                            Task {
                                await recipeCatalogStore.toggleFavorite(recipeId: selected.id)
                                selectedRecipe = recipeCatalogStore.recipes.first(where: { $0.id == selected.id })
                            }
                        }
                    )
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $mealPlan.showSummarySheet) {
                MealPlanSummarySheet(mealPlan: mealPlan)
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
                Text("Czy na pewno chcesz usunąć zapisany plan posiłków? Usunie też przypisane posiłki z kalendarza.")
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
    RecipesView()
}
