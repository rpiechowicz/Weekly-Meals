import SwiftUI

struct MealPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let slot: MealSlot
    let recipes: [Recipe]
    let recipeCounts: [UUID: Int]
    let totalRecipeCounts: [UUID: Int]
    var onSelect: (Recipe) -> Void

    @State private var searchText: String = ""

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
    }

    private var slotSubtitle: String {
        switch slot {
        case .breakfast: return "Lekki start dnia"
        case .lunch: return "Główny posiłek"
        case .dinner: return "Spokojny finał dnia"
        }
    }

    private var uniqueRecipes: [Recipe] {
        var seen = Set<UUID>()
        return recipes.filter { seen.insert($0.id).inserted }
    }

    private var filteredRecipes: [Recipe] {
        guard !searchText.isEmpty else { return uniqueRecipes }
        return uniqueRecipes.filter { recipe in
            recipe.name.localizedCaseInsensitiveContains(searchText) ||
            recipe.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var availableRecipes: [Recipe] {
        filteredRecipes.filter { (recipeCounts[$0.id] ?? 0) > 0 }
    }

    private var unavailableRecipes: [Recipe] {
        filteredRecipes.filter { (recipeCounts[$0.id] ?? 0) == 0 }
    }

    private func columns(for availableWidth: CGFloat) -> [GridItem] {
        let count = horizontalSizeClass == .compact ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: count)
    }

    private func cardWidth(for availableWidth: CGFloat) -> CGFloat {
        let count: CGFloat = horizontalSizeClass == .compact ? 2 : 3
        let horizontalPadding: CGFloat = 28
        let spacing: CGFloat = 12 * (count - 1)
        return max(150, floor((availableWidth - horizontalPadding - spacing) / count))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    DashboardSheetBackground(theme: slot.mealPickerSheetTheme)
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            pickerHeader

                            if filteredRecipes.isEmpty {
                                emptyState
                            } else {
                                if !availableRecipes.isEmpty {
                                    sectionHeader(
                                        title: "Do wyboru",
                                        badge: "\(availableRecipes.count) z \(filteredRecipes.count)"
                                    )

                                    LazyVGrid(columns: columns(for: proxy.size.width), spacing: 12) {
                                        ForEach(availableRecipes) { recipe in
                                            availableCard(recipe, width: cardWidth(for: proxy.size.width))
                                        }
                                    }
                                }

                                if !unavailableRecipes.isEmpty {
                                    sectionHeader(
                                        title: availableRecipes.isEmpty ? "Brak wolnych pozycji" : "Niedostępne",
                                        badge: nil
                                    )
                                    .padding(.top, availableRecipes.isEmpty ? 0 : 6)

                                    VStack(spacing: 10) {
                                        ForEach(unavailableRecipes) { recipe in
                                            unavailableRow(recipe)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 22)
                    }
                }
                .navigationTitle("Wybierz posiłek")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Anuluj") { dismiss() }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Szukaj przepisów")
        .presentationDetents([.large])
        .task {
            ImagePrefetcher.prefetch(uniqueRecipes.compactMap(\.imageURL))
        }
    }

    // MARK: - Header

    private var pickerHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                slot.accentColor.opacity(0.38),
                                slot.secondaryAccentColor.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: slot.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(slot.accentColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(slot.title)
                    .font(.headline)
                    .fontWeight(.bold)
                Text("\(slot.time) • \(slotSubtitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)
        }
        .padding(16)
        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.2)
    }

    private func sectionHeader(title: String, badge: String?) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            if let badge {
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(slot.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(slot.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.16), in: Capsule())
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Cards

    private func availableCard(_ recipe: Recipe, width: CGFloat) -> some View {
        let count = recipeCounts[recipe.id] ?? 0
        let total = max(totalRecipeCounts[recipe.id] ?? 1, 1)

        return Button {
            onSelect(recipe)
            dismiss()
        } label: {
            ZStack(alignment: .topLeading) {
                RecipeCarouselCard(
                    recipe: recipe,
                    width: width,
                    selectionCount: 0,
                    showsHeart: true
                )

                HStack(spacing: 4) {
                    Text("\(count)/\(total)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    slot.accentColor.opacity(colorScheme == .dark ? 0.95 : 0.88),
                                    slot.secondaryAccentColor.opacity(colorScheme == .dark ? 0.82 : 0.74)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 2)
                .padding(.top, 10)
                .padding(.leading, 10)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func unavailableRow(_ recipe: Recipe) -> some View {
        HStack(alignment: .center, spacing: 12) {
            thumbnail(recipe)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("Wykorzystany w innych dniach")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "xmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DashboardPalette.surface(colorScheme, level: .secondary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.12), lineWidth: 1)
        )
        .opacity(0.62)
    }

    private func thumbnail(_ recipe: Recipe) -> some View {
        Group {
            if let url = recipe.imageURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty, .failure:
                        thumbnailPlaceholder
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(slot.accentColor.opacity(0.16))
            Image(systemName: "fork.knife")
                .font(.title3)
                .foregroundStyle(slot.accentColor)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Brak pasujących przepisów")
                .font(.headline.weight(.semibold))

            Text(searchText.isEmpty ? "Dodaj przepisy w Planie tygodnia." : "Spróbuj innej frazy wyszukiwania.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !searchText.isEmpty {
                Button("Wyczyść wyszukiwanie") {
                    searchText = ""
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(slot.accentColor)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 16)
        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.2)
    }
}

private extension MealSlot {
    var mealPickerSheetTheme: DashboardSheetTheme {
        switch self {
        case .breakfast: return .sunrise
        case .lunch: return .ocean
        case .dinner: return .plum
        }
    }
}

#Preview("Meal Picker") {
    MealPickerSheet(slot: .lunch, recipes: RecipesMock.all) { _ in }
}
