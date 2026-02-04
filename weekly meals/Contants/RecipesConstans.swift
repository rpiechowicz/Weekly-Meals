import Foundation
/// Stałe i pomocnicze funkcje związane z widokiem/przepisami.
enum RecipesConstants {
    /// Polski tytuł dla kategorii przepisu.
    /// Uzupełnij mapowanie zgodnie z wartościami enum `RecipesCategory` w projekcie.
    static func displayName(for category: RecipesCategory) -> String {
        switch category {
        case .all:
            return "Wszystkie"
        case .favourite:
            return "Ulubione"
        case .breakfast:
            return "Śniadania"
        case .lunch:
            return "Obiady"
        case .dinner:
            return "Kolacje"
        @unknown default:
            return String(describing: category)
        }
    }
}

