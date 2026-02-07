import Foundation
/// Stałe i pomocnicze funkcje związane z widokiem/przepisami.
enum RecipesConstants {
    /// Polski tytuł dla kategorii przepisu.
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

    /// Ikona SF Symbol dla kategorii przepisu.
    static func icon(for category: RecipesCategory) -> String {
        switch category {
        case .all:       return "square.grid.2x2"
        case .favourite: return "heart.fill"
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "fork.knife"
        case .dinner:    return "moon.stars.fill"
        @unknown default: return "questionmark.circle"
        }
    }
}

