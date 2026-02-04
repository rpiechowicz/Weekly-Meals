import SwiftUI

struct RecipesListView: View {
    @State private var searchText = ""
    
    // Mock data - później zastąpisz prawdziwymi danymi z ViewModelu
    private var recipes = RecipesMock.all
    
    // Filtered recipes based on search
    private var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return recipes
        } else {
            return recipes.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.description.localizedCaseInsensitiveContains(searchText) ||
                recipe.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(filteredRecipes) { recipe in
                        RecipeItem(recipe: recipe)
                    }
                    
                    if filteredRecipes.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("Brak wyników")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Spróbuj wyszukać coś innego")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Przepisy")
            .searchable(text: $searchText, prompt: "Szukaj przepisów")
        }
    }
}

#Preview {
    RecipesListView()
}
