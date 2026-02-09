import SwiftUI

struct ProductsView: View {
    @Environment(\.weeklyMealStore) private var mealStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.colorScheme) private var colorScheme
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

    private var progress: Double {
        guard !shoppingItems.isEmpty else { return 0 }
        return Double(boughtCount) / Double(shoppingItems.count)
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
        ScrollView {
            VStack(spacing: 12) {
                progressCard

                ForEach(groupedByDepartment, id: \.department) { department, items in
                    departmentSection(department: department, items: items)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 16)
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "cart.fill")
                    .font(.title3)
                    .foregroundStyle(.green)

                Text("Lista zakupów")
                    .font(.headline)

                Spacer()

                Text("\(boughtCount) z \(shoppingItems.count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressView(value: progress)
                .tint(boughtCount == shoppingItems.count ? .green : .blue)
                .scaleEffect(y: 1.5)

            if boughtCount == shoppingItems.count {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Wszystko kupione!")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .myBackground()
        .myBorderOverlay()
    }

    // MARK: - Department Section

    private func departmentSection(department: String, items: [ShoppingItem]) -> some View {
        let icon = ProductConstants.departmentIcon(for: department)
        let color = ProductConstants.departmentColor(for: department)
        let boughtInSection = items.filter { isBought($0) }.count
        let allBought = boughtInSection == items.count

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(colorScheme == .dark ? 0.25 : 0.15))
                    Image(systemName: icon)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                }
                .frame(width: 28, height: 28)

                Text(department)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(allBought ? .secondary : .primary)

                Spacer()

                Text("\(boughtInSection)/\(items.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(allBought ? .green : .secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(allBought
                                  ? Color.green.opacity(colorScheme == .dark ? 0.2 : 0.1)
                                  : Color(.tertiarySystemFill))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // Items
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    shoppingRow(item, color: color)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 44)
                            .padding(.trailing, 14)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .myBackground()
        .myBorderOverlay()
    }

    // MARK: - Shopping Row

    private func shoppingRow(_ item: ShoppingItem, color: Color) -> some View {
        let bought = isBought(item)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                toggleBought(item)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: bought ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(bought ? .green : Color(.tertiaryLabel))
                    .contentTransition(.symbolEffect(.replace))

                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(bought ? .regular : .medium)
                    .strikethrough(bought)
                    .foregroundStyle(bought ? .secondary : .primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("\(item.formattedAmount) \(item.unit.rawValue)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(bought ? Color.secondary : color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(bought
                                  ? Color(.tertiarySystemFill).opacity(0.5)
                                  : color.opacity(colorScheme == .dark ? 0.18 : 0.1))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
