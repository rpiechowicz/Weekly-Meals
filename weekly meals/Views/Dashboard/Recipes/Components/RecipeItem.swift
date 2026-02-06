import SwiftUI

struct RecipeItemView: View {
    let recipe: Recipe
    var isInPlanningMode: Bool = false
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemFill))
                    .frame(height: 140)
                    .overlay(
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                    )
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                                .background(Circle().fill(.ultraThickMaterial).padding(2))
                                .padding(8)
                        } else if recipe.favourite {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                                .padding(8)
                        }
                    }

                Text(recipe.category.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .padding(8)
            }

            Text(recipe.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(recipe.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(12)
        .myBackground()
        .myBorderOverlay(
            color: isSelected ? .green : Color(.separator),
            lineWidth: isSelected ? 2.5 : 0.5
        )
        .frame(height: 220)
    }
}


#Preview {
    RecipeItemView(recipe: Recipe(name: "Omlet z warzywami", description: "Puszysty omlet z papryką, szpinakiem i serem feta.", category: .breakfast))
}
