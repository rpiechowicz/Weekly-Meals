import SwiftUI

private enum ProductsFilter: String, CaseIterable {
    case toBuy
    case all
}

struct ProductsView: View {
    @Environment(\.shoppingListStore) private var shoppingListStore
    @Environment(\.datesViewModel) private var datesViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var archivePendingDeletion: ArchivedShoppingList?
    @State private var selectedFilter: ProductsFilter = .toBuy

    private static let weekRangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private var shoppingItems: [ShoppingItem] {
        shoppingListStore.items
    }

    private var archivedCurrentWeek: ArchivedShoppingList? {
        shoppingListStore.currentClosedArchive(for: datesViewModel.weekStartISO)
    }

    private var hasOpenRevision: Bool {
        shoppingListStore.hasOpenRevision(for: datesViewModel.weekStartISO)
    }

    private var isCurrentWeekArchived: Bool {
        archivedCurrentWeek != nil && !hasOpenRevision
    }

    private var activeItems: [ShoppingItem] {
        hasOpenRevision
        ? shoppingListStore.pendingItems(for: datesViewModel.weekStartISO)
        : shoppingItems
    }

    private var readonlyItems: [ShoppingItem] {
        hasOpenRevision
        ? shoppingListStore.readonlyItems(for: datesViewModel.weekStartISO)
        : []
    }

    private var groupedByDepartment: [(department: String, items: [ShoppingItem])] {
        groupItemsByDepartment(activeItems)
    }

    private var groupedReadonlyByDepartment: [(department: String, items: [ShoppingItem])] {
        groupItemsByDepartment(readonlyItems)
    }

    private func groupItemsByDepartment(_ items: [ShoppingItem]) -> [(department: String, items: [ShoppingItem])] {
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

        return Dictionary(grouping: activeItems, by: \.department)
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
        activeItems.filter(\.isChecked).count
    }

    private var remainingCount: Int {
        max(0, activeItems.count - boughtCount)
    }

