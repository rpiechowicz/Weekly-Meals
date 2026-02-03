import SwiftUI

struct AuthFooterView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Logowanie wyłącznie przez Apple – szybkie i bezpieczne.")
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
