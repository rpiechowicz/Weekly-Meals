import SwiftUI

extension View {
    func myBorderOverlay(
        cornerRadius: CGFloat = 14,
        color: Color = Color(.separator),
        lineWidth: CGFloat = 0.5
    ) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(color, lineWidth: lineWidth)
        )
    }
    
    func myBackground() -> some View {
        background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
