import SwiftUI

/// Loader pokazywany wyłącznie w wąskim przypadku restore sesji, gdy mamy
/// token ale jeszcze nie wiemy czy trafimy w dashboard czy w NoHousehold
/// (brak persisted householdId). W normalnym cold/warm starcie ten widok
/// nie jest montowany — dashboard wchodzi od razu, a każda zakładka
/// pokazuje własny skeleton podczas ładowania danych (pattern jak
/// Instagram / Spotify / Gmail).
///
/// UX: stały brand mark + indeterministyczny „stripe" na pasku postępu
/// + cyklujący komunikat. Jak tylko SessionStore ustawi household,
/// root view crossfade'uje do dashboardu.
struct StartupLoaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared: Bool = false
    @State private var stripeOffset: CGFloat = -0.5
    @State private var statusIndex: Int = 0
    @State private var statusTask: Task<Void, Never>?

    private static let statusMessages = [
        "Łączę z Twoim gospodarstwem",
        "Pobieram bazę przepisów",
        "Odświeżam plan tygodnia"
    ]

    var body: some View {
        ZStack {
            DashboardLiquidBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                brandMark
                Spacer()
                progressCluster
                    .padding(.bottom, 56)
            }
            .padding(.horizontal, 28)
        }
        .onAppear(perform: handleAppear)
        .onDisappear {
            statusTask?.cancel()
            statusTask = nil
        }
    }

    private var brandMark: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.blue.opacity(colorScheme == .dark ? 0.32 : 0.22),
                                Color.blue.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 86
                        )
                    )
                    .frame(width: 168, height: 168)
                    .blur(radius: 18)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DashboardPalette.surface(colorScheme, level: .secondary))
                    .frame(width: 84, height: 84)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.22), lineWidth: 1)
                    )
                    .shadow(
                        color: colorScheme == .dark ? .black.opacity(0.5) : Color(red: 0.36, green: 0.46, blue: 0.61).opacity(0.18),
                        radius: 20,
                        x: 0,
                        y: 14
                    )

                Image(systemName: "fork.knife")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)

            Text("Weekly Meals")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .tracking(0.2)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)
        }
    }

    private var progressCluster: some View {
        VStack(spacing: 14) {
            progressBar
                .frame(height: 4)
                .frame(maxWidth: 220)

            Text(Self.statusMessages[statusIndex])
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .id(statusIndex)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 4)),
                        removal: .opacity.combined(with: .offset(y: -4))
                    )
                )
                .frame(minHeight: 18)
                .accessibilityLabel(Text(Self.statusMessages[statusIndex]))
        }
        .opacity(appeared ? 1 : 0)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DashboardPalette.surface(colorScheme, level: .tertiary))
                    .overlay(
                        Capsule()
                            .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.14), lineWidth: 0.5)
                    )

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .blue.opacity(0),
                                .blue.opacity(0.85),
                                .cyan.opacity(0.85),
                                .cyan.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width * 0.45)
                    .offset(x: width * stripeOffset)
            }
            .clipShape(Capsule())
        }
        .accessibilityElement()
        .accessibilityLabel("Ładowanie")
    }

    private func handleAppear() {
        withAnimation(.easeOut(duration: 0.45)) {
            appeared = true
        }
        stripeOffset = -0.5
        withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
            stripeOffset = 1.1
        }
        startStatusCycle()
    }

    private func startStatusCycle() {
        statusTask?.cancel()
        statusTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.32)) {
                    statusIndex = (statusIndex + 1) % Self.statusMessages.count
                }
            }
        }
    }
}

#Preview("Light") {
    StartupLoaderView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    StartupLoaderView()
        .preferredColorScheme(.dark)
}
