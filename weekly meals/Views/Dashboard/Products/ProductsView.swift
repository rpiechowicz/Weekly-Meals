import SwiftUI

struct ProductsView: View {
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
            .navigationTitle("Produkty")
        }
    }
}

#Preview {
    ProductsView()
}
