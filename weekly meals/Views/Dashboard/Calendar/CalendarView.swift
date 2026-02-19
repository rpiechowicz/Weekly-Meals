import SwiftUI

struct CalendarView: View {
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel

    @State private var slotToPick: MealSlot? = nil
    @State private var detailRecipe: Recipe? = nil

    // MARK: - Computed

    private var isDayEditable: Bool {
        datesViewModel.isEditable(datesViewModel.selectedDate)
    }

    private var dayNutrition: DayNutrition {
        let recipes = mealStore.plan(for: datesViewModel.selectedDate).allRecipes
        return DayNutrition(
            kcal: recipes.reduce(0) { $0 + Int($1.nutritionPerServing.kcal) },
            protein: recipes.reduce(0) { $0 + Int($1.nutritionPerServing.protein) },
            fat: recipes.reduce(0) { $0 + Int($1.nutritionPerServing.fat) },
            carbs: recipes.reduce(0) { $0 + Int($1.nutritionPerServing.carbs) }
        )
    }

    private func recipe(for slot: MealSlot) -> Recipe? {
        mealStore.recipe(for: datesViewModel.selectedDate, slot: slot)
    }

    private func availableCounts(for slot: MealSlot, includeCurrentFor date: Date? = nil) -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for recipe in mealStore.savedPlan.availableRecipes(for: slot) {
            counts[recipe.id, default: 0] += 1
        }
        if let date,
           let current = mealStore.recipe(for: date, slot: slot) {
            counts[current.id, default: 0] += 1
        }
        return counts
    }

    private func totalCounts(for slot: MealSlot) -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for entry in mealStore.savedPlan.entries(for: slot) {
            counts[entry.recipe.id, default: 0] += 1
        }
        return counts
    }

    private func pickerRecipes(for slot: MealSlot) -> [Recipe] {
        mealStore.savedPlan.entries(for: slot).map(\.recipe)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardLiquidBackground()
                    .ignoresSafeArea()

                @Bindable var bindableDates = datesViewModel
                List {
                    DatesView(datesViewModal: bindableDates)
                        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.28)
                        .padding(.horizontal, 14)
                        .padding(.top, 4)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)

                    if let errorMessage = mealStore.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }

                    dayHeader
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)

                    ForEach(MealSlot.allCases) { slot in
                        MealCardView(slot: slot, recipe: recipe(for: slot), isEditable: isDayEditable)
                            .contentShape(Rectangle())
                            .onTapGesture { handleTap(slot) }
                            .swipeActions(edge: .leading) {
                                if recipe(for: slot) != nil && isDayEditable {
                                    Button("Edytuj") { slotToPick = slot }
                                        .tint(slot.accentColor)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                if recipe(for: slot) != nil && isDayEditable {
                                    Button("Usuń") { clearRecipe(for: slot) }
                                        .tint(.red)
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollBounceBehavior(.always)
            }
            .navigationTitle("Kalendarz")
            .task(id: datesViewModel.weekStartISO) {
                await mealStore.loadSavedPlanFromBackend(weekStart: datesViewModel.weekStartISO)
                await mealStore.loadWeekPlanFromBackend(
                    weekStart: datesViewModel.weekStartISO,
                    dates: datesViewModel.dates
                )
            }
            .sheet(item: $slotToPick) { slot in
                MealPickerSheet(
                    slot: slot,
                    recipes: pickerRecipes(for: slot),
                    recipeCounts: availableCounts(for: slot, includeCurrentFor: datesViewModel.selectedDate),
                    totalRecipeCounts: totalCounts(for: slot)
                ) { selected in
                    // Zwolnij poprzedni przepis z tego slotu (jeśli był)
                    let previous = recipe(for: slot)
                    if let previous {
                        mealStore.markAsAvailable(previous, slot: slot)
                    }
                    mealStore.markAsSelected(selected, slot: slot)
                    Task {
                        let success = await mealStore.upsertWeekSlot(
                            recipe: selected,
                            for: datesViewModel.selectedDate,
                            slot: slot,
                            weekStart: datesViewModel.weekStartISO
                        )
                        if !success {
                            mealStore.markAsAvailable(selected, slot: slot)
                            if let previous {
                                mealStore.markAsSelected(previous, slot: slot)
                            }
                        }
                    }
                }
                .dashboardLiquidSheet()
            }
            .sheet(item: $detailRecipe) { recipe in
                NavigationStack {
                    RecipeDetailView(recipe: recipe)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
                .dashboardLiquidSheet()
            }
        }
    }

    // MARK: - Day Header

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(datesViewModel.formattedDate(datesViewModel.selectedDate))
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                    Text("Bilans dnia")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if !isDayEditable {
                    pastDayBadge
                }
            }

            nutritionPanel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .dashboardLiquidCard(cornerRadius: 24, strokeOpacity: 0.22)
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private var pastDayBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
            Text("Archiwum")
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var nutritionPanel: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                nutritionMetricChip(title: "Kalorie", value: "\(dayNutrition.kcal) kcal", icon: "flame.fill", tint: .orange)
                nutritionMetricChip(title: "Białko", value: "\(dayNutrition.protein) g", icon: "bolt.fill", tint: .blue)
                nutritionMetricChip(title: "Tłuszcz", value: "\(dayNutrition.fat) g", icon: "drop.fill", tint: .pink)
                nutritionMetricChip(title: "Węgle", value: "\(dayNutrition.carbs) g", icon: "leaf.fill", tint: .green)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    nutritionMetricChip(title: "Kalorie", value: "\(dayNutrition.kcal) kcal", icon: "flame.fill", tint: .orange)
                    nutritionMetricChip(title: "Białko", value: "\(dayNutrition.protein) g", icon: "bolt.fill", tint: .blue)
                }
                HStack(spacing: 8) {
                    nutritionMetricChip(title: "Tłuszcz", value: "\(dayNutrition.fat) g", icon: "drop.fill", tint: .pink)
                    nutritionMetricChip(title: "Węgle", value: "\(dayNutrition.carbs) g", icon: "leaf.fill", tint: .green)
                }
            }
        }
    }

    private func nutritionMetricChip(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func handleTap(_ slot: MealSlot) {
        if let recipe = recipe(for: slot) {
            detailRecipe = recipe
        } else if isDayEditable {
            slotToPick = slot
        }
    }

    private func clearRecipe(for slot: MealSlot) {
        let previous = recipe(for: slot)
        if let previous {
            mealStore.markAsAvailable(previous, slot: slot)
        }
        Task {
            let success = await mealStore.removeWeekSlot(
                for: datesViewModel.selectedDate,
                slot: slot,
                weekStart: datesViewModel.weekStartISO
            )
            if !success, let previous {
                mealStore.markAsSelected(previous, slot: slot)
            }
        }
    }
}

// MARK: - DayNutrition

private struct DayNutrition {
    var kcal: Int = 0
    var protein: Int = 0
    var fat: Int = 0
    var carbs: Int = 0
}

#Preview {
    CalendarView()
}
