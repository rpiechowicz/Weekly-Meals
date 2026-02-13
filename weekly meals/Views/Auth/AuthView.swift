import SwiftUI

struct AuthView: View {
    let isLoading: Bool
    let errorMessage: String?
    let onLoginTap: (_ displayName: String, _ email: String?) -> Void

    var body: some View {
        ZStack {
            AuthBackgroundView()
            
            VStack {
                Spacer()
                
                AuthHeaderView()
                
                Spacer()
                
                AuthFeaturesView()
                
                Spacer()
                
                AuthActionsView(
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                    onLoginUser1Tap: {
                        onLoginTap("Rafał Dev", "rafal.dev@example.com")
                    },
                    onLoginUser2Tap: {
                        onLoginTap("Ania Dev", "ania.dev@example.com")
                    }
                )
                
                Spacer()
                
                AuthFooterView()
                
                Spacer()
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
