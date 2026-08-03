import FirebaseCore
import GoogleSignIn
import SwiftData
import SwiftUI
import UserNotifications

@main
struct BenApp: App {
    @State private var coordinator = OnboardingCoordinator()
    @State private var router: NotificationRouter
    @State private var pendingEmailMonitor = PendingEmailMonitor()
    private let services: AppServices
    private let notificationDelegate: NotificationDelegate

    init() {
        // Real logins need Firebase; previews/tests run fine without it.
        if FirebaseApp.app() == nil,
           Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        let services = AppServices.fromLaunchArguments()
        let router = NotificationRouter()
        let delegate = NotificationDelegate(router: router, analytics: services.analytics)
        UNUserNotificationCenter.current().delegate = delegate
        // "Remind me tomorrow" on every bill reminder.
        let snooze = UNNotificationAction(identifier: "snooze_tomorrow", title: "Remind me tomorrow")
        let category = UNNotificationCategory(
            identifier: "bill_reminder", actions: [snooze], intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
        self.services = services
        self._router = State(initialValue: router)
        self.notificationDelegate = delegate
        Self.applyForestBoldChrome()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
                .environment(router)
                .environment(pendingEmailMonitor)
                .environment(\.services, services)
                .tint(.chartreuse)
                .background(Color.forestBottom)
                // Forest Bold is one committed world — no light variant.
                .preferredColorScheme(.dark)
                // Google Sign-In returns via the reversed client ID URL scheme.
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(Self.makeContainer())
    }

    /// Nav titles and tab bar in Baloo/forest — SwiftUI has no direct hooks for these.
    private static func applyForestBoldChrome() {
        let cream = UIColor(red: 0.973, green: 0.945, blue: 0.871, alpha: 1)      // F8F1DE
        let chartreuse = UIColor(red: 0.827, green: 0.914, blue: 0.478, alpha: 1) // D3E97A
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        if let large = UIFont(name: "Baloo2-ExtraBold", size: 34) {
            nav.largeTitleTextAttributes = [.font: large, .foregroundColor: chartreuse]
        }
        if let inline = UIFont(name: "Baloo2-Bold", size: 17) {
            nav.titleTextAttributes = [.font: inline, .foregroundColor: cream]
        }
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav

        if let tabFont = UIFont(name: "Baloo2-Bold", size: 11) {
            let item = UITabBarItemAppearance()
            item.normal.titleTextAttributes = [.font: tabFont]
            item.selected.titleTextAttributes = [.font: tabFont]
            let tab = UITabBarAppearance()
            tab.stackedLayoutAppearance = item
            tab.inlineLayoutAppearance = item
            tab.compactInlineLayoutAppearance = item
            UITabBar.appearance().standardAppearance = tab
        }
    }

    private static func makeContainer() -> ModelContainer {
        let inMemory = ProcessInfo.processInfo.arguments.contains("-inMemoryStore")
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: Bill.self, configurations: configuration)
        } catch {
            // Last resort: an in-memory store beats crashing on first launch.
            return try! ModelContainer(  // swiftlint:disable:this force_try
                for: Bill.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }
}
