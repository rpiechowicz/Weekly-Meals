import SwiftUI

enum RecipeCategoryBadgeStyle {
    case subtle
    case overlayDark
}

struct RecipeInfoBadge: View {
    let icon: String
    let text: String
    var color: Color = .secondary
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .myBackground()
        .myBorderOverlay()
    }
}

struct RecipeMetricBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 11)

            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .foregroundStyle(labelColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(badgeFill, in: Capsule())
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var badgeFill: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.09)
        }

        return Color(red: 0.88, green: 0.89, blue: 0.92)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }

    private var labelColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.78)
            : Color.black.opacity(0.58)
    }
}

struct RecipeCategoryBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let text: String
    let tint: Color
    var style: RecipeCategoryBadgeStyle = .subtle

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)

            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(labelColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundFill, in: Capsule())
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 0.9)
        )
        .shadow(color: shadowColor, radius: colorScheme == .dark ? 8 : 5, x: 0, y: 2)
    }

    private var backgroundFill: Color {
        switch style {
        case .subtle:
            if colorScheme == .dark {
                return Color(red: 0.15, green: 0.17, blue: 0.21).opacity(0.74)
            }

            return DashboardPalette.surface(colorScheme, level: .primary).opacity(0.96)
        case .overlayDark:
            return Color.black.opacity(colorScheme == .dark ? 0.38 : 0.48)
        }
    }

    private var borderColor: Color {
        switch style {
        case .subtle:
            return tint.opacity(colorScheme == .dark ? 0.24 : 0.16)
        case .overlayDark:
            return Color.white.opacity(colorScheme == .dark ? 0.12 : 0.16)
        }
    }

    private var labelColor: Color {
        switch style {
        case .subtle:
            return colorScheme == .dark
                ? Color.white.opacity(0.88)
                : Color.black.opacity(0.66)
        case .overlayDark:
            return Color.white.opacity(0.94)
        }
    }

    private var dotColor: Color {
        switch style {
        case .subtle:
            return tint.opacity(colorScheme == .dark ? 0.92 : 0.82)
        case .overlayDark:
            return tint.opacity(0.96)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .subtle:
            return .black.opacity(colorScheme == .dark ? 0.18 : 0.08)
        case .overlayDark:
            return .black.opacity(colorScheme == .dark ? 0.24 : 0.16)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        RecipeInfoBadge(icon: "clock", text: "30 min")
        RecipeInfoBadge(icon: "person.2", text: "2 porcje")
        RecipeInfoBadge(icon: "star", text: "łatwe", color: .green)
        RecipeInfoBadge(icon: "star.leadinghalf.filled", text: "średnie", color: .orange)
        RecipeInfoBadge(icon: "star.fill", text: "trudne", color: .red)
        RecipeMetricBadge(icon: "clock", text: "30 min")
        RecipeMetricBadge(icon: "flame.fill", text: "380 kcal")
        RecipeCategoryBadge(text: "Kolacje", tint: .purple)
        RecipeCategoryBadge(text: "Kolacje", tint: .purple, style: .overlayDark)
    }
    .padding()
}
