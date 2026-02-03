//
//  RecipesView.swift
//  weekly meals
//
//  Created by Rafi on 03/02/2026.
//

import SwiftUI

struct RecipesView: View {
    var body: some View {
        VStack(spacing: 0) {
            Headers(HeaderConstans.Recipes.self)
            
            // Tutaj będzie główna zawartość przepisów
            ScrollView {
                Text("Zawartość przepisów")
                    .padding()
            }
        }
    }
}

#Preview {
    RecipesView()
}
