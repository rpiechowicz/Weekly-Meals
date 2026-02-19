import SwiftUI

struct DashboardLiquidBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.22),
                    Color.cyan.opacity(0.16),
                    Color.indigo.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.cyan.opacity(0.35))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: -120, y: -200)

            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: 140, y: 220)
        }
    }
}

extension View {
    func dashboardLiquidCard(
        cornerRadius: CGFloat = 22,
        strokeOpacity: Double = 0.24
    ) -> some View {
        myBackground(cornerRadius: cornerRadius)
            .myBorderOverlay(
                cornerRadius: cornerRadius,
                color: Color.white.opacity(strokeOpacity),
                lineWidth: 1
            )
    }

    @ViewBuilder
    func dashboardLiquidSheet(cornerRadius: CGFloat = 30) -> some View {
        if #available(iOS 16.4, *) {
            self
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(cornerRadius)
                .presentationBackground(.ultraThinMaterial)
        } else {
            self
                .presentationDragIndicator(.visible)
        }
    }
}
