# Overnight build: Ben v1 walking skeleton

Execute this plan phase by phase. Build + test green before advancing. Commit per phase.
Deliverable by morning: the app runs in the simulator and a user can complete the entire
onboarding flow (S1→S10) with a real bill photo, receive a scheduled local notification,
see the paywall, and land on the home screen. All specs: `docs/onboarding-flow.md`.

## Phase 0 — Scaffold (~30 min)
- `brew install xcodegen swiftlint` if missing. `xcodegen generate`. Confirm empty app builds and runs in simulator.
- Wire `BenTheme.swift` at app root (`.tint(.benAccent)`, canvas background). Commit.

## Phase 1 — Domain core (test-first)
- `Bill` SwiftData model: issuer, amount (Decimal), dueDate, status (derived), sourceImage data ref, notes, createdAt, isSecondBill helper.
- `BillStatus` derivation: upcoming / dueSoon (≤5 days) / overdue / paid. Exhaustive unit tests incl. edge days, timezone, midnight boundaries.
- `AnalyticsService` protocol + `LocalAnalytics` (console + JSON file). Events exactly: onboarding_started, intent_selected, reminder_style_selected, bill_upload_started, bill_parse_succeeded/failed, manual_entry_started/completed, bill_upload_completed (props: bill_count_after_upload, is_first_bill, is_second_bill, upload_method, has_notification), notification_set, os_permission_granted/denied, account_created, paywall_viewed (page_depth), trial_started, trial_abandoned_at_paywall, second_bill_prompt_shown, forwarding_setup, activation_deferred, notification_triggered, app_opened_from_notification.

## Phase 2 — Bill parsing
- `BillParsing` protocol: image/PDF in → `ParsedBill { issuer?, amount?, dueDate?, confidence }`.
- `VisionBillParser`: VNRecognizeTextRequest + heuristics (largest $ amount near "amount due/total due"; date parsing for AU formats incl. "24 Jul 2026", "24/07/2026", "24-07-26"; issuer from prominent header text). Unit-test heuristics on synthetic strings — no golden images needed.
- `MockBillParser` returning a fixture AGL bill for previews/UI tests.

## Phase 3 — Onboarding flow S1–S7 (activation loop)
Build exactly to spec: S1 welcome → S2 intent (4 pills) → S3 reminder style → S4 trust block + upload method → S5 capture/extract (PhotosPicker + camera + file importer) → S6 confirm (inline-editable fields, original image below, single confirm CTA) → S7 reminder schedule (pre-filled from S3 against the real due date, editable) + pre-permission sheet + UNUserNotificationCenter request → schedule the actual local notifications.
- Branch B1 (no bill handy): "remind me tonight" local notification deep-linking back to S4 + 20-second sample walkthrough.
- Branch B2 (parse failure): 3-field manual entry, pre-filled with partials, same S6 confirm after.
- Branch B3 (permission denied): silent mode, no re-prompt, one contextual re-ask flag stored for first due date.
- Every Ben line in `Font.benVoice`, copy per spec's "Ben copy direction" blocks.

## Phase 4 — S8–S10 + home screen
- S8 set-state: bill card + next reminder + "Nothing else needs your attention." + progress line. Account save = local placeholder (Sign in with Apple is HUMAN-GATED: capability/entitlement — stub the button, log the event).
- S9 hard paywall: 3-page pager (outcome → 7-day trial timeline with user-chosen pre-charge reminder day → US$49.99/yr default + US$5.99/mo cards). `StubSubscriptionService`: starts trial, persists trial state, computes days remaining. Trial lapse = view-only mode flag.
- S10 second-bill bridge: category suggestion chips (static mapping: electricity→internet/water/insurance etc.), forwarding-address card (display-only stub: HUMAN-GATED email ingestion backend), "later" path scheduling the single day-4 nudge (cancel it if second bill added first).
- Home screen: status-sorted bill list (StatusPill per design system), "nothing needs your attention" designed state, add-bill entry → S4 flow reused.

## Phase 5 — Notifications end-to-end
- Reminder copy per voice rules ("Ben here — [AGL] is due Friday.").
- Tapping notification → app opens to the relevant bill; fire app_opened_from_notification.
- Unit-test scheduling maths (reminder style × due date → trigger dates; never schedule in the past).

## Phase 6 — Polish + verification pass
- swiftlint --strict clean. Dynamic Type spot-check at xxxLarge (no truncated amounts). Dark mode pass — all tokens flip.
- UI test: complete happy path S1→S10 with MockBillParser.
- Write `BUILD_REPORT.md`: what shipped, test counts, screenshots via `xcrun simctl io booted screenshot`, every HUMAN_TODO item, suggested next session priorities.

## Explicitly out of scope tonight
Real accounts/auth, RevenueCat, email forwarding backend, PostHog, App Store assets, Ben's final illustration (use SF Symbol placeholder `person.crop.circle` tinted clay, sized ≤44pt).
