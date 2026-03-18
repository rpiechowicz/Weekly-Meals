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

enum DashboardActionTone {
    case neutral
    case accent(Color)
    case destructive
}

struct DashboardActionLabel: View {
    let title: String?
    let systemImage: String
    var tone: DashboardActionTone = .neutral
    var fullWidth: Bool = false
    var isDisabled: Bool = false
    var foregroundColor: Color? = nil
    var controlSize: CGFloat = 34

    private var resolvedForegroundColor: Color {
        if let foregroundColor {
            return foregroundColor
        }

        switch tone {
        case .destructive:
            return .red
        case .neutral, .accent:
            return .primary
        }
    }

    private var backgroundColor: Color {
        if isDisabled {
            return Color.white.opacity(0.05)
        }

        switch tone {
        case .neutral:
            return Color.white.opacity(0.06)
        case .accent(let color):
            return color.opacity(0.12)
        case .destructive:
            return Color.red.opacity(0.08)
        }
    }

    private var borderColor: Color {
        if isDisabled {
            return Color.white.opacity(0.08)
        }

        switch tone {
        case .neutral:
            return Color.white.opacity(0.12)
        case .accent(let color):
            return color.opacity(0.2)
        case .destructive:
            return Color.red.opacity(0.18)
        }
    }

    var body: some View {
        HStack(spacing: title == nil ? 0 : 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))

            if let title {
                Text(title)
                    .lineLimit(1)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(isDisabled ? .secondary : resolvedForegroundColor)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .frame(width: title == nil ? controlSize : nil, height: controlSize)
        .padding(.horizontal, title == nil ? 0 : 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .opacity(isDisabled ? 0.72 : 1)
    }
}

struct DashboardActionButton: View {
    let title: String?
    let systemImage: String
    var tone: DashboardActionTone = .neutral
    var fullWidth: Bool = false
    var isDisabled: Bool = false
    var foregroundColor: Color? = nil
    var controlSize: CGFloat = 34
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            DashboardActionLabel(
                title: title,
                systemImage: systemImage,
                tone: tone,
                fullWidth: fullWidth,
                isDisabled: isDisabled,
                foregroundColor: foregroundColor,
                controlSize: controlSize
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
