import SwiftUI

struct AuthFeaturesView: View {
    var body: some View {
        VStack(spacing: 12) {
            FeatureCard(
                icon: "calendar.badge.clock",
                title: "Plan tygodniowy",
                subtitle: "Ułóż menu na cały tydzień i oszczędzaj czas."
            )
            FeatureCard(
                icon: "cart.badge.plus",
                title: "Lista zakupów",
                subtitle: "Automatyczna lista na podstawie Twojego planu."
            )
            FeatureCard(
                icon: "leaf.fill",
                title: "Zdrowe wybory",
                subtitle: "Zbilansowane propozycje posiłków."
            )
            FeatureCard(
                icon: "bell.badge.fill",
                title: "Przypomnienia",
                subtitle: "Nigdy nie zapomnij o posiłku z powiadomieniami."
            )
        }.padding()
    }
}

#Preview {
    AuthFeaturesView()
}
