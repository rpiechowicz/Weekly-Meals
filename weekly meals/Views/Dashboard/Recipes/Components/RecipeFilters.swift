import SwiftUI

struct RecipeFilters: View {
    let categories: [RecipesCategory]
    @Binding var selectedCategory: RecipesCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        Text(RecipesConstants.displayName(for: category))
                            .font(.subheadline)
                            .foregroundStyle(selectedCategory == category ? Color.blue : Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Group {
                                    if selectedCategory == category {
                                        Capsule()
                                            .fill(Color.blue.opacity(0.15)) // jasne wypełnienie
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.blue.opacity(0.6), lineWidth: 1) // ciemniejszy border
                                            )
                                    } else {
                                        Capsule()
                                            .fill(Color(.systemBackground).opacity(0.6))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1) // subtelny border
                                            )
                                    }
                                }
                            )
                            .shadow(color: (selectedCategory == category ? Color.blue.opacity(0.15) : Color.clear), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: selectedCategory)
                }
            }
            .padding()
        }
    }
}
