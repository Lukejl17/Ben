import Foundation
import Observation

/// Drives S1→S10 plus branches. One source of truth for onboarding state.
@Observable @MainActor
final class OnboardingCoordinator {
    enum Step: Equatable {
        case welcome          // 1  — the handshake
        case demoScan         // 2  — watch Ben read a sample bill
        case intent           // 3  — life moment
        case sources          // 4  — where bills live
        case volume           // 5  — how many a month
        case statMaths        // 6  — their number, multiplied out
        case lateFees         // 7  — the money question
        case feeling          // 8  — what the stress feels like
        case mirror           // 9  — here's what I heard
        case statOdds         // 10 — 1 in 3, flipped personal
        case reminderStyle    // 11 — when Ben speaks
        case plan             // 12 — you said, Ben does
        case upload           // 13 — first bill (S4, + B1 sheet)
        case capture          //    — S5
        case manualEntry      //    — B2
        case confirm          //    — S6
        case reminderSetup    //    — S7
        case overdueStyle     //    — S7b, cadence for bills that slip
        case setState         //    — S8
        case commit           // 14 — the pact, thumb on it
        case paywall          // 15 — S9
        case secondBill       // 16 — S10
        /// After the second bill's reminder is set — calm close before home.
        case secondBillLockedIn
        /// Terminal for the add-a-bill flow launched from home.
        case done
    }

    var step: Step = .welcome

    // Collected along the way
    var intent: IntentContext?
    var sources: Set<BillSource> = []
    var volume: BillVolume?
    var lateFees: LateFeeHistory?
    var feeling: BillFeeling?
    var committed = false
    var reminderStyle: ReminderStyle = .fewDaysEarly
    var uploadMethod: UploadMethod = .photo
    var pendingImageData: Data?
    var parsed: ParsedBill?
    /// R2 key of the emailed bill being confirmed — claimed (deleted) on save.
    var pendingEmailKey: String?
    /// True while walking the B1 sample bill — nothing is saved.
    var isSampleWalkthrough = false
    /// Set by S6 confirm; S7/S8 read it (soonest instalment when split).
    var confirmedBill: Bill?
    /// All bills saved from the latest confirm — one item, or several instalments.
    var confirmedBills: [Bill] = []
    /// S7 outcome, read by S8 and analytics.
    var notificationsGranted: Bool?

    /// Adding a bill from the home screen reuses S4–S7 without the intro steps.
    var isAddingSubsequentBill = false

    func advance(to next: Step) {
        step = next
    }

    /// Persists the interview answers as user attributes. Called whenever an
    /// answer lands so a drop-off mid-flow still leaves useful segmentation.
    func saveAttributes() {
        OnboardingAttributes.save(.init(
            moment: intent,
            sources: sources,
            volume: volume,
            lateFees: lateFees,
            feeling: feeling,
            reminderStyle: reminderStyle,
            committed: committed
        ))
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

    /// Sign-out: back to the handshake with no leftover flow state.
    func resetToWelcome() {
        pendingImageData = nil
        parsed = nil
        confirmedBill = nil
        confirmedBills = []
        pendingEmailKey = nil
        isSampleWalkthrough = false
        isAddingSubsequentBill = false
        uploadMethod = .photo
        step = .welcome
    }

    func resetForSecondBill() {
        pendingImageData = nil
        parsed = nil
        confirmedBill = nil
        confirmedBills = []
        uploadMethod = .photo
        pendingEmailKey = nil
        step = .upload
    }
}
