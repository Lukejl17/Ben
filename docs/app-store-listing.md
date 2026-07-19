# App Store listing — copy-paste pack

Everything below is ready to paste into App Store Connect. Character counts are
against Apple's limits. Voice rules applied: calm, no exclamation marks, no
urgency or guilt, Australian in tone.

---

## App Name (30 chars max)

```
Ben: Bill Reminders & Tracker
```
(29 chars. Title carries the heaviest keyword weight — `bill`, `reminders`, `tracker`.)

## Subtitle (30 chars max)

```
Due dates, sorted quietly
```
(25 chars. Carries `due dates` without duplicating title keywords. Alternatives to test later:
- `Never miss a due date` (21)
- `Calm bill & due date organiser` (30)
)

## Promotional Text (170 chars max — editable without review)

```
Bills, gathered in one calm place. Snap a bill, Ben reads the details, you confirm, and a reminder is set. Due dates handled, without the stress.
```
(146 chars.)

## Keywords field (100 chars max, comma-separated, no spaces, no duplicates of title/subtitle)

```
bpay,utilities,rent,electricity,expense,budget,organiser,organizer,recurring,payment,schedule,alert
```
(99 chars. Singular forms where possible; Apple matches plurals. `organiser`+`organizer`
covers AU/US spelling — the AU spelling matters in this storefront.)

## Description (4000 chars max)

```
Ben keeps your bills under control and out of your mind.

Snap a photo of any bill and Ben reads the details — biller, amount, due date, even the BPAY reference. You check them, confirm, and Ben sets a reminder. That's it. Nothing is saved without your say-so.

WHAT BEN DOES

• Reads bills from a photo — electricity, rent, water, phone, insurance, rego, subscriptions
• Tracks every due date in one calm place
• Reminds you before a bill is due — one clear reason, no nagging
• Copies payment details (BPAY, BSB, account, reference) straight into your banking app
• Shows what's due this week and what the month looks like

WHAT BEN DOESN'T DO

• No bank logins. Ben never connects to your accounts.
• No selling your data. Your bills are processed on your phone and stay there.
• No noise. If nothing needs your attention, Ben stays quiet.

BUILT FOR AUSTRALIA

BPAY references, AU date formats, and billers you'll actually recognise. Made for the everyday punter who just wants the power bill paid on time.

PRIVACY, PLAINLY

Bill reading happens on your device. There's no account to create and no server holding your bills.

SUBSCRIPTION

Ben is free to try for 7 days. After that, a subscription unlocks unlimited bills. Payment is charged to your Apple ID account at confirmation of purchase. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in Settings > Apple ID > Subscriptions.

SUPPORT

Something not right? Tell us at support@benandbill.app and a human will reply.

Terms of use: https://benandbill.app/terms
Privacy policy: https://benandbill.app/privacy
```

## What's New (first release)

```
Ben's first outing. Snap a bill, confirm the details, get a reminder before it's due. If something's off, tell us at support@benandbill.app.
```

## Category

- Primary: **Finance**
- Secondary: **Productivity**

## Other fields

| Field | Value |
|---|---|
| Age rating | 4+ |
| Copyright | © 2026 <your entity name> |
| Support URL | https://benandbill.app/support |
| Marketing URL | https://benandbill.app |
| Privacy nutrition | "Data Not Collected" if analytics stay local-only; revisit when PostHog ships |

## In-App Purchase display names (shown on the listing)

| Product | Display name (30) | Description (45) |
|---|---|---|
| Annual | `Ben Unlimited (Yearly)` | `Unlimited bills, reminders and insights.` |
| Monthly | `Ben Unlimited (Monthly)` | `Unlimited bills, reminders and insights.` |

---

## Screenshot captions (final copy, source of truth)

Order and copy per the sauce hunt (benefit first, trust early, scenario later,
huge type, AUD everywhere, no superlatives, no price claims):

1. `Know what's due — without the stress.`
2. `Snap a bill. Ben reads the rest.`
3. `A nudge before it's due. Then quiet.`
4. `Pay in two taps — details ready for your banking app.`
5. `Your bills stay on your phone. No bank logins, ever.`
6. `Rent, power, rego — one calm place.`

Mockups to riff on: `design-boards/app-store-screenshots.html`
(open in a browser; each frame exports at 1290×2796).

## Rating prompt placement (listing-adjacent, from the same research)

Native `SKStoreReviewController` prompt after the **second bill confirmed** —
success moment, not onboarding.
