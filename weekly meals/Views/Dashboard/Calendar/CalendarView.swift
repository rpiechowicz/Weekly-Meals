import SwiftUI

struct CalendarView: View {
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.recipeCatalogStore) private var recipeCatalogStore
    @Environment(\.colorScheme) private var scheme

    @State private var detailRecipe: Recipe?
    @State private var showAssigner = false

    // MARK: - Derived

    private var isDayEditable: Bool {
        datesViewModel.isEditable(datesViewModel.selectedDate)
    }

    private var dayRecipes: [Recipe] {
        mealStore.plan(for: datesViewModel.selectedDate).allRecipes
    }

    private var dayKcal:    Int { dayRecipes.reduce(0) { $0 + Int($1.nutritionPerServing.kcal) } }
    private var dayProtein: Int { dayRecipes.reduce(0) { $0 + Int($1.nutritionPerServing.protein) } }
    private var dayFat:     Int { dayRecipes.reduce(0) { $0 + Int($1.nutritionPerServing.fat) } }
    private var dayCarbs:   Int { dayRecipes.reduce(0) { $0 + Int($1.nutritionPerServing.carbs) } }

    /// Set of "yyyy-MM-dd" keys for visible days that already have ≥1 meal — drives the sage planned-dot.
    private var plannedDates: Set<String> {
        var set = Set<String>()
        for date in datesViewModel.dates {
            let plan = mealStore.plan(for: date)
            if !plan.allRecipes.isEmpty {
                set.insert(plan.dateKey)
            }
        }
        return set
    }

    private func recipe(for slot: MealSlot) -> Recipe? {
        mealStore.recipe(for: datesViewModel.selectedDate, slot: slot)
    }

    /// Live `favourite` flag from the recipe catalog. The meal store snapshots
    /// `Recipe.favourite` at plan-save time and never resyncs, so we look up
    /// the current state by recipe id and fall back to the snapshot.
    private func isFavourite(for slot: MealSlot) -> Bool {
        guard let r = recipe(for: slot) else { return false }
        if let live = recipeCatalogStore.recipes.first(where: { $0.id == r.id }) {
            return live.favourite
        }
        return r.favourite
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WMPageBackground(scheme: scheme)
                    .ignoresSafeArea()

                ScrollView {
                    @Bindable var bindableDates = datesViewModel
                    VStack(alignment: .leading, spacing: 0) {
                        // Week bar — top spacing chosen so the bar sits ~78pt
                        // from screen top on iPhone 17 Pro (safe-area top ≈ 59pt).
                        EditorialWeekBar(
                            datesViewModel: bindableDates,
                            plannedDates: plannedDates
                        )
                        .padding(.horizontal, 22)
                        .padding(.top, 19)

                        // Rule below week bar — `margin: '14px 22px 18px'`.
                        Rectangle()
                            .fill(Color.wmRule(scheme))
                            .frame(height: 1)
                            .padding(.horizontal, 22)
                            .padding(.top, 14)
                            .padding(.bottom, 18)

                        // Hero — `padding: '0 22px 18px'`.
                        EditorialDayHero(date: datesViewModel.selectedDate)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 18)

                        // Macros — `padding: '0 22px 22px'`.
                        EditorialMacroBlock(
                            kcal: dayKcal,
                            protein: dayProtein,
                            fat: dayFat,
                            carbs: dayCarbs
                        )
                        .padding(.horizontal, 22)
                        .padding(.bottom, 22)

                        // "W MENU" rule — `margin: '0 22px 18px'`.
                        menuRule
                            .padding(.horizontal, 22)
                            .padding(.bottom, 18)

                        if let errorMessage = mealStore.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 22)
                                .padding(.bottom, 12)
                        }

                        // Meals — `padding: '0 22px 0', gap: 16`. Outer scroll has `paddingBottom: 40`.
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(MealSlot.allCases.enumerated()), id: \.element.id) { idx, slot in
                                EditorialMealCard(
                                    slot: slot,
                                    number: idx + 1,
                                    recipe: recipe(for: slot),
                                    isFavourite: isFavourite(for: slot),
                                    isEditable: isDayEditable,
                                    onTap: { handleAssignedTap(slot: slot) },
                                    onAssign: { showAssigner = true },
                                    onToggleFavorite: { toggleFavorite(for: slot) }
                                )
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 40)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: datesViewModel.weekStartISO) {
                await mealStore.loadSavedPlanFromBackend(weekStart: datesViewModel.weekStartISO)
                await mealStore.loadWeekPlanFromBackend(
                    weekStart: datesViewModel.weekStartISO,
                    dates: datesViewModel.dates
                )
            }
            .sheet(isPresented: $showAssigner) {
                DayAssignerSheet(
                    weekDates: datesViewModel.dates,
                    weekStartISO: datesViewModel.weekStartISO
                )
                .dashboardLiquidSheet()
            }
            .sheet(item: $detailRecipe) { selected in
                NavigationStack {
                    RecipeDetailView(
                        recipe: selected,
                        onToggleFavorite: {
                            Task { @MainActor in
                                await recipeCatalogStore.toggleFavorite(recipeId: selected.id)
                                detailRecipe = await recipeCatalogStore.loadRecipeDetail(recipeId: selected.id)
                                    ?? recipeCatalogStore.recipes.first(where: { $0.id == selected.id })
                                    ?? selected
                            }
                        }
                    )
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
                .dashboardLiquidSheet()
            }
        }
    }

    // MARK: - Pieces

    private var menuRule: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.wmRule(scheme))
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            Text("W MENU")
                .font(.system(size: 9, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color.wmMuted(scheme))

            Rectangle()
                .fill(Color.wmRule(scheme))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Actions

    private func handleAssignedTap(slot: MealSlot) {
        guard let assigned = recipe(for: slot) else { return }
        Task { @MainActor in
            detailRecipe = await recipeCatalogStore.loadRecipeDetail(recipeId: assigned.id) ?? assigned
        }
    }

    private func toggleFavorite(for slot: MealSlot) {
        guard let assigned = recipe(for: slot) else { return }
        Task { @MainActor in
            await recipeCatalogStore.toggleFavorite(recipeId: assigned.id)
        }
    }
}

#Preview {
    CalendarView()
}
