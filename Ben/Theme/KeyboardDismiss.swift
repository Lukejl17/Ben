import SwiftUI
import UIKit

/// Window-level tap that resigns the keyboard without stealing control taps.
/// Skips UITextField / UITextView so focusing a field still works.
@MainActor
enum KeyboardDismissInstaller {
    private static var installed = false
    private static let proxy = Proxy()

    static func installIfNeeded() {
        guard !installed else { return }
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        guard let window = windows.first(where: \.isKeyWindow) ?? windows.first else { return }

        let tap = UITapGestureRecognizer(
            target: proxy,
            action: #selector(Proxy.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        tap.requiresExclusiveTouchType = false
        tap.delegate = proxy
        window.addGestureRecognizer(tap)
        installed = true
    }

    private final class Proxy: NSObject, UIGestureRecognizerDelegate {
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

extension View {
    /// Re-try install when a window appears (first frame can miss keyWindow).
    func benInstallKeyboardDismiss() -> some View {
        onAppear { KeyboardDismissInstaller.installIfNeeded() }
    }
}
