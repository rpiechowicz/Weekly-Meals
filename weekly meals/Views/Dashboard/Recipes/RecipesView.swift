import SwiftUI

struct RecipesView: View {
    @Environment(\.recipeCatalogStore) private var recipeCatalogStore

    @State private var selectedCategory: RecipesCategory = .all
    @State private var searchText = ""
    @State private var selectedRecipe: Recipe?
    @State private var debouncedSearchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?

    private var categories: [RecipesCategory] = RecipesCategory.allCases

    private var filteredRecipes: [Recipe] {
        var filtered = recipeCatalogStore.recipes

        switch selectedCategory {
        case .all:
            break
        case .favourite:
            filtered = filtered.filter { $0.favourite }
        default:
            filtered = filtered.filter { $0.category == selectedCategory }
        }

        if !debouncedSearchText.isEmpty {
            filtered = filtered.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(debouncedSearchText) ||
                recipe.description.localizedCaseInsensitiveContains(debouncedSearchText)
            }
        }

        return filtered
    }

    private var shouldShowSkeleton: Bool {
        recipeCatalogStore.isLoading && recipeCatalogStore.recipes.isEmpty
    }

    private var selectedFilterIcon: String {
        selectedCategory == .all
        ? "line.3.horizontal.decrease.circle"
        : "line.3.horizontal.decrease.circle.fill"
    }

    private var selectedFilterTint: Color {
        selectedCategory == .all ? .secondary : .blue
    }

    private var selectedCategoryTitle: String {
        selectedCategory == .all
        ? "Wszystkie przepisy"
        : RecipesConstants.displayName(for: selectedCategory)
    }

    private var recipesSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(searchText.isEmpty ? selectedCategoryTitle : "Wyniki wyszukiwania")
                    .font(.title3)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)

                Spacer(minLength: 0)
                recipesFilterActions
            }
        }
        .padding(16)
        .dashboardLiquidCard(cornerRadius: 24, strokeOpacity: 0.28)
    }

    private var recipesFilterActions: some View {
        Menu {
            ForEach(categories, id: \.self) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedCategory = category
                    }
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
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selectedFilterTint)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filtr kategorii: \(selectedCategoryTitle)")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardLiquidBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        recipesSummaryCard

                        if let errorMessage = recipeCatalogStore.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .dashboardLiquidCard(cornerRadius: 16, strokeOpacity: 0.2)
                        }

                        if shouldShowSkeleton {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 16) {
                                ForEach(0..<6, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 250)
                                        .redacted(reason: .placeholder)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.bottom, 12)
                        } else if filteredRecipes.isEmpty {
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
                                        Task { @MainActor in
                                            selectedRecipe = await recipeCatalogStore.loadRecipeDetail(recipeId: recipe.id) ?? recipe
                                        }
                                    } label: {
                                        RecipeItemView(recipe: recipe)
                                    }
                                    .buttonStyle(.plain)
                                    .task {
                                        await recipeCatalogStore.loadNextPageIfNeeded(currentItemId: recipe.id, threshold: 8)
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.bottom, 18)

                            if recipeCatalogStore.isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom, 16)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
                }
            }
            .navigationTitle("Przepisy")
            .task {
                debouncedSearchText = searchText
                await recipeCatalogStore.loadIfNeeded()
            }
            .onChange(of: searchText) { _, newValue in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard !Task.isCancelled else { return }
                    debouncedSearchText = newValue
                }
            }
            .onDisappear {
                searchDebounceTask?.cancel()
            }
            .searchable(text: $searchText, prompt: "Szukaj przepisów")
            .sheet(item: $selectedRecipe) { selected in
                NavigationStack {
                    RecipeDetailView(
                        recipe: selected,
                        onToggleFavorite: {
                            Task {
                                await recipeCatalogStore.toggleFavorite(recipeId: selected.id)
                                selectedRecipe = recipeCatalogStore.recipes.first(where: { $0.id == selected.id })
                            }
                        }
                    )
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
                .dashboardLiquidSheet()
            }
        }
    }
}

#Preview {
    RecipesView()
}
