import SwiftUI

struct MealPlanSummarySheet: View {
    let mealPlan: MealPlanViewModel
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.shoppingListStore) private var shoppingListStore
    @Environment(\.colorScheme) private var colorScheme
    private var canSave: Bool { true }
    private var remainingCount: Int { max(MealPlanViewModel.maxTotal - mealPlan.totalCount, 0) }

    private func usedCount(for recipe: Recipe, slot: MealSlot) -> Int {
        datesViewModel.dates.reduce(into: 0) { result, date in
            if mealStore.recipe(for: date, slot: slot)?.id == recipe.id {
                result += 1
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardSheetBackground(theme: .twilight)
                    .ignoresSafeArea()

                List {
                    summaryOverviewCard
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    ForEach(MealSlot.allCases) { slot in
                        Section {
                            let unique = mealPlan.uniqueRecipes(for: slot)
                            if unique.isEmpty {
                                emptyRow
                                    .padding(12)
                                    .dashboardLiquidCard(cornerRadius: 14, strokeOpacity: 0.16)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            } else {
                                ForEach(unique) { recipe in
                                    let inUse = usedCount(for: recipe, slot: slot)
                                    let recipeCount = mealPlan.recipeCount(recipe)
                                    MealPlanSummaryRow(
                                        recipe: recipe,
                                        slot: slot,
                                        count: recipeCount,
                                        canIncrement: mealPlan.canAdd(to: slot),
                                        canDecrement: recipeCount > inUse,
                                        onIncrement: {
                                            withAnimation(.easeInOut(duration: 0.18)) {
                                                mealPlan.incrementRecipe(recipe)
                                            }
                                        },
                                        onDecrement: {
                                            withAnimation(.easeInOut(duration: 0.18)) {
                                                mealPlan.decrementRecipe(recipe)
                                            }
                                        }
                                    )
                                    .padding(10)
                                    .dashboardLiquidCard(cornerRadius: 16, strokeOpacity: 0.16)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                }
                            }
                        } header: {
                            HStack(spacing: 10) {
                                Image(systemName: slot.icon)
                                    .foregroundStyle(slot.accentColor)
                                    .frame(width: 26, height: 26)
                                    .background(slot.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.18), in: Circle())
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(slot.title)
                                    Text(slot.time)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(mealPlan.count(for: slot))/\(MealPlanViewModel.maxPerSlot)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DashboardPalette.surface(colorScheme, level: .tertiary), in: Capsule())
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Plan posiłków")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") { saveTapped() }
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var summaryOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Podgląd planu")
                    .font(.title3.weight(.bold))
                    .fontDesign(.rounded)

                Text(summaryHelperText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                let progressWidth = mealPlan.totalCount == 0
                    ? 0
                    : max(width * CGFloat(Double(mealPlan.totalCount) / Double(MealPlanViewModel.maxTotal)), 8)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DashboardPalette.surface(colorScheme, level: .tertiary))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(colorScheme == .dark ? 0.88 : 0.78),
                                    Color.cyan.opacity(colorScheme == .dark ? 0.82 : 0.72)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth)
                }
            }
            .frame(height: 10)

            HStack(alignment: .top, spacing: 12) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "hand.tap")
                    Text("Użyj + i -, aby szybko dopracować liczbę wybranych przepisów.")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(mealPlan.totalCount)/\(MealPlanViewModel.maxTotal)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.top, 1)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.16)
    }

    private var summaryHelperText: String {
        if mealPlan.totalCount == 0 {
            return "To szybki podgląd całego tygodnia. Wróć do listy i dobierz przepisy dla każdej pory dnia."
        }

        if remainingCount == 0 {
            return "Jeśli układ Ci pasuje, zapisz plan i użyj go później jako bazy do kalendarza oraz zakupów."
        }

        return "To szybkie podsumowanie wyboru przed zapisem. Możesz jeszcze wrócić i dopracować proporcje między posiłkami."
    }

    // MARK: - Empty Row

    private var emptyRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.dashed")
                .foregroundStyle(.secondary)
            Text("Brak wybranych posiłków")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - Save

    private func saveTapped() {
        let plan = SavedMealPlan(
            breakfastEntries: mealPlan.recipes(for: .breakfast).map { PlanEntry(recipe: $0) },
            lunchEntries: mealPlan.recipes(for: .lunch).map { PlanEntry(recipe: $0) },
            dinnerEntries: mealPlan.recipes(for: .dinner).map { PlanEntry(recipe: $0) }
        )
        Task {
            await mealStore.saveMealPlanToBackend(plan, weekStart: datesViewModel.weekStartISO)
            await shoppingListStore.load(weekStart: datesViewModel.weekStartISO, force: true)
        }
        mealPlan.savePlan()
        if let onSave {
            onSave()
        } else {
            dismiss()
        }
    }
}

// MARK: - Summary Row (oryginalny widok z +/-)

private struct MealPlanSummaryRow: View {
    let recipe: Recipe
    let slot: MealSlot
    let count: Int
    let canIncrement: Bool
    let canDecrement: Bool
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let imageURL = recipe.imageURL {
                    CachedAsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .empty:
                            ProgressView()
                        case .failure:
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.title3)
                                .foregroundStyle(slot.accentColor)
                        @unknown default:
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.title3)
                                .foregroundStyle(slot.accentColor)
                        }
                    }
                } else {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.title3)
                        .foregroundStyle(slot.accentColor)
                }
            }
            .frame(width: 54, height: 54)
            .background(Color(.secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(recipe.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        summaryControlButton(
                            icon: "minus",
                            tint: .orange,
                            isEnabled: canDecrement,
                            action: onDecrement
                        )

                        Text("\(count)x")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .frame(minWidth: 28)

                        summaryControlButton(
                            icon: "plus",
                            tint: .green,
                            isEnabled: canIncrement,
                            action: onIncrement
                        )
                    }
                }

                HStack(spacing: 8) {
                    summaryMetaPill(icon: "clock", text: "\(recipe.prepTimeMinutes) min")
                    summaryMetaPill(icon: "flame.fill", text: "\(Int(recipe.nutritionPerServing.kcal)) kcal")
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func summaryControlButton(
        icon: String,
        tint: Color,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        DashboardActionButton(
            title: nil,
            systemImage: icon,
            tone: .neutral,
            isDisabled: !isEnabled,
            foregroundColor: isEnabled ? tint : .secondary,
            controlSize: 28,
            action: action
        )
    }

    private func summaryMetaPill(icon: String, text: String) -> some View {
        RecipeMetricBadge(icon: icon, text: text)
    }
}
