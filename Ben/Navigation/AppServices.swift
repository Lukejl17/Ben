import Foundation
import SwiftUI

/// Dependency container. UI-test launch arguments swap in deterministic fakes.
struct AppServices {
    var analytics: any AnalyticsService
    var parser: any BillParsing
    var scheduler: ReminderScheduler
    var subscriptions: any SubscriptionService
    var accounts: any AccountService
    var emailIn: any EmailInFetching

    static func live() -> AppServices {
        let emailIn = EmailInClient()
        return AppServices(
            analytics: LocalAnalytics(),
            parser: VisionBillParser(),
            scheduler: ReminderScheduler(),
            subscriptions: StubSubscriptionService(),
            accounts: FirebaseAccountService(emailIn: emailIn),
            emailIn: emailIn
        )
    }

    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> AppServices {
        var services = live()
        if arguments.contains("-mockParser") {
            services.parser = MockBillParser()
        }
        if arguments.contains("-failingParser") {
            services.parser = FailingBillParser()
        }
        if arguments.contains("-nullAnalytics") {
            services.analytics = NullAnalytics()
        }
        if arguments.contains("-freshAccount") {
            let suite = UserDefaults(suiteName: "ui-test-account")!
            suite.removePersistentDomain(forName: "ui-test-account")
            services.accounts = StubAccountService(defaults: suite)
            services.emailIn = MockEmailInClient()
        }
        if arguments.contains("-stubAccount") {
            services.accounts = StubAccountService()
            services.emailIn = MockEmailInClient()
        }
        if arguments.contains("-freshTrial") {
            let suite = UserDefaults(suiteName: "ui-test-trial")!
            suite.removePersistentDomain(forName: "ui-test-trial")
            services.subscriptions = StubSubscriptionService(defaults: suite)
        }
        return services
    }
}

private struct AppServicesKey: EnvironmentKey {
    static let defaultValue = AppServices(
        analytics: NullAnalytics(),
        parser: MockBillParser(),
        scheduler: ReminderScheduler(),
        subscriptions: StubSubscriptionService(),
        accounts: StubAccountService(),
        emailIn: MockEmailInClient()
    )
}

extension EnvironmentValues {
    var services: AppServices {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }
}
