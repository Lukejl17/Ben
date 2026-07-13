# Ben design system v1 — Warm Earthy

Own only colour, type, and Ben's presence rules. Everything else: stock SwiftUI + Liquid Glass.
Tokens live in `Ben/Theme/BenTheme.swift` — the ONLY place hex values may appear.

## Rules
1. Native first: stock components, Liquid Glass defaults, `.tint(.benAccent)` at root. No custom chrome/glass.
2. One accent per view: eucalyptus is the only interactive colour. Clay = Ben's illustration only.
3. Colour is state, not decoration: the 4 status colours are the app's only situational colour. No red anywhere.
4. Serif = Ben speaking (`Font.benVoice` / New York). Everything else SF Pro. Amounts always `.monospacedDigit()`.

## Core palette (light / dark)
| Token | Light | Dark | Use |
|---|---|---|---|
| benAccent | #3F6B52 | #7FA98E | Only interactive colour |
| benAccentDeep | #2F4A3A | #A8C6B3 | Pressed, text on tint |
| benCanvas | #F7F3EA | #1C1B17 | Page background |
| benCard | #FFFFFF | #26241F | Cards, sheets |
| benHairline | #E3DCCB | #3A372F | Borders |
| benInk | #2C2A23 | #F0EDE4 | Primary text |
| benInkSecondary | #6B6557 | #A8A294 | Supporting text |
| benInkMuted | #8A8271 | #7A7466 | Meta, placeholders |
| benClay | #C4744A | #D08D66 | Ben's illustration ONLY |

## Status colours (tint / text)
| Status | Light | Dark |
|---|---|---|
| Upcoming | #EDEAE0 / #57534A | #33302A / #B5AF9F |
| Due soon | #F3E4D4 / #7A4A23 | #3E2F1E / #D9A96F |
| Paid | #E4EEE6 / #2F4A3A | #243528 / #9DC3AA |
| Overdue (terracotta, never red) | #EBD6CB / #8A3B22 | #3F281E / #D98F6C |

## Type roles
| Role | SwiftUI |
|---|---|
| Promise (S1/S8 headline) | `.largeTitle.bold()` |
| Screen title | `.title2.weight(.semibold)` |
| Ben's voice | `.system(.body, design: .serif)` |
| Bill amount | `.title3.weight(.semibold)` + `.monospacedDigit()` |
| Body | `.body` |
| Label / pills / buttons | `.subheadline.weight(.medium)` |
| Meta | `.footnote` in benInkMuted |

Dynamic Type mandatory — text styles only, test at xxxLarge.

## Hard no's
No gradients · no custom glass · no emotional colour shifts · no bright reds/neon · animation = fades + standard transitions only · Ben ≤44pt, never floating, one expression · no confetti (S8 is calm text, not celebration).
