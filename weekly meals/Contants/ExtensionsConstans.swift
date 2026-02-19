import SwiftUI

extension View {
    func myBorderOverlay(
        cornerRadius: CGFloat = 14,
        color: Color = Color.white.opacity(0.24),
        lineWidth: CGFloat = 1
    ) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(color, lineWidth: lineWidth)
        )
    }
    
    func myBackground(cornerRadius: CGFloat = 14) -> some View {
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}
