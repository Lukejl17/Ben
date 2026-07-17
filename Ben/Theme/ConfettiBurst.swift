import SwiftUI

/// A short celebration: palette-coloured pieces fall from the top and fade.
/// Fire and forget — it never intercepts touches.
struct ConfettiBurst: View {
    private struct Piece: Identifiable {
        let id: Int
        let xFraction: CGFloat
        let delay: Double
        let spin: Double
        let size: CGFloat
        let drift: CGFloat
        let color: Color
    }

    private static let colors: [Color] = [.chartreuse, .amber, .sky, .lavender, .clay, .cream]

    private let pieces: [Piece] = (0..<44).map { index in
        Piece(
            id: index,
            xFraction: CGFloat.random(in: 0.03...0.97),
            delay: Double.random(in: 0...0.35),
            spin: Double.random(in: -540...540),
            size: CGFloat.random(in: 7...12),
            drift: CGFloat.random(in: -50...50),
            color: colors[index % colors.count]
        )
    }

    @State private var falling = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 1.55)
                        .rotationEffect(.degrees(falling ? piece.spin : 0))
                        .position(
                            x: piece.xFraction * geo.size.width + (falling ? piece.drift : 0),
                            y: falling ? geo.size.height + 30 : -30
                        )
                        .opacity(falling ? 0.85 : 1)
                        .animation(.easeIn(duration: 1.05).delay(piece.delay), value: falling)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            falling = true
        }
    }
}
