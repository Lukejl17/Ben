# Human-gated tasks (Claude Code appends here overnight)

Pre-seeded — these need Luke, not Claude:

- [x] Apple Developer account + DEVELOPMENT_TEAM in project.yml (device builds / TestFlight)
  Team `4CGY239475` (Repertoire Studio). Bundle ID `com.repertoirestudio.Ben`.
- [ ] Sign in with Apple capability + entitlement (S8 account save is hidden until then)
- [ ] RevenueCat **API key at archive time** — SDK is wired; do not commit keys.
      Copy `Secrets.xcconfig.example` → `Secrets.xcconfig` (gitignored) and paste the
      Apple public SDK key (`appl_…`). Or set `REVENUECAT_API_KEY` in Xcode build settings.
      Products: `com.repertoirestudio.Ben.pro.yearly` / `.monthly`, entitlement `ben_pro`.
- [ ] App Store Connect products: annual US$49.99 / monthly US$5.99, 7-day intro trial
- [ ] PostHog project + API key → replace LocalAnalytics
- [ ] Email forwarding ingestion backend (S10 forwarding address is display-only)
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

- [ ] Replace StubAccountService internals with real auth: Sign in with Apple
      (capability + entitlement — same item as above) AND Google Sign-In SDK
      (OAuth client ID in Google Cloud console). Protocol + all call sites stay.
- [ ] Email ingestion backend: provision per-account addresses matching
      StubAccountService.forwardingAddress format (bills-<8 chars>@ben.app),
      parse inbound MIME → ParsedBill → push to app for S6 confirm.
      Requires owning ben.app inbound mail (e.g. SES/Postmark inbound).
