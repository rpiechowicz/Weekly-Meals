import Foundation

struct ProductConstants {
    // Działy w sklepie (kategorie wysokiego poziomu)
    struct Department {
        static let vegetables = "Warzywa"
        static let fruits = "Owoce"
        static let meat = "Mięso"
        static let fish = "Ryby"
        static let bakery = "Piekarnia"
        static let dairy = "Nabiał"
        static let grains = "Zboża i makarony"
        static let canned = "Konserwy"
        static let beverages = "Napoje"
        static let snacks = "Przekąski i słodycze"
        static let household = "Chemia i gospodarstwo"
        static let frozen = "Mrożonki"
        static let spices = "Przyprawy i sosy"
        static let oils = "Olej i tłuszcze"
        static let bakerySweets = "Cukiernia"
        static let other = "Inne"
    }

    // Mapowanie produktu -> dział sklepu
    static let productToDepartment: [String: String] = [
        // Warzywa
        "Marchew": Department.vegetables,
        "Ziemniaki": Department.vegetables,
        "Cebula": Department.vegetables,
        "Czosnek": Department.vegetables,
        "Papryka": Department.vegetables,
        "Ogórek": Department.vegetables,
        "Pomidory": Department.vegetables,
        "Sałata": Department.vegetables,
        "Szpinak": Department.vegetables,
        "Brokuł": Department.vegetables,
        "Kalafior": Department.vegetables,
        "Cukinia": Department.vegetables,
        "Bakłażan": Department.vegetables,
        "Buraki": Department.vegetables,

        // Owoce
        "Jabłka": Department.fruits,
        "Banany": Department.fruits,
        "Pomarańcze": Department.fruits,
        "Cytryny": Department.fruits,
        "Truskawki": Department.fruits,
        "Winogrona": Department.fruits,
        "Borówki": Department.fruits,
        "Maliny": Department.fruits,
        "Gruszki": Department.fruits,
        "Ananas": Department.fruits,

        // Mięso i ryby
        "Pierś z kurczaka": Department.meat,
        "Udko z kurczaka": Department.meat,
        "Wołowina": Department.meat,
        "Wieprzowina": Department.meat,
        "Indyk": Department.meat,
        "Kiełbasa": Department.meat,
        "Szynka": Department.meat,
        "Boczek": Department.meat,
        "Łosoś": Department.fish,
        "Dorsz": Department.fish,
        "Tuńczyk (świeży)": Department.fish,

        // Nabiał
        "Mleko": Department.dairy,
        "Jogurt": Department.dairy,
        "Masło": Department.dairy,
        "Śmietana": Department.dairy,
        "Ser żółty": Department.dairy,
        "Twaróg": Department.dairy,
        "Mozzarella": Department.dairy,
        "Jajka": Department.dairy,

        // Zboża i makarony
        "Chleb": Department.bakery,
        "Bułki": Department.bakery,
        "Tortilla": Department.bakery,
        "Makaron": Department.grains,
        "Ryż": Department.grains,
        "Kasza": Department.grains,
        "Płatki owsiane": Department.grains,
        "Mąka": Department.grains,

        // Konserwy i słoiki
        "Fasola konserwowa": Department.canned,
        "Ciecierzyca konserwowa": Department.canned,
        "Pomidory krojone (puszka)": Department.canned,
        "Tuńczyk (puszka)": Department.canned,
        "Kukurydza (puszka)": Department.canned,
        "Ogórki kiszone": Department.canned,

        // Napoje
        "Woda": Department.beverages,
        "Sok": Department.beverages,
        "Kawa": Department.beverages,
        "Herbata": Department.beverages,

        // Przekąski i słodycze
        "Czekolada": Department.snacks,
        "Ciastka": Department.snacks,
        "Chipsy": Department.snacks,
        "Orzechy": Department.snacks,
        "Baton": Department.snacks,

        // Przyprawy i sosy
        "Sól": Department.spices,
        "Pieprz": Department.spices,
        "Papryka słodka": Department.spices,
        "Curry": Department.spices,
        "Ketchup": Department.spices,
        "Musztarda": Department.spices,
        "Majonez": Department.spices,
        "Sos sojowy": Department.spices,
        "Ocet": Department.spices,

        // Oleje i tłuszcze
        "Oliwa z oliwek": Department.oils,
        "Olej rzepakowy": Department.oils,
        "Masło klarowane": Department.oils,

        // Mrożonki
        "Warzywa mrożone": Department.frozen,
        "Owoce mrożone": Department.frozen,
        "Lody": Department.frozen,

        // Chemia i gospodarstwo
        "Papier toaletowy": Department.household,
        "Ręczniki papierowe": Department.household,
        "Płyn do naczyń": Department.household,
        "Proszek do prania": Department.household,
        "Worki na śmieci": Department.household,
    ]

    // Pomocnicze API
    static func department(for productName: String) -> String {
        return productToDepartment[productName] ?? Department.other
    }

    static func products(in department: String) -> [String] {
        return productToDepartment
            .filter { $0.value == department }
            .map { $0.key }
            .sorted()
    }
}
