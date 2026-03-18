import SwiftUI

struct CalendarView: View {
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.recipeCatalogStore) private var recipeCatalogStore

    @State private var slotToPick: MealSlot? = nil
    @State private var detailRecipe: Recipe? = nil

    private static let weekRangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

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

    private var weekRangeText: String {
        guard let first = datesViewModel.dates.first,
              let last = datesViewModel.dates.last else {
            return "Bieżący tydzień"
        }
        return "\(Self.weekRangeFormatter.string(from: first)) - \(Self.weekRangeFormatter.string(from: last))"
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
                CalendarLiquidBackground()
                    .ignoresSafeArea()

                @Bindable var bindableDates = datesViewModel
                List {
                    DatesView(datesViewModal: bindableDates)
                        .dashboardLiquidCard(cornerRadius: 24, strokeOpacity: 0.22)
                        .padding(.horizontal, 16)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
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
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
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
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(datesViewModel.formattedDate(datesViewModel.selectedDate))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .fontWeight(.semibold)
                }

                Spacer(minLength: 8)

                if !isDayEditable {
                    pastDayBadge
                }
            }

            nutritionPanel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.18)
        .padding(.horizontal, 16)
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
        .background(Color.white.opacity(0.16), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
    }

    private var nutritionPanel: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            nutritionStatRow(title: "Kalorie", value: "\(dayNutrition.kcal)", unit: "kcal", icon: "flame.fill", tint: .orange)
            nutritionStatRow(title: "Białko", value: "\(dayNutrition.protein)", unit: "g", icon: "bolt.fill", tint: .blue)
            nutritionStatRow(title: "Tłuszcze", value: "\(dayNutrition.fat)", unit: "g", icon: "drop.fill", tint: .pink)
            nutritionStatRow(title: "Węglowodany", value: "\(dayNutrition.carbs)", unit: "g", icon: "leaf.fill", tint: .green)
        }
    }

    private func nutritionStatRow(
        title: String,
        value: String,
        unit: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))

                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(unit)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func handleTap(_ slot: MealSlot) {
        if let recipe = recipe(for: slot) {
            Task {
                detailRecipe = await recipeCatalogStore.loadRecipeDetail(recipeId: recipe.id) ?? recipe
            }
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

private struct CalendarLiquidBackground: View {
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
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 95)
                .offset(x: -120, y: -190)

            Circle()
                .fill(Color.purple.opacity(colorScheme == .dark ? 0.18 : 0.1))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: 150, y: 240)

            Circle()
                .fill(Color.cyan.opacity(colorScheme == .dark ? 0.12 : 0.09))
                .frame(width: 210, height: 210)
                .blur(radius: 85)
                .offset(x: 120, y: -240)
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
