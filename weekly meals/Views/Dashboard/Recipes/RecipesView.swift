import SwiftUI

struct RecipesView: View {
    @State private var selectedCategory: RecipesCategory = .all
    @State private var searchText = ""
    @State private var selectedRecipe: Recipe?
    @State private var mealPlan = MealPlanViewModel()

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
            ZStack(alignment: .bottom) {
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
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 16) {
                                ForEach(filteredRecipes) { recipe in
                                    Button {
                                        if mealPlan.isActive {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                mealPlan.toggleRecipe(recipe)
                                            }
                                        } else {
                                            selectedRecipe = recipe
                                        }
                                    } label: {
                                        RecipeItemView(
                                            recipe: recipe,
                                            isInPlanningMode: mealPlan.isActive,
                                            isSelected: mealPlan.isActive && mealPlan.isSelected(recipe)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
//                            .padding(.vertical, 16)
                            .padding(.top, 0)
                            .padding(.bottom, 18)
                            .padding(.bottom, mealPlan.isActive ? 60 : 0)
                        }
                    }
                }

                if mealPlan.isActive {
                    MealPlanFloatingBar(
                        totalCount: mealPlan.totalCount,
                        maxCount: MealPlanViewModel.maxTotal
                    ) {
                        mealPlan.showSummarySheet = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Przepisy")
            .searchable(text: $searchText, prompt: "Szukaj przepisów")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            if mealPlan.isActive {
                                mealPlan.exitPlanningMode()
                            } else {
                                mealPlan.enterPlanningMode()
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mealPlan.isActive
                                  ? "xmark.circle.fill"
                                  : "calendar.badge.plus")
                            if mealPlan.isActive {
                                Text("Anuluj")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(mealPlan.isActive ? .red : .blue)
                    }
                }
            }
            .sheet(item: $selectedRecipe) { selected in
                NavigationStack {
                    RecipeDetailView(recipe: selected)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $mealPlan.showSummarySheet) {
                MealPlanSummarySheet(mealPlan: mealPlan) {
                    mealPlan.exitPlanningMode()
                }
            }
            .alert(
                "Limit osiągnięty",
                isPresented: Binding(
                    get: { mealPlan.slotFullAlert != nil },
                    set: { if !$0 { mealPlan.slotFullAlert = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                if let slot = mealPlan.slotFullAlert {
                    Text("Możesz dodać maksymalnie 7 przepisów do kategorii \(slot.title).")
                }
            }
        }
    }
}

#Preview {
    RecipesView()
}
