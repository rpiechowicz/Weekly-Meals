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
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Pokrój papryką w drobną kostkę, a szpinak posiekaj."),
            PreparationStep(stepNumber: 2, instruction: "Rozbij jajka do miski i ubij je widelcem na gładką masę."),
            PreparationStep(stepNumber: 3, instruction: "Rozgrzej patelnię z masłem na średnim ogniu."),
            PreparationStep(stepNumber: 4, instruction: "Podsmaż papryką przez 2-3 minuty, następnie dodaj szpinak."),
            PreparationStep(stepNumber: 5, instruction: "Wlej jajka na patelnię i smaż przez około 3 minuty, aż zaczną się ściskać."),
            PreparationStep(stepNumber: 6, instruction: "Posyp pokruszonym serem feta i złóż omlet na pół. Smaż jeszcze minutę.")
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
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Obierz pomidory ze skórki, sparzone wcześniej we wrzątku."),
            PreparationStep(stepNumber: 2, instruction: "Pokrój pomidory i zblenduj na gładką masę."),
            PreparationStep(stepNumber: 3, instruction: "W garnku zagotuj bulion warzywny."),
            PreparationStep(stepNumber: 4, instruction: "Dodaj zblendowane pomidory do bulionu i gotuj 15 minut."),
            PreparationStep(stepNumber: 5, instruction: "Oddzielnie ugotuj makaron zgodnie z instrukcją na opakowaniu."),
            PreparationStep(stepNumber: 6, instruction: "Dodaj śmietankę do zupy, wymieszaj i dopraw solą i pieprzem."),
            PreparationStep(stepNumber: 7, instruction: "Podawaj zupę z ugotowanym makaronem.")
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
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Ugotuj ryż basmati zgodnie z instrukcją na opakowaniu."),
            PreparationStep(stepNumber: 2, instruction: "Pokrój pierś z kurczaka na mniejsze kawałki i przypraw solą, pieprzem oraz ulubionymi przyprawami."),
            PreparationStep(stepNumber: 3, instruction: "Rozgrzej patelnię z oliwą na średnim ogniu."),
            PreparationStep(stepNumber: 4, instruction: "Smaż kurczaka przez około 8-10 minut, aż będzie złocisty i dobrze wysmażony."),
            PreparationStep(stepNumber: 5, instruction: "Ugotuj brokuły na parze przez 5-7 minut, aby były miękkie, ale chrupiące."),
            PreparationStep(stepNumber: 6, instruction: "Ułóż w misce ryż, dodaj kurczaka i brokuły. Możesz polać sosem na bazie sosu sojowego lub naturalnym jogurtem.")
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
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Rozgnieć banany widelcem na gładką masę."),
            PreparationStep(stepNumber: 2, instruction: "Dodaj jajka i płatki owsiane do bananów, dokładnie wymieszaj."),
            PreparationStep(stepNumber: 3, instruction: "Opcjonalnie dodaj szczyptę cynamonu dla lepszego smaku."),
            PreparationStep(stepNumber: 4, instruction: "Rozgrzej patelnię na średnim ogniu (możesz użyć odrobiny masła lub oleju)."),
            PreparationStep(stepNumber: 5, instruction: "Nakładaj łyżką porcje ciasta na patelnię i smaż około 2-3 minuty z każdej strony, aż będą złociste."),
            PreparationStep(stepNumber: 6, instruction: "Podawaj z jogurtem naturalnym, owocami lub miodem.")
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

