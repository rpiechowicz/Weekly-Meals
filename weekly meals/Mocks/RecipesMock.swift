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

    static let avocadoToast = Recipe(
        name: "Tost z awokado",
        description: "Chrupiący tost z kremowym awokado i jajkiem.",
        favourite: false,
        category: .breakfast,
        servings: 1,
        prepTimeMinutes: 10,
        difficulty: .easy,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Pieczywo tostowe", amount: 2, unit: .piece),
            Ingredient(name: "Awokado", amount: 1, unit: .piece),
            Ingredient(name: "Jajko", amount: 1, unit: .piece),
            Ingredient(name: "Sok z cytryny", amount: 5, unit: .milliliter),
            Ingredient(name: "Sól", amount: 1, unit: .teaspoon),
            Ingredient(name: "Pieprz", amount: 1, unit: .teaspoon)
        ],
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Opiecz pieczywo na patelni lub w tosterze."),
            PreparationStep(stepNumber: 2, instruction: "Rozgnieć awokado z sokiem z cytryny, dopraw solą i pieprzem."),
            PreparationStep(stepNumber: 3, instruction: "Ugotuj jajko na miękko lub usmaż jajko sadzone."),
            PreparationStep(stepNumber: 4, instruction: "Posmaruj tosty awokado i dodaj jajko."),
            PreparationStep(stepNumber: 5, instruction: "Podawaj od razu.")
        ],
        nutrition: Nutrition(kcal: 450, protein: 16, fat: 28, carbs: 36, fiber: 8, salt: 1.5)
    )

    static let greekSalad = Recipe(
        name: "Sałatka grecka",
        description: "Klasyczna sałatka z fetą, oliwkami i warzywami.",
        favourite: false,
        category: .lunch,
        servings: 2,
        prepTimeMinutes: 15,
        difficulty: .easy,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Pomidory", amount: 200, unit: .gram),
            Ingredient(name: "Ogórek", amount: 150, unit: .gram),
            Ingredient(name: "Ser feta", amount: 100, unit: .gram),
            Ingredient(name: "Oliwki", amount: 50, unit: .gram),
            Ingredient(name: "Cebula czerwona", amount: 50, unit: .gram),
            Ingredient(name: "Oliwa", amount: 20, unit: .gram),
            Ingredient(name: "Oregano", amount: 1, unit: .teaspoon)
        ],
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Pokrój warzywa w większą kostkę."),
            PreparationStep(stepNumber: 2, instruction: "Dodaj pokruszoną fetę i oliwki."),
            PreparationStep(stepNumber: 3, instruction: "Skrop oliwą i dopraw oregano."),
            PreparationStep(stepNumber: 4, instruction: "Delikatnie wymieszaj i podawaj.")
        ],
        nutrition: Nutrition(kcal: 700, protein: 22, fat: 55, carbs: 30, fiber: 8, salt: 3)
    )

    static let spaghettiBolognese = Recipe(
        name: "Spaghetti bolognese",
        description: "Makaron z sosem pomidorowym i wołowiną.",
        favourite: false,
        category: .dinner,
        servings: 4,
        prepTimeMinutes: 45,
        difficulty: .medium,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Makaron spaghetti", amount: 400, unit: .gram),
            Ingredient(name: "Mięso mielone wołowe", amount: 500, unit: .gram),
            Ingredient(name: "Passata pomidorowa", amount: 500, unit: .milliliter),
            Ingredient(name: "Cebula", amount: 100, unit: .gram),
            Ingredient(name: "Czosnek", amount: 2, unit: .piece),
            Ingredient(name: "Oliwa", amount: 20, unit: .gram),
            Ingredient(name: "Przyprawy", amount: 2, unit: .teaspoon)
        ],
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Ugotuj makaron al dente zgodnie z instrukcją."),
            PreparationStep(stepNumber: 2, instruction: "Podsmaż cebulę i czosnek na oliwie."),
            PreparationStep(stepNumber: 3, instruction: "Dodaj mięso i smaż do zrumienienia."),
            PreparationStep(stepNumber: 4, instruction: "Wlej passatę, dopraw i duś 20–25 minut."),
            PreparationStep(stepNumber: 5, instruction: "Podawaj z makaronem." )
        ],
        nutrition: Nutrition(kcal: 2200, protein: 120, fat: 80, carbs: 260, fiber: 12, salt: 6)
    )

    static let veggieCurry = Recipe(
        name: "Warzywne curry",
        description: "Aromatyczne curry z warzywami i mlekiem kokosowym.",
        favourite: true,
        category: .dinner,
        servings: 4,
        prepTimeMinutes: 35,
        difficulty: .medium,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Mleko kokosowe", amount: 400, unit: .milliliter),
            Ingredient(name: "Ciecierzyca", amount: 240, unit: .gram),
            Ingredient(name: "Warzywa mieszane", amount: 400, unit: .gram),
            Ingredient(name: "Pasta curry", amount: 40, unit: .gram),
            Ingredient(name: "Ryż basmati (suchy)", amount: 200, unit: .gram),
            Ingredient(name: "Olej", amount: 10, unit: .gram)
        ],
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Podsmaż pastę curry na oleju."),
            PreparationStep(stepNumber: 2, instruction: "Dodaj warzywa i smaż kilka minut."),
            PreparationStep(stepNumber: 3, instruction: "Wlej mleko kokosowe i dodaj ciecierzycę."),
            PreparationStep(stepNumber: 4, instruction: "Gotuj 15–20 minut do miękkości warzyw."),
            PreparationStep(stepNumber: 5, instruction: "Podawaj z ugotowanym ryżem.")
        ],
        nutrition: Nutrition(kcal: 1900, protein: 60, fat: 90, carbs: 230, fiber: 20, salt: 5)
    )

    static let oatmealBerries = Recipe(
        name: "Owsianka z owocami",
        description: "Kremowa owsianka z bananem i jagodami.",
        favourite: false,
        category: .breakfast,
        servings: 2,
        prepTimeMinutes: 10,
        difficulty: .easy,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Płatki owsiane", amount: 100, unit: .gram),
            Ingredient(name: "Mleko", amount: 300, unit: .milliliter),
            Ingredient(name: "Banan", amount: 1, unit: .piece),
            Ingredient(name: "Jagody", amount: 100, unit: .gram),
            Ingredient(name: "Miód", amount: 20, unit: .gram)
        ],
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Ugotuj płatki w mleku do zgęstnienia."),
            PreparationStep(stepNumber: 2, instruction: "Dodaj pokrojonego banana i jagody."),
            PreparationStep(stepNumber: 3, instruction: "Dosłodź miodem i podawaj ciepłe.")
        ],
        nutrition: Nutrition(kcal: 700, protein: 20, fat: 12, carbs: 130, fiber: 10, salt: 0.6)
    )

    static let chickenCaesarWrap = Recipe(
        name: "Wrap z kurczakiem Caesar",
        description: "Sycący wrap z kurczakiem, sałatą i sosem Caesar.",
        favourite: true,
        category: .lunch,
        servings: 2,
        prepTimeMinutes: 20,
        difficulty: .easy,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Tortilla", amount: 2, unit: .piece),
            Ingredient(name: "Kurczak grillowany", amount: 200, unit: .gram),
            Ingredient(name: "Sałata rzymska", amount: 100, unit: .gram),
            Ingredient(name: "Sos Caesar", amount: 60, unit: .gram),
            Ingredient(name: "Parmezan", amount: 30, unit: .gram)
        ],
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Pokrój kurczaka w paski."),
            PreparationStep(stepNumber: 2, instruction: "Wymieszaj z sałatą, sosem i parmezanem."),
            PreparationStep(stepNumber: 3, instruction: "Zawiń farsz w tortille."),
            PreparationStep(stepNumber: 4, instruction: "Opcjonalnie podgrzej na suchej patelni.")
        ],
        nutrition: Nutrition(kcal: 1100, protein: 70, fat: 55, carbs: 90, fiber: 8, salt: 3)
    )

    static let salmonQuinoa = Recipe(
        name: "Łosoś z komosą ryżową",
        description: "Delikatny łosoś podany z komosą i brokułem.",
        favourite: false,
        category: .dinner,
        servings: 2,
        prepTimeMinutes: 30,
        difficulty: .medium,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Łosoś", amount: 300, unit: .gram),
            Ingredient(name: "Komosa ryżowa", amount: 150, unit: .gram),
            Ingredient(name: "Brokuł", amount: 200, unit: .gram),
            Ingredient(name: "Oliwa", amount: 10, unit: .gram),
            Ingredient(name: "Cytryna", amount: 1, unit: .piece),
            Ingredient(name: "Przyprawy", amount: 1, unit: .teaspoon)
        ],
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Ugotuj komosę ryżową zgodnie z instrukcją."),
            PreparationStep(stepNumber: 2, instruction: "Dopraw łososia i usmaż lub upiecz na złoto."),
            PreparationStep(stepNumber: 3, instruction: "Ugotuj brokuł na parze do miękkości."),
            PreparationStep(stepNumber: 4, instruction: "Podawaj łososia z komosą i brokułem, skrop sokiem z cytryny.")
        ],
        nutrition: Nutrition(kcal: 1200, protein: 80, fat: 45, carbs: 90, fiber: 10, salt: 2)
    )

    static let lentilSoup = Recipe(
        name: "Zupa z soczewicy",
        description: "Pożywna zupa na bazie czerwonej soczewicy.",
        favourite: false,
        category: .lunch,
        servings: 4,
        prepTimeMinutes: 40,
        difficulty: .easy,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Soczewica czerwona", amount: 250, unit: .gram),
            Ingredient(name: "Bulion warzywny", amount: 1, unit: .liter),
            Ingredient(name: "Marchew", amount: 150, unit: .gram),
            Ingredient(name: "Cebula", amount: 100, unit: .gram),
            Ingredient(name: "Pomidory krojone", amount: 400, unit: .gram),
            Ingredient(name: "Przyprawy", amount: 2, unit: .teaspoon)
        ],
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Podsmaż cebulę i marchew."),
            PreparationStep(stepNumber: 2, instruction: "Dodaj soczewicę i wymieszaj."),
            PreparationStep(stepNumber: 3, instruction: "Zalej bulionem i dodaj pomidory."),
            PreparationStep(stepNumber: 4, instruction: "Gotuj 20–25 minut do miękkości."),
            PreparationStep(stepNumber: 5, instruction: "Dopraw do smaku i podawaj.")
        ],
        nutrition: Nutrition(kcal: 1600, protein: 80, fat: 20, carbs: 260, fiber: 30, salt: 5)
    )

    static let scrambledEggs = Recipe(
        name: "Jajecznica ze szczypiorkiem",
        description: "Puszysta jajecznica z masłem i świeżym szczypiorkiem.",
        favourite: false,
        category: .breakfast,
        servings: 2,
        prepTimeMinutes: 10,
        difficulty: .easy,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Jajka", amount: 4, unit: .piece),
            Ingredient(name: "Masło", amount: 10, unit: .gram),
            Ingredient(name: "Szczypiorek", amount: 10, unit: .gram),
            Ingredient(name: "Sól", amount: 1, unit: .teaspoon),
            Ingredient(name: "Pieprz", amount: 1, unit: .teaspoon)
        ],
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Roztrzep jajka w misce."),
            PreparationStep(stepNumber: 2, instruction: "Rozpuść masło na patelni."),
            PreparationStep(stepNumber: 3, instruction: "Smaż jajka na małym ogniu, mieszając."),
            PreparationStep(stepNumber: 4, instruction: "Dodaj posiekany szczypiorek."),
            PreparationStep(stepNumber: 5, instruction: "Dopraw solą i pieprzem.")
        ],
        nutrition: Nutrition(kcal: 500, protein: 28, fat: 40, carbs: 2, fiber: 1, salt: 2)
    )

    static let beefStirFry = Recipe(
        name: "Wołowina stir-fry z warzywami",
        description: "Szybkie danie z wok’a z makaronem ryżowym.",
        favourite: false,
        category: .dinner,
        servings: 3,
        prepTimeMinutes: 25,
        difficulty: .medium,
        imageURL: nil,
        ingredients: [
            Ingredient(name: "Wołowina", amount: 400, unit: .gram),
            Ingredient(name: "Papryka", amount: 200, unit: .gram),
            Ingredient(name: "Cebula", amount: 100, unit: .gram),
            Ingredient(name: "Sos sojowy", amount: 30, unit: .milliliter),
            Ingredient(name: "Makaron ryżowy (suchy)", amount: 200, unit: .gram),
            Ingredient(name: "Olej", amount: 10, unit: .gram),
            Ingredient(name: "Czosnek", amount: 2, unit: .piece)
        ],
        preparationSteps: [
            PreparationStep(stepNumber: 1, instruction: "Rozgrzej olej na patelni lub woku."),
            PreparationStep(stepNumber: 2, instruction: "Smaż wołowinę do zrumienienia."),
            PreparationStep(stepNumber: 3, instruction: "Dodaj warzywa i smaż 3–4 minuty."),
            PreparationStep(stepNumber: 4, instruction: "Dodaj czosnek i sos sojowy, wymieszaj."),
            PreparationStep(stepNumber: 5, instruction: "Ugotuj makaron ryżowy i połącz z mięsem i warzywami.")
        ],
        nutrition: Nutrition(kcal: 1800, protein: 90, fat: 50, carbs: 230, fiber: 8, salt: 6)
    )

    static let all: [Recipe] = [
        omelette,
        tomatoSoup,
        chickenBowl,
        pancakes,
        avocadoToast,
        greekSalad,
        spaghettiBolognese,
        veggieCurry,
        oatmealBerries,
        chickenCaesarWrap,
        salmonQuinoa,
        lentilSoup,
        scrambledEggs,
        beefStirFry
    ]
}

