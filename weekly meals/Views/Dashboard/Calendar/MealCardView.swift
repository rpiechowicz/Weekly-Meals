import SwiftUI

enum MealSlot: String, CaseIterable, Identifiable, Codable {
    case breakfast
    case lunch
    case dinner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: return "Śniadanie"
        case .lunch: return "Obiad"
        case .dinner: return "Kolacja"
        }
    }

    var time: String {
        switch self {
        case .breakfast: return "08:00"
        case .lunch: return "16:00"
        case .dinner: return "20:00"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "fork.knife"
        case .dinner: return "moon.stars.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch: return .blue
        case .dinner: return .purple
        }
    }

    var secondaryAccentColor: Color {
        switch self {
        case .breakfast: return .yellow
        case .lunch: return .cyan
        case .dinner: return .indigo
        }
    }
}

struct MealCardView: View {
    private static let contentAreaMinHeight: CGFloat = 76

    let slot: MealSlot
    let recipe: Recipe? // nil => brak wybranego posiłku
    var isEditable: Bool = true
    @Environment(\.colorScheme) private var colorScheme

    private var isEmpty: Bool { recipe == nil }
    private var hasRecipe: Bool { recipe != nil }

    private var statusTitle: String {
        if hasRecipe {
            return "Zaplanowany"
        }
        if isEditable {
            return "Do uzupełnienia"
        }
        return "Zamknięty"
    }

    private var statusSubtitle: String {
        if hasRecipe {
            return "Tapnij, aby zobaczyć szczegóły"
        }
        if isEditable {
            return "Tapnij, aby dodać posiłek"
        }
        return "Ten dzień jest tylko do podglądu"
    }

    private var thumbnail: some View {
        Group {
            if let url = recipe?.imageURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholderThumb
                }
            } else {
                placeholderThumb
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var placeholderThumb: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(slot.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.15))
            Image(systemName: "fork.knife")
                .font(.title3)
                .foregroundStyle(slot.accentColor)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: slot.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(slot.accentColor)
                    .frame(width: 36, height: 36)
                    .background(slot.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(slot.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(statusSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(slot.time)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(slot.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(slot.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.12), in: Capsule())
                }
            }

            if let recipe {
                HStack(spacing: 12) {
                    thumbnail

                    VStack(alignment: .leading, spacing: 6) {
                        Text(recipe.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            recipeMetaPill(icon: "clock", text: "\(recipe.prepTimeMinutes) min")
                            recipeMetaPill(icon: "flame.fill", text: "\(Int(recipe.nutritionPerServing.kcal)) kcal")
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: Self.contentAreaMinHeight, alignment: .leading)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(surfaceFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(slot.accentColor.opacity(0.24), lineWidth: 1)
                )
            } else if isEditable {
                emptyCallToAction
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text("Dzień nieedytowalny")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: Self.contentAreaMinHeight, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(surfaceFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(borderStroke, lineWidth: 1)
                )
            }

        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardLiquidCard(cornerRadius: 24, strokeOpacity: 0.2)
    }

    private var emptyCallToAction: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(slot.accentColor)
                .frame(width: 30, height: 30)
                .background(slot.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Dodaj posiłek")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text("Wybierz przepis z planu tygodniowego")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(slot.accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(slot.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    slot.accentColor.opacity(0.24),
                    lineWidth: 1
                )
        )
        .frame(maxWidth: .infinity, minHeight: Self.contentAreaMinHeight, alignment: .leading)
    }

    private func recipeMetaPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(surfaceFill)
        )
    }

    private var surfaceFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.22)
    }

    private var borderStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color.white.opacity(0.28)
    }

}

#Preview("Meal Cards") {
    ScrollView {
        VStack(spacing: 16) {
            MealCardView(slot: .breakfast, recipe: RecipesMock.omelette)
            MealCardView(slot: .lunch, recipe: RecipesMock.chickenBowl)
            MealCardView(slot: .dinner, recipe: nil)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
