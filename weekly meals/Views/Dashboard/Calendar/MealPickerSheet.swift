import SwiftUI

struct MealPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let slot: MealSlot
    let recipes: [Recipe]
    let recipeCounts: [UUID: Int]
    let totalRecipeCounts: [UUID: Int]
    var onSelect: (Recipe) -> Void

    @State private var selectedCategory: RecipesCategory
    @State private var searchText: String = ""

    private var categories: [RecipesCategory] { RecipesCategory.allCases }
    private var selectedFilterIcon: String {
        selectedCategory == .all
        ? "line.3.horizontal.decrease.circle"
        : RecipesConstants.icon(for: selectedCategory)
    }
    private var selectedFilterTint: Color {
        selectedCategory == .all ? .secondary : .blue
    }

    init(
        slot: MealSlot,
        recipes: [Recipe],
        recipeCounts: [UUID: Int] = [:],
        totalRecipeCounts: [UUID: Int] = [:],
        onSelect: @escaping (Recipe) -> Void
    ) {
        self.slot = slot
        self.recipes = recipes
        self.recipeCounts = recipeCounts
        self.totalRecipeCounts = totalRecipeCounts
        self.onSelect = onSelect
        self._selectedCategory = State(initialValue: {
            switch slot {
            case .breakfast: return .breakfast
            case .lunch:     return .lunch
            case .dinner:    return .dinner
            }
        }())
    }

    private var uniqueRecipes: [Recipe] {
        var seen = Set<UUID>()
        return recipes.filter { seen.insert($0.id).inserted }
    }

    private var filteredRecipes: [Recipe] {
        var filtered = uniqueRecipes

        switch selectedCategory {
        case .all:
            break
        case .favourite:
            filtered = filtered.filter { $0.favourite }
        default:
            filtered = filtered.filter { $0.category == selectedCategory }
        }

        if !searchText.isEmpty {
            filtered = filtered.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardLiquidBackground()
                    .ignoresSafeArea()

                ScrollView {
                    if filteredRecipes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "fork.knife.circle")
                                .font(.system(size: 56))
                                .foregroundStyle(.secondary)

                            Text("Brak przepisów")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text("Dopasuj filtr lub wpisz inną frazę.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 44)
                        .padding(.horizontal, 16)
                        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.18)
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 16) {
                            ForEach(filteredRecipes) { recipe in
                                let count = recipeCounts[recipe.id] ?? 0
                                let total = totalRecipeCounts[recipe.id] ?? 1
                                Button {
                                    onSelect(recipe)
                                    dismiss()
                                } label: {
                                    RecipeItemView(
                                        recipe: recipe,
                                        badgeCount: 0,
                                        availabilityBadgeText: "\(count)/\(total)",
                                        availabilityBadgeColor: count > 0 ? .green : .orange
                                    )
                                    .opacity(count > 0 ? 1 : 0.55)
                                }
                                .buttonStyle(.plain)
                                .disabled(count <= 0)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Wybierz posiłek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: slot.icon)
                            .foregroundStyle(slot.accentColor)
                        Text(slot.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(categories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: RecipesConstants.icon(for: category))
                                    Text(RecipesConstants.displayName(for: category))
                                    Spacer(minLength: 8)
                                    if selectedCategory == category {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: selectedFilterIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(selectedFilterTint)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Szukaj przepisów")
        .presentationDetents([.large])
    }
}

#Preview("Meal Picker") {
    MealPickerSheet(slot: .lunch, recipes: RecipesMock.all) { _ in }
}
