import ActivityKit
import Foundation

/// Shared ActivityKit model for a bill that's due today.
/// Must live in both the app and the widget extension.
struct BillDueAttributes: ActivityAttributes {
    /// Dynamic bits that can change while the activity is up.
    struct ContentState: Codable, Hashable, Sendable {
        var amountText: String
        /// When true, the track fills through to Paid (outro before dismiss).
        var isPaid: Bool

        init(amountText: String, isPaid: Bool = false) {
            self.amountText = amountText
            self.isPaid = isPaid
        }
    }

    var billID: String
    var issuer: String
    var dueDate: Date
}
