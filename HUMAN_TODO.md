# Human-gated tasks (Claude Code appends here overnight)

Pre-seeded — these need Luke, not Claude:

- [x] Apple Developer account + DEVELOPMENT_TEAM in project.yml (device builds / TestFlight)
      Team ID `4CGY239475` · Repertoire Studio Pty Ltd · set 3 Aug 2026
- [x] Sign in with Apple capability + entitlement (App ID + Ben/Ben.entitlements)
- [x] RevenueCat project **Ben** — Test Store + Apple app `com.repertoirestudio.Ben`,
      entitlement `ben_pro`, offerings `$rc_annual` / `$rc_monthly`. Confirm the signup email.
- [x] Apple public SDK key (`appl_…`) in `RevenueCatConfig.publicAPIKey` (Release);
      Test Store key used in Debug.
- [x] App Store Connect products: yearly US$49.99 / monthly US$5.99, 7-day intro trial
      (IDs `com.repertoirestudio.Ben.pro.yearly` / `.monthly`, group Ben Pro).
      Submit with the next app version.
- [ ] PostHog project + API key → replace LocalAnalytics
- [x] Email forwarding ingestion backend (S10 forwarding address is display-only)
- [ ] Ben's illustration (clay + ink palette, one calm expression, ≤44pt — replaces SF Symbol placeholder)

Added overnight (14 Jul 2026):

- [ ] Xcode 26.6 in /Applications is missing the iOS 26.5 simulator platform — open Xcode once and
      install it (Settings → Components), or keep building with ~/Downloads/Xcode-beta.app
      (`export DEVELOPER_DIR=~/Downloads/Xcode-beta.app/Contents/Developer`). Everything tonight
      was built and tested with the beta.

- [x] Ben character flat redraw — done (v2, design-refs/character/ben-character-v2-flat.png).
- [x] Ben character true-alpha export — done (v3, 5016px,
      design-refs/character/ben-character-v3-alpha.png). CANONICAL asset. Note: hat + thumb break
      outside the lime disc by design — never circle-mask this file, render it whole.
- [ ] Ben character: one calmer second pose (no thumbs-up) for neutral/apologetic moments
      (B2 manual entry, overdue contexts).

Added 15 Jul 2026 (settings/accounts/email-in build):

- [x] Real auth — DONE 19 Jul via Firebase Authentication (FirebaseAccountService):
      email/password + Google live; Apple button is wired but needs the Developer
      membership + Sign in with Apple capability to light up (below).
- [x] Email ingestion backend — DONE 19 Jul: Postmark → Worker → R2, D1 maps
      Firebase uid → forwarding token, app polls /pending and feeds S6 confirm.

Added 19 Jul 2026 (Firebase + email-in production build):

- [x] Apple Developer membership approved. App ID `com.repertoirestudio.Ben` registered
      with Sign in with Apple. App Store Connect app created (Apple ID 6797410242,
      name "Ben: Bill Reminders & Tracker"). Remaining for Apple login in Firebase:
      create a Sign in with Apple key + enable the Apple provider in Firebase Console.
- [ ] Verify Firebase Console has Email/Password + Google + Apple providers enabled
      (project: repertoirestudio-ben).
- [ ] Google OAuth branding: Google Cloud Console → APIs & Services → OAuth consent
      screen → App name = "Ben" (and optional logo). This is what users see instead of
      a Firebase hostname on consent. Native Google Sign-In SDK is wired in-app (Aug 2026);
      if anything still shows `*.firebaseapp.com`, check Auth → Settings → Authorized domains
      / custom auth domain later.
- [ ] Postmark: move off the sandbox/test tier when real user mail should flow
      (request approval in their dashboard).

## TestFlight (next human step in Xcode)
- [ ] Archive + upload: open Ben.xcodeproj → Any iOS Device → Product → Archive →
      Distribute App → App Store Connect → Upload. Then enable Internal Testing in TestFlight.

## Paywall (flow F)
Code is live on this branch: hard gate, RevenueCat SDK, restore, StoreKit prices, identity on sign-in.
ASC group **Ben Pro** exists with yearly/monthly products. Submit them with the next app version.

1. [x] App ID `com.repertoirestudio.Ben` → In-App Purchase (always-on for iOS)
2. [x] App Store Connect subscription group **Ben Pro**
      - `com.repertoirestudio.Ben.pro.yearly` — US$49.99/year, 7-day free intro
      - `com.repertoirestudio.Ben.pro.monthly` — US$5.99/month, no trial
      - [ ] Optional standing price US$69.99/year if we keep the 29% off / was-price badge (ACCC + App Review)
      - [ ] Submit the group with the next TestFlight/app version (Apple requires this for the first subscription group)
3. [x] RevenueCat iOS app + P8 key + Apple products on entitlement `ben_pro`
4. [x] Apple public SDK key (`appl_…`) in Release builds
- [x] Restore purchase, Privacy Policy and T&Cs URLs on the offer screen
- [ ] Source the fee-comparison figures (credit card ~$30, utility ~$15, telco ~$15) properly before ads go live; the $119 Finder yearly average is already cited.
