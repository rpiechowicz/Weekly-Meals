import SwiftUI

struct MealPlanSummarySheet: View {
    let mealPlan: MealPlanViewModel
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel

    private var canSave: Bool {
        mealPlan.totalCount > 0
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
                                MealPlanSummaryRow(
                                    recipe: recipe,
                                    slot: slot,
                                    count: mealPlan.recipeCount(recipe),
                                    canAdd: mealPlan.canAdd(to: slot),
                                    onIncrement: { mealPlan.incrementRecipe(recipe) },
                                    onDecrement: { mealPlan.decrementRecipe(recipe) }
                                )
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            mealPlan.toggleRecipe(recipe)
                                        }
                                    } label: {
                                        Label("Usuń", systemImage: "trash")
                                    }
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
        // Wyczyść z kalendarza przepisy, których nie ma w nowym planie
        // i zsynchronizuj flagi isSelected
        mealStore.cleanupCalendarAndSync(with: plan)
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
    let canAdd: Bool
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(slot.accentColor.opacity(0.15))
                Image(systemName: "fork.knife.circle.fill")
                    .font(.title3)
                    .foregroundStyle(slot.accentColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(recipe.prepTimeMinutes) min", systemImage: "clock")
                    Label("\(Int(recipe.nutritionPerServing.kcal)) kcal", systemImage: "flame.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            // Licznik +/-
            HStack(spacing: 8) {
                Button { onDecrement() } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(count <= 1 ? .gray : .red)
                }
                .disabled(count <= 1)

                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .frame(minWidth: 20)

                Button { onIncrement() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(canAdd ? .green : .gray)
                }
                .disabled(!canAdd)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
