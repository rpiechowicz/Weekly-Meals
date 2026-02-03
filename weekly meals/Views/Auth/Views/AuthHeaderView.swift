import SwiftUI

struct AuthHeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.green, .green.opacity(0.35))
                .font(.system(size: 64))
                .accessibilityHidden(true)

            Text("Weekly Meals")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)

            Text("Planuj posiłki wygodnie i zdrowo.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

#Preview {
    AuthHeaderView()
        .padding()
}
