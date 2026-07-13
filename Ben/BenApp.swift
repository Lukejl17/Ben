import SwiftUI
import SwiftData

@main
struct BenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.benAccent)
                .background(Color.benCanvas)
        }
    }
}
