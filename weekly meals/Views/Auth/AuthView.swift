import SwiftUI

struct AuthView: View {
    let isLoading: Bool
    let errorMessage: String?
    let onSignInWithAppleTap: () -> Void

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
                            onSignInWithAppleTap: onSignInWithAppleTap
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
        onSignInWithAppleTap: {}
    )
}
