import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen + Dynamic Island for a bill due today.
/// Compact: small Ben + one-line bubble, issuer over amount, Due → Reminded → Paid.
struct BillDueLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BillDueAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .widgetURL(Self.billURL(context.attributes.billID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image("BenCharacter")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                        Text(context.state.isPaid ? "That’s sorted." : "Don’t let this one slip.")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Self.cream)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .contentTransition(.opacity)
                    }
                    .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(context.attributes.issuer)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Self.cream.opacity(0.7))
                            .lineLimit(1)
                        Text(context.state.amountText)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Self.chartreuse)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.trailing, 2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    StatusTrackView(isPaid: context.state.isPaid, showLabels: false, dark: true)
                        .padding(.horizontal, 2)
                        .padding(.bottom, 2)
                }
            } compactLeading: {
                Image("BenCharacter")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            } compactTrailing: {
                Text(shortAmount(context.state.amountText))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Self.cream)
            } minimal: {
                Image("BenCharacter")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
            }
            .widgetURL(Self.billURL(context.attributes.billID))
        }
    }

    private func shortAmount(_ text: String) -> String {
        if text.count <= 8 { return text }
        return text.replacingOccurrences(of: ".00", with: "")
    }

    private static func billURL(_ billID: String) -> URL {
        URL(string: "ben://bill/\(billID)")!
    }

    // Forest Bold tokens (widget can't import BenTheme).
    fileprivate static let cream = Color(red: 0.980, green: 0.953, blue: 0.890)         // FAF3E3
    fileprivate static let onCreamStrong = Color(red: 0.184, green: 0.290, blue: 0.149) // 2F4A26
    fileprivate static let onCreamMuted = Color(red: 0.420, green: 0.420, blue: 0.341)  // 6B6B57
    fileprivate static let onCreamEyebrow = Color(red: 0.369, green: 0.478, blue: 0.227) // 5E7A3A
    fileprivate static let chartreuse = Color(red: 0.827, green: 0.914, blue: 0.478)    // D3E97A
    fileprivate static let onChartreuse = Color(red: 0.133, green: 0.212, blue: 0.106)  // 22361B
    fileprivate static let amber = Color(red: 0.914, green: 0.631, blue: 0.231)         // E9A13B
}

// MARK: - Lock Screen

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<BillDueAttributes>

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Image("BenCharacter")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                SpeechBubble(
                    text: context.state.isPaid ? "That’s sorted." : "Don’t let this one slip."
                )
                .contentTransition(.opacity)

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(context.attributes.issuer)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(BillDueLiveActivity.onCreamEyebrow)
                        .lineLimit(1)
                    Text(context.state.amountText)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(BillDueLiveActivity.onCreamStrong)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            StatusTrackView(isPaid: context.state.isPaid, showLabels: true, dark: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .animation(.easeInOut(duration: 0.75), value: context.state.isPaid)
        .activityBackgroundTint(BillDueLiveActivity.cream)
        .activitySystemActionForegroundColor(BillDueLiveActivity.onCreamStrong)
    }
}

// MARK: - Tiny speech bubble (tail points left, into Ben’s mouth)

private struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(BillDueLiveActivity.onCreamStrong)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
            )
            .overlay(alignment: .leading) {
                Triangle()
                    .fill(Color.white)
                    .frame(width: 7, height: 10)
                    .rotationEffect(.degrees(180))
                    .offset(x: -5)
            }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Status track

/// Due → Reminded → Paid. First two lit while due; paid lights when marked in-app.
private struct StatusTrackView: View {
    var isPaid: Bool
    var showLabels: Bool
    var dark: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                trackStep(systemName: "calendar", style: .on)
                trackRail(filled: true)
                trackStep(systemName: "bell.fill", style: .mid)
                // Second rail fills when paid — ActivityKit animates the width change.
                FillingRail(isFilled: isPaid, dark: dark)
                trackStep(
                    systemName: "checkmark",
                    style: isPaid ? .on : .off
                )
            }
            if showLabels {
                HStack {
                    Text("Due")
                    Spacer()
                    Text("Reminded")
                    Spacer()
                    Text("Paid")
                }
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    dark
                        ? BillDueLiveActivity.cream.opacity(0.45)
                        : BillDueLiveActivity.onCreamEyebrow
                )
                .textCase(.uppercase)
            }
        }
    }

    private enum StepStyle { case on, mid, off }

    private func trackStep(systemName: String, style: StepStyle) -> some View {
        let bg: Color
        switch style {
        case .on:
            bg = BillDueLiveActivity.chartreuse
        case .mid:
            bg = BillDueLiveActivity.amber
        case .off:
            bg = dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
        }
        let fg: Color
        switch style {
        case .on:
            fg = BillDueLiveActivity.onChartreuse
        case .mid:
            fg = Color(red: 0.165, green: 0.165, blue: 0.125)
        case .off:
            fg = dark ? BillDueLiveActivity.cream.opacity(0.45) : BillDueLiveActivity.onCreamMuted
        }
        return Image(systemName: systemName)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(fg)
            .frame(width: 22, height: 22)
            .background(Circle().fill(bg))
    }

    private func trackRail(filled: Bool) -> some View {
        let empty = dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)
        return Capsule()
            .fill(filled ? BillDueLiveActivity.chartreuse : empty)
            .frame(height: 3)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 3)
    }
}

/// Grey rail that fills chartreuse left→right when `isFilled` flips true.
private struct FillingRail: View {
    var isFilled: Bool
    var dark: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1))
                Capsule()
                    .fill(BillDueLiveActivity.chartreuse)
                    .frame(width: isFilled ? geo.size.width : 0)
            }
        }
        .frame(height: 3)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 3)
    }
}
