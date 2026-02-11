import SwiftUI

struct MealPlanSummarySheet: View {
    let mealPlan: MealPlanViewModel
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.shoppingListStore) private var shoppingListStore
    @State private var showProtectedRecipeAlert = false
    @State private var protectedRecipeAlertMessage = ""

    private var canSave: Bool {
        mealPlan.totalCount > 0
    }

    private func usedCount(for recipe: Recipe, slot: MealSlot) -> Int {
        datesViewModel.dates.reduce(into: 0) { result, date in
            if mealStore.recipe(for: date, slot: slot)?.id == recipe.id {
                result += 1
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(MealSlot.allCases) { slot in
                    Section {
                        let unique = mealPlan.uniqueRecipes(for: slot)
                        if unique.isEmpty {
                            emptyRow
                        } else {
                            ForEach(unique) { recipe in
                                let inUse = usedCount(for: recipe, slot: slot)
                                let recipeCount = mealPlan.recipeCount(recipe)
                                MealPlanSummaryRow(
                                    recipe: recipe,
                                    slot: slot,
                                    count: recipeCount,
                                    minCount: inUse
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        withAnimation {
                                            mealPlan.incrementRecipe(recipe)
                                        }
                                    } label: {
                                        Label("Dodaj", systemImage: "plus")
                                    }
                                    .tint(.green)
                                    .disabled(!mealPlan.canAdd(to: slot))
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        withAnimation {
                                            if mealPlan.recipeCount(recipe) > inUse {
                                                mealPlan.decrementRecipe(recipe)
                                            } else {
                                                protectedRecipeAlertMessage = "Nie możesz odjąć tego przepisu, bo jest już przypisany w kalendarzu (\(inUse) raz(y)). Najpierw usuń go z dnia w Kalendarzu."
                                                showProtectedRecipeAlert = true
                                            }
                                        }
                                    } label: {
                                        Label("Odejmij", systemImage: "minus")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Image(systemName: slot.icon)
                                .foregroundStyle(slot.accentColor)
                            Text(slot.title)
                            Spacer()
                            Text("\(mealPlan.count(for: slot))/\(MealPlanViewModel.maxPerSlot)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("Plan posiłków")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") { saveTapped() }
                        .disabled(!canSave)
                }
            }
            .alert("Nie można odjąć przepisu", isPresented: $showProtectedRecipeAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(protectedRecipeAlertMessage)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Empty Row

    private var emptyRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.dashed")
                .foregroundStyle(.secondary)
            Text("Brak wybranych posiłków")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Save

    private func saveTapped() {
        let plan = SavedMealPlan(
            breakfastEntries: mealPlan.recipes(for: .breakfast).map { PlanEntry(recipe: $0) },
            lunchEntries: mealPlan.recipes(for: .lunch).map { PlanEntry(recipe: $0) },
            dinnerEntries: mealPlan.recipes(for: .dinner).map { PlanEntry(recipe: $0) }
        )
        mealStore.saveMealPlan(plan)
        // Aktualizacja planu nie może automatycznie przypisywać posiłków do kolejnych dni.
        // Dni ustawiamy wyłącznie ręcznie w CalendarView.
        mealStore.cleanupCalendarAndSync(with: plan)
        Task {
            await shoppingListStore.load(weekStart: datesViewModel.weekStartISO, force: true)
        }
        dismiss()
        mealPlan.savePlan()
        onSave?()
    }
}

// MARK: - Summary Row (oryginalny widok z +/-)

private struct MealPlanSummaryRow: View {
    let recipe: Recipe
    let slot: MealSlot
    let count: Int
    let minCount: Int
    
    private var freeCount: Int {
        max(0, count - minCount)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let imageURL = recipe.imageURL {
                    AsyncImage(url: imageURL) { phase in
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

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(recipe.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(count)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                    )
                }

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
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    statusChip(title: "Przypisane", value: minCount, color: .orange)
                    statusChip(title: "Wolne", value: freeCount, color: freeCount > 0 ? .green : .orange)
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func statusChip(title: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text("\(value)")
                .monospacedDigit()
                .fontWeight(.semibold)
        }
        .font(.caption2)
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.14))
        )
    }
}
