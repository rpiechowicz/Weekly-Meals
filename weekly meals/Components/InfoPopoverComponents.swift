import SwiftUI

struct InfoPopoverContent<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            TipTap {
                content()
            }
        }
    }
}

struct InfoTipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
