//
//  ProductsView.swift
//  weekly meals
//
//  Created by Rafi on 03/02/2026.
//

import SwiftUI

struct ProductsView: View {
    var body: some View {
        VStack(spacing: 0) {
            Headers(HeaderConstans.Products.self)
            
            // Tutaj będzie główna zawartość produktów
            ScrollView {
                Text("Zawartość produktów")
                    .padding()
            }
        }
    }
}

#Preview {
    ProductsView()
}
