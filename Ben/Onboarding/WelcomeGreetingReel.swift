import SwiftUI
import UIKit

/// S1 greeting wheel — continuous reel that races past hellos then ease-outs
/// onto the device-region word. Stacked above "I'm Ben."
struct WelcomeGreetingReel: View {
    var locale: Locale = .current

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var strip: [String] = [WelcomeGreeting.display(WelcomeGreeting.brand)]
    @State private var offset: CGFloat = 0

    private let fontSize: CGFloat = 44
    private var rowHeight: CGFloat { fontSize * 1.1 }
    private let titleFont = Font.baloo("Baloo2-ExtraBold", 44, relativeTo: .largeTitle)

    private var targetWord: String {
        WelcomeGreeting.word(locale: locale)
    }

    private var slotWidth: CGFloat {
        WelcomeGreeting.allWords
            .map { textWidth(WelcomeGreeting.display($0)) }
            .max() ?? textWidth(WelcomeGreeting.display(WelcomeGreeting.brand))
    }

    var body: some View {
        VStack(spacing: 0) {
            reelWindow
                .frame(width: slotWidth, height: rowHeight)
                .accessibilityHidden(true)

            Text("I'm Ben.")
                .font(titleFont)
                .foregroundStyle(Color.chartreuse)
                .accessibilityHidden(true)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(targetWord), I'm Ben.")
        .task(id: locale.identifier) {
            await play()
        }
    }

    private var reelWindow: some View {
        VStack(spacing: 0) {
            ForEach(Array(strip.enumerated()), id: \.offset) { _, word in
                Text(word)
                    .font(titleFont)
                    .foregroundStyle(Color.chartreuse)
                    .frame(width: slotWidth, height: rowHeight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .offset(y: offset)
        .frame(width: slotWidth, height: rowHeight, alignment: .top)
        .clipped()
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.22),
                    .init(color: .black, location: 0.78),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func play() async {
        let landing = targetWord
        let built = WelcomeGreeting.reelStrip(landingOn: landing)
        strip = built
        offset = 0

        if reduceMotion || built.count <= 1 {
            offset = -CGFloat(max(built.count - 1, 0)) * rowHeight
            return
        }

        // Brand hold so G'day registers before the wheel turns.
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled else { return }

        let endIndex = built.count - 1
        let duration = 2.2
        let start = Date()

        // Ease-out quint — races early, settles onto the region hello.
        while !Task.isCancelled {
            let progress = min(1, Date().timeIntervalSince(start) / duration)
            let eased = 1 - pow(1 - progress, 5)
            offset = -CGFloat(endIndex) * rowHeight * eased
            if progress >= 1 { break }
            try? await Task.sleep(for: .milliseconds(16))
        }
        offset = -CGFloat(endIndex) * rowHeight
    }

    private func textWidth(_ string: String) -> CGFloat {
        let font = UIFont(name: "Baloo2-ExtraBold", size: fontSize)
            ?? .systemFont(ofSize: fontSize, weight: .heavy)
        return ceil((string as NSString).size(withAttributes: [.font: font]).width) + 4
    }
}
