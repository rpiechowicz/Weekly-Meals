import SwiftUI

struct RecipeItemView: View {
    let recipe: Recipe
    var isInPlanningMode: Bool = false
    var isSelected: Bool = false
    var badgeCount: Int = 0
    var availabilityBadgeText: String? = nil
    var availabilityBadgeColor: Color = .green
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if let imageURL = recipe.imageURL {
                    Color(.secondarySystemFill)
                        .frame(height: 140)
                        .overlay(
                            CachedAsyncImage(url: imageURL) { phase in
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

                HStack {
                    Spacer()
                    if isSelected {
                        Label("Wybrane", systemImage: "checkmark.circle.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(8)
                    } else if recipe.favourite {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .padding(8)
                    }
                }

                if let availabilityBadgeText {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(availabilityBadgeText)
                                .font(.caption)
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(availabilityBadgeColor, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
                                )
                                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                                .padding(8)
                        }
                    }
                } else if badgeCount > 1 {
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

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(recipe.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    categoryPill
                }

                Text(recipe.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    infoPill(icon: "clock", text: "\(recipe.prepTimeMinutes) min")
                    infoPill(icon: "flame.fill", text: "\(Int(recipe.nutritionPerServing.kcal)) kcal")
                }
            }

            Spacer(minLength: 0)

            if isInPlanningMode {
                planningFooter
            }
        }
        .padding(12)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected
                        ? Color.green.opacity(colorScheme == .dark ? 0.8 : 0.65)
                        : DashboardPalette.neutralBorder(colorScheme, opacity: 0.12),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .frame(height: 286)
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

    private var categoryPill: some View {
        Text(recipe.category.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DashboardPalette.surface(colorScheme, level: .tertiary), in: Capsule())
    }

    private func infoPill(icon: String, text: String) -> some View {
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

    private var planningFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .green : .secondary)

            Text(isSelected ? "Kliknij, aby usunąć z planu" : "Kliknij, aby dodać do planu")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private var cardFill: Color {
        if isSelected {
            return DashboardPalette.tintFill(.green, scheme: colorScheme, dark: 0.12, light: 0.13)
        }

        return DashboardPalette.surface(colorScheme, level: .secondary)
    }
}


#Preview {
    RecipeItemView(recipe: RecipesMock.omelette)
}
