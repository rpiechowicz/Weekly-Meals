import SwiftUI

// Weekly Meals v2 "Cozy Kitchen" design tokens.
// Source of truth: v2-design/Weekly Meals - Onboarding.html (WM_TOKENS).
// Dark-first; light mirrors. Colors converted from OKLCH → sRGB.

enum WMPalette {
    // Warm terracotta family — primary brand accent. Reads as food + warmth
    // without going saturated red.
    static let terracotta = Color(red: 219 / 255, green: 132 / 255, blue: 82 / 255)      // oklch(0.72 0.14 48)
    static let terracottaDeep = Color(red: 182 / 255, green: 100 / 255, blue: 60 / 255)  // oklch(0.60 0.15 40)
    static let sage = Color(red: 135 / 255, green: 194 / 255, blue: 165 / 255)           // oklch(0.74 0.10 155)
    static let indigo = Color(red: 101 / 255, green: 115 / 255, blue: 202 / 255)         // oklch(0.62 0.14 265)
    static let butter = Color(red: 232 / 255, green: 207 / 255, blue: 133 / 255)         // oklch(0.88 0.10 88)

    // Warm canvas. Dark is near-black with a warm brown cast.
    static let canvasDark = Color(red: 26 / 255, green: 20 / 255, blue: 17 / 255)     // #1A1411
    static let canvasLight = Color(red: 250 / 255, green: 246 / 255, blue: 240 / 255) // #FAF6F0

    static let labelDark = Color(red: 251 / 255, green: 243 / 255, blue: 232 / 255)   // #FBF3E8
    static let labelLight = Color(red: 26 / 255, green: 20 / 255, blue: 17 / 255)     // #1A1411
}

extension Color {
    static func wmCanvas(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? WMPalette.canvasDark : WMPalette.canvasLight
    }

    static func wmLabel(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? WMPalette.labelDark : WMPalette.labelLight
    }

    static func wmMuted(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 251 / 255, green: 243 / 255, blue: 232 / 255).opacity(0.58)
            : Color(red: 26 / 255, green: 20 / 255, blue: 17 / 255).opacity(0.56)
    }

    static func wmTileBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 251 / 255, green: 243 / 255, blue: 232 / 255).opacity(0.04)
            : Color(red: 26 / 255, green: 20 / 255, blue: 17 / 255).opacity(0.04)
    }

    static func wmTileStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 251 / 255, green: 243 / 255, blue: 232 / 255).opacity(0.06)
            : Color(red: 26 / 255, green: 20 / 255, blue: 17 / 255).opacity(0.06)
    }

    static func wmFeatureRowBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 251 / 255, green: 243 / 255, blue: 232 / 255).opacity(0.08)
            : Color(red: 26 / 255, green: 20 / 255, blue: 17 / 255).opacity(0.04)
    }

    static func wmAccentTint(_ scheme: ColorScheme) -> Color {
        WMPalette.terracotta.opacity(scheme == .dark ? 0.16 : 0.12)
    }

    static func wmRule(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? WMPalette.labelDark.opacity(0.12)
            : WMPalette.labelLight.opacity(0.12)
    }

    static func wmFaint(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? WMPalette.labelDark.opacity(0.32)
            : WMPalette.labelLight.opacity(0.32)
    }

    static func wmStrike(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? WMPalette.labelDark.opacity(0.30)
            : WMPalette.labelLight.opacity(0.30)
    }

    static func wmBarTrack(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? WMPalette.labelDark.opacity(0.07)
            : WMPalette.labelLight.opacity(0.07)
    }

    static func wmChipBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? WMPalette.labelDark.opacity(0.08)
            : WMPalette.labelLight.opacity(0.05)
    }
}

// Page background — warm canvas with a soft terracotta glow at the top.
// Used as the root of editorial screens (Kalendarz v2).
struct WMPageBackground: View {
    let scheme: ColorScheme

    var body: some View {
        let base = scheme == .dark
            ? Color(red: 12 / 255, green: 8 / 255, blue: 6 / 255)        // #0C0806
            : Color(red: 251 / 255, green: 245 / 255, blue: 234 / 255)   // #FBF5EA

        let glow = WMPalette.terracotta.opacity(scheme == .dark ? 0.12 : 0.10)

        return ZStack {
            base
            RadialGradient(
                colors: [glow, .clear],
                center: .top,
                startRadius: 0,
                endRadius: 360
            )
        }
    }
}
