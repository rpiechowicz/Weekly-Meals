import SwiftUI

struct RecipeItemView: View {
    let recipe: Recipe
    var isInPlanningMode: Bool = false
    var isSelected: Bool = false
    var badgeCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image section
            ZStack(alignment: .topLeading) {
                if let imageURL = recipe.imageURL {
                    Color(.secondarySystemFill)
                        .frame(height: 140)
                        .overlay(
                            AsyncImage(url: imageURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure:
                                    Image(systemName: "fork.knife.circle")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary)
                                case .empty:
                                    ProgressView()
                                @unknown default:
                                    Image(systemName: "fork.knife.circle")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    recipePlaceholder
                }

                // Top-trailing badge
                HStack {
                    Spacer()
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

                // Category badge
                Text(recipe.category.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .padding(8)

                // Count badge (bottom-right of image)
                if badgeCount > 1 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(badgeCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(.blue, in: Circle())
                                .padding(8)
                        }
                    }
                }
            }
            .frame(height: 140)

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
        .frame(height: 260)
    }

    private var recipePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.secondarySystemFill))
            .frame(height: 140)
            .overlay(
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            )
    }
}


#Preview {
    RecipeItemView(recipe: RecipesMock.omelette)
}
