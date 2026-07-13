import SwiftData
import SwiftUI
import UserNotifications

@main
struct BenApp: App {
    @State private var coordinator = OnboardingCoordinator()
    @State private var router: NotificationRouter
    private let services: AppServices
    private let notificationDelegate: NotificationDelegate

    init() {
        let services = AppServices.fromLaunchArguments()
        let router = NotificationRouter()
        let delegate = NotificationDelegate(router: router, analytics: services.analytics)
        UNUserNotificationCenter.current().delegate = delegate
        self.services = services
        self._router = State(initialValue: router)
        self.notificationDelegate = delegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
                .environment(router)
                .environment(\.services, services)
                .tint(.benAccent)
                .background(Color.benCanvas)
        }
        .modelContainer(Self.makeContainer())
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
