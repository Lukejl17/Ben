# Human-gated tasks (Claude Code appends here overnight)

Pre-seeded — these need Luke, not Claude:

- [ ] Apple Developer account + DEVELOPMENT_TEAM in project.yml (device builds / TestFlight)
- [ ] Sign in with Apple capability + entitlement (S8 account save is stubbed until then)
- [ ] RevenueCat account + API key → replace StubSubscriptionService (S9)
- [ ] App Store Connect products: annual US$49.99 / monthly US$5.99, 7-day intro trial
- [ ] PostHog project + API key → replace LocalAnalytics
- [ ] Email forwarding ingestion backend (S10 forwarding address is display-only)
- [ ] Ben's illustration (clay + ink palette, one calm expression, ≤44pt — replaces SF Symbol placeholder)

Added overnight (14 Jul 2026):

- [ ] Xcode 26.6 in /Applications is missing the iOS 26.5 simulator platform — open Xcode once and
      install it (Settings → Components), or keep building with ~/Downloads/Xcode-beta.app
      (`export DEVELOPER_DIR=~/Downloads/Xcode-beta.app/Contents/Developer`). Everything tonight
      was built and tested with the beta.
