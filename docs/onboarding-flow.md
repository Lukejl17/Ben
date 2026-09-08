# Ben onboarding flow v1 — build spec

Activation = upload first bill + confirm + set notification (target 60–70%).
PMF metric = second bill within 7 days (target 40%+). ~3 min to activation.
Model: 7-day trial → hard paywall. US$49.99/yr (default) + US$5.99/mo, store-localised.

## Phase A — Arrive & intend

### S1 · Welcome
One promise + one CTA. Ben avatar small, beside copy. No signup, no carousel.
> Ben: "G'day — I'm Ben. Give me your bills and I'll tell you when they matter. The rest of the time, you won't hear from me."
CTA: "Set up my first bill". Event: `onboarding_started`.

### S2 · Intent — life stage
Single-select pills, no branching: Just bought a home · Moved in with someone · Bills piling up lately · Just getting organised.
Stored as `intent_context`, flavours later copy + S10 suggestions. Event: `intent_selected`.

### S3 · Intent — reminder style
Options: A few days early (default) · Just before it's due · Both, for big bills.
State the anti-noise promise out loud.
> Ben: "I only speak up when a bill actually needs you. No streaks, no check-ins, no noise. When suits you?"
Event: `reminder_style_selected`.

## Phase B — First bill (the aha)

### S4 · The ask + trust block
Before any picker: what we extract (issuer, amount, due date) · you confirm everything · delete any time · "you pay for Ben, so your data is never the product".
Methods: Photo · PDF/file · Forward an email (shown, "available after setup").
Small honest link: "I don't have a bill handy" → B1. Event: `bill_upload_started (upload_method)`.

**B1 · No bill handy:** (a) "Remind me tonight" — one local notification deep-linking back to S4; (b) 20-sec sample bill walkthrough ending back at S4. Never a demo home screen. Event: `activation_deferred`.

### S5 · Capture & extract
Camera/photo/file → on-device parse. Calm processing state ("Reading it now…"). Events: `bill_parse_succeeded/failed`.

**B2 · Parse failure:** manual entry, 3 fields max (issuer, amount, due date), pre-filled with partials.
> Ben: "That one's hard to read — happens a lot. Type the basics and I've got it from here."
Same S6 confirm after. Events: `manual_entry_started/completed`.

### S6 · Confirm
Extracted fields large + inline-editable; original image below; single CTA "Looks right — track it". No auto-confirm, nothing pre-ticked.
> Ben: "Give this a once-over so everything stays accurate. I'd rather be checked than wrong."
Event: `bill_upload_completed` ⭐ (props: bill_count_after_upload, is_first_bill, is_second_bill, upload_method, has_notification).

## Phase C — Notification contract

### S7 · Reminder setup + OS permission
Schedule pre-filled from S3 against the real due date (e.g. 3 days before + on the day), user-editable.
> Ben: "Your [AGL] bill is due 24 July. I'll mention it on the 21st — sound right? After that, silence until it matters."
Pre-permission sheet first, THEN the OS prompt. Events: `notification_set` ⭐, `os_permission_granted/denied`.
**⭐ ACTIVATED here.**

**B3 · Permission denied:** no re-prompt, no guilt. "No worries — I'll keep everything ready in here instead." Silent mode; one contextual re-ask when first due date approaches. Events: `notification_denied`, `notification_reask_shown/accepted`.

## Phase D — Set state + paywall

### S8 · You're set
> Ben: "Done. [AGL, $243, due 24 July] is my problem now. Nothing else needs your attention."
Progress line (factual, not gamified): "1 bill tracked. Most people add 2–3 to stop thinking about bills entirely."
Account save: one-tap (Sign in with Apple — stub tonight). Event: `account_created`.

### S9 · Hard paywall (multi-page)
Page 1 outcome: "Never get surprised by a bill again — and never hear from Ben otherwise."
Page 2 trial timeline: today full access · day 5 pre-charge reminder, user picks the day · day 7 billed.
Page 3 price: US$49.99/yr default (≈US$4.17/mo shown) + US$5.99/mo.
Continuing requires starting the trial. Honesty offsets all ship: explicit timeline, user-chosen reminder day, one-tap cancel path, lapse = view-only (bills visible, reminders stop, one factual line, no guilt).
Trust block reprised. Events: `paywall_viewed (page_depth)`, `trial_started`, `trial_abandoned_at_paywall`.

### S10 · Second-bill bridge
Category chips from bill #1 + intent: "People tracking electricity usually also track internet · water · insurance" → one-tap opens S4 pre-filled.
Forwarding address card (stub): "bills@… — forward any bill email and I'll do the rest."
Decline is first-class: "Later's fine. I'll mention it once this week — that's all."
> Ben: "One bill down. Got internet or insurance floating around an inbox somewhere? Add it now, forward it later, or leave it with me."
Events: `second_bill_prompt_shown`, `forwarding_setup`.
After a second bill is confirmed + reminder set → locked-in screen, then
`onboarding_completed (path: second_bill)`. “Later's fine” →
`onboarding_completed (path: deferred)`. That event is the funnel end.

## Post-session second-bill system (days 0–7)
| Trigger | Message |
|---|---|
| First real due-soon notification fires | The reminder + one rider: "Want me watching your other bills too?" → S4 |
| Day ~4, only if no second bill AND no due-date notification yet | Single promised nudge: "Ben here — mentioned I'd ask once: any other bills for me?" (cancel if second bill added) |
| Email forwarded (post-backend) | "Got your [Telstra] bill. Tap to confirm." → S6 |
| Abandoned at B1/B2 | One recovery nudge naming the exact stopping point |

## Metrics (and anti-metrics)
Track: activation rate, second-bill-within-7-days, paywall view rate (≥85% of installs, session one), trial start rate, day-0 trial cancellations, trial→paid at day 7, % trialists receiving ≥1 real due-date reminder before day 7, notification retention, per-screen drop-offs segmented by failure point, onboarding completion rate (`onboarding_completed` / `onboarding_started`, segmented by `path`).
NEVER: DAU, session length, streaks, screens/session.
