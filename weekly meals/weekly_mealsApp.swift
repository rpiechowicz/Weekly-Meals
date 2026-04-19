//
//  weekly_mealsApp.swift
//  weekly meals
//
//  Created by Rafi on 03/02/2026.
//

import Foundation
import SwiftUI
import UserNotifications

enum AppEnvironment {
    /// Adres backendu. Kolejność priorytetów:
    /// 1. Zmienna środowiskowa API_BASE_URL (przydatna przy lokalnym debugowaniu)
    /// 2. Info.plist → klucz API_BASE_URL (domyślnie produkcja)
    /// 3. Bezpieczny fallback: produkcja
    static let apiBaseURL: URL = {
        if let envRaw = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: envRaw) {
            return url
        }
        if let plistRaw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !plistRaw.isEmpty,
           let url = URL(string: plistRaw) {
            return url
        }
        return URL(string: "https://weakly-meals-backend-production.up.railway.app")!
    }()
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var sessionStore: SessionStore?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        PlanChangeNotificationService.requestAuthorizationIfNeeded()
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        sessionStore?.updatePushDeviceToken(token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Ignore in simulator/dev without APNs entitlement.
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct weekly_mealsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var sessionStore = SessionStore()
    @AppStorage("settings.theme") private var themeRawValue: String = AppTheme.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if sessionStore.isAuthenticated,
                   let mealStore = sessionStore.weeklyMealStore,
                   let recipeCatalogStore = sessionStore.recipeCatalogStore,
                   let shoppingListStore = sessionStore.shoppingListStore {
                    DashboardView()
                        .environment(\.weeklyMealStore, mealStore)
                        .environment(\.datesViewModel, sessionStore.datesViewModel)
                        .environment(\.recipeCatalogStore, recipeCatalogStore)
                        .environment(\.shoppingListStore, shoppingListStore)
                } else if sessionStore.isAuthenticated {
                    NoHouseholdView(
                        isLoading: sessionStore.isSigningIn,
                        errorMessage: sessionStore.authError,
                        onCreate: { name in
                            Task {
                                await sessionStore.createHousehold(name: name)
                            }
                        },
                        onLogout: {
                            sessionStore.logout()
                        }
                    )
                } else {
                    AuthView(
                        isLoading: sessionStore.isSigningIn,
                        errorMessage: sessionStore.authError,
                        onSignInWithAppleTap: {
                            Task {
                                await sessionStore.signInWithApple()
                            }
                        }
                    )
                }
            }
            .environment(\.sessionStore, sessionStore)
            .preferredColorScheme((AppTheme(rawValue: themeRawValue) ?? .system).colorScheme)
            .onAppear {
                appDelegate.sessionStore = sessionStore
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    sessionStore.refreshRealtimeStoresOnForeground()
                }
            }
            .onOpenURL { url in
                sessionStore.handleIncomingURL(url)
            }
            .alert(
                "Dołączyć do gospodarstwa?",
                isPresented: Binding(
                    get: { sessionStore.invitationPrompt != nil },
                    set: { isPresented in
                        if !isPresented {
                            sessionStore.dismissInvitationPrompt()
                        }
                    }
                ),
                presenting: sessionStore.invitationPrompt
            ) { prompt in
                Button("Nie teraz", role: .cancel) {
                    sessionStore.dismissInvitationPrompt()
                }
                Button("Dołącz") {
                    Task {
                        await sessionStore.acceptPendingInvitation(token: prompt.token)
                    }
                }
            } message: { prompt in
                Text(prompt.message)
            }
        }
    }
}
