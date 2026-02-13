import SwiftUI

struct CalendarView: View {
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel

    @State private var slotToPick: MealSlot? = nil
    @State private var detailRecipe: Recipe? = nil
    @State private var showTipPopover: Bool = false

    // MARK: - Computed

    private var isDayEditable: Bool {
        datesViewModel.isEditable(datesViewModel.selectedDate)
    }

    private var dayNutrition: DayNutrition {
        let recipes = mealStore.plan(for: datesViewModel.selectedDate).allRecipes
        return DayNutrition(
            kcal: recipes.reduce(0) { $0 + Int($1.nutritionPerServing.kcal) },
            protein: recipes.reduce(0) { $0 + Int($1.nutritionPerServing.protein) },
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
            VStack(spacing: 0) {
                @Bindable var bindableDates = datesViewModel
                DatesView(datesViewModal: bindableDates)

                if let errorMessage = mealStore.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                dayHeader
                mealList
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
            }
            .sheet(item: $detailRecipe) { recipe in
                NavigationStack {
                    RecipeDetailView(recipe: recipe)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Day Header

    private var dayHeader: some View {
        HStack(alignment: .center) {
            Text(datesViewModel.formattedDate(datesViewModel.selectedDate))
                .font(.title2)
                .fontWeight(.bold)

            Spacer(minLength: 8)

            if !isDayEditable {
                pastDayBadge
            }

            infoButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var pastDayBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.circle.fill")
        }
        .font(.title3)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)
        .padding(4)
        .background(.ultraThinMaterial, in: Circle())
    }

    private var infoButton: some View {
        Button {
            showTipPopover.toggle()
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .padding(4)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTipPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            infoPopoverContent
                .padding()
                .padding(.vertical, 8)
                .presentationCompactAdaptation(.none)
        }
    }

    // MARK: - Info Popover

    private var infoPopoverContent: some View {
        VStack(alignment: .trailing, spacing: 0) {
            TipTap {
                HStack(alignment: .firstTextBaseline) {
                    Text("Informacje")
                        .font(.headline)
                    Spacer()
                }

                nutritionSummary

                Divider()

                tipRow(icon: "hand.rays", text: "Stuknij kartę posiłku, aby zobaczyć szczegóły.")
                tipRow(icon: "hand.draw", text: "Przesuń w lewo/prawo aby edytować bądź usuwać dany posiłek.")
            }
        }
    }

    private var nutritionSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Podsumowanie dnia")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                HStack {
                    nutritionBadge(icon: "flame.fill", color: .orange, text: "\(dayNutrition.kcal) kcal")
                    nutritionBadge(icon: "bolt.fill", color: .blue, text: "\(dayNutrition.protein) g białka")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                nutritionBadge(icon: "leaf.fill", color: .green, text: "\(dayNutrition.carbs) g węglowodanów")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func nutritionBadge(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Meal List

    private var mealList: some View {
        List {
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
        .scrollDisabled(true)
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
    var carbs: Int = 0
}

#Preview {
    CalendarView()
}
