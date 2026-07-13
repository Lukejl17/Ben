import Foundation
import Observation

/// Drives S1→S10 plus branches. One source of truth for onboarding state.
@Observable @MainActor
final class OnboardingCoordinator {
    enum Step: Equatable {
        case welcome          // S1
        case intent           // S2
        case reminderStyle    // S3
        case upload           // S4 (+ B1 sheet)
        case capture          // S5
        case manualEntry      // B2
        case confirm          // S6
        case reminderSetup    // S7
        case setState         // S8
        case paywall          // S9
        case secondBill       // S10
        /// Terminal for the add-a-bill flow launched from home.
        case done
    }

    var step: Step = .welcome

    // Collected along the way
    var intent: IntentContext?
    var reminderStyle: ReminderStyle = .fewDaysEarly
    var uploadMethod: UploadMethod = .photo
    var pendingImageData: Data?
    var parsed: ParsedBill?
    /// True while walking the B1 sample bill — nothing is saved.
    var isSampleWalkthrough = false
    /// Set by S6 confirm; S7/S8 read it.
    var confirmedBill: Bill?
    /// S7 outcome, read by S8 and analytics.
    var notificationsGranted: Bool?

    /// Adding a bill from the home screen reuses S4–S7 without the intro steps.
    var isAddingSubsequentBill = false

    func advance(to next: Step) {
        step = next
    }

    func startSampleWalkthrough() {
        isSampleWalkthrough = true
        uploadMethod = .sample
        parsed = MockBillParser.aglFixture
        step = .confirm
    }

    func endSampleWalkthrough() {
        isSampleWalkthrough = false
        parsed = nil
        pendingImageData = nil
        step = .upload
    }

    func resetForSecondBill() {
        pendingImageData = nil
        parsed = nil
        confirmedBill = nil
        uploadMethod = .photo
        step = .upload
    }
}