    private var weekRangeText: String {
        guard let first = datesViewModel.dates.first,
              let last = datesViewModel.dates.last else {
            return "Bieżący tydzień"
        }
        return "\(Self.weekRangeFormatter.string(from: first)) - \(Self.weekRangeFormatter.string(from: last))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ProductsLiquidBackground()
                    .ignoresSafeArea()

                Group {
                    if shoppingListStore.isLoading && shoppingItems.isEmpty && readonlyItems.isEmpty {
                        ProgressView("Ładowanie listy zakupów...")
                    } else if isCurrentWeekArchived {
                        archivedState
                    } else if shoppingItems.isEmpty && !hasOpenRevision {
                        emptyState
                    } else {
                        shoppingList
                    }
                }
            }
            .navigationTitle("Produkty")
            .alert("Usunąć listę z historii?", isPresented: archiveDeleteAlertBinding) {
                Button("Anuluj", role: .cancel) {
                    archivePendingDeletion = nil
                }
                Button("Usuń", role: .destructive) {
                    if let archivePendingDeletion {
                        shoppingListStore.deleteArchivedList(archiveId: archivePendingDeletion.id)
                    }
                    archivePendingDeletion = nil
                }
            } message: {
                Text("Ta operacja usunie zapisany wpis historyczny dla wybranego tygodnia.")
            }
            .task(id: datesViewModel.weekStartISO) {
                selectedFilter = .toBuy
                await shoppingListStore.load(weekStart: datesViewModel.weekStartISO)
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Text("Tydzień")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        Text(weekRangeText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }

                    VStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.blue.opacity(colorScheme == .dark ? 0.28 : 0.18),
                                            Color.cyan.opacity(colorScheme == .dark ? 0.18 : 0.12)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Image(systemName: "basket")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .frame(width: 82, height: 82)

                        VStack(spacing: 8) {
                            Text("Lista zakupów jest jeszcze pusta")
                                .font(.title3.weight(.semibold))
                                .multilineTextAlignment(.center)

                            Text("Dodaj posiłki do planu tygodniowego, a produkty pojawią się tutaj automatycznie.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 8) {
                            emptyHintChip(icon: "calendar.badge.plus", title: "Dodaj plan")
                            emptyHintChip(icon: "cart", title: "Lista pojawi się sama")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 28)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .padding(18)
                .dashboardLiquidCard(cornerRadius: 24, strokeOpacity: 0.2)

                historySection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 14)
        }
        .scrollContentBackground(.hidden)
    }

    private var archivedState: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lista przeniesiona do historii")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text("Tydzień \(weekRangeText) jest już zamknięty. Nowe produkty utworzą kolejną listę.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "archivebox.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: 42, height: 42)
                            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if let archivedCurrentWeek {
                        HStack(spacing: 8) {
                            statPill(value: "\(archivedCurrentWeek.revision)", title: "Lista", tint: .purple)
                            statPill(value: "\(archivedCurrentWeek.boughtCount)", title: "Kupione", tint: .green)
                            statPill(value: "\(archivedCurrentWeek.totalCount)", title: "Razem", tint: .blue)
                        }
                    }

                    Button {
                        shoppingListStore.restoreArchivedList(weekStart: datesViewModel.weekStartISO)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Pokaż listę ponownie")
                                .fontWeight(.semibold)
                        }
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .dashboardLiquidCard(cornerRadius: 24, strokeOpacity: 0.2)

                historySection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 14)
        }
        .scrollContentBackground(.hidden)
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

                if hasOpenRevision {
                    revisionFilterBar
                }

                if groupedByDepartment.isEmpty {
                    if hasOpenRevision {
                        noPendingProductsCard
                    } else {
                        compactEmptyCard
                    }
                } else {
                    ForEach(groupedByDepartment, id: \.department) { department, items in
                        departmentSection(department: department, items: items)
                    }
                }

                if hasOpenRevision && selectedFilter == .all && !groupedReadonlyByDepartment.isEmpty {
                    readonlySection
                }

                historySection
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
                    Text(hasOpenRevision ? "Nowa lista zakupów" : "Lista zakupów")
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
                statPill(value: "\(activeItems.count)", title: "Razem", tint: .blue)
            }

            HStack(spacing: 8) {
                actionButton(
                    title: shoppingListStore.isBatchUpdating ? "Zaznaczanie..." : "Kupione wszystko",
                    icon: shoppingListStore.isBatchUpdating ? "hourglass" : "checkmark.circle.fill",
                    tint: .green,
                    isDisabled: remainingCount == 0 || shoppingListStore.isBatchUpdating
                ) {
                    Task {
                        await shoppingListStore.markAllChecked()
                    }
                }

                actionButton(
                    title: "Zamknij listę",
                    icon: "archivebox.fill",
                    tint: .blue,
                    isDisabled: !canCloseCurrentList || shoppingListStore.isBatchUpdating
                ) {
                    shoppingListStore.archiveCurrentList(weekLabel: weekRangeText)
                }
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

    private func actionButton(
        title: String,
        icon: String,
        tint: Color,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isDisabled ? .secondary : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                (isDisabled ? Color.white.opacity(0.05) : tint.opacity(0.12)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isDisabled ? Color.white.opacity(0.08) : tint.opacity(0.18),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func emptyHintChip(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: Capsule())
    }

    private var revisionFilterBar: some View {
        HStack(spacing: 8) {
            filterButton(title: "Do kupienia", icon: "cart.badge.plus", filter: .toBuy)
            filterButton(title: "Wszystkie", icon: "square.stack.3d.down.right", filter: .all)
        }
    }

    private func filterButton(title: String, icon: String, filter: ProductsFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                (isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.05)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var compactEmptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "basket")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Brak aktywnej listy")
                .font(.footnote)
                .fontWeight(.semibold)

            Text("Zapisz plan tygodniowy, aby wygenerować produkty.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.14)
    }

    private var noPendingProductsCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.title3)
                .foregroundStyle(.green)

            Text("Brak nowych produktów do kupienia")
                .font(.footnote)
                .fontWeight(.semibold)

            Text("Zmiany w planie nie dodały nowych zakupów. W sekcji poniżej masz produkty kupione wcześniej.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.14)
    }

    private var historySection: some View {
        Group {
            if !shoppingListStore.archivedLists.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Historia list")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Spacer(minLength: 0)

                        Text("\(shoppingListStore.archivedLists.count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }

                    VStack(spacing: 8) {
                        ForEach(shoppingListStore.archivedLists.prefix(6)) { archive in
                            archiveRow(archive)
                        }
                    }
                }
                .padding(16)
                .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.16)
            }
        }
    }

    private var readonlySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kupione wcześniej")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Te produkty pochodzą z ostatniej zamkniętej listy i są tylko do podglądu.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(groupedReadonlyByDepartment, id: \.department) { department, items in
                readonlyDepartmentSection(department: department, items: items)
            }
        }
    }

    private func archiveRow(_ archive: ArchivedShoppingList) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(colorScheme == .dark ? 0.16 : 0.1))
                Image(systemName: "archivebox.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(archive.weekLabel)
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text("Lista \(archive.revision) • Kupione \(archive.boughtCount)/\(archive.totalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            Button {
                archivePendingDeletion = archive
            } label: {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Usuń z historii")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var archiveDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { archivePendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    archivePendingDeletion = nil
                }
            }
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

    private func readonlyDepartmentSection(department: String, items: [ShoppingItem]) -> some View {
        let icon = ProductConstants.departmentIcon(for: department)
        let color = ProductConstants.departmentColor(for: department)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(colorScheme == .dark ? 0.16 : 0.1))
                    Image(systemName: icon)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(color.opacity(0.9))
                }
                .frame(width: 26, height: 26)

                Text(verbatim: department)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Readonly")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    readonlyShoppingRow(item, color: color)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 46)
                            .padding(.trailing, 12)
                    }
                }
            }
            .padding(.bottom, 4)
        }
        .dashboardLiquidCard(cornerRadius: 18, strokeOpacity: 0.14)
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
        .disabled(shoppingListStore.isBatchUpdating)
        .opacity(shoppingListStore.isBatchUpdating ? 0.72 : 1)
    }

    private func readonlyShoppingRow(_ item: ShoppingItem, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))

                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.name)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            Text(verbatim: "\(item.formattedAmount) \(item.unit)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(color.opacity(colorScheme == .dark ? 0.1 : 0.08))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .opacity(0.72)
    }

    private var canCloseCurrentList: Bool {
        if shoppingListStore.isBatchUpdating || shoppingItems.isEmpty {
            return false
        }

        if hasOpenRevision {
            return shoppingItems.allSatisfy(\.isChecked)
        }

        return !activeItems.isEmpty && boughtCount == activeItems.count
    }

    private var progressSubtitle: String {
        if hasOpenRevision && activeItems.isEmpty {
            return "Brak nowych produktów do dokupienia"
        }
        if hasOpenRevision {
            return "Kupujesz tylko nowe lub brakujące produkty"
        }
        if activeItems.isEmpty {
            return "Lista jest jeszcze pusta"
        }
        if remainingCount == 0 {
            return "Wszystko kupione na ten tydzień"
        }
        if boughtCount == 0 {
            return "Masz \(remainingCount) pozycji do kupienia"
        }
        return "Zostało \(remainingCount) z \(activeItems.count) pozycji"
    }

    private var completionRatio: Double {
        guard !activeItems.isEmpty else { return 0 }
        return Double(boughtCount) / Double(activeItems.count)
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
                    .frame(width: activeItems.isEmpty ? 0 : width)
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
