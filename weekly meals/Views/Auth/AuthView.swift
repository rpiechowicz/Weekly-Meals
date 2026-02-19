import SwiftUI

struct AuthView: View {
    let isLoading: Bool
    let errorMessage: String?
    let onLoginTap: (_ displayName: String, _ email: String?) -> Void

    var body: some View {
        ZStack {
            AuthBackgroundView()

            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        AuthHeaderView()
                        AuthFeaturesView()
                        AuthActionsView(
                            isLoading: isLoading,
                            errorMessage: errorMessage,
                            onLoginUser1Tap: {
                                onLoginTap("user1", "user1@example.com")
                            },
                            onLoginUser2Tap: {
                                onLoginTap("user2", "user2@example.com")
                            }
                        )
                        AuthFooterView()
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height, alignment: .center)
                }
            }
        }
    }
}

#Preview {
    AuthView(
        isLoading: false,
        errorMessage: nil,
        onLoginTap: { _, _ in }
    )
}
