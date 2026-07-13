import Foundation
import SwiftUI

/// Dependency container. UI-test launch arguments swap in deterministic fakes.
struct AppServices {
    var analytics: any AnalyticsService
    var parser: any BillParsing
    var scheduler: ReminderScheduler

    static func live() -> AppServices {
        AppServices(analytics: LocalAnalytics(), parser: VisionBillParser(), scheduler: ReminderScheduler())
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
        return services
    }
}

private struct AppServicesKey: EnvironmentKey {
    static let defaultValue = AppServices(
        analytics: NullAnalytics(),
        parser: MockBillParser(),
        scheduler: ReminderScheduler()
    )
}

extension EnvironmentValues {
    var services: AppServices {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }
}
