import SwiftUI

private struct RecipeMealSection: Identifiable {
    let category: RecipesCategory
    let title: String
    let subtitle: String
    let recipes: [Recipe]

    var id: RecipesCategory { category }
    var accent: Color { RecipesConstants.tint(for: category) }
    var icon: String { RecipesConstants.icon(for: category) }
}

struct RecipesView: View {
    @Environment(\.recipeCatalogStore) private var recipeCatalogStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""
    @State private var selectedRecipe: Recipe?
    @State private var featuredSelection: Int = 0
    @State private var debouncedSearchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var categorySheetSelection: RecipesCategory?

    private var visibleRecipes: [Recipe] {
        var filtered = recipeCatalogStore.recipes

        if !debouncedSearchText.isEmpty {
            filtered = filtered.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(debouncedSearchText) ||
                recipe.description.localizedCaseInsensitiveContains(debouncedSearchText)
            }
        }

        return filtered
    }

    /// Skeleton pokazuje się dopóki store nie oznaczy pierwszej próby ładowania
    /// jako zakończonej (`didLoad`). Bazowanie tylko na `isLoading` powodowało
    /// mignięcie empty state'u przy pierwszym wejściu: przed `.task` mamy
    /// `isLoading=false` i `recipes.isEmpty`, więc poprzednie warunki
    /// fallbackowały do „Brak przepisów".
    private var shouldShowSkeleton: Bool {
        !recipeCatalogStore.didLoad && recipeCatalogStore.errorMessage == nil
    }

    private var mealSections: [RecipeMealSection] {
        let sections = [
            makeSection(
                for: .breakfast,
                title: "Śniadania",
                subtitle: "Na dobry start"
            ),
            makeSection(
                for: .lunch,
                title: "Obiady",
                subtitle: "Na środek dnia"
            ),
            makeSection(
                for: .dinner,
                title: "Kolacje",
                subtitle: "Na spokojny wieczór"
            )
        ]

        if debouncedSearchText.isEmpty {
            return sections
        }

        return sections.filter { !$0.recipes.isEmpty }
    }

    private var hasVisibleRecipes: Bool {
        mealSections.contains { !$0.recipes.isEmpty }
    }

    private var featuredRecipes: [Recipe] {
        Array(
            visibleRecipes
                .sorted(by: isFeaturedRecipePreferred(_:_:))
                .prefix(6)
        )
    }

    private var carouselCardWidth: CGFloat {
        horizontalSizeClass == .compact ? 200 : 244
    }

    private var featuredTitle: String {
        debouncedSearchText.isEmpty ? "Polecane" : "Najlepsze dopasowanie"
    }

    private var featuredEyebrow: String? {
        debouncedSearchText.isEmpty ? "SMAKI NA DZIŚ" : nil
    }

    private var featuredEyebrowColor: Color {
        colorScheme == .dark
            ? Color(red: 0.74, green: 0.94, blue: 0.50)
            : Color(red: 0.36, green: 0.62, blue: 0.14)
    }

    var body: some View {
        NavigationStack {
            rootContent
            .navigationTitle("Przepisy")
            .task {
                debouncedSearchText = searchText
                await recipeCatalogStore.loadIfNeeded()
            }
            .onChange(of: recipeCatalogStore.recipes.count) { _, _ in
                featuredSelection = 0
                ImagePrefetcher.prefetch(recipeCatalogStore.recipes.compactMap(\.imageURL))
            }
            .onChange(of: searchText) { _, newValue in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard !Task.isCancelled else { return }
                    debouncedSearchText = newValue
                    featuredSelection = 0
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
            .sheet(item: $categorySheetSelection) { category in
                RecipeCategorySheetView(
                    category: category,
                    recipes: recipeCatalogStore.recipes.filter { $0.category == category }
                )
                .presentationDetents([.large])
                .dashboardLiquidSheet()
            }
        }
    }

    private var rootContent: some View {
        ZStack {
            RecipesLiquidBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if let errorMessage = recipeCatalogStore.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .dashboardLiquidCard(cornerRadius: 16, strokeOpacity: 0.2)
                    }

                    contentBody
                }
                .padding(.horizontal, 14)
                .padding(.top, 20)
                .padding(.bottom, 18)
            }
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if shouldShowSkeleton {
            VStack(spacing: 26) {
                RecipeFeaturedSkeleton()

                ForEach(0..<3, id: \.self) { _ in
                    RecipeRailSkeletonSection(cardWidth: carouselCardWidth)
                }
            }
        } else if !hasVisibleRecipes {
            VStack(spacing: 12) {
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)

                Text("Brak przepisów")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(debouncedSearchText.isEmpty ? "Ta baza jest jeszcze pusta." : "Spróbuj wpisać inną frazę wyszukiwania.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
            .padding(.horizontal, 16)
            .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.2)
        } else {
            if !featuredRecipes.isEmpty {
                RecipesFeaturedSectionView(
                    title: featuredTitle,
                    eyebrow: featuredEyebrow,
                    eyebrowColor: featuredEyebrowColor,
                    recipes: featuredRecipes,
                    selection: $featuredSelection,
                    onSelect: openDetail(for:),
                    onPrefetch: { recipe in
                        await recipeCatalogStore.loadNextPageIfNeeded(currentItemId: recipe.id, threshold: 8)
                    }
                )
            }

            VStack(spacing: 28) {
                ForEach(mealSections) { section in
                    RecipeRailSectionView(
                        section: section,
                        cardWidth: carouselCardWidth,
                        onSelect: openDetail(for:),
                        onSeeMore: { category in
                            categorySheetSelection = category
                        },
                        onPrefetch: { recipe in
                            await recipeCatalogStore.loadNextPageIfNeeded(currentItemId: recipe.id, threshold: 8)
                        }
                    )
                }
            }

            if recipeCatalogStore.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, -8)
                    .padding(.bottom, 6)
            }
        }
    }

    private func makeSection(
        for category: RecipesCategory,
        title: String,
        subtitle: String
    ) -> RecipeMealSection {
        RecipeMealSection(
            category: category,
            title: title,
            subtitle: subtitle,
            recipes: visibleRecipes.filter { $0.category == category }
        )
    }

    private func openDetail(for recipe: Recipe) {
        Task { @MainActor in
            selectedRecipe = await recipeCatalogStore.loadRecipeDetail(recipeId: recipe.id) ?? recipe
        }
    }

    private func isFeaturedRecipePreferred(_ lhs: Recipe, _ rhs: Recipe) -> Bool {
        if lhs.favourite != rhs.favourite {
            return lhs.favourite && !rhs.favourite
        }

        if lhs.prepTimeMinutes != rhs.prepTimeMinutes {
            return lhs.prepTimeMinutes < rhs.prepTimeMinutes
        }

        if lhs.servings != rhs.servings {
            return lhs.servings > rhs.servings
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

private struct RecipesFeaturedSectionView: View {
    let title: String
    let eyebrow: String?
    let eyebrowColor: Color
    let recipes: [Recipe]
    @Binding var selection: Int
    let onSelect: (Recipe) -> Void
    let onPrefetch: (Recipe) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.caption2.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(eyebrowColor)
                }

                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)

            TabView(selection: $selection) {
                ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                    Button {
                        onSelect(recipe)
                    } label: {
                        RecipeFeaturedCard(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .tag(index)
                    .task {
                        await onPrefetch(recipe)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 372)

            if recipes.count > 1 {
                HStack(spacing: 6) {
                    ForEach(recipes.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == selection ? Color.primary.opacity(0.9) : Color.primary.opacity(0.18))
                            .frame(width: index == selection ? 22 : 6, height: 6)
                            .animation(.easeInOut(duration: 0.2), value: selection)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
            }
        }
    }
}

private struct RecipeFeaturedCard: View {
    let recipe: Recipe
    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat = 28

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            thumbnail

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            topRow

            bottomContent
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DashboardPalette.surface(colorScheme, level: .secondary))
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.14), lineWidth: 1)
        )
        .shadow(color: colorScheme == .dark ? .black.opacity(0.2) : .clear, radius: 14, x: 0, y: 10)
    }

    private var topRow: some View {
        VStack {
            HStack {
                Spacer()
                favoriteBadge
            }
            .padding(.top, 14)
            .padding(.horizontal, 14)

            Spacer(minLength: 0)
        }
    }

    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recipe.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 1)

            HStack(spacing: 8) {
                RecipeOverlayMetricBadge(icon: "clock", text: "\(recipe.prepTimeMinutes) min")

                RecipeOverlayMetricBadge(
                    icon: "flame.fill",
                    text: "\(Int(recipe.nutritionPerServing.kcal)) kcal"
                )

                RecipeOverlayMetricBadge(
                    icon: RecipesConstants.icon(for: recipe.category),
                    text: RecipesConstants.displayName(for: recipe.category)
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            LinearGradient(
                colors: [
                    RecipesConstants.tint(for: recipe.category).opacity(colorScheme == .dark ? 0.46 : 0.3),
                    RecipesConstants.tint(for: recipe.category).opacity(colorScheme == .dark ? 0.22 : 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: RecipesConstants.icon(for: recipe.category))
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private var favoriteBadge: some View {
        Image(systemName: recipe.favourite ? "heart.fill" : "heart")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(recipe.favourite ? Color.pink : Color.white.opacity(0.96))
            .frame(width: 38, height: 38)
            .background(Color.black.opacity(colorScheme == .dark ? 0.34 : 0.3), in: Circle())
    }

}

private struct RecipeRailSectionView: View {
    let section: RecipeMealSection
    let cardWidth: CGFloat
    let onSelect: (Recipe) -> Void
    let onSeeMore: (RecipesCategory) -> Void
    let onPrefetch: (Recipe) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.subtitle.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(section.accent)

                    Text(section.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 8)

                Button {
                    onSeeMore(section.category)
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(section.accent)
                        .frame(width: 34, height: 34)
                        .background(section.accent.opacity(0.16), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(section.accent.opacity(0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zobacz wszystkie – \(section.title)")
            }
            .padding(.horizontal, 2)

            if section.recipes.isEmpty {
                Text("Brak przepisów w tej sekcji.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.14)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(section.recipes) { recipe in
                            Button {
                                onSelect(recipe)
                            } label: {
                                RecipeCarouselCard(recipe: recipe, width: cardWidth)
                            }
                            .buttonStyle(.plain)
                            .task {
                                await onPrefetch(recipe)
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
}

private struct RecipeCategorySheetView: View {
    let category: RecipesCategory
    let recipes: [Recipe]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.recipeCatalogStore) private var recipeCatalogStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""
    @State private var selectedRecipe: Recipe?

    private var accent: Color {
        RecipesConstants.tint(for: category)
    }

    private var filteredRecipes: [Recipe] {
        let source = recipes.filter { recipe in
            guard !searchText.isEmpty else { return true }
            return recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.description.localizedCaseInsensitiveContains(searchText)
        }

        return source.sorted { lhs, rhs in
            if lhs.favourite != rhs.favourite {
                return lhs.favourite && !rhs.favourite
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var theme: DashboardSheetTheme {
        switch category {
        case .breakfast:
            return .sunrise
        case .lunch:
            return .spring
        case .dinner:
            return .plum
        case .all, .favourite:
            return .ocean
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    DashboardSheetBackground(theme: theme)
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            headerCard

                            if filteredRecipes.isEmpty {
                                emptyState
                            } else {
                                LazyVGrid(columns: sheetColumns(for: proxy.size.width), spacing: 12) {
                                    ForEach(filteredRecipes) { recipe in
                                        Button {
                                            openDetail(for: recipe)
                                        } label: {
                                            RecipeCarouselCard(
                                                recipe: recipe,
                                                width: sheetCardWidth(for: proxy.size.width)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 22)
                    }
                }
                .navigationTitle(RecipesConstants.displayName(for: category))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Zamknij") {
                            dismiss()
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Szukaj w tej kategorii")
                .sheet(item: $selectedRecipe) { selected in
                    NavigationStack {
                        RecipeDetailView(
                            recipe: selected,
                            onToggleFavorite: {
                                Task { @MainActor in
                                    await recipeCatalogStore.toggleFavorite(recipeId: selected.id)
                                    selectedRecipe = await recipeCatalogStore.loadRecipeDetail(recipeId: selected.id)
                                        ?? recipeCatalogStore.recipes.first(where: { $0.id == selected.id })
                                        ?? selected
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

    private func sheetCardWidth(for availableWidth: CGFloat) -> CGFloat {
        let columnCount = horizontalSizeClass == .compact ? 2 : 3
        let horizontalPadding: CGFloat = 28
        let spacing: CGFloat = 12
        let totalSpacing = CGFloat(columnCount - 1) * spacing
        let usableWidth = availableWidth - horizontalPadding - totalSpacing
        return max(150, floor(usableWidth / CGFloat(columnCount)))
    }

    private func sheetColumns(for availableWidth: CGFloat) -> [GridItem] {
        let count = horizontalSizeClass == .compact ? 2 : 3
        let width = sheetCardWidth(for: availableWidth)
        return Array(repeating: GridItem(.fixed(width), spacing: 12), count: count)
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(colorScheme == .dark ? 0.22 : 0.16))

                Image(systemName: RecipesConstants.icon(for: category))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("Wszystkie \(RecipesConstants.displayName(for: category).lowercased())")
                    .font(.headline.weight(.bold))

                Text("\(recipes.count) przepisów do szybkiego przeglądu i wyszukania.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.16)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Brak wyników")
                .font(.headline.weight(.semibold))

            Text("Spróbuj innej frazy wyszukiwania.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 16)
        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.16)
    }

    private func openDetail(for recipe: Recipe) {
        Task { @MainActor in
            selectedRecipe = await recipeCatalogStore.loadRecipeDetail(recipeId: recipe.id) ?? recipe
        }
    }
}

private struct RecipeRailSkeletonSection: View {
    let cardWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DashboardPalette.surface(colorScheme, level: .tertiary))
                .frame(width: 220, height: 48)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(DashboardPalette.surface(colorScheme, level: .tertiary))
                            .frame(width: cardWidth, height: cardWidth * 1.26)
                            .redacted(reason: .placeholder)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

private struct RecipeFeaturedSkeleton: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DashboardPalette.surface(colorScheme, level: .tertiary))
                    .frame(width: 170, height: 28)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DashboardPalette.surface(colorScheme, level: .tertiary))
                    .frame(maxWidth: .infinity)
                    .frame(height: 16)
            }

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(DashboardPalette.surface(colorScheme, level: .tertiary))
                .frame(height: 352)
                .redacted(reason: .placeholder)

            HStack(spacing: 8) {
                Spacer()
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index == 1 ? Color.green.opacity(0.7) : Color.primary.opacity(0.14))
                        .frame(width: index == 1 ? 20 : 6, height: 6)
                }
                Spacer()
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

#Preview {
    RecipesView()
}
