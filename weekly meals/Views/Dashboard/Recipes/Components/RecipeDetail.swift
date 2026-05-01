import SwiftUI

// Recipe detail v2 — "Stat Cards Grid" editorial layout.
// Mirrors v2-design/Weekly Meals - Szczegoly Posilku.html (variant F):
// • 320pt hero photo with top fade scrim + bottom fade-into-canvas
// • Glass heart button (top-leading) and xmark close (top-trailing) overlaid on photo
// • Eyebrow row: category pill left, hairline divider, clock + time right
// • Display title + description in label/muted colors
// • Asymmetric macro grid (1.4fr kcal tile + 3 stacked smaller tiles)
// • Sage-tinted preparation steps and indigo-tinted ingredient list
struct RecipeDetailView: View {
    @Environment(\.colorScheme) private var scheme

    let recipe: Recipe
    var onToggleFavorite: (() -> Void)?
    var onClose: (() -> Void)?

    var body: some View {
        ZStack {
            WMPageBackground(scheme: scheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroPhoto

                    eyebrowRow
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    titleBlock
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    nutritionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                    if !recipe.preparationSteps.isEmpty {
                        preparationSection
                            .padding(.horizontal, 16)
                            .padding(.top, 28)
                    }

                    if !recipe.ingredients.isEmpty {
                        ingredientsSection
                            .padding(.horizontal, 16)
                            .padding(.top, 28)
                    }

                    Color.clear.frame(height: 28)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Hero photo

    private var heroPhoto: some View {
        // Sharp photo + canvas-color bottom gradient, like the design's
        // `fadeBottom`. The photo darkens into the same color the canvas
        // renders below it, so the bottom edge is invisible — no alpha
        // trickery, no blur, just a long, smooth color fade that matches
        // exactly what `WMPageBackground` would paint at this Y position.
        //
        // The outer `.clipped()` is load-bearing: `image.scaledToFill()`
        // makes the photo overflow the 320pt frame vertically, and without
        // a clip at the hero's edge that overflow renders behind the
        // *next* row in the VStack — the translucent eyebrow pill then
        // shows photo content through it. Clipping locks the hero to the
        // declared 320pt so the canvas-fade overlay anchors correctly and
        // the eyebrow lands on real canvas.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .background(
                photoLayer
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            )
            .overlay(topScrim, alignment: .top)
            .overlay(canvasFadeGradient, alignment: .bottom)
            .overlay(alignment: .topLeading) {
                heartButton
                    .padding(.top, 14)
                    .padding(.leading, 16)
            }
            .overlay(alignment: .topTrailing) {
                closeButton
                    .padding(.top, 14)
                    .padding(.trailing, 16)
            }
            .clipped()
    }

    private var canvasFadeGradient: some View {
        // End color is the *actual* page-bg color at Y≈320, including the
        // contribution of `WMPageBackground`'s terracotta radial glow at
        // that distance from the top. Computed once analytically: the glow
        // (terracotta, ~12% opacity, radial endRadius=360) contributes
        // ~1.3% at Y=320, blending the base color upward by ~3 units on R.
        // Matching the page exactly is what kills the boundary line — a
        // 3-unit RGB mismatch is small but reads as a hairline edge.
        let canvasEnd = scheme == .dark
            ? Color(red: 15 / 255, green: 10 / 255, blue: 7 / 255)
            : Color(red: 252 / 255, green: 246 / 255, blue: 234 / 255)

        return LinearGradient(
            stops: [
                .init(color: canvasEnd.opacity(0),    location: 0.0),
                .init(color: canvasEnd.opacity(0.06), location: 0.22),
                .init(color: canvasEnd.opacity(0.20), location: 0.42),
                .init(color: canvasEnd.opacity(0.45), location: 0.62),
                .init(color: canvasEnd.opacity(0.75), location: 0.80),
                .init(color: canvasEnd.opacity(0.92), location: 0.92),
                .init(color: canvasEnd,               location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 150)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var photoLayer: some View {
        if let url = recipe.imageURL {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty, .failure:
                    photoFallback
                @unknown default:
                    photoFallback
                }
            }
        } else {
            photoFallback
        }
    }

    private var photoFallback: some View {
        ZStack {
            LinearGradient(
                colors: [
                    categoryAccent.opacity(scheme == .dark ? 0.46 : 0.32),
                    categoryAccent.opacity(scheme == .dark ? 0.20 : 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: categoryIcon)
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var topScrim: some View {
        // Subtle darken at the top so the heart/close glass buttons separate
        // from any bright photography.
        LinearGradient(
            colors: [
                Color.black.opacity(scheme == .dark ? 0.42 : 0.22),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 140)
        .allowsHitTesting(false)
    }

    private var heartButton: some View {
        Button {
            onToggleFavorite?()
        } label: {
            Image(systemName: recipe.favourite ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(recipe.favourite ? Color.white : Color.white.opacity(0.96))
                .frame(width: 40, height: 40)
                .background {
                    if recipe.favourite {
                        Circle().fill(WMPalette.terracotta)
                    } else {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle().fill(Color(red: 20 / 255, green: 14 / 255, blue: 10 / 255).opacity(0.40))
                            )
                    }
                }
                .overlay(
                    Circle().stroke(.white.opacity(recipe.favourite ? 0.30 : 0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(onToggleFavorite == nil)
        .opacity(onToggleFavorite == nil ? 0 : 1)
        .accessibilityLabel(recipe.favourite ? "Usuń z ulubionych" : "Dodaj do ulubionych")
    }

    private var closeButton: some View {
        Button {
            onClose?()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.96))
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle().fill(Color(red: 20 / 255, green: 14 / 255, blue: 10 / 255).opacity(0.40))
                        )
                }
                .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .opacity(onClose == nil ? 0 : 1)
        .disabled(onClose == nil)
        .accessibilityLabel("Zamknij")
    }

    // MARK: - Eyebrow row (category badge + clock)

    private var eyebrowRow: some View {
        HStack(spacing: 10) {
            categoryPill
            Rectangle()
                .fill(Color.wmRule(scheme))
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .bold))
                Text(verbatim: "\(recipe.prepTimeMinutes) MIN")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .monospacedDigit()
            }
            .foregroundStyle(Color.wmMuted(scheme))
            .fixedSize()
        }
    }

    private var categoryPill: some View {
        HStack(spacing: 6) {
            Image(systemName: categoryIcon)
                .font(.system(size: 11, weight: .bold))
            Text(categoryLabel.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.7)
        }
        .foregroundStyle(categoryAccent)
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(categoryAccent.opacity(scheme == .dark ? 0.20 : 0.14))
        )
        .overlay(
            Capsule().stroke(categoryAccent.opacity(scheme == .dark ? 0.40 : 0.32), lineWidth: 1)
        )
    }

    // MARK: - Title + description

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recipe.name)
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Color.wmLabel(scheme))
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)

            if !recipe.description.isEmpty {
                Text(recipe.description)
                    .font(.system(size: 14.5, weight: .regular))
                    .foregroundStyle(Color.wmMuted(scheme))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Nutrition (asymmetric grid)

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeader(
                icon: "sparkles",
                title: "Wartości odżywcze",
                accent: WMPalette.terracotta
            )

            // Asymmetric 1.4 : 1 split — kcal hero on the left, three smaller
            // tiles stacked on the right. Default `maxWidth: .infinity` would
            // give 1:1; GeometryReader lets us mirror the design's 1.4fr/1fr.
            GeometryReader { proxy in
                let spacing: CGFloat = 10
                let avail = proxy.size.width - spacing
                let bigW = avail * 1.4 / 2.4
                let smallW = avail - bigW

                HStack(alignment: .top, spacing: spacing) {
                    NutritionFeatureTile(
                        label: "Kalorie",
                        value: formatValue(recipe.nutritionPerServing.kcal, fractionDigits: 0),
                        unit: "kcal",
                        icon: "flame.fill",
                        accent: WMPalette.terracotta
                    )
                    .frame(width: bigW)

                    VStack(spacing: 10) {
                        NutritionCompactTile(
                            label: "Białko",
                            value: formatValue(recipe.nutritionPerServing.protein),
                            unit: "g",
                            icon: "sparkles",
                            accent: WMPalette.indigo
                        )

                        NutritionCompactTile(
                            label: "Węglowodany",
                            value: formatValue(recipe.nutritionPerServing.carbs),
                            unit: "g",
                            icon: "leaf.fill",
                            accent: WMPalette.sage
                        )

                        NutritionCompactTile(
                            label: "Tłuszcze",
                            value: formatValue(recipe.nutritionPerServing.fat),
                            unit: "g",
                            icon: "heart.fill",
                            accent: WMPalette.terracottaDeep
                        )
                    }
                    .frame(width: smallW)
                }
            }
            .frame(height: 168)
        }
    }

    private func formatValue(_ value: Double, fractionDigits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Preparation steps

    private var preparationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeader(
                icon: "book.closed.fill",
                title: "Przygotowanie",
                accent: WMPalette.sage
            )

            VStack(spacing: 10) {
                ForEach(recipe.preparationSteps.sorted(by: { $0.stepNumber < $1.stepNumber })) { step in
                    PreparationStepRow(
                        index: step.stepNumber,
                        text: step.instruction
                    )
                }
            }
        }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeader(
                icon: "basket.fill",
                title: "Składniki",
                accent: WMPalette.indigo
            )

            VStack(spacing: 0) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    IngredientListRow(
                        ingredient: ingredient,
                        amountText: formatIngredientAmount(ingredient)
                    )

                    if index < recipe.ingredients.count - 1 {
                        Rectangle()
                            .fill(Color.wmRule(scheme))
                            .frame(height: 1)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.wmTileBg(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.wmTileStroke(scheme), lineWidth: 1)
            )
        }
    }

    private func formatIngredientAmount(_ ingredient: Ingredient) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        let amount = formatter.string(from: NSNumber(value: ingredient.amount)) ?? "\(ingredient.amount)"
        return "\(amount) \(ingredient.unit.rawValue)"
    }

    // MARK: - Category palette mapping

    private var categoryAccent: Color {
        switch recipe.category {
        case .breakfast: return WMPalette.butter
        case .lunch:     return WMPalette.sage
        case .dinner:    return WMPalette.indigo
        case .favourite: return WMPalette.terracotta
        case .all:       return WMPalette.indigo
        }
    }

    private var categoryLabel: String {
        RecipesConstants.displayName(for: recipe.category)
    }

    private var categoryIcon: String {
        RecipesConstants.icon(for: recipe.category)
    }
}

