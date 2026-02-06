import SwiftUI

struct MealPlanSummarySheet: View {
    let mealPlan: MealPlanViewModel
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(MealSlot.allCases) { slot in
                    Section {
                        let recipes = mealPlan.uniqueRecipes(for: slot)
                        if recipes.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.dashed")
                                    .foregroundStyle(.secondary)
                                Text("Brak wybranych posiłków")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        } else {
                            ForEach(recipes) { recipe in
                                MealPlanSummaryRow(
                                    recipe: recipe,
                                    slot: slot,
                                    count: mealPlan.recipeCount(recipe),
                                    canAdd: mealPlan.canAdd(to: slot),
                                    onIncrement: {
                                        withAnimation { mealPlan.incrementRecipe(recipe) }
                                    },
                                    onDecrement: {
                                        withAnimation { mealPlan.decrementRecipe(recipe) }
                                    }
                                )
                                .swipeActions(edge: .trailing) {
                                    Button("Usuń", role: .destructive) {
                                        withAnimation {
                                            mealPlan.toggleRecipe(recipe)
                                        }
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
                    Button("Zapisz") {
                        dismiss()
                        mealPlan.savePlan()
                    }
                    .disabled(mealPlan.totalCount == 0)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

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
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                        Text("\(recipe.prepTimeMinutes) min")
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                        Text("\(Int(recipe.nutritionPerServing.kcal)) kcal")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button {
                    onDecrement()
                } label: {
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

                Button {
                    onIncrement()
                } label: {
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
