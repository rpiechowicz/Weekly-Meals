import Foundation
import UserNotifications

enum PlanChangeNotificationService {
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func notifyRemotePlanChange(
        action: String?,
        weekStart: String,
        changedByDisplayName: String?,
        dayOfWeek: String? = nil,
        mealType: String? = nil
    ) {
        guard isNotificationsEnabled else { return }
        guard isPlanNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        let actor = (changedByDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? changedByDisplayName!
            : "Ktoś"
        content.title = "Aktualizacja planu posiłków"
        content.body = bodyText(for: action, weekStart: weekStart, actor: actor, dayOfWeek: dayOfWeek, mealType: mealType)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "plan-change-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func bodyText(
        for action: String?,
        weekStart: String,
        actor: String,
        dayOfWeek: String?,
        mealType: String?
    ) -> String {
        let meal = mapMealType(mealType).lowercased()
        let day = mapDayOfWeek(dayOfWeek).lowercased()

        switch action?.uppercased() {
        case "UPSERT_SLOT":
            if dayOfWeek != nil, mealType != nil {
                return "\(actor) edytował plan \(meal) na \(day)."
            }
            return "\(actor) zaktualizował plan posiłków."
        case "REMOVE_SLOT":
            if dayOfWeek != nil, mealType != nil {
                return "\(actor) usunął \(meal) z planu na \(day)."
            }
            return "\(actor) usunął pozycję z planu posiłków."
        case "CLEAR_PLAN":
            return "\(actor) usunął plan posiłków na ten tydzień."
        case "SAVE_PLAN":
            return "\(actor) ustawił plan posiłków na ten tydzień."
        default:
            return "\(actor) zmienił plan posiłków."
        }
    }

    private static func mapMealType(_ value: String?) -> String {
        switch value?.uppercased() {
        case "BREAKFAST":
            return "Śniadanie"
        case "LUNCH":
            return "Obiad"
        case "DINNER":
            return "Kolację"
        default:
            return "Posiłek"
        }
    }

    private static func mapDayOfWeek(_ value: String?) -> String {
        switch value?.uppercased() {
        case "MON":
            return "Poniedziałek"
        case "TUE":
            return "Wtorek"
        case "WED":
            return "Środę"
        case "THU":
            return "Czwartek"
        case "FRI":
            return "Piątek"
        case "SAT":
            return "Sobotę"
        case "SUN":
            return "Niedzielę"
        default:
            return "wybrany dzień"
        }
    }

    private static var isNotificationsEnabled: Bool {
        let defaults = UserDefaults.standard
        let key = "settings.notifications.enabled"
        if defaults.object(forKey: key) == nil { return true }
        return defaults.bool(forKey: key)
    }

    private static var isPlanNotificationsEnabled: Bool {
        let defaults = UserDefaults.standard
        let key = "settings.notifications.planReminders"
        if defaults.object(forKey: key) == nil { return true }
        return defaults.bool(forKey: key)
    }
}

enum ShoppingListNotificationService {
    static func notifyRemoteShoppingListChange(
        action: String?,
        changedByDisplayName: String?,
        isChecked: Bool? = nil
    ) {
        guard isNotificationsEnabled else { return }
        guard isShoppingNotificationsEnabled else { return }

        let actor = (changedByDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? changedByDisplayName!
            : "Ktoś"

        guard let body = bodyText(for: action, actor: actor, isChecked: isChecked) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Aktualizacja listy zakupów"
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "shopping-list-change-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func bodyText(for action: String?, actor: String, isChecked: Bool?) -> String? {
        switch action?.uppercased() {
        case "SET_ITEM_CHECKED":
            if isChecked == false {
                return "\(actor) przywrócił produkt na liście zakupów do kupienia."
            }
            return "\(actor) oznaczył produkt na liście zakupów jako kupiony."
        case "ARCHIVE_LIST":
            return "\(actor) zamknął listę zakupów."
        case "SELECT_ARCHIVE":
            return "\(actor) przywrócił wcześniejszą listę zakupów."
        case "DELETE_ARCHIVE":
            return "\(actor) usunął listę zakupów z historii."
        case "DELETE_ALL_ARCHIVES":
            return "\(actor) wyczyścił historię list zakupów."
        case "UPSERT_SLOT", "REMOVE_SLOT", "SAVE_PLAN", "CLEAR_PLAN":
            guard !isPlanNotificationsEnabled else { return nil }
            return "\(actor) zmienił plan posiłków, więc lista zakupów została odświeżona."
        case .none:
            return nil
        default:
            return "\(actor) zaktualizował listę zakupów."
        }
    }

    private static var isNotificationsEnabled: Bool {
        let defaults = UserDefaults.standard
        let key = "settings.notifications.enabled"
        if defaults.object(forKey: key) == nil { return true }
        return defaults.bool(forKey: key)
    }

    private static var isShoppingNotificationsEnabled: Bool {
        let defaults = UserDefaults.standard
        let key = "settings.notifications.shoppingReminders"
        if defaults.object(forKey: key) == nil { return true }
        return defaults.bool(forKey: key)
    }

    private static var isPlanNotificationsEnabled: Bool {
        let defaults = UserDefaults.standard
        let key = "settings.notifications.planReminders"
        if defaults.object(forKey: key) == nil { return true }
        return defaults.bool(forKey: key)
    }
}
