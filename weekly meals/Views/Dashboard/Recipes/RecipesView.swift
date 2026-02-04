import SwiftUI

struct RecipesView: View {
    @State private var selectedCategory: RecipesCategory = .all
    @State private var searchText = ""

    private var categories: [RecipesCategory] = RecipesCategory.allCases
    
    // Mock data - później zastąpisz prawdziwymi danymi
    private var recipes = RecipesMock.all
    
    // Filtered recipes based on category and search
    private var filteredRecipes: [Recipe] {
        var filtered = recipes
        
        // Filter by category
        if selectedCategory != .all {
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
                    LazyVStack(spacing: 10) {
                        ForEach(filteredRecipes) { recipe in
                            RecipeItem(recipe: recipe)
                        }
                        
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
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle("Przepisy")
            .searchable(text: $searchText, prompt: "Szukaj przepisów")
        }
    }
}

#Preview {
    RecipesView()
}
