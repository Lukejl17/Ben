import SwiftUI

/// Screen 6 — their monthly answer, multiplied out to a year. The number
/// spins up odometer-style and ticks to a stop.
struct StatMathsView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator

    var body: some View {
        let volume = coordinator.volume ?? .lostCount
        BenScreen {
            VStack(spacing: 16) {
                Spacer(minLength: 12)
                Text("Here's what that means.")
                    .font(.baloo("Baloo2-ExtraBold", 29, relativeTo: .title))
                    .foregroundStyle(Color.chartreuse)
                    .multilineTextAlignment(.center)
                BenCard(padding: 24) {
                    VStack(spacing: 6) {
                        BenEyebrow(text: "Due dates a year, roughly")
                        SpinNumber(mode: .countUp(
                            to: volume.dueDatesPerYear,
                            suffix: volume.isEstimate ? "+" : ""
                        ))
                        Text(OnboardingCopy.mathsSub(volume))
                            .font(.benMeta)
                            .foregroundStyle(Color.onCreamMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
                BenVoiceText(text: OnboardingCopy.mathsVoice(volume))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 640)
        } cta: {
            BenPrimaryButton(title: "Take them off me") {
                coordinator.advance(to: .lateFees)
            }
        }
    }
}

/// Screen 9 — here's what I heard. Their answers assembled into one card,
/// chips staggering in with the same rhythm as the scan demo.
struct MirrorView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var shownChips = 0

    var body: some View {
        let chips = mirrorChips
        BenScreen {
            VStack(spacing: 16) {
                Spacer(minLength: 12)
                Text("Here's what I heard.")
                    .font(.baloo("Baloo2-ExtraBold", 29, relativeTo: .title))
                    .foregroundStyle(Color.chartreuse)
                BenCard {
                    VStack(alignment: .leading, spacing: 10) {
                        BenEyebrow(text: "Your bill picture")
                        FlowChips(chips: Array(chips.prefix(shownChips)))
                        if let intent = coordinator.intent {
                            Text(OnboardingCopy.momentMirror(intent))
                                .font(.benMeta)
                                .foregroundStyle(Color.onCreamMuted)
                        }
                    }
                }
                if let feeling = coordinator.feeling {
                    BenVoiceText(text: OnboardingCopy.feelingEcho(feeling))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 640)
        } cta: {
            BenPrimaryButton(title: "That's me") {
                coordinator.advance(to: .statOdds)
            }
        }
        .task {
            for step in 1...chips.count {
                try? await Task.sleep(for: .seconds(0.14))
                withAnimation(.spring(duration: 0.3)) { shownChips = step }
            }
        }
    }

    private var mirrorChips: [String] {
        var chips: [String] = []
        if let intent = coordinator.intent { chips.append(intent.label) }
        chips.append(contentsOf: coordinator.sources.map { source in
            source.label.components(separatedBy: ",")[0]
        }.sorted())
        if let volume = coordinator.volume { chips.append("\(volume.label) bills a month") }
        if let fees = coordinator.lateFees { chips.append("Fees: \(fees.label)") }
        if let feeling = coordinator.feeling { chips.append(feeling.label) }
        return chips
    }
}

/// Screen 10 — the population stat, flipped personal. The reel spins down
/// and ticks to a stop on 3.
struct StatOddsView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator

    var body: some View {
        BenScreen {
            VStack(spacing: 16) {
                Spacer(minLength: 12)
                Text("The bit nobody plans for.")
                    .font(.baloo("Baloo2-ExtraBold", 29, relativeTo: .title))
                    .foregroundStyle(Color.chartreuse)
                    .multilineTextAlignment(.center)
                BenCard(padding: 24) {
                    VStack(spacing: 6) {
                        BenEyebrow(text: "Missed bills, nationally")
                        SpinNumber(mode: .reelDown(from: 9, to: 3, prefix: "1 in "))
                        Text("Australians have missed a power bill payment")
                            .font(.benMeta)
                            .foregroundStyle(Color.onCreamMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                BenVoiceText(text: OnboardingCopy.oddsVoice(coordinator.lateFees))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 640)
        } cta: {
            BenPrimaryButton(title: "Not me anymore") {
                coordinator.advance(to: .reminderStyle)
            }
        }
    }
}

/// Screen 12 — the "you said, Ben does" ledger. Every row quotes their
/// answer verbatim, then answers it. Rows rise in like the scan's fields.
struct PlanView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var shownRows = 0

    var body: some View {
        let rows = planRows
        BenScreen {
            VStack(spacing: 14) {
                Spacer(minLength: 12)
                Text("Your plan, then.")
                    .font(.baloo("Baloo2-ExtraBold", 29, relativeTo: .title))
                    .foregroundStyle(Color.chartreuse)
                ForEach(rows.indices, id: \.self) { index in
                    planRow(rows[index])
                        .opacity(shownRows > index ? 1 : 0)
                        .offset(y: shownRows > index ? 0 : 12)
                }
                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 640)
        } cta: {
            BenPrimaryButton(title: "Let's do the first bill") {
                coordinator.advance(to: .upload)
            }
        }
        .task {
            for step in 1...rows.count {
                try? await Task.sleep(for: .seconds(0.18))
                withAnimation(.spring(duration: 0.35)) { shownRows = step }
            }
        }
    }

    private var planRows: [(said: String, does: String)] {
        var rows: [(String, String)] = []
        if let intent = coordinator.intent {
            rows.append(("\"\(intent.label)\"", OnboardingCopy.momentPlan(intent)))
        }
        let sources = coordinator.sources
            .map { $0.label.lowercased().components(separatedBy: ",")[0] }
            .sorted()
            .joined(separator: ", ")
        rows.append((
            sources.isEmpty ? "wherever your bills live" : "your bills live in: \(sources)",
            "Photo, PDF, or email them in. Each one takes about 20 seconds."
        ))
        rows.append((
            "\"\(coordinator.reminderStyle.label)\"",
            "That's exactly when I'll speak, and never otherwise."
        ))
        if let feeling = coordinator.feeling {
            rows.append(("\"\(feeling.label)\"", OnboardingCopy.feelingEcho(feeling)))
        }
        return rows
    }

    private func planRow(_ row: (said: String, does: String)) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text("✓")
                .font(.baloo("Baloo2-ExtraBold", 15, relativeTo: .footnote))
                .foregroundStyle(Color.onChartreuse)
                .frame(width: 34, height: 34)
                .background(Color.chartreuse, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("You said: \(row.said)")
                    .font(.benMeta)
                    .italic()
                    .foregroundStyle(Color.forestInk.opacity(0.55))
                Text(row.does)
                    .font(.baloo("Baloo2-Bold", 14, relativeTo: .footnote))
                    .foregroundStyle(Color.forestInk)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .benRowSurface(radius: 20)
    }
}

/// Answer chips that wrap onto multiple lines inside the mirror card.
private struct FlowChips: View {
    let chips: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(chips, id: \.self) { chip in
                Text(chip)
                    .font(.baloo("Baloo2-Bold", 12.5, relativeTo: .caption))
                    .foregroundStyle(Color.onCreamStrong)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.onCreamStrong.opacity(0.08), in: Capsule())
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
    }
}

/// Minimal wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let positions = arrange(proposal: proposal, subviews: subviews).positions
        for (subview, position) in zip(subviews, positions) {
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(
        proposal: ProposedViewSize, subviews: Subviews
    ) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var cursor = CGPoint.zero
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x + size.width > maxWidth, cursor.x > 0 {
                cursor.x = 0
                cursor.y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(cursor)
            cursor.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, cursor.x - spacing)
        }
        return (CGSize(width: totalWidth, height: cursor.y + rowHeight), positions)
    }
}
