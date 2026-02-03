import SwiftUI

struct AuthBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .overlay(
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.25), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 320, height: 320)
                    .offset(x: -140, y: -240)
                    .blur(radius: 40)
                
                RoundedRectangle(cornerRadius: 48, style: .continuous)
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.18), .clear],
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading
                    ))
                    .frame(width: 380, height: 280)
                    .offset(x: 140, y: 260)
                    .blur(radius: 50)
            }
        )
    }
}

#Preview {
    AuthBackgroundView()
}
