import SwiftUI

struct CalendarView: View {
    @State private var datesViewModel = DatesViewModel()
    
    @State private var breakfastRecipe: Recipe? = RecipesMock.omelette
    @State private var lunchRecipe: Recipe? = RecipesMock.chickenBowl
    @State private var dinnerRecipe: Recipe? = nil
    
    @State private var slotToPick: MealSlot? = nil
    @State private var detailRecipe: Recipe? = nil
    
    @State private var countNutritionOfDay = {
        var kcal: Int = 0
        var protein: Int = 0
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatesView(datesViewModal: datesViewModel)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(datesViewModel.formattedDate(datesViewModel.selectedDate))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text("123")
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
