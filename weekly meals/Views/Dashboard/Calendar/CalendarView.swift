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
        let breakfastRecipeKcal: Int = Int(breakfastRecipe?.nutrition.kcal ?? 0)
        let breakfastRecipeProtein: Int = Int(breakfastRecipe?.nutrition.protein ?? 0)
        let breakfastRecipeCarbs: Int = Int(breakfastRecipe?.nutrition.carbs ?? 0)
        
        let lunchRecipeKcal: Int = Int(lunchRecipe?.nutrition.kcal ?? 0)
        let lunchRecipeProtein: Int = Int(lunchRecipe?.nutrition.protein ?? 0)
        let lunchRecipeCarbs: Int = Int(lunchRecipe?.nutrition.carbs ?? 0)
        
        let dinnerRecipeKcal: Int = Int(dinnerRecipe?.nutrition.kcal ?? 0)
        let dinnerRecipeProtein: Int = Int(dinnerRecipe?.nutrition.protein ?? 0)
        let dinnerRecipeCarbs: Int = Int(dinnerRecipe?.nutrition.carbs ?? 0)
        
        let countOfKcal: Int = (breakfastRecipeKcal + lunchRecipeKcal + dinnerRecipeKcal) / 2
        let countOfProtein: Int = (breakfastRecipeProtein + lunchRecipeProtein + dinnerRecipeProtein) / 2
        let countOfCarbs: Int = (breakfastRecipeCarbs + lunchRecipeCarbs + dinnerRecipeCarbs) / 2
        
        print(breakfastRecipeKcal, lunchRecipeKcal, dinnerRecipeKcal)
        
        return DayNutrition(kcal: countOfKcal, protein: countOfProtein, carbs: countOfCarbs)
    }

    var body: some View {
        NavigationStack {
            VStack {
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
                            .padding(8)
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
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "hand.draw")
                                        .foregroundStyle(.blue)
                                    Text("Przesuń w lewo posiłek aby edytować go.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .presentationCompactAdaptation(.none)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    MealCardView(slot: .breakfast, recipe: breakfastRecipe)
                        .onTapGesture {
                            if let recipe = breakfastRecipe {
                                detailRecipe = recipe
                            } else {
                                slotToPick = .breakfast
                            }
                        }

                    MealCardView(slot: .lunch, recipe: lunchRecipe)
                        .onTapGesture {
                            if let recipe = lunchRecipe {
                                detailRecipe = recipe
                            } else {
                                slotToPick = .lunch
                            }
                        }

                    MealCardView(slot: .dinner, recipe: dinnerRecipe)
                        .onTapGesture {
                            if let recipe = dinnerRecipe {
                                detailRecipe = recipe
                            } else {
                                slotToPick = .dinner
                            }
                        }
                }
                .padding(.horizontal)
                
                Spacer()
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
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

#Preview {
    CalendarView()
}
