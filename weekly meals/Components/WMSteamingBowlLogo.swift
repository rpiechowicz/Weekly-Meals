import SwiftUI

/// Cozy Kitchen "Steaming Bowl" — wektorowy logo v2 z designu
/// (`Weekly Meals - Loader i Logo.html`). Trzy strugi pary tworzą
/// abstrakcyjne "W" nad terakotową miską na ciepłym tle.
///
/// Renderowane przez `Canvas`, żeby precyzyjnie oddać krzywe Béziera ze
/// źródła i jednocześnie skalować się bez aliasingu. Kolory pochodzą
/// z `WMPalette` (sRGB-equiv. dla OKLCH z designu).
struct WMSteamingBowlLogo: View {
    enum Palette {
        case auto
        case dark
        case light
    }

    var size: CGFloat = 100
    var mono: Bool = false
    var palette: Palette = .auto

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 100

            drawBackground(in: context, scale: scale, canvasSize: canvasSize, isLight: isLight)
            drawSteam(in: context, scale: scale, isLight: isLight)
            drawBowlRim(in: context, scale: scale, isLight: isLight)
            drawBowlBody(in: context, scale: scale, isLight: isLight)
            drawBowlShine(in: context, scale: scale)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var isLight: Bool {
        switch palette {
        case .auto: return colorScheme == .light
        case .dark: return false
        case .light: return true
        }
    }

    // MARK: - Drawing

