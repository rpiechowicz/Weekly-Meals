import SwiftUI

struct ProductsView: View {
    @Environment(\.shoppingListStore) private var shoppingListStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedFilter: ProductsFilter = .all

    private enum ProductsFilter: CaseIterable, Identifiable {
        case all
        case missing
        case bought

        var id: Self { self }

        var title: String {
            switch self {
            case .all: return "Wszystkie"
            case .missing: return "Do kupienia"
            case .bought: return "Kupione"
            }
        }

        var icon: String {
            switch self {
            case .all: return "line.3.horizontal.decrease.circle"
            case .missing: return "circle"
            case .bought: return "checkmark.circle.fill"
            }
        }
    }

    private var shoppingItems: [ShoppingItem] {
        shoppingListStore.items
    }

    private var visibleItems: [ShoppingItem] {
        switch selectedFilter {
        case .all:
            return shoppingItems
        case .missing:
            return shoppingItems.filter { !$0.isChecked }
        case .bought:
            return shoppingItems.filter(\.isChecked)
        }
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

        return Dictionary(grouping: visibleItems, by: \.department)
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

    private var remainingCount: Int {
        max(0, shoppingItems.count - boughtCount)
    }

    private var progress: Double {
        guard !shoppingItems.isEmpty else { return 0 }
        return Double(boughtCount) / Double(shoppingItems.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardLiquidBackground()
                    .ignoresSafeArea()

                Group {
                    if shoppingListStore.isLoading && shoppingItems.isEmpty {
                        ProgressView("Ładowanie listy zakupów...")
                    } else if shoppingItems.isEmpty {
                        emptyState
                    } else {
                        shoppingList
                    }
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
        .padding()
        .dashboardLiquidCard(cornerRadius: 24, strokeOpacity: 0.28)
        .padding(.horizontal, 14)
    }

    private var shoppingList: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let errorMessage = shoppingListStore.errorMessage, !errorMessage.isEmpty {
                    Text(verbatim: errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                progressCard
                filterBar

                if groupedByDepartment.isEmpty {
                    filteredEmptyState
                } else {
                    ForEach(groupedByDepartment, id: \.department) { department, items in
                        departmentSection(department: department, items: items)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 16)
        }
        .scrollContentBackground(.hidden)
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
            }

            HStack(spacing: 8) {
                progressStatChip(title: "Pozostało", value: "\(remainingCount)")
                progressStatChip(title: "Kupione", value: "\(boughtCount)")
                progressStatChip(title: "Razem", value: "\(shoppingItems.count)")
            }

            ProgressView(value: progress)
                .tint(boughtCount == shoppingItems.count ? .green : .blue)
                .scaleEffect(y: 1.35)
                .animation(.easeInOut(duration: 0.35), value: progress)

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
        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.24)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(ProductsFilter.allCases) { filter in
                let isSelected = selectedFilter == filter
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: filter.icon)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(filter.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.96), .cyan.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        : AnyShapeStyle(Color.white.opacity(0.14)),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? Color.white.opacity(0.24) : Color.white.opacity(0.18),
                                lineWidth: 0.8
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.18)
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Brak pozycji dla filtra „\(selectedFilter.title)”")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .dashboardLiquidCard(cornerRadius: 16, strokeOpacity: 0.16)
    }

    private func progressStatChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

                Text(verbatim: department)
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
        .dashboardLiquidCard(cornerRadius: 20, strokeOpacity: 0.22)
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

                Text(verbatim: item.name)
                    .font(.subheadline)
                    .fontWeight(bought ? .regular : .medium)
                    .strikethrough(bought)
                    .foregroundStyle(bought ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 4)

                Text(verbatim: "\(item.formattedAmount) \(item.unit)")
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
