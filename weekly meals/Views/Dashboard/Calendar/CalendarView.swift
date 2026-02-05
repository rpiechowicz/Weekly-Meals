import SwiftUI

struct CalendarView: View {
    struct DayNutrition {
        var kcal: Int = 0
        var protein: Int = 0
        var carbs: Int = 0
    }

    @State private var datesViewModel = DatesViewModel()

    @State private var breakfastRecipe: Recipe? = RecipesMock.omelette
    @State private var lunchRecipe: Recipe? = RecipesMock.chickenBowl
    @State private var dinnerRecipe: Recipe? = nil

    @State private var slotToPick: MealSlot? = nil
    @State private var detailRecipe: Recipe? = nil

    @State private var showTipPopover: Bool = false

    private var countNutritionOfDay: DayNutrition {
        let recipes = [breakfastRecipe, lunchRecipe, dinnerRecipe]

        let totalKcal = recipes.compactMap { $0?.nutrition.kcal }.reduce(0, +)
        let totalProtein = recipes.compactMap { $0?.nutrition.protein }.reduce(0, +)
        let totalCarbs = recipes.compactMap { $0?.nutrition.carbs }.reduce(0, +)

        return DayNutrition(
            kcal: Int(totalKcal) / 2,
            protein: Int(totalProtein) / 2,
            carbs: Int(totalCarbs) / 2
        )
    }

    private func recipe(for slot: MealSlot) -> Recipe? {
        switch slot {
        case .breakfast: breakfastRecipe
        case .lunch: lunchRecipe
        case .dinner: dinnerRecipe
        }
    }

    private func handleTap(_ slot: MealSlot) {
        if let recipe = recipe(for: slot) {
            detailRecipe = recipe
        } else {
            slotToPick = slot
        }
    }

    private func clearRecipe(for slot: MealSlot) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            switch slot {
            case .breakfast: breakfastRecipe = nil
            case .lunch: lunchRecipe = nil
            case .dinner: dinnerRecipe = nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatesView(datesViewModal: datesViewModel)

                HStack(alignment: .center) {
                    Text(datesViewModel.formattedDate(datesViewModel.selectedDate))
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer(minLength: 8)

                    Button {
                        showTipPopover.toggle()
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTipPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                        VStack(alignment: .trailing, spacing: 0) {
                            TipTap() {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("Informacje")
                                        .font(.headline)
                                    Spacer()
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Podsumowanie dnia")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    VStack(spacing: 12) {
                                        HStack {
                                            HStack(spacing: 6) {
                                                Image(systemName: "flame.fill")
                                                    .foregroundStyle(.orange)
                                                Text("\(countNutritionOfDay.kcal) kcal")
                                                    .monospacedDigit()
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(.ultraThinMaterial, in: Capsule())

                                            HStack(spacing: 6) {
                                                Image(systemName: "bolt.fill")
                                                    .foregroundStyle(.blue)
                                                Text("\(countNutritionOfDay.protein) g białka")
                                                    .monospacedDigit()
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(.ultraThinMaterial, in: Capsule())
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        HStack(spacing: 6) {
                                            Image(systemName: "leaf.fill")
                                                .foregroundStyle(.green)
                                            Text("\(countNutritionOfDay.carbs) g węglowodanów")
                                                .monospacedDigit()
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(.ultraThinMaterial, in: Capsule())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }

                                Divider()

                                HStack(spacing: 8) {
                                    Image(systemName: "hand.rays")
                                        .foregroundStyle(.blue)
                                    Text("Stuknij kartę posiłku, aby zobaczyć szczegóły.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "hand.draw")
                                        .foregroundStyle(.blue)
                                    Text("Przesuń w prawo aby edytować, w lewo aby usunąć.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding()
                        .presentationCompactAdaptation(.none)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

                List {
                    ForEach(MealSlot.allCases) { slot in
                        MealCardView(slot: slot, recipe: recipe(for: slot))
                            .contentShape(Rectangle())
                            .onTapGesture { handleTap(slot) }
                            .swipeActions(edge: .trailing) {
                                if recipe(for: slot) != nil {
                                    Button("Edytuj") { slotToPick = slot }
                                        .tint(slot.accentColor)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if recipe(for: slot) != nil {
                                    Button("Usuń") { clearRecipe(for: slot) }
                                        .tint(.red)
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
            }
            .navigationTitle("Kalendarz")
            .sheet(item: $slotToPick) { slot in
                MealPickerSheet(slot: slot, recipes: RecipesMock.all) { selected in
                    switch slot {
                    case .breakfast: breakfastRecipe = selected
                    case .lunch:     lunchRecipe = selected
                    case .dinner:    dinnerRecipe = selected
                    }
                }
            }
            .sheet(item: $detailRecipe) { recipe in
                NavigationStack {
                    RecipeDetailView(recipe: recipe)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    CalendarView()
}
