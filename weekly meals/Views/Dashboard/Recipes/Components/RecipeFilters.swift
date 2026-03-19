import SwiftUI

struct RecipeFilters: View {
    let categories: [RecipesCategory]
    @Binding var selectedCategory: RecipesCategory
    var disabled: Bool = false

    var body: some View {
        Menu {
            ForEach(categories, id: \.self) { category in
                Button {
                    selectedCategory = category
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: RecipesConstants.icon(for: category))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RecipesConstants.tint(for: category))
                            .frame(width: 18, alignment: .center)

                        Text(RecipesConstants.displayName(for: category))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        if category == selectedCategory {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        label: {
            DashboardActionLabel(
                title: nil,
                systemImage: RecipesConstants.icon(for: selectedCategory),
                tone: .neutral,
                isDisabled: disabled,
                foregroundColor: RecipesConstants.tint(for: selectedCategory),
                controlSize: 40,
                iconFont: .system(size: 17, weight: .semibold)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
        .accessibilityLabel("Kategoria: \(RecipesConstants.displayName(for: selectedCategory))")
    }
}
