import SwiftUI

struct AuthFooterView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Tryb developerski: szybkie logowanie lokalne. Apple Sign-In podłączymy na końcu.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Polityka prywatności") {}
                    .buttonStyle(.plain)
                    .font(.footnote)
                Button("Warunki korzystania") {}
                    .buttonStyle(.plain)
                    .font(.footnote)
            }
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AuthFooterView()
        .padding()
}
