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
            VStack(spacing: 12) {
                if let errorMessage = shoppingListStore.errorMessage, !errorMessage.isEmpty {
                    Text(verbatim: errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                progressCard

                if groupedByDepartment.isEmpty {
                    emptyState
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lista zakupów")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(progressSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)
            }

            progressBar

            HStack(spacing: 8) {
                statPill(value: "\(remainingCount)", title: "Do kupienia", tint: .orange)
                statPill(value: "\(boughtCount)", title: "Kupione", tint: .green)
                statPill(value: "\(shoppingItems.count)", title: "Razem", tint: .blue)
            }
        }
        .padding(16)
        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.17)
    }

    private func statPill(value: String, title: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .monospacedDigit()

            HStack(spacing: 6) {
                Circle()
                    .fill(tint.opacity(0.95))
                    .frame(width: 7, height: 7)

                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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

                Text(allBought ? "Gotowe" : "\(items.count) pozycji")
                    .font(.caption2.weight(.semibold))
                    .fontWeight(.medium)
                    .foregroundStyle(allBought ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                allBought
                                ? Color.green.opacity(colorScheme == .dark ? 0.2 : 0.12)
                                : Color.white.opacity(0.12)
                            )
                    )
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    shoppingRow(item, color: color)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 46)
                            .padding(.trailing, 12)
                    }
                }
            }
            .padding(.bottom, 4)
        }
        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.16)
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
                ZStack {
                    Circle()
                        .fill(
                            bought
                            ? Color.green.opacity(colorScheme == .dark ? 0.2 : 0.12)
                            : Color.white.opacity(0.08)
                        )

                    Image(systemName: bought ? "checkmark" : "circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(bought ? .green : Color(.tertiaryLabel))
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: item.name)
                        .font(.footnote)
                        .fontWeight(bought ? .regular : .medium)
                        .strikethrough(bought)
                        .foregroundStyle(bought ? .secondary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Text(verbatim: "\(item.formattedAmount) \(item.unit)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(bought ? Color.secondary : color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(
                                bought
                                ? Color.white.opacity(0.08)
                                : color.opacity(colorScheme == .dark ? 0.18 : 0.1)
                            )
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var progressSubtitle: String {
        if shoppingItems.isEmpty {
            return "Lista jest jeszcze pusta"
        }
        if remainingCount == 0 {
            return "Wszystko kupione na ten tydzień"
        }
        if boughtCount == 0 {
            return "Masz \(remainingCount) pozycji do kupienia"
        }
        return "Zostało \(remainingCount) z \(shoppingItems.count) pozycji"
    }

    private var completionRatio: Double {
        guard !shoppingItems.isEmpty else { return 0 }
        return Double(boughtCount) / Double(shoppingItems.count)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            let width = geometry.size.width * completionRatio

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.64, blue: 1.0).opacity(0.95),
                                Color(red: 0.23, green: 0.83, blue: 0.76).opacity(0.82)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: shoppingItems.isEmpty ? 0 : width)
                    .animation(.easeInOut(duration: 0.28), value: completionRatio)
            }
        }
        .frame(height: 8)
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