// MARK: - Section header

private struct EditorialSectionHeader: View {
    let icon: String
    let title: String
    let accent: Color

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(accent.opacity(scheme == .dark ? 0.20 : 0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(accent.opacity(scheme == .dark ? 0.40 : 0.30), lineWidth: 1)
                )

            Text(title)
                .font(.system(size: 18, weight: .heavy))
                .tracking(-0.3)
                .foregroundStyle(accent)
                .fixedSize()

            Rectangle()
                .fill(Color.wmRule(scheme))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Nutrition tiles

private struct NutritionFeatureTile: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let accent: Color

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accent.opacity(scheme == .dark ? 0.22 : 0.16))
                    )

                Text(label.uppercased())
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 38, weight: .heavy))
                    .tracking(-1.2)
                    .foregroundStyle(Color.wmLabel(scheme))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(unit)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.wmMuted(scheme))
            }
        }
        .padding(16)
        .frame(minHeight: 152)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.wmTileBg(scheme))

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(scheme == .dark ? 0.25 : 0.18),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: 6,
                            endRadius: 220
                        )
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(scheme == .dark ? 0.35 : 0.28), lineWidth: 1)
        )
    }
}

private struct NutritionCompactTile: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let accent: Color

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accent.opacity(scheme == .dark ? 0.20 : 0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(accent.opacity(scheme == .dark ? 0.36 : 0.28), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(Color.wmMuted(scheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(-0.3)
                        .foregroundStyle(Color.wmLabel(scheme))
                        .monospacedDigit()
                        .lineLimit(1)

                    Text(unit)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.wmMuted(scheme))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.wmTileBg(scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.wmTileStroke(scheme), lineWidth: 1)
        )
    }
}

