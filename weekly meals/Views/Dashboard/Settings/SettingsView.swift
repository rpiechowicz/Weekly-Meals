import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            Headers(HeaderConstans.Settings.self)
            
            // Tutaj będzie główna zawartość ustawień
            ScrollView {
                Text("Zawartość ustawień")
                    .padding()
            }
        }
    }
}

#Preview {
    SettingsView()
}
