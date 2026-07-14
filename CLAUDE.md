# Ben — bill tracking for the everyday punter

Ben is a calm, trusted iOS app that keeps bills under control and out of the user's mind.
You are building v1. Read `docs/onboarding-flow.md` and `docs/design-system.md` before writing any code.

## The constitution (violating these = the feature is wrong)

- Trust before optimisation. System of record, not decision engine.
- No silent saves: users explicitly confirm every extracted bill.
- Notifications are conservative, factual, one clear reason each. Silence is a feature.
- Calm always: no panic language, no bright reds, no confetti, no gamification, no streaks.
- Ben (the character) speaks in serif (`Font.benVoice`), appears only where he does work, never floats or dominates.
- Never instrument DAU/session-length/engagement metrics.
- Activation = upload first bill + confirm details + set notification. PMF metric = second bill within 7 days.

## Tech decisions (locked — do not relitigate)

- iOS 26+, Swift, SwiftUI, Liquid Glass defaults. Stock components tinted `.benAccent`. No custom chrome.
- Persistence: SwiftData, local-first. No backend in v1.
- OCR: on-device. VisionKit `DataScannerViewController` / `VNRecognizeTextRequest` behind a `BillParsing` protocol. Ship `MockBillParser` for tests and previews.
- Notifications: local only (`UserNotifications`). No push, no server.
- Subscriptions: `SubscriptionService` protocol with `StubSubscriptionService` (7-day trial state machine in-memory/UserDefaults). RevenueCat integration is a HUMAN-GATED task — leave a `// HUMAN: RevenueCat API key` marker and keep the protocol clean.
- Analytics: `AnalyticsService` protocol → console + local JSON log for now. PostHog later (HUMAN-GATED: API key). Event names/properties exactly as specced in `docs/onboarding-flow.md`.
- Project generation: XcodeGen (`project.yml`). Never hand-edit the `.xcodeproj` — edit `project.yml` and regenerate.
- Design tokens: `Ben/Theme/BenTheme.swift` is the only source of colour/type. No hex literals anywhere else.

## Commands

- ⚠️ `/Applications/Xcode.app` (26.6) is missing its iOS platform component; build with
  `export DEVELOPER_DIR=~/Downloads/Xcode-beta.app/Contents/Developer` until it's downloaded.
- Regenerate project: `xcodegen generate`
- Build: `xcodebuild -project Ben.xcodeproj -scheme Ben -destination 'platform=iOS Simulator,name=iPhone 17' build`
- Test: `xcodebuild -project Ben.xcodeproj -scheme Ben -destination 'platform=iOS Simulator,name=iPhone 17' test`
- Lint: `swiftlint --strict` (config in `.swiftlint.yml`)
- If the iPhone 17 simulator is missing, list with `xcrun simctl list devices available` and use the newest iPhone.

## Visual QA (mandatory after any UI change)

- Run `./shots.sh light && ./shots.sh dark` — walks S1→S10 + home via XCUITest and
  exports named PNGs to `screenshots/{light,dark}/`.
- READ the screenshots and critique against `docs/design-system.md` and `design-refs/`
  (wraps, contrast, spacing, dead zones, shadow presence, dark-mode token flips).
  Fix and re-run until clean. Never ship a screen you haven't looked at.

## Working rules

- Work in small vertical slices; after EVERY slice: `xcodegen generate` (if files added), build, test. Never move on with a red build.
- Commit after every green slice with a descriptive message. Never push (no remote configured).
- Unit-test the pure logic hard: bill parsing heuristics, `BillStatus` derivation from due dates, trial state machine, notification scheduling maths.
- UI copy: every Ben spoken line must pass "would this feel helpful if I were already stressed?" Bad: urgency, guilt, exclamation marks. Good: plain, warm, Australian in tone not slang.
- Anything requiring credentials, accounts, payments, or the App Store: STOP, add it to `HUMAN_TODO.md`, and continue with the stub.
- If genuinely blocked, write the blocker + attempted approaches to `HUMAN_TODO.md` and move to the next task rather than spinning.
