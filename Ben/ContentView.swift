import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.benCanvas.ignoresSafeArea()
            BenVoiceText(text: "G'day — I'm Ben.")
        }
    }
}

#Preview {
    ContentView()
}
