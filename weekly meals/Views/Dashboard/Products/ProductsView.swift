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

    var body: some View {
        NavigationStack {
            ZStack {
                ProductsLiquidBackground()
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
        .padding(18)
        .dashboardLiquidCard(cornerRadius: 22, strokeOpacity: 0.22)
        .padding(.horizontal, 16)
    }

    private var shoppingList: some View {
        ScrollView {
            VStack(spacing: 9) {
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
            .padding(.vertical, 9)
            .padding(.bottom, 14)
        }
        .scrollContentBackground(.hidden)
    }

    private var progressCard: some View {
        HStack(spacing: 8) {
            progressStatChip(icon: "clock.fill", title: "Do kupienia", value: "\(remainingCount)", tint: .orange)
            progressStatChip(icon: "checkmark.circle.fill", title: "Kupione", value: "\(boughtCount)", tint: .green)
            progressStatChip(icon: "square.grid.2x2.fill", title: "Razem", value: "\(shoppingItems.count)", tint: .blue)
        }
        .padding(10)
        .dashboardLiquidCard(cornerRadius: 16, strokeOpacity: 0.17)
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(ProductsFilter.allCases) { filter in
                let isSelected = selectedFilter == filter
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filter.icon)
                            .font(.caption2)
                            .fontWeight(.semibold)
                        Text(filter.title)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .cyan.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        : AnyShapeStyle(Color.white.opacity(0.1)),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? Color.blue.opacity(0.36) : Color.white.opacity(0.16),
                                lineWidth: 0.8
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .dashboardLiquidCard(cornerRadius: 14, strokeOpacity: 0.14)
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
        .padding(.vertical, 14)
        .dashboardLiquidCard(cornerRadius: 14, strokeOpacity: 0.14)
    }

    private func progressStatChip(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private func departmentSection(department: String, items: [ShoppingItem]) -> some View {
        let icon = ProductConstants.departmentIcon(for: department)
        let color = ProductConstants.departmentColor(for: department)
        let boughtInSection = items.filter(\.isChecked).count
        let allBought = boughtInSection == items.count

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(color.opacity(colorScheme == .dark ? 0.24 : 0.14))
                    Image(systemName: icon)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                }
                .frame(width: 26, height: 26)

                Text(verbatim: department)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(allBought ? .secondary : .primary)

                Spacer()

                Text("\(boughtInSection)/\(items.count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(allBought ? .green : .secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(
                                allBought
                                ? Color.green.opacity(colorScheme == .dark ? 0.2 : 0.12)
                                : Color.white.opacity(0.12)
                            )
                    )
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 5)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    shoppingRow(item, color: color)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 38)
                            .padding(.trailing, 10)
                    }
                }
            }
            .padding(.bottom, 2)
        }
        .dashboardLiquidCard(cornerRadius: 16, strokeOpacity: 0.16)
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
            HStack(spacing: 10) {
                Image(systemName: bought ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(bought ? .green : Color(.tertiaryLabel))
                    .contentTransition(.symbolEffect(.replace))

                Text(verbatim: item.name)
                    .font(.footnote)
                    .fontWeight(bought ? .regular : .medium)
                    .strikethrough(bought)
                    .foregroundStyle(bought ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 4)

                Text(verbatim: "\(item.formattedAmount) \(item.unit)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(bought ? Color.secondary : color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(
                                bought
                                ? Color.white.opacity(0.08)
                                : color.opacity(colorScheme == .dark ? 0.18 : 0.1)
                            )
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}

private struct ProductsLiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    colorScheme == .dark
                        ? Color(red: 0.08, green: 0.09, blue: 0.11)
                        : Color(red: 0.95, green: 0.96, blue: 0.98),
                    colorScheme == .dark
                        ? Color(red: 0.05, green: 0.06, blue: 0.07)
                        : Color(red: 0.92, green: 0.94, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.11))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: -130, y: -210)

            Circle()
                .fill(Color.green.opacity(colorScheme == .dark ? 0.14 : 0.09))
                .frame(width: 210, height: 210)
                .blur(radius: 80)
                .offset(x: 120, y: -250)

            Circle()
                .fill(Color.cyan.opacity(colorScheme == .dark ? 0.16 : 0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: 140, y: 250)
        }
    }
}

#Preview {
    ProductsView()
}
