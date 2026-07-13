import SwiftData
import SwiftUI

@main
struct BenApp: App {
    @State private var coordinator = OnboardingCoordinator()
    private let services = AppServices.fromLaunchArguments()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
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