// MARK: - Step + ingredient rows

private struct PreparationStepRow: View {
    let index: Int
    let text: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.system(size: 13, weight: .heavy))
                .italic()
                .monospacedDigit()
                .foregroundStyle(WMPalette.sage)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(WMPalette.sage.opacity(scheme == .dark ? 0.20 : 0.14))
                )
                .overlay(
                    Circle().stroke(WMPalette.sage.opacity(scheme == .dark ? 0.40 : 0.30), lineWidth: 1)
                )

            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.wmLabel(scheme))
                .lineSpacing(3)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.wmTileBg(scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.wmTileStroke(scheme), lineWidth: 1)
        )
    }
}

private struct IngredientListRow: View {
    let ingredient: Ingredient
    let amountText: String

    @Environment(\.colorScheme) private var scheme

    private var displayName: String {
        let trimmed = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return trimmed }
        return String(first).uppercased(with: Locale(identifier: "pl_PL")) + trimmed.dropFirst()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(displayName)
                .font(.system(size: 14, weight: .medium))
                .tracking(-0.1)
                .foregroundStyle(Color.wmLabel(scheme))

            Spacer(minLength: 8)

            Text(amountText)
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.1)
                .foregroundStyle(Color.wmMuted(scheme))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Recipe Detail · Dark") {
    RecipeDetailView(recipe: RecipesMock.chickenBowl, onToggleFavorite: {}, onClose: {})
        .preferredColorScheme(.dark)
}

#Preview("Recipe Detail · Light") {
    RecipeDetailView(recipe: RecipesMock.chickenBowl, onToggleFavorite: {}, onClose: {})
        .preferredColorScheme(.light)
}
