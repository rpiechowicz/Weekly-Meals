import SwiftUI

struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    var onToggleFavorite: (() -> Void)?
    
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
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Image Header
                    ZStack(alignment: .bottomLeading) {
                        if let imageURL = recipe.imageURL {
                            AsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                placeholderHeader
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
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Title & Category
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(recipe.name)
                                    .font(.title)
                                    .fontWeight(.bold)

                                Spacer()

                                Button {
                                    onToggleFavorite?()
                                } label: {
                                    Image(systemName: recipe.favourite ? "heart.fill" : "heart")
                                        .font(.title3)
                                        .foregroundStyle(recipe.favourite ? .red : .gray)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Text(recipe.category.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
                                NutritionCard(title: "Kalorie", value: "\(Int(recipe.nutritionPerServing.kcal))", unit: "kcal", icon: "flame.fill", color: .orange)
                                NutritionCard(title: "Białko", value: "\(Int(recipe.nutritionPerServing.protein))", unit: "g", icon: "bolt.fill", color: .blue)
                                NutritionCard(title: "Węglowodany", value: "\(Int(recipe.nutritionPerServing.carbs))", unit: "g", icon: "leaf.fill", color: .green)
                                NutritionCard(title: "Tłuszcze", value: "\(Int(recipe.nutritionPerServing.fat))", unit: "g", icon: "drop.fill", color: .purple)
                                NutritionCard(title: "Błonnik", value: "\(Int(recipe.nutritionPerServing.fiber))", unit: "g", icon: "heart.fill", color: .pink)
                                NutritionCard(title: "Sól", value: String(format: "%.1f", recipe.nutritionPerServing.salt), unit: "g", icon: "sparkles", color: .cyan)
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
                                        Text(ingredient.name)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        
                                        Spacer(minLength: 8)
                                        
                                        // Amount
                                        Text("\(ingredient.amount.formatted()) \(ingredient.unit.rawValue)")
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
            
            // Close button overlay
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
            .padding()
        }
    }
}


#Preview("Recipe Detail") {
    RecipeDetailView(recipe: RecipesMock.chickenBowl)
}
