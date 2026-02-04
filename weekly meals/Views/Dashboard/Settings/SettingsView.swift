import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    LazyVStack {
                        ForEach(1...50, id: \.self) { index in
                            Text("\(index)")
                        }
                    }
                }
            }
            .navigationTitle("Ustawienia")
        }
    }
}

#Preview {
    SettingsView()
}
