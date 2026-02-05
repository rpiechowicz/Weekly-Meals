import SwiftUI

enum MealSlot: String, CaseIterable, Identifiable {
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholderThumb: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(slot.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.12))
            Image(systemName: "fork.knife.circle.fill")
                .font(.title3)
                .foregroundStyle(slot.accentColor)
        }
    }

    private func difficultyIcon(for diff: Difficulty) -> String {
        switch diff {
        case .easy: return "star"
        case .medium: return "star.leadinghalf.filled"
        case .hard: return "star.fill"
        }
    }

    private func difficultyColor(for diff: Difficulty) -> Color {
        switch diff {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(slot.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
                    Image(systemName: slot.icon)
                        .font(.subheadline)
                        .foregroundStyle(slot.accentColor)
                }
                .frame(width: 32, height: 32)

                Text(slot.title)
                    .font(.headline)
                    .foregroundStyle(isEmpty ? .secondary : .primary)

                Spacer(minLength: 0)

                Text(slot.time)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(slot.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(slot.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.12))
                    )
            }

            if let recipe {
                // Content with selected recipe
                HStack(alignment: .center, spacing: 12) {
                    thumbnail

                    VStack(alignment: .leading, spacing: 6) {
                        Text(recipe.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        
                        HStack(spacing: 10) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text("\(recipe.prepTimeMinutes) min")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                                                        
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                Text("\(Int(recipe.nutritionPerServing.kcal)) kcal")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
            } else {
                // Empty state inside card
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(Color.gray.opacity(colorScheme == .dark ? 0.35 : 0.22))
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(slot.accentColor)
                        Text("Dodaj posiłek")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 48)
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .myBackground()
        .myBorderOverlay()
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
