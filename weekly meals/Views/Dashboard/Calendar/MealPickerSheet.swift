import SwiftUI

struct MealPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let slot: MealSlot
    let recipes: [Recipe]
    var onSelect: (Recipe) -> Void

    @State private var selectedCategory: RecipesCategory
    @State private var searchText: String = ""

    private var slotCategory: RecipesCategory {
        switch slot {
        case .breakfast: .breakfast
        case .lunch:     .lunch
        case .dinner:    .dinner
        }
    }

    private var categories: [RecipesCategory] { RecipesCategory.allCases }

    init(slot: MealSlot, recipes: [Recipe], onSelect: @escaping (Recipe) -> Void) {
        self.slot = slot
        self.recipes = recipes
        self.onSelect = onSelect
        self._selectedCategory = State(initialValue: {
            switch slot {
            case .breakfast: return .breakfast
            case .lunch:     return .lunch
            case .dinner:    return .dinner
            }
        }())
    }

    private var filteredRecipes: [Recipe] {
        var filtered = recipes

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
            VStack(spacing: 0) {
                // Filters
                RecipeFilters(
                    categories: categories,
                    selectedCategory: $selectedCategory,
                    disabled: true
                )

                ScrollView {
                    if filteredRecipes.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "fork.knife.circle")
                                .font(.system(size: 64))
                                .foregroundStyle(.secondary)

                            Text("Brak przepisów")
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text("Dopasuj filtry lub wyszukaj inaczej")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                        .padding(.horizontal)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 16) {
                            ForEach(filteredRecipes) { recipe in
                                Button {
                                    onSelect(recipe)
                                    dismiss()
                                } label: {
                                    RecipeItemView(recipe: recipe)
                                }
                                .buttonStyle(.plain)
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
            }
        }
        .searchable(text: $searchText, prompt: "Szukaj przepisów")
        .presentationDetents([.large, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Meal Picker") {
    MealPickerSheet(slot: .lunch, recipes: RecipesMock.all) { _ in }
}
