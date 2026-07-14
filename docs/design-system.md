# Ben design system v2 — Warm Earthy, Tactile

Distilled from `design-refs/` (Unscripted, AllTrails 2025 rebrand, Superwall) +
Headway/Flo patterns + iOS 26 Liquid Glass. Supersedes v1's flat look.

## The feel, in one line
Soft atmospheric canvas, opaque floating surfaces with real shadows, capsule
controls, one confident accent, serif reserved for Ben's voice and hero numbers.

## Ten rules

1. **Elevation replaces borders.** Cards/inputs/chips are filled surfaces with
   soft shadows — never outlined boxes. Hairlines only in dark mode (shadows die there).
2. **Atmospheric canvas.** Light: soft 3-stop gradient (pale sky → sand → pale
   eucalyptus wash), barely saturated. Dark: deep warm charcoal gradient. Never flat.
3. **Capsules everywhere.** Primary CTA = 56pt accent-gradient capsule. Secondary =
   tinted wash capsule. Chips/status = small capsules. No rounded-rect buttons.
4. **Floating circular chrome.** Back/close/toolbar actions are 44pt circles —
   white fill + e2 shadow (light) / glass (dark), Unscripted-style.
5. **Tinted icon circles.** Icons sit in 44–52pt pastel circles (eucalyptus,
   amber, sky, clay washes) — this is where colour variety lives.
6. **Filled inputs.** Fields are filled neutral surfaces, radius 14, small
   accent-toned label INSIDE above the value. No bordered text fields.
7. **Serif = soul.** Ben's voice lines and hero numbers (big amounts) in New
   York serif. Everything else SF. Screen titles `.largeTitle.bold()`.
8. **One accent.** Eucalyptus for every interactive element. Status colours only
   on status pills. Clay only on Ben. No red — terracotta for overdue.
9. **Pinned CTAs.** Primary action pinned to bottom via safeAreaInset, full-width,
   20pt margins — content scrolls beneath.
10. **Glass is chrome.** iOS 26 `.glassEffect()` for floating circles, toasts, tab
    accessories — never for content cards (amounts stay legible on opaque).

## Tokens

### Shadows (light mode; halve opacity in dark, add 0.5pt hairline instead)
| Level | Use | Spec |
|---|---|---|
| e1 | cards, inputs | black 6%, radius 16, y 6 |
| e2 | floating circles, FAB, tab bar | black 10%, radius 20, y 8 |
| e3 | sheets, toasts | black 14%, radius 28, y 10 |

### Radii
Cards 20 · inputs 14 · sheets 28 (top) · buttons/chips = capsule · icon circles = circle.

### Canvas gradient
Light: `#EEF2F7` (top) → `#F7F3EA` (mid 45%) → `#EDF2EA` (bottom).
Dark: `#191C1E` → `#1C1B17` → `#1A211C`.

### Core palette (unchanged from v1)
benAccent #3F6B52/#7FA98E · benAccentDeep #2F4A3A/#A8C6B3 · benCard #FFFFFF/#26241F ·
benInk #2C2A23/#F0EDE4 · benInkSecondary #6B6557/#A8A294 · benInkMuted #8A8271/#7A7466 ·
benClay #C4744A/#D08D66 · hairline (dark mode only) #3A372F.

### Icon-circle washes (light/dark bg · fg pairs)
eucalyptus #E4EEE6/#243528 · amber #F6ECD4/#3E3520 · sky #E1EBF0/#20313A ·
clay #F3E0D5/#3B2A20. Fg = the deep stop of the same family.

### Buttons
- **Primary capsule**: LinearGradient benAccent→benAccentDeep (subtle, vertical),
  white `.benLabel` text, height 56, e2 shadow, pressed scale 0.98.
- **Secondary capsule**: eucalyptus wash fill, benAccentDeep text.
- **Tertiary**: text + small accent icon circle (Unscripted "Add item" pattern).
- **Glass circle** (44pt): floating chrome actions.

### Type roles
| Role | Spec |
|---|---|
| Screen title | `.largeTitle.bold()` |
| Hero amount | `.system(size 40+, design serif, bold)` + monospacedDigit |
| Ben's voice | `.system(.title3/.body, design: .serif)` |
| Card title | `.headline` |
| Body | `.body`, secondary at benInkSecondary |
| Label/chip/button | `.subheadline.weight(.semibold)` |
| Meta | `.footnote` benInkMuted |

### Spacing rhythm
20 horizontal margins · 12 between cards · 28 between sections · 16 title→content ·
sections get `.headline` headers with 4pt accent tick optional.

## Motion
Springs (`.spring(duration: 0.35)`) for step transitions; pressed scale 0.98;
toast slides from bottom with e3 + glass. Nothing bounces more than once.

## Hard no's (updated)
No outlined/stroked cards · no flat full-bleed screens without canvas gradient ·
no bright red · no confetti · Ben ≤44pt, one expression · glass never under data.
