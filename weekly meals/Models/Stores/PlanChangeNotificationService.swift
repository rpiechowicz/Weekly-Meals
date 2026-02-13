import Foundation
import UserNotifications

enum PlanChangeNotificationService {
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func notifyRemotePlanChange(action: String?, weekStart: String, changedByDisplayName: String?) {
        guard isNotificationsEnabled else { return }
        guard isPlanNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        let actor = (changedByDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? changedByDisplayName!
            : "Ktoś"
        content.title = "Aktualizacja planu posiłków"
        content.body = bodyText(for: action, weekStart: weekStart, actor: actor)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "plan-change-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func bodyText(for action: String?, weekStart: String, actor: String) -> String {
        switch action?.uppercased() {
        case "UPSERT_SLOT":
            return "\(actor) zaktualizował plan posiłków."
        case "REMOVE_SLOT":
            return "\(actor) usunął pozycję z planu posiłków."
        case "CLEAR_PLAN":
            return "\(actor) usunął cały plan posiłków."
        case "SAVE_PLAN":
            return "\(actor) zapisał plan posiłków."
        default:
            return "\(actor) zmienił plan posiłków."
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
