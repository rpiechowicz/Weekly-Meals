import SwiftUI

struct ProductsView: View {
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel
    @State private var boughtItems: Set<String> = []
    @State private var showClearAlert = false

    // MARK: - Computed

    private var weekRecipes: [Recipe] {
        if mealStore.hasSavedPlan {
            return mealStore.savedPlan.allRecipes()
        }
        return mealStore.allRecipes(for: datesViewModel.dates)
    }

    private var shoppingItems: [ShoppingItem] {
        Self.aggregateIngredients(from: weekRecipes)
    }

    private var groupedByDepartment: [(department: String, items: [ShoppingItem])] {
        Dictionary(grouping: shoppingItems, by: \.department)
            .sorted { $0.key < $1.key }
            .map { (department: $0.key, items: $0.value) }
    }

    private var boughtCount: Int {
        shoppingItems.filter { isBought($0) }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if shoppingItems.isEmpty {
                    emptyState
                } else {
                    shoppingList
                }
            }
            .navigationTitle("Produkty")
            .toolbar {
                if !shoppingItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        clearButton
                    }
                }
            }
            .alert("Wyczyść plan tygodnia", isPresented: $showClearAlert) {
                Button("Anuluj", role: .cancel) { }
                Button("Wyczyść", role: .destructive) {
                    mealStore.clearWeek(dates: datesViewModel.dates)
                    mealStore.clearSavedPlan()
                    boughtItems.removeAll()
                }
            } message: {
                Text("Czy na pewno chcesz usunąć plan posiłków na ten tydzień? Tej akcji nie można cofnąć.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "Brak produktów",
            systemImage: "basket",
            description: Text("Zaplanuj posiłki w zakładce Przepisy, aby zobaczyć listę zakupów.")
        )
    }

    // MARK: - Shopping List

    private var shoppingList: some View {
        List {
            // Pasek postępu
            if !shoppingItems.isEmpty {
                Section {
                    HStack {
                        Text("\(boughtCount)/\(shoppingItems.count) kupione")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if boughtCount == shoppingItems.count {
                            Label("Gotowe!", systemImage: "checkmark.seal.fill")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            ForEach(groupedByDepartment, id: \.department) { department, items in
                Section(department) {
                    ForEach(items) { item in
                        shoppingRow(item)
                    }
                }
            }
        }
    }

    private func shoppingRow(_ item: ShoppingItem) -> some View {
        let bought = isBought(item)

        return HStack(spacing: 12) {
            Button {
                toggleBought(item)
            } label: {
                Image(systemName: bought ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(bought ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(item.name)
                .strikethrough(bought)
                .foregroundStyle(bought ? .secondary : .primary)

            Spacer()

            Text("\(item.formattedAmount) \(item.unit.rawValue)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Toolbar

    private var clearButton: some View {
        Button {
            showClearAlert = true
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(.red)
        }
    }

    // MARK: - Bought State

    private func itemKey(_ item: ShoppingItem) -> String {
        "\(item.name)|\(item.unit.rawValue)"
    }

    private func isBought(_ item: ShoppingItem) -> Bool {
        boughtItems.contains(itemKey(item))
    }

    private func toggleBought(_ item: ShoppingItem) {
        let key = itemKey(item)
        if boughtItems.contains(key) {
            boughtItems.remove(key)
        } else {
            boughtItems.insert(key)
        }
    }

    // MARK: - Aggregation

    static func aggregateIngredients(from recipes: [Recipe]) -> [ShoppingItem] {
        var aggregated: [String: ShoppingItem] = [:]

        for recipe in recipes {
            for ingredient in recipe.ingredients {
                let key = "\(ingredient.name)|\(ingredient.unit.rawValue)"
                if var existing = aggregated[key] {
                    existing.totalAmount += ingredient.amount
                    aggregated[key] = existing
                } else {
                    aggregated[key] = ShoppingItem(
                        name: ingredient.name,
                        totalAmount: ingredient.amount,
                        unit: ingredient.unit,
                        department: ProductConstants.department(for: ingredient.name)
                    )
                }
            }
        }

        return aggregated.values.sorted { $0.name < $1.name }
    }
}

// MARK: - ShoppingItem

struct ShoppingItem: Identifiable {
    let id = UUID()
    var name: String
    var totalAmount: Double
    var unit: IngredientUnit
    var department: String

    var formattedAmount: String {
        totalAmount.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", totalAmount)
            : String(format: "%.1f", totalAmount)
    }
}

#Preview {
    ProductsView()
}
