import SwiftUI

// Editorial top header on Ustawienia v2.
//
// Source: settings.jsx → top title block.
//   `padding: '54px 20px 0'` outer; title `marginTop: 8, marginBottom: 16`.
//   Title — 32pt 700, lineHeight 38pt, tracking -0.4, label color.
//
// Settings doesn't carry the "№ X · …" eyebrow that Kalendarz / Produkty
// use — the design intentionally drops it because there is no per-week
// context to surface. The header is just the static "Ustawienia" word at
// the top of the screen.
struct EditorialSettingsHeader: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text("Ustawienia")
            .font(.system(size: 32, weight: .heavy))
            .tracking(-0.4)
            .foregroundStyle(Color.wmLabel(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
