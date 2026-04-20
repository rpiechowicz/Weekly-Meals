import SwiftUI

enum MealSlot: String, CaseIterable, Identifiable, Codable {
    case breakfast
    case lunch
    case dinner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: return "Śniadanie"
        case .lunch: return "Obiad"
        case .dinner: return "Kolacja"
        }
    }

    var time: String {
        switch self {
        case .breakfast: return "08:00"
        case .lunch: return "16:00"
        case .dinner: return "20:00"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "fork.knife"
        case .dinner: return "moon.stars.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch: return .blue
        case .dinner: return .purple
        }
    }

    var secondaryAccentColor: Color {
        switch self {
        case .breakfast: return .yellow
        case .lunch: return .cyan
        case .dinner: return .indigo
        }
    }
}
