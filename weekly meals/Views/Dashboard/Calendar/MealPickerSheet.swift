import SwiftUI

struct MealPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let slot: MealSlot
    let recipes: [Recipe]
    let recipeCounts: [UUID: Int]
    let totalRecipeCounts: [UUID: Int]
    var onSelect: (Recipe) -> Void

    @State private var searchText: String = ""

    private var slotSubtitle: String {
        switch slot {
        case .breakfast: return "Lekki start dnia"
        case .lunch: return "Główny posiłek"
        case .dinner: return "Spokojny finał dnia"
        }
    }

    private var availableFilteredCount: Int {
        filteredRecipes.filter { (recipeCounts[$0.id] ?? 0) > 0 }.count
    }

    private var visibleAvailableRecipes: [Recipe] {
        filteredRecipes.filter { (recipeCounts[$0.id] ?? 0) > 0 }
    }

    private var visibleUnavailableRecipes: [Recipe] {
        filteredRecipes.filter { (recipeCounts[$0.id] ?? 0) == 0 }
    }

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

    private var uniqueRecipes: [Recipe] {
        var seen = Set<UUID>()
        return recipes.filter { seen.insert($0.id).inserted }
    }

    private var filteredRecipes: [Recipe] {
        var filtered = uniqueRecipes

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
            ZStack {
                DashboardSheetBackground(theme: slot.mealPickerSheetTheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        pickerHeader

                        if filteredRecipes.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "fork.knife.circle")
                                    .font(.system(size: 56))
                                    .foregroundStyle(.secondary)

                                Text("Brak pasujących przepisów")
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                Text("Wpisz inną frazę wyszukiwania.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if !searchText.isEmpty {
                                    Button("Wyczyść wyszukiwanie") {
                                        searchText = ""
                                    }
                                    .buttonStyle(.plain)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(slot.accentColor)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 44)
                            .padding(.horizontal, 16)
                            .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.2)
                        } else {
                            LazyVStack(spacing: 14) {
                                if !visibleAvailableRecipes.isEmpty {
                                    recipeSectionHeader(
                                        title: "Do wyboru",
                                        badgeText: "\(visibleAvailableRecipes.count) z \(filteredRecipes.count) dostępne"
                                    )

                                    ForEach(visibleAvailableRecipes) { recipe in
                                        recipeRow(recipe)
                                    }
                                }

                                if !visibleUnavailableRecipes.isEmpty {
                                    recipeSectionHeader(
                                        title: visibleAvailableRecipes.isEmpty ? "Brak wolnych pozycji" : "Niedostępne",
                                        badgeText: visibleAvailableRecipes.isEmpty
                                            ? "\(visibleAvailableRecipes.count) z \(filteredRecipes.count) dostępne"
                                            : nil
                                    )

                                    ForEach(visibleUnavailableRecipes) { recipe in
                                        recipeRow(recipe)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
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
        .searchable(text: $searchText, prompt: "Szukaj przepisów")
        .presentationDetents([.large])
    }

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
        .padding(18)
        .dashboardLiquidCard(cornerRadius: 24, strokeOpacity: 0.22)
    }

    private func recipeSectionHeader(title: String, badgeText: String? = nil) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Spacer(minLength: 0)

            if let badgeText {
                Text(badgeText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(slot.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(slot.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.18), in: Capsule())
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    private func recipeRow(_ recipe: Recipe) -> some View {
        let count = recipeCounts[recipe.id] ?? 0
        let total = max(totalRecipeCounts[recipe.id] ?? 1, 1)
        let isAvailable = count > 0

        return Button {
            onSelect(recipe)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                recipeThumbnail(recipe, isAvailable: isAvailable)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(recipe.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        if recipe.favourite {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(.pink)
                        }
                    }

                    Text(recipe.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        rowMetaPill(icon: "clock", text: "\(recipe.prepTimeMinutes) min")
                        rowMetaPill(icon: "flame.fill", text: "\(Int(recipe.nutritionPerServing.kcal)) kcal")
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    Text("\(count)/\(total)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(isAvailable ? Color.white : Color.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            isAvailable ? slot.accentColor : DashboardPalette.surface(colorScheme, level: .emphasized),
                            in: Capsule()
                        )

                    Image(systemName: isAvailable ? "chevron.right.circle.fill" : "xmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(isAvailable ? slot.accentColor : Color.secondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DashboardPalette.surface(colorScheme, level: .secondary))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isAvailable ? slot.accentColor.opacity(colorScheme == .dark ? 0.36 : 0.48) : DashboardPalette.neutralBorder(colorScheme, opacity: 0.12),
                        lineWidth: 1
                    )
            )
            .opacity(isAvailable ? 1 : 0.58)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }

    private func recipeThumbnail(_ recipe: Recipe, isAvailable: Bool) -> some View {
        Group {
            if let url = recipe.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        thumbnailPlaceholder
                    case .empty:
                        ZStack {
                            thumbnailPlaceholder
                            ProgressView()
                        }
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(slot.accentColor.opacity(isAvailable ? 0.4 : 0.2), lineWidth: 1)
        )
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(slot.accentColor.opacity(0.16))
            Image(systemName: "fork.knife")
                .font(.title3)
                .foregroundStyle(slot.accentColor)
        }
    }

    private func rowMetaPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(DashboardPalette.surface(colorScheme, level: .tertiary), in: Capsule())
    }
}

private extension MealSlot {
    var mealPickerSheetTheme: DashboardSheetTheme {
        switch self {
        case .breakfast:
            return .sunrise
        case .lunch:
            return .ocean
        case .dinner:
            return .plum
        }
    }
}

#Preview("Meal Picker") {
    MealPickerSheet(slot: .lunch, recipes: RecipesMock.all) { _ in }
}
