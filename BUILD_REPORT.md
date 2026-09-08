# Ben v1 walking skeleton — overnight build report

**Built:** 13–14 July 2026 · **Result: all 7 phases green, committed per phase**

## TL;DR

The app runs in the simulator and a user can complete the entire onboarding
flow S1→S10 with a bill photo: parse → confirm → schedule real local
notifications → hard paywall with a working 7-day stub trial → second-bill
bridge → home screen. **57 unit tests + 2 UI tests, all passing. SwiftLint
`--strict` clean.** The full happy path is covered by an XCUITest that walks
every screen.

## How to run

```bash
cd ~/dev/ben
xcodegen generate          # if project.yml changed
open Ben.xcodeproj         # run the Ben scheme on iPhone 17 simulator
```

⚠️ **Toolchain note:** `/Applications/Xcode.app` (26.6) is missing its iOS 26.5
simulator platform, so everything was built with
`~/Downloads/Xcode-beta.app` (26.4) instead:

```bash
export DEVELOPER_DIR=~/Downloads/Xcode-beta.app/Contents/Developer
xcodebuild -project Ben.xcodeproj -scheme Ben \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Either open Xcode 26.6 once and let it download the iOS platform component
(Settings → Components), or keep using the beta.

## What shipped, by phase (one commit each)

| Phase | Delivered |
|---|---|
| 0 | XcodeGen scaffold, BenTheme tokens wired at root, app boots |
| 1 | `Bill` SwiftData model, pure `BillStatus.derive` (timezone/midnight-safe), `AnalyticsService` → console + JSON-lines file with the exact specced event names |
| 2 | `BillParsing` protocol, `VisionBillParser` (VNRecognizeTextRequest + PDF render), pure AU-format heuristics (`24 Jul 2026`, `24/07/2026`, `24-07-26`, keyword-proximate amounts, known-issuer table), `MockBillParser` AGL fixture |
| 3 | S1 welcome → S2 intent → S3 reminder style → S4 trust block + methods → S5 capture (PhotosPicker/camera/file) → S6 inline-editable confirm → S7 reminder schedule + pre-permission sheet + OS prompt. Branches: B1 (remind-me-tonight nudge + sample walkthrough), B2 (3-field manual entry with partial pre-fill), B3 (silent mode + stored re-ask flag) |
| 4 | S8 set-state (bill card, progress line, stubbed Sign in with Apple), S9 3-page hard paywall (outcome → honest trial timeline with user-chosen pre-charge day → $49.99/yr / $5.99/mo cards) on a persisted `StubSubscriptionService` trial machine with view-only lapse, S10 second-bill bridge (category chips, forwarding stub, day-4 nudge that cancels on second bill), home screen with status-sorted list + context actions |
| 5 | Notification delegate: tap → opens the relevant bill (or resumes S4 for B1); `notification_triggered` / `app_opened_from_notification` events; scheduling maths never fires in the past |
| 6 | SwiftLint strict clean, dark-mode + Dynamic Type xxxLarge passes, happy-path UI test, this report |

## Test counts

- **57 unit tests** across 6 suites: BillStatus derivation (16 — boundaries,
  midnight, timezones, month/year rollover), parsing heuristics (16),
  analytics event names/props (4), trial state machine (7), reminder
  scheduling maths + copy (14)
- **2 UI tests**: launch smoke + full S1→S10 happy path on the mock parser
- Screenshot-walk test (skipped unless `SCREENSHOTS=1`) produced the gallery below

## Screenshots

Light + dark for every screen in `screenshots/light/` and `screenshots/dark/`:
s1-welcome, s2-intent, s3-reminder-style, s4-trust-upload, s6-confirm,
s7-reminder-setup, s7b-pre-permission, s8-set-state, s9-paywall-outcome,
s9-paywall-timeline, s9-paywall-price, s10-second-bill, home.
Also `dynamic-type-xxxl.png` (S1 at the largest non-accessibility size — wraps, no truncation).

## Deliberate calls worth knowing

- **Status is always derived**, never stored — it can't go stale overnight.
- Parsing heuristics are **pure functions over recognised text lines**, so they're
  unit-tested on synthetic strings; Vision plumbing is a thin adapter.
- `bill_upload_completed` fires with `has_notification: false` at S6 —
  notification truth arrives at S7 as `notification_set` (matches the spec's
  event split; noted in case you'd rather it carry the final value).
- The day-4 second-bill nudge is cancelled automatically when a second bill is
  confirmed (KICKOFF requirement).
- Reminder copy is generated per voice rules and unit-tested:
  "Ben here — AGL is due Friday." / "…due today." / "…due 24 July."
- UI-test hooks are launch args: `-mockParser -failingParser -autoCapture
  -resetOnboarding -inMemoryStore -freshTrial -forceDark -nullAnalytics`.

## Human-gated (see HUMAN_TODO.md — unchanged list, all stubbed)

Apple Developer team ID · Sign in with Apple entitlement · RevenueCat +
App Store Connect products · PostHog key · email-forwarding backend ·
Events include `onboarding_completed` (path: second_bill | deferred) as funnel end.
Ben's final illustration. Markers are in code as `// HUMAN:` comments.

## Suggested next-session priorities

1. **Real-bill OCR tuning** — run VisionBillParser over a handful of genuine AU
   bills (AGL/Telstra/water PDFs) and tighten the heuristics where they miss.
2. **B3 re-ask moment** — the `notificationReaskPending` flag is stored but the
   contextual re-ask UI when the first due date approaches isn't built yet.
3. **Paid flow polish** — mark-as-paid exists via long-press context menu; a
   swipe action + a bill detail edit screen would round out the home screen.
4. **Trial pre-charge reminder notification** — the chosen day is persisted;
   scheduling the actual local notification for it is a 20-minute job.
5. **Post-trial view-only enforcement** — the flag renders a banner; reminders
   aren't yet suppressed on lapse.

## Where things live

Onboarding screens `Ben/Onboarding/` · services (parsing, notifications,
analytics, subscription) `Ben/Services/` · domain `Ben/Models/` · theme
`Ben/Theme/BenTheme.swift` · flow state `Ben/Navigation/OnboardingCoordinator.swift`.

*Note: this repo lives at `~/dev/ben`. The session was launched from
`~/Desktop/Ben-Xcode` (the older prototype) — a pointer file there links here.*
