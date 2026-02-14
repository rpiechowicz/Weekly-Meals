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
