# Human-gated tasks (Claude Code appends here overnight)

Pre-seeded — these need Luke, not Claude:

- [x] Apple Developer account + DEVELOPMENT_TEAM in project.yml (device builds / TestFlight)
      Team ID `4CGY239475` · Repertoire Studio Pty Ltd · set 3 Aug 2026
- [x] Sign in with Apple capability + entitlement (App ID + Ben/Ben.entitlements)
- [ ] RevenueCat account + paste the public Apple API key into `RevenueCatConfig.publicAPIKey`
      (`Ben/Services/RevenueCatSubscriptionService.swift`) or Info.plist `REVENUECAT_API_KEY`.
      Dashboard: https://app.revenuecat.com — create project **Ben**, add iOS app
      bundle `com.repertoirestudio.Ben`, copy the **Apple** public SDK key (`appl_…`).
      Use the Test Store key only in Debug; TestFlight/App Store must use the Apple key.
- [ ] App Store Connect products: annual US$49.99 / monthly US$5.99, 7-day intro trial
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

Do these in order — purchases stay blocked with a calm error until the API key is in the build.

1. [ ] App ID `com.repertoirestudio.Ben` → enable **In-App Purchase**
2. [ ] App Store Connect → Features → In-App Purchases: auto-renewable group **Ben Pro**
      - `ben_pro_annual` — US$49.99/year, 7-day free intro trial
      - `ben_pro_monthly` — US$5.99/month, no trial
      - Optional standing price US$69.99/year if we keep the 29% off / was-price badge (ACCC + App Review)
3. [ ] RevenueCat dashboard (https://app.revenuecat.com):
      - Project **Ben**, iOS app bundle `com.repertoirestudio.Ben`
      - Products `ben_pro_annual` and `ben_pro_monthly` imported from App Store Connect (or Test Store products with the same IDs)
      - Entitlement `ben_pro` attached to both products
      - Offering `default` with `$rc_annual` → annual, `$rc_monthly` → monthly
      - Copy the **Apple** public SDK key (`appl_…`) — Test Store key is Debug-only
4. [ ] Paste that key into `RevenueCatConfig.publicAPIKey` (`Ben/Services/RevenueCatSubscriptionService.swift`)
      or Info.plist `REVENUECAT_API_KEY`, then archive a new TestFlight
5. [ ] Sandbox: StoreKit file `Ben/StoreKit/BenProducts.storekit` is attached to the Ben scheme for local Xcode testing. For device/TestFlight, use a sandbox Apple ID after products are in ASC + RC.
- [x] Restore purchase, Privacy Policy and T&Cs URLs on the offer screen
- [ ] Source the fee-comparison figures (credit card ~$30, utility ~$15, telco ~$15) properly before ads go live; the $119 Finder yearly average is already cited.

## Support desk (Slack + Workspace) — Phase 0 HUMAN
- [ ] Google Workspace: create `support@benandbill.app` (shared inbox or user). Confirm apex MX still delivers to Google — do not point apex MX at Postmark.
- [ ] Gmail auto-forward a copy of support mail to Postmark inbound `support-desk@in.benandbill.app` (keep Gmail copy).
- [ ] Slack: ops workspace + private `#ben-support` + Slack app (bot token, signing secret, interactivity URL → support-desk Worker). Invite bot; copy channel ID.
- [ ] Postmark: inbound webhook → support-desk Worker `/inbound?secret=…`; verify outbound From `support@benandbill.app`.
- [ ] Deploy Worker per [docs/support/SETUP.md](docs/support/SETUP.md); store secrets in Wrangler only.
- [ ] Smoke: test mail → Slack draft → Approve sends; Reject does not.
