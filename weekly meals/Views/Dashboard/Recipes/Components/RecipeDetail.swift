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
        switch recipe.category {
        case .breakfast: return .orange
        case .lunch: return .blue
        case .dinner: return .purple
        case .favourite: return .pink
        case .all: return .teal
        }
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
                    // Image Header
                    ZStack {
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
                            .frame(height: 275)
                            .clipped()
                        } else {
                            placeholderHeader
                                .frame(height: 275)
                        }
                        
                        // Gradient overlay for better text readability
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
                    .ignoresSafeArea(edges: .top)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            onToggleFavorite?()
                        } label: {
                            Image(systemName: recipe.favourite ? "heart.fill" : "heart")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(recipe.favourite ? .pink : Color.white.opacity(0.94))
                                .frame(width: 38, height: 38)
                                .background(
                                    DashboardPalette.surface(colorScheme, level: .secondary),
                                    in: Circle()
                                )
                                .overlay(
                                    Circle()
                                        .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(16)
                    }
                    .overlay(alignment: .topLeading) {
                        RecipeCategoryBadge(
                            text: RecipesConstants.displayName(for: recipe.category),
                            tint: categoryTint,
                            style: .overlayDark
                        )
                        .padding(16)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recipe.name)
                                .font(.title)
                                .fontWeight(.bold)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // Description
                        Text(recipe.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        // Quick Info
                        HStack(spacing: 10) {
                            RecipeInfoBadge(icon: "clock", text: "\(recipe.prepTimeMinutes) min")
                            RecipeInfoBadge(icon: "person.2", text: "\(recipe.servings) porcje")
                            RecipeInfoBadge(icon: difficultyIcon, text: recipe.difficulty.rawValue, color: difficultyColor)
                        }
                        
                        Divider()
                        
                        // Nutrition Info
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
                            .padding(1) // Spacer for border visibility
                        }
                        
                        Divider()
                        
                        // Preparation Steps
                        if !recipe.preparationSteps.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sposób przygotowania")
                                    .font(.headline)
                                
                                VStack(spacing: 0) {
                                    ForEach(recipe.preparationSteps.sorted(by: { $0.stepNumber < $1.stepNumber })) { step in
                                        HStack(alignment: .top, spacing: 16) {
                                            // Step number badge - soft style
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                    .fill(Color.accentColor.opacity(0.15))
                                                    .frame(width: 32, height: 32)
                                                
                                                Text("\(step.stepNumber)")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(Color.accentColor)
                                            }
                                            
                                            // Instruction text
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
                            
                            Divider()
                        }
                        
                        // Ingredients
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Składniki")
                                .font(.headline)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { index, ingredient in
                                    HStack(alignment: .center, spacing: 12) {
                                        // Ingredient name
                                        Text(ingredientDisplayName(ingredient.name))
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        
                                        Spacer(minLength: 8)
                                        
                                        // Amount
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
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}


#Preview("Recipe Detail") {
    RecipeDetailView(recipe: RecipesMock.chickenBowl)
}
