import SwiftUI

/// Smart startup loader pokazywany po logowaniu / restore sesji, dopóki
/// SessionStore nie przygotuje krytycznych danych (przepisy, miniaturki,
/// domownicy). Minimum 2 s ekspozycji (vide `SessionStore`), żeby crossfade
/// Auth/Loader/Dashboard wyglądał płynnie zamiast migotać.
struct StartupLoaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulse: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            DashboardLiquidBackground()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(DashboardPalette.surface(colorScheme, level: .secondary))
                        .frame(width: 88, height: 88)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(DashboardPalette.neutralBorder(colorScheme, opacity: 0.18), lineWidth: 1)
                        )
                        .shadow(
                            color: Color.blue.opacity(pulse ? 0.22 : 0.08),
                            radius: pulse ? 26 : 14,
                            x: 0,
                            y: 8
                        )

                    Image(systemName: "fork.knife")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(pulse ? 1.06 : 0.96)
                }
                .scaleEffect(appeared ? 1 : 0.92)
                .opacity(appeared ? 1 : 0)

                VStack(spacing: 6) {
                    Text("Przygotowujemy Twój tydzień")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Ładujemy przepisy, domowników i plan tygodnia.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)

                ProgressView()
                    .controlSize(.regular)
                    .tint(.blue)
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

#Preview {
    StartupLoaderView()
}
