import SwiftUI

struct DashboardView: View {
    @State private var showMealView = false
    
    var body: some View {
        ZStack {
            NavigationMenu()
        }
    }
}

#Preview {
    DashboardView()
}
