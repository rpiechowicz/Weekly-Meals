import SwiftUI

struct ProductsView: View {
    @Environment(\.shoppingListStore) private var shoppingListStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var shoppingItems: [ShoppingItem] {
        shoppingListStore.items
    }

    private var groupedByDepartment: [(department: String, items: [ShoppingItem])] {
        let departmentOrder: [String: Int] = [
            ProductConstants.Department.vegetables: 1,
            ProductConstants.Department.fruits: 2,
            ProductConstants.Department.meat: 3,
            ProductConstants.Department.fish: 4,
            ProductConstants.Department.dairy: 5,
            ProductConstants.Department.bakery: 6,
            ProductConstants.Department.grains: 7,
            ProductConstants.Department.canned: 8,
            ProductConstants.Department.spices: 9,
            ProductConstants.Department.oils: 10,
            ProductConstants.Department.alcohols: 11,
            ProductConstants.Department.beverages: 12,
            ProductConstants.Department.snacks: 13,
            ProductConstants.Department.frozen: 14,
            ProductConstants.Department.bakerySweets: 15,
            ProductConstants.Department.household: 16,
            ProductConstants.Department.other: 99
        ]
        let normalizedOther = ProductConstants.Department.other
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return Dictionary(grouping: shoppingItems, by: \.department)
            .sorted {
                let leftKey = $0.key.trimmingCharacters(in: .whitespacesAndNewlines)
                let rightKey = $1.key.trimmingCharacters(in: .whitespacesAndNewlines)

                let leftIsOther = leftKey.lowercased() == normalizedOther
                let rightIsOther = rightKey.lowercased() == normalizedOther
                if leftIsOther != rightIsOther {
                    return !leftIsOther
                }

                let leftRank = departmentOrder[leftKey] ?? 999
                let rightRank = departmentOrder[rightKey] ?? 999
                if leftRank != rightRank { return leftRank < rightRank }
                return leftKey < rightKey
            }
            .map { (department: $0.key, items: $0.value) }
    }

    private var boughtCount: Int {
        shoppingItems.filter(\.isChecked).count
    }

    private var progress: Double {
        guard !shoppingItems.isEmpty else { return 0 }
        return Double(boughtCount) / Double(shoppingItems.count)
    }

    var body: some View {
        NavigationStack {
            Group {
                if shoppingListStore.isLoading && shoppingItems.isEmpty {
                    ProgressView("Ładowanie listy zakupów...")
                } else if shoppingItems.isEmpty {
                    emptyState
                } else {
                    shoppingList
                }
            }
            .navigationTitle("Produkty")
            .task(id: datesViewModel.weekStartISO) {
                await shoppingListStore.load(weekStart: datesViewModel.weekStartISO)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Brak produktów",
            systemImage: "basket",
            description: Text("Brak pozycji dla tygodnia \(datesViewModel.weekStartISO).")
        )
    }

    private var shoppingList: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let errorMessage = shoppingListStore.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

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

            if boughtCount == shoppingItems.count && !shoppingItems.isEmpty {
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

    private func departmentSection(department: String, items: [ShoppingItem]) -> some View {
        let icon = ProductConstants.departmentIcon(for: department)
        let color = ProductConstants.departmentColor(for: department)
        let boughtInSection = items.filter(\.isChecked).count
        let allBought = boughtInSection == items.count

        return VStack(alignment: .leading, spacing: 0) {
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
                            .fill(
                                allBought
                                ? Color.green.opacity(colorScheme == .dark ? 0.2 : 0.1)
                                : Color(.tertiarySystemFill)
                            )
                    )
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

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

    private func shoppingRow(_ item: ShoppingItem, color: Color) -> some View {
        let bought = item.isChecked

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                _ = Task {
                    await shoppingListStore.toggleChecked(item)
                }
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

                Text("\(item.formattedAmount) \(item.unit)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(bought ? Color.secondary : color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                bought
                                ? Color(.tertiarySystemFill).opacity(0.5)
                                : color.opacity(colorScheme == .dark ? 0.18 : 0.1)
                            )
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}

#Preview {
    ProductsView()
}
