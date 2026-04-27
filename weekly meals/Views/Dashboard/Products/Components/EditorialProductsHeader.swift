import SwiftUI

// Editorial top header on Produkty v2.
//
// Layout (from products.jsx):
//   `padding: '58px 20px 8px'` → outer block.
//   Eyebrow row — `marginBottom: 12`, gap 12 between eyebrow and trailing icons.
//   Eyebrow text — 10.5pt, 700, tracking 1.6, terracotta, uppercase.
//   Title block — 40pt / line-height 42pt, weight 800, tracking -1.2.
//     Line 1 "Produkty" in label color, weight 800.
//     Line 2 "na ten tydzień" in muted color, weight 500, italic, tracking -0.8.
struct EditorialProductsHeader: View {
    let weekNumber: Int
    var onSearch: (() -> Void)? = nil
    var onAction: (() -> Void)? = nil
    var actionIcon: String = "sparkles"
    var actionAccent: Color = WMPalette.terracotta
    var isActionHighlighted: Bool = true

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                eyebrowRow

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    if let onSearch {
                        EditorialIconButton(
                            icon: "magnifyingglass",
                            accent: WMPalette.terracotta,
                            highlighted: false,
                            action: onSearch
                        )
                    }
                    if let onAction {
                        EditorialIconButton(
                            icon: actionIcon,
                            accent: actionAccent,
                            highlighted: isActionHighlighted,
                            action: onAction
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: -4) {
                Text("Produkty")
                    .font(.system(size: 40, weight: .heavy))
                    .tracking(-1.2)
                    .foregroundStyle(Color.wmLabel(scheme))

                Text("na ten tydzień")
                    .font(.system(size: 40, weight: .medium))
                    .italic()
                    .tracking(-0.8)
                    .foregroundStyle(Color.wmMuted(scheme))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Eyebrow row with the week number rolling up via `CountingNumber` —
    /// same component the Kalendarz kcal counter uses, so the count-up
    /// animation feels native across screens. The literal pieces ("№", " · "
    /// suffix) flank the animated digit so the tracking + font apply
    /// uniformly across all glyphs.
    private var eyebrowRow: some View {
        HStack(spacing: 0) {
            Text("№ ")
            CountingNumber(target: weekNumber)
            Text(" · ZAKUPY TYGODNIA")
        }
        .font(.system(size: 10.5, weight: .bold))
        .tracking(1.6)
        .foregroundStyle(WMPalette.terracotta)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
}

// 38pt circular pill with border + soft inner highlight, matching the design's
// `IconBtn`. When `highlighted` is true the fill picks up the accent tint
// (used for the right-most action button in the editorial header).
struct EditorialIconButton: View {
    let icon: String
    var accent: Color = WMPalette.terracotta
    var highlighted: Bool = false
    var action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        highlighted
                        ? accent.opacity(0.20)
                        : Color.wmTileBg(scheme)
                    )

                Circle()
                    .stroke(
                        highlighted
                        ? accent.opacity(0.40)
                        : Color.wmTileStroke(scheme),
                        lineWidth: 1
                    )

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(highlighted ? accent : Color.wmLabel(scheme))
            }
            .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(icon))
    }
}
