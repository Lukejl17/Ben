# Human-gated tasks (Claude Code appends here overnight)

Pre-seeded — these need Luke, not Claude:

- [x] Apple Developer account + DEVELOPMENT_TEAM in project.yml (device builds / TestFlight)
  Team `4CGY239475` (Repertoire Studio). Bundle ID `com.repertoirestudio.Ben`.
- [ ] Sign in with Apple capability + entitlement (account buttons stay hidden until then)
- [x] RevenueCat public SDK key in the app (Test Store in Debug, Apple `appl_` in Release).
      Products: `com.repertoirestudio.Ben.pro.yearly` / `.monthly`, entitlement `ben_pro`.
- [ ] App Store Connect: yearly US$49.99 with 7-day free trial, monthly US$5.99, if they are not already live
- [ ] Upload the next build to TestFlight from a Mac (Product > Archive). This Linux agent cannot do that.
- [ ] PostHog project + API key → replace LocalAnalytics
- [ ] Email forwarding ingestion backend (S10 forwarding address is display-only)
- [ ] Support desk go-live (logins, not git): Cloudflare D1 `ben-support-tickets`
      + worker `ben-support-desk` secrets (`WEBHOOK_SECRET`, `SLACK_BOT_TOKEN`,
      `SLACK_SIGNING_SECRET`, `POSTMARK_SERVER_TOKEN`), Postmark **Ben Support Desk**
      inbound webhook, forward `support@benandbill.app`, invite `@Ben Support` to
      `#ben-support` and `#ben-engineering-support-tickets`. Do not change bills inbound.
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
