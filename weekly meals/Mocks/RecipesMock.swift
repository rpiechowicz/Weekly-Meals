import Foundation

enum RecipesMock {
    static let omelette = Recipe(
        name: "Omlet z warzywami",
        description: "Puszysty omlet z papryką, szpinakiem i serem feta.",
        favourite: true,
        category: .breakfast,
        servings: 2,
        prepTimeMinutes: 15,
        difficulty: .easy,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Jajka", amount: 3, unit: .piece),
            Ingredient(name: "Papryka", amount: 80, unit: .gram),
            Ingredient(name: "Szpinak", amount: 50, unit: .gram),
            Ingredient(name: "Ser feta", amount: 30, unit: .gram),
            Ingredient(name: "Masło", amount: 10, unit: .gram)
        ],
        nutrition: Nutrition(kcal: 520, protein: 32, fat: 38, carbs: 8, fiber: 2, salt: 2)
    )

    static let tomatoSoup = Recipe(
        name: "Zupa pomidorowa",
        description: "Klasyczna pomidorowa z makaronem.",
        favourite: false,
        category: .lunch,
        servings: 4,
        prepTimeMinutes: 30,
        difficulty: .easy,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Pomidory", amount: 800, unit: .gram),
            Ingredient(name: "Bulion warzywny", amount: 1, unit: .liter),
            Ingredient(name: "Makaron", amount: 200, unit: .gram),
            Ingredient(name: "Śmietanka", amount: 50, unit: .milliliter)
        ],
        nutrition: Nutrition(kcal: 1200, protein: 40, fat: 20, carbs: 200, fiber: 12, salt: 5)
    )

    static let chickenBowl = Recipe(
        name: "Miska z kurczakiem i ryżem",
        description: "Wysokobiałkowy posiłek z warzywami.",
        favourite: true,
        category: .dinner,
        servings: 2,
        prepTimeMinutes: 25,
        difficulty: .medium,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Pierś z kurczaka", amount: 300, unit: .gram),
            Ingredient(name: "Ryż basmati (suchy)", amount: 150, unit: .gram),
            Ingredient(name: "Brokuł", amount: 200, unit: .gram),
            Ingredient(name: "Oliwa", amount: 10, unit: .gram),
            Ingredient(name: "Przyprawy", amount: 1, unit: .teaspoon)
        ],
        nutrition: Nutrition(kcal: 1250, protein: 85, fat: 30, carbs: 150, fiber: 10, salt: 2)
    )

    static let pancakes = Recipe(
        name: "Placki bananowe",
        description: "Szybkie, słodkie śniadanie na bazie banana i jajka.",
        favourite: false,
        category: .breakfast,
        servings: 2,
        prepTimeMinutes: 15,
        difficulty: .easy,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Banany", amount: 2, unit: .piece),
            Ingredient(name: "Jajka", amount: 2, unit: .piece),
            Ingredient(name: "Płatki owsiane", amount: 60, unit: .gram),
            Ingredient(name: "Jogurt naturalny", amount: 100, unit: .gram)
        ],
        nutrition: Nutrition(kcal: 700, protein: 28, fat: 18, carbs: 110, fiber: 9, salt: 1.2)
    )

    static let all: [Recipe] = [
        omelette,
        tomatoSoup,
        chickenBowl,
        pancakes
    ]
}

