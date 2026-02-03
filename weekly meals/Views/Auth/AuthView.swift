import SwiftUI

struct AuthView: View {
    var body: some View {
        ZStack {
            AuthBackgroundView()
            
            VStack {
                Spacer()
                
                AuthHeaderView()
                
                Spacer()
                
                AuthFeaturesView()
                
                Spacer()
                
                AuthActionsView()
                
                Spacer()
                
                AuthFooterView()
                
                Spacer()
            }
        }
    }
}

#Preview {
    AuthView()
}
