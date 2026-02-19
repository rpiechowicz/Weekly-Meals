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
}

struct MealCardView: View {
    let slot: MealSlot
    let recipe: Recipe? // nil => brak wybranego posiłku
    var isEditable: Bool = true
    @Environment(\.colorScheme) var colorScheme

    private var isEmpty: Bool { recipe == nil }

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
                .fill(slot.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.12))
            Image(systemName: "fork.knife.circle.fill")
                .font(.title3)
                .foregroundStyle(slot.accentColor)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(slot.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.14))
                    Image(systemName: slot.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(slot.accentColor)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(slot.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(isEmpty ? "Brak przypisanego posiłku" : "Zaplanowany posiłek")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(slot.time)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(slot.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(slot.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.12), in: Capsule())
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
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.16))
                )
            } else if isEditable {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(slot.accentColor)
                    Text("Dodaj posiłek")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(slot.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(slot.accentColor.opacity(0.22), lineWidth: 1)
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text("Dzień nieedytowalny")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.07 : 0.12))
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardLiquidCard(cornerRadius: 24, strokeOpacity: 0.2)
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
                .fill(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.2))
        )
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
