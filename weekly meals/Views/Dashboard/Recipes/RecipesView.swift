import SwiftUI

struct RecipesView: View {
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel
    @State private var selectedCategory: RecipesCategory = .all
    @State private var searchText = ""
    @State private var selectedRecipe: Recipe?
    @State private var mealPlan = MealPlanViewModel()
    @State private var showDeletePlanAlert = false

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
                    // Recipes List
                    ScrollView {
                        // Category Filters
                        RecipeFilters(categories: categories, selectedCategory: $selectedCategory)

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
                                            isSelected: mealPlan.isActive && mealPlan.selectedRecipeIDs.contains(recipe.id)
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
                    if mealPlan.isActive {
                        Button {
                            withAnimation { mealPlan.exitPlanningMode() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Anuluj")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.red)
                        }
                    } else if mealStore.hasSavedPlan {
                        // Jest plan → menu z edycją/usuwaniem
                        Menu {
                            Button {
                                withAnimation { mealPlan.loadFromSaved(mealStore.savedPlan) }
                            } label: {
                                Label("Edytuj plan", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                showDeletePlanAlert = true
                            } label: {
                                Label("Usuń plan", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "list.bullet.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                    } else {
                        // Brak planu → bezpośrednio twórz
                        Button {
                            withAnimation { mealPlan.enterPlanningMode() }
                        } label: {
                            Image(systemName: "calendar.badge.plus")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
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
                MealPlanSummarySheet(mealPlan: mealPlan)
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
            .alert("Usuń plan", isPresented: $showDeletePlanAlert) {
                Button("Usuń", role: .destructive) {
                    mealStore.clearSavedPlan()
                    mealStore.clearWeek(dates: datesViewModel.dates)
                }
                Button("Anuluj", role: .cancel) { }
            } message: {
                Text("Czy na pewno chcesz usunąć zapisany plan posiłków? Usunie też przypisane posiłki z kalendarza.")
            }
        }
    }
}

#Preview {
    RecipesView()
}
