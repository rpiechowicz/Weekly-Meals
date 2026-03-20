import SwiftUI

struct RecipesView: View {
    @Environment(\.recipeCatalogStore) private var recipeCatalogStore
    @Environment(\.colorScheme) private var colorScheme

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

    private var recipesHelperText: String {
        if !searchText.isEmpty {
            return "Przeglądaj wyniki, zmień filtr po prawej i stuknij przepis, aby zobaczyć szczegóły."
        }

        return "Przeglądaj bazę przepisów, filtruj kategorie i otwieraj dania, aby podejrzeć składniki oraz opis."
    }

    private var recipesSummaryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                Text(searchText.isEmpty ? "Wszystkie przepisy" : "Wyniki wyszukiwania")
                    .font(.title3)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                RecipeFilters(categories: categories, selectedCategory: $selectedCategory)
            }

            Text(recipesHelperText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.22)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RecipesLiquidBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 8) {
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
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 12)], spacing: 12) {
                                ForEach(0..<6, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(DashboardPalette.surface(colorScheme, level: .tertiary))
                                        .frame(height: 232)
                                        .redacted(reason: .placeholder)
                                }
                            }
                            .padding(.top, 6)
                            .padding(.horizontal, 2)
                            .padding(.bottom, 12)
                        } else if filteredRecipes.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "fork.knife.circle")
                                    .font(.system(size: 56))
                                    .foregroundStyle(.secondary)

                                Text("Brak przepisów")
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                Text("Spróbuj wybrać inną kategorię")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 6)
                            .padding(.vertical, 44)
                            .padding(.horizontal, 16)
                            .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.2)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 12)], spacing: 12) {
                                ForEach(filteredRecipes) { recipe in
                                    Button {
                                        Task { @MainActor in
                                            selectedRecipe = await recipeCatalogStore.loadRecipeDetail(recipeId: recipe.id) ?? recipe
                                        }
                                    } label: {
                                        RecipeGridCard(recipe: recipe)
                                    }
                                    .buttonStyle(.plain)
                                    .task {
                                        await recipeCatalogStore.loadNextPageIfNeeded(currentItemId: recipe.id, threshold: 8)
                                    }
                                }
                            }
                            .padding(.top, 6)
                            .padding(.horizontal, 2)
                            .padding(.bottom, 18)

                            if recipeCatalogStore.isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom, 16)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
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

private struct RecipesLiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DashboardPalette.backgroundTop(for: colorScheme),
                    DashboardPalette.backgroundBottom(for: colorScheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.11))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: -130, y: -210)

            Circle()
                .fill(Color.cyan.opacity(colorScheme == .dark ? 0.14 : 0.09))
                .frame(width: 210, height: 210)
                .blur(radius: 80)
                .offset(x: 120, y: -260)

            Circle()
                .fill(Color.purple.opacity(colorScheme == .dark ? 0.16 : 0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: 140, y: 260)
        }
    }
}

private struct RecipeGridCard: View {
    let recipe: Recipe
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            thumbnail
                .frame(height: 126)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topLeading) {
                    categoryBadge
                        .padding(.leading, 12)
                        .padding(.top, 12)
                }
                .overlay(alignment: .topTrailing) {
                    if recipe.favourite {
                        Image(systemName: "heart.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.pink)
                            .frame(width: 26, height: 26)
                            .background(DashboardPalette.surface(colorScheme, level: .secondary), in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.12), lineWidth: 1)
                            )
                            .padding(.trailing, 10)
                            .padding(.top, 10)
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(recipe.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                metaPill(icon: "clock", text: "\(recipe.prepTimeMinutes) min")
                metaPill(icon: "flame.fill", text: "\(Int(recipe.nutritionPerServing.kcal)) kcal")
            }
        }
        .padding(11)
        .frame(height: 232)
        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.18)
    }

    private var thumbnail: some View {
        Group {
            if let imageURL = recipe.imageURL {
                CachedAsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderThumb
                    case .empty:
                        ZStack {
                            placeholderThumb
                            ProgressView()
                        }
                    @unknown default:
                        placeholderThumb
                    }
                }
            } else {
                placeholderThumb
            }
        }
    }

    private var placeholderThumb: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(categoryTint.opacity(colorScheme == .dark ? 0.22 : 0.18))

            Image(systemName: "fork.knife")
                .font(.title3)
                .foregroundStyle(categoryTint)
        }
    }

    private var categoryBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(categoryTint)
                .frame(width: 6, height: 6)

            Text(RecipesConstants.displayName(for: recipe.category))
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Color.white.opacity(0.96))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.58 : 0.5))
        )
        .overlay(
            Capsule()
                .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.16), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 2)
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(DashboardPalette.surface(colorScheme, level: .tertiary), in: Capsule())
    }

    private var categoryTint: Color {
        switch recipe.category {
        case .breakfast: return .orange
        case .lunch: return .blue
        case .dinner: return .purple
        case .favourite: return .pink
        case .all: return .teal
        }
    }
}

#Preview {
    RecipesView()
}
