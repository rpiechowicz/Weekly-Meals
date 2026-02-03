//
//  RecipesView.swift
//  weekly meals
//
//  Created by Rafi on 03/02/2026.
//

import SwiftUI

struct RecipesView: View {
    @State private var selectedCategory: RecipesCategory = .all

    private var categories: [RecipesCategory] = RecipesCategory.allCases

    var body: some View {
        VStack(spacing: 0) {
            Headers(HeaderConstans.Recipes.self)
            
            ScrollView {
                FiltersView(categories: categories, selectedCategory: $selectedCategory)
            }
        }
    }
}

#Preview {
    RecipesView()
}
