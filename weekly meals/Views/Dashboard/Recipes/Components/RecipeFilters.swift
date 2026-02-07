import SwiftUI

struct RecipeFilters: View {
    let categories: [RecipesCategory]
    @Binding var selectedCategory: RecipesCategory
    var selected: Bool = false
    var disabled: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(categories, id: \.self) { category in
                let isSelected = selectedCategory == category

                Button {
                    selectedCategory = category
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: RecipesConstants.icon(for: category))
                            .font(.subheadline)

                        if isSelected {
                            Text(RecipesConstants.displayName(for: category))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    .foregroundStyle(isSelected ? Color.blue : Color.primary)
                    .padding(.horizontal, isSelected ? 14 : 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.blue.opacity(0.15) : Color(.systemBackground).opacity(0.6))
                            .overlay(
                                Capsule()
                                    .stroke(
                                        isSelected ? Color.blue.opacity(0.6) : Color.secondary.opacity(0.25),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(
                        color: isSelected ? Color.blue.opacity(0.15) : .clear,
                        radius: 6, x: 0, y: 2
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(disabled && !isSelected)
                .opacity(disabled && !isSelected ? 0.5 : 1)
                .animation(.easeInOut(duration: 0.2), value: selectedCategory)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 20)
    }
}
