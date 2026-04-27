import SwiftUI

// User's primary eating-style preference. Stored in `@AppStorage` as the
// raw value, so adding cases later is non-breaking — unknown ids fall
// back to `.none`. Used by Settings → Dieta i alergeny and (eventually)
// by the recipe-suggestions backend.
enum DietPreference: String, CaseIterable, Identifiable {
    case none
    case vegetarian
    case vegan
    case pescatarian
    case keto
    case paleo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:         return "Bez ograniczeń"
        case .vegetarian:   return "Wegetariańska"
        case .vegan:        return "Wegańska"
        case .pescatarian:  return "Pescetariańska"
        case .keto:         return "Ketogeniczna"
        case .paleo:        return "Paleo"
        }
    }

    var subtitle: String {
        switch self {
        case .none:         return "Aplikacja proponuje wszystkie przepisy."
        case .vegetarian:   return "Bez mięsa i ryb."
        case .vegan:        return "Bez produktów odzwierzęcych."
        case .pescatarian:  return "Bez mięsa, z rybami i owocami morza."
        case .keto:         return "Bardzo niska zawartość węglowodanów."
        case .paleo:        return "Bez zbóż, nabiału i przetworzonej żywności."
        }
    }

    var icon: String {
        switch self {
        case .none:         return "fork.knife"
        case .vegetarian:   return "leaf.fill"
        case .vegan:        return "carrot.fill"
        case .pescatarian:  return "fish.fill"
        case .keto:         return "flame.fill"
        case .paleo:        return "hare.fill"
        }
    }

    var accent: Color {
        switch self {
        case .none:         return WMPalette.terracotta
        case .vegetarian:   return WMPalette.sage
        case .vegan:        return WMPalette.sage
        case .pescatarian:  return WMPalette.indigo
        case .keto:         return WMPalette.terracotta
        case .paleo:        return WMPalette.butter
        }
    }
}

// 14 official EU allergens trimmed to the 10 most-common in everyday
// Polish cooking. Multi-select; persisted in `@AppStorage` as a sorted
// comma-separated raw-value string (`"eggs,gluten,nuts"`).
enum Allergen: String, CaseIterable, Identifiable {
    case gluten
    case lactose
    case nuts
    case peanuts
    case eggs
    case soy
    case fish
    case shellfish
    case sesame
    case celery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gluten:       return "Gluten"
        case .lactose:      return "Laktoza"
        case .nuts:         return "Orzechy"
        case .peanuts:      return "Orzeszki ziemne"
        case .eggs:         return "Jaja"
        case .soy:          return "Soja"
        case .fish:         return "Ryby"
        case .shellfish:    return "Skorupiaki"
        case .sesame:       return "Sezam"
        case .celery:       return "Seler"
        }
    }
}
