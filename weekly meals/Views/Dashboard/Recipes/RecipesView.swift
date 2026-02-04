import SwiftUI

struct RecipesView: View {
    @State private var selectedCategory: RecipesCategory = .all
    @State private var searchText = ""
    @State private var selectedRecipe: Recipe?

    private var categories: [RecipesCategory] = RecipesCategory.allCases
    
    // Mock data - później zastąpisz prawdziwymi danymi
    private var recipes = RecipesMock.all
    
    // Filtered recipes based on category and search
    private var filteredRecipes: [Recipe] {
        var filtered = recipes
        
        // Filter by category (handle favourites separately)
        switch selectedCategory {
        case .all:
            break
        case .favourite:
            filtered = filtered.filter { $0.favourite }
        default:
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Filter by search text
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
                // Category Filters
                RecipeFilters(categories: categories, selectedCategory: $selectedCategory)
                
                // Recipes List
                ScrollView {
                    if filteredRecipes.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "fork.knife.circle")
                                .font(.system(size: 64))
                                .foregroundStyle(.secondary)
                            
                            Text("Brak przepisów")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Spróbuj wybrać inną kategorię")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                        .padding(.horizontal)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 16) {
                            ForEach(filteredRecipes) { recipe in
                                Button {
                                    selectedRecipe = recipe
                                } label: {
                                    RecipeItemView(recipe: recipe)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                    }
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Przepisy")
            .searchable(text: $searchText, prompt: "Szukaj przepisów")
            .sheet(item: $selectedRecipe) { selected in
                NavigationStack {
                    RecipeDetailView(recipe: selected)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    RecipesView()
}
