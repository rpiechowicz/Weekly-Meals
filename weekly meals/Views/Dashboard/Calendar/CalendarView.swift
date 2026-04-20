import SwiftUI

struct CalendarView: View {
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.recipeCatalogStore) private var recipeCatalogStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var detailRecipe: Recipe?
    @State private var showAssigner = false

    // MARK: - Derived

    private var isDayEditable: Bool {
        datesViewModel.isEditable(datesViewModel.selectedDate)
    }

    private var hasAssignableDay: Bool {
        datesViewModel.dates.contains { datesViewModel.isEditable($0) }
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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardSheetBackground(theme: .indigo)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        @Bindable var bindableDates = datesViewModel
                        DatesView(datesViewModal: bindableDates)
                            .dashboardLiquidCard(cornerRadius: 24, strokeOpacity: 0.2)

                        if let errorMessage = mealStore.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .dashboardLiquidCard(cornerRadius: 16, strokeOpacity: 0.2)
                        }

                        dayHeaderCard

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
            .navigationTitle("Kalendarz")
            .toolbar {
                if hasAssignableDay {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAssigner = true
                        } label: {
                            Image(systemName: "pencil.and.list.clipboard")
                                .font(.body.weight(.semibold))
                        }
                        .accessibilityLabel("Przypisz posiłki")
                    }
                }
            }
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

    // MARK: - Day header (nutrition)

    private var dayHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(datesViewModel.formattedDate(datesViewModel.selectedDate))
                    .font(.headline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)

                if !isDayEditable {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.bold))
                        Text("Tylko podgląd")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(DashboardPalette.surface(colorScheme, level: .tertiary), in: Capsule())
                }

                Spacer(minLength: 0)
            }

            nutritionPanel
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.18)
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
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(unit)
                        .font(.caption2.weight(.medium))
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
                .fill(DashboardPalette.surface(colorScheme, level: .secondary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.08), lineWidth: 1)
        )
    }

    // MARK: - Slot card

    @ViewBuilder
    private func slotCard(_ slot: MealSlot) -> some View {
        let assigned = recipe(for: slot)

        VStack(alignment: .leading, spacing: 12) {
            slotHeader(slot: slot, assigned: assigned)

            if let assigned {
                assignedContent(slot: slot, recipe: assigned)
            } else {
                emptyRow(slot: slot)
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

    private func slotHeader(slot: MealSlot, assigned: Recipe?) -> some View {
        HStack(alignment: .center, spacing: 12) {
            slotIcon(slot)

            VStack(alignment: .leading, spacing: 2) {
                Text(slot.title)
                    .font(.headline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)

                Text(assigned == nil ? (isDayEditable ? "Do uzupełnienia" : "Brak") : "Zaplanowany")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            timePill(slot)
        }
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

    private func timePill(_ slot: MealSlot) -> some View {
        Text(slot.time)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(slot.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                slot.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.16),
                in: Capsule()
            )
    }

    private func assignedContent(slot: MealSlot, recipe: Recipe) -> some View {
        Button {
            openDetail(for: recipe)
        } label: {
            HStack(spacing: 12) {
                ticketThumbnail(recipe: recipe, slot: slot)

                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        ticketMeta(icon: "clock", text: "\(recipe.prepTimeMinutes) min")
                        ticketMeta(icon: "flame.fill", text: "\(Int(recipe.nutritionPerServing.kcal)) kcal")
                    }
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                DashboardPalette.surface(colorScheme, level: .secondary)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(slot.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func ticketThumbnail(recipe: Recipe, slot: MealSlot) -> some View {
        Group {
            if let url = recipe.imageURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty, .failure:
                        ticketThumbPlaceholder(slot: slot)
                    @unknown default:
                        ticketThumbPlaceholder(slot: slot)
                    }
                }
            } else {
                ticketThumbPlaceholder(slot: slot)
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func ticketThumbPlaceholder(slot: MealSlot) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(slot.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.18))
            Image(systemName: slot.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(slot.accentColor)
        }
    }

    private func ticketMeta(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
    }

    private func emptyRow(slot: MealSlot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isDayEditable ? "circle.dashed" : "lock.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)

            Text(isDayEditable ? "Brak przypisanego posiłku" : "Dzień nieedytowalny")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DashboardPalette.surface(colorScheme, level: .tertiary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.12), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func openDetail(for recipe: Recipe) {
        Task { @MainActor in
            detailRecipe = await recipeCatalogStore.loadRecipeDetail(recipeId: recipe.id) ?? recipe
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
