import SwiftUI

struct RecipeDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    let recipe: Recipe
    var onToggleFavorite: (() -> Void)?

    private var sheetTheme: DashboardSheetTheme {
        switch recipe.category {
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
    
    private var placeholderHeader: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.4),
                Color.accentColor.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var difficultyIcon: String {
        switch recipe.difficulty {
        case .easy: return "star"
        case .medium: return "star.leadinghalf.filled"
        case .hard: return "star.fill"
        }
    }
    
    private var difficultyColor: Color {
        switch recipe.difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    private var categoryTint: Color {
        RecipesConstants.tint(for: recipe.category)
    }

    private func ingredientDisplayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return trimmed }
        return String(first).uppercased(with: Locale(identifier: "pl_PL")) + trimmed.dropFirst()
    }

    private func formatNutritionValue(_ value: Double, maximumFractionDigits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formatIngredientAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    var body: some View {
        ZStack {
            DashboardSheetBackground(theme: sheetTheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection

                    VStack(alignment: .leading, spacing: 24) {
                        nutritionSection

                        if !recipe.preparationSteps.isEmpty {
                            preparationSection
                        }

                        ingredientsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: -34) {
            heroImage

            summaryCard
                .padding(.horizontal, 16)
                .zIndex(1)
        }
    }

    private var heroImage: some View {
        Group {
            if let imageURL = recipe.imageURL {
                CachedAsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .empty, .failure:
                        placeholderHeader
                    @unknown default:
                        placeholderHeader
                    }
                }
            } else {
                placeholderHeader
            }
        }
        .frame(height: 286)
        .clipped()
        .overlay(
            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(colorScheme == .dark ? 0.24 : 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea(edges: .top)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                RecipeCategoryBadge(category: recipe.category)

                Spacer(minLength: 8)

                favoriteControl
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(recipe.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .fixedSize(horizontal: false, vertical: true)

                Text(recipe.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    RecipeInfoBadge(icon: "clock", text: "\(recipe.prepTimeMinutes) min")
                    RecipeInfoBadge(icon: "person.2", text: "\(recipe.servings) porcje")
                    RecipeInfoBadge(icon: difficultyIcon, text: recipe.difficulty.rawValue, color: difficultyColor)
                }
                .padding(.vertical, 1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardLiquidCard(cornerRadius: 28, strokeOpacity: 0.18)
    }

    @ViewBuilder
    private var favoriteControl: some View {
        if let onToggleFavorite {
            RecipeFavoriteButton(isFavorite: recipe.favourite, action: onToggleFavorite)
        } else if recipe.favourite {
            RecipeFavoriteButton(isFavorite: true)
        }
    }

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wartości odżywcze")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                NutritionCard(title: "Kalorie", value: formatNutritionValue(recipe.nutritionPerServing.kcal, maximumFractionDigits: 0), unit: "kcal", icon: "flame.fill", color: .orange)
                NutritionCard(title: "Białko", value: formatNutritionValue(recipe.nutritionPerServing.protein), unit: "g", icon: "bolt.fill", color: .blue)
                NutritionCard(title: "Węglowodany", value: formatNutritionValue(recipe.nutritionPerServing.carbs), unit: "g", icon: "leaf.fill", color: .green)
                NutritionCard(title: "Tłuszcze", value: formatNutritionValue(recipe.nutritionPerServing.fat), unit: "g", icon: "drop.fill", color: .pink)
                NutritionCard(title: "Błonnik", value: formatNutritionValue(recipe.nutritionPerServing.fiber), unit: "g", icon: "heart.fill", color: .pink)
                NutritionCard(title: "Sól", value: formatNutritionValue(recipe.nutritionPerServing.salt), unit: "g", icon: "sparkles", color: .cyan)
            }
            .padding(1)
        }
    }

    private var preparationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sposób przygotowania")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(recipe.preparationSteps.sorted(by: { $0.stepNumber < $1.stepNumber })) { step in
                    HStack(alignment: .top, spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(categoryTint.opacity(colorScheme == .dark ? 0.22 : 0.15))
                                .frame(width: 32, height: 32)

                            Text("\(step.stepNumber)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(categoryTint)
                        }

                        Text(step.instruction)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 14)

                    if step.stepNumber < recipe.preparationSteps.count {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .myBackground()
            .myBorderOverlay()
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Składniki")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    HStack(alignment: .center, spacing: 12) {
                        Text(ingredientDisplayName(ingredient.name))
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer(minLength: 8)

                        Text("\(formatIngredientAmount(ingredient.amount)) \(ingredient.unit.rawValue)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 14)

                    if index < recipe.ingredients.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .myBackground()
            .myBorderOverlay()
        }
    }
}


#Preview("Recipe Detail") {
    RecipeDetailView(recipe: RecipesMock.chickenBowl)
}