    private func drawBackground(
        in context: GraphicsContext,
        scale: CGFloat,
        canvasSize: CGSize,
        isLight: Bool
    ) {
        let path = Path(
            roundedRect: CGRect(x: 0, y: 0, width: canvasSize.width, height: canvasSize.height),
            cornerRadius: 22 * scale,
            style: .continuous
        )

        if mono {
            context.fill(path, with: .color(monoBackgroundColor(isLight: isLight)))
            return
        }

        let topColor: Color = isLight
            ? Color(red: 254 / 255, green: 243 / 255, blue: 223 / 255) // #FEF3DF
            : Color(red: 58 / 255,  green: 42 / 255,  blue: 32 / 255)  // #3A2A20
        let bottomColor: Color = isLight
            ? Color(red: 244 / 255, green: 223 / 255, blue: 184 / 255) // #F4DFB8
            : Color(red: 26 / 255,  green: 20 / 255,  blue: 17 / 255)  // #1A1411

        context.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [topColor, bottomColor]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: canvasSize.height)
            )
        )
    }

    private func drawSteam(in context: GraphicsContext, scale: CGFloat, isLight: Bool) {
        // SVG: M36 46 C32 40 40 36 36 28 (i analogiczne dla x=50, x=64).
        let curls: [(start: CGPoint, c1: CGPoint, c2: CGPoint, end: CGPoint)] = [
            (CGPoint(x: 36, y: 46), CGPoint(x: 32, y: 40), CGPoint(x: 40, y: 36), CGPoint(x: 36, y: 28)),
            (CGPoint(x: 50, y: 46), CGPoint(x: 46, y: 40), CGPoint(x: 54, y: 36), CGPoint(x: 50, y: 26)),
            (CGPoint(x: 64, y: 46), CGPoint(x: 60, y: 40), CGPoint(x: 68, y: 36), CGPoint(x: 64, y: 28)),
        ]

        let steamColor: Color = isLight
            ? Color(red: 182 / 255, green: 100 / 255, blue: 60 / 255)   // terracottaDeep
            : Color(red: 251 / 255, green: 243 / 255, blue: 232 / 255)  // cream
        let opacity: Double = isLight ? 0.85 : 0.92

        for curl in curls {
            var path = Path()
            path.move(to: curl.start.scaled(by: scale))
            path.addCurve(
                to: curl.end.scaled(by: scale),
                control1: curl.c1.scaled(by: scale),
                control2: curl.c2.scaled(by: scale)
            )
            context.stroke(
                path,
                with: .color(steamColor.opacity(opacity)),
                style: StrokeStyle(lineWidth: 3.2 * scale, lineCap: .round)
            )
        }
    }

    private func drawBowlRim(in context: GraphicsContext, scale: CGFloat, isLight: Bool) {
        // SVG: <ellipse cx="50" cy="56" rx="30" ry="5" />
        let rect = CGRect(x: 20 * scale, y: 51 * scale, width: 60 * scale, height: 10 * scale)
        let color: Color
        if mono {
            color = isLight
                ? Color(red: 26 / 255,  green: 20 / 255,  blue: 17 / 255)
                : Color(red: 251 / 255, green: 243 / 255, blue: 232 / 255)
        } else {
            color = isLight
                ? Color(red: 200 / 255, green: 155 / 255, blue: 80 / 255)  // mustard (butter light)
                : Color(red: 232 / 255, green: 207 / 255, blue: 133 / 255) // butter dark
        }
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private func drawBowlBody(in context: GraphicsContext, scale: CGFloat, isLight: Bool) {
        // SVG: M22 56 Q22 78 50 80 Q78 78 78 56 Z
        var path = Path()
        path.move(to: CGPoint(x: 22, y: 56).scaled(by: scale))
        path.addQuadCurve(
            to: CGPoint(x: 50, y: 80).scaled(by: scale),
            control: CGPoint(x: 22, y: 78).scaled(by: scale)
        )
        path.addQuadCurve(
            to: CGPoint(x: 78, y: 56).scaled(by: scale),
            control: CGPoint(x: 78, y: 78).scaled(by: scale)
        )
        path.closeSubpath()

        if mono {
            let creamLow: Color = isLight
                ? Color(red: 26 / 255, green: 20 / 255, blue: 17 / 255).opacity(0.18)
                : Color(red: 251 / 255, green: 243 / 255, blue: 232 / 255).opacity(0.18)
            context.fill(path, with: .color(creamLow))
            return
        }

        // OKLCH(0.78 0.14 55) → ~#EBA569 ; OKLCH(0.55 0.15 35) → ~#A84C32.
        let topColor = Color(red: 235 / 255, green: 165 / 255, blue: 105 / 255)
        let bottomColor = Color(red: 168 / 255, green: 76 / 255,  blue: 50 / 255)

        context.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [topColor, bottomColor]),
                startPoint: CGPoint(x: 50 * scale, y: 56 * scale),
                endPoint: CGPoint(x: 50 * scale, y: 80 * scale)
            )
        )
    }

    private func drawBowlShine(in context: GraphicsContext, scale: CGFloat) {
        // SVG: M27 60 Q27 72 36 76
        var path = Path()
        path.move(to: CGPoint(x: 27, y: 60).scaled(by: scale))
        path.addQuadCurve(
            to: CGPoint(x: 36, y: 76).scaled(by: scale),
            control: CGPoint(x: 27, y: 72).scaled(by: scale)
        )
        context.stroke(
            path,
            with: .color(Color(red: 251 / 255, green: 243 / 255, blue: 232 / 255).opacity(0.25)),
            style: StrokeStyle(lineWidth: 1.6 * scale, lineCap: .round)
        )
    }

    private func monoBackgroundColor(isLight: Bool) -> Color {
        // Odpowiednik `bgCard` z designu (CK / CKL).
        isLight
            ? Color(red: 251 / 255, green: 246 / 255, blue: 236 / 255) // #FBF6EC
            : Color(red: 42 / 255,  green: 32 / 255,  blue: 26 / 255)  // #2A201A
    }
}

private extension CGPoint {
    func scaled(by factor: CGFloat) -> CGPoint {
        CGPoint(x: x * factor, y: y * factor)
    }
}

#Preview("Steaming Bowl — dark") {
    ZStack {
        Color(red: 26 / 255, green: 20 / 255, blue: 17 / 255).ignoresSafeArea()
        VStack(spacing: 16) {
            WMSteamingBowlLogo(size: 140, palette: .dark)
            HStack(spacing: 12) {
                WMSteamingBowlLogo(size: 64, palette: .dark)
                WMSteamingBowlLogo(size: 44, palette: .dark)
                WMSteamingBowlLogo(size: 28, palette: .dark)
            }
        }
    }
}

#Preview("Steaming Bowl — light") {
    ZStack {
        Color(red: 250 / 255, green: 243 / 255, blue: 232 / 255).ignoresSafeArea()
        VStack(spacing: 16) {
            WMSteamingBowlLogo(size: 140, palette: .light)
            HStack(spacing: 12) {
                WMSteamingBowlLogo(size: 52, mono: true, palette: .light)
                WMSteamingBowlLogo(size: 52, mono: true, palette: .dark)
            }
        }
    }
}
