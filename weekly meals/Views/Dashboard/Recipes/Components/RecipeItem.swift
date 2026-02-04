import SwiftUI

struct RecipeItem: View {
    let recipe: Recipe
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(spacing: 12) {
                // Image
                ZStack {
                    if let imageURL = recipe.imageURL {
                        AsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            placeholderImage
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        placeholderImage
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Category badge
                    VStack {
                        Spacer()
                        HStack {
                            Text(recipe.category.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                            Spacer()
                        }
                        .padding(6)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(recipe.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        if recipe.favourite {
                            Image(systemName: "heart.fill")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    Text(recipe.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Label("\(recipe.prepTimeMinutes) min", systemImage: "clock")
                        Label("\(Int(recipe.nutritionPerServing.kcal)) kcal", systemImage: "flame")
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            RecipeDetailView(recipe: recipe)
        }
    }
    
    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.4),
                    Color.accentColor.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Image(systemName: "fork.knife")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

#Preview("Single Recipe") {
    RecipeItem(recipe: RecipesMock.omelette)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("List Layout") {
    NavigationStack {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(RecipesMock.all) { recipe in
                    RecipeItem(recipe: recipe)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Przepisy")
    }
}
