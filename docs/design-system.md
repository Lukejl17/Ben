# Ben design system v3 — Forest Bold

Locked 15 Jul 2026 from design board 01 (direction B). Supersedes v2 entirely.
Boards: design-boards/home-board-01.html (language), character-board-02.html (character rules).

## The feel, in one line
One committed world: deep forest ground with soft glows, chartreuse display type,
cream widgets floating on top, chunky Baloo 2 everywhere, Ben the character as a
guest in exactly five moments.

## Ten rules

1. **One world.** Forest Bold has no light/dark split — the app forces dark scheme.
   The ground is always the forest gradient + two radial glows (BenCanvas), never flat.
2. **Chartreuse is the voice of action.** Display titles, primary CTAs, the FAB,
   selected states, section headers. Nothing else gets it.
3. **Cream widgets carry the content.** Hero cards, price cards, trust card, fields,
   dial options — radius 26–32, real shadow, light-scheme interiors (`onCream` inks).
4. **Translucent rows support.** Secondary surfaces are rowFill + rowStroke borders
   (benRowSurface) — bills, minis, chips, banners.
5. **Baloo 2 everywhere.** ExtraBold for titles/heroes, Bold for labels/rows,
   Medium for body/voice. Bundled variable font; Dynamic Type via relativeTo.
6. **Solid accent chips.** Icon circles and status-on-cream chips use solid amber /
   sky / lavender / clay / chartreuse with their dark `on*` inks.
7. **Status is quiet on forest, solid on cream.** StatusPill (translucent) on rows;
   StatusChipOnCream (solid) on cream. Overdue is terracotta/clay — never red.
8. **The character is a guest, not a resident.** Welcome (large), working states,
   empty states, B2 apology — and nowhere else. Render whole; never circle-mask
   (his hat and thumb break the disc by design).
9. **Widgets first.** Screens compose from hero widget + mini widgets + rows,
   pinned chartreuse CTA. Eyebrow labels (tracked uppercase Baloo 11) name widgets.
10. **Motion stays calm.** Springs ~0.3s, pressed scale 0.97, dial slide+fade.
    No confetti, no bounce-for-joy.

## Tokens (BenTheme.swift is the only home of hex)

Ground: forestTop #25401C → forestBottom #1B3015 + glows #3E6B2E / #173014.
Display/interactive: chartreuse #D3E97A, onChartreuse #22361B.
Cream: #FAF3E3; inks onCream #293223, onCreamStrong #2F4A26,
onCreamEyebrow #5E7A3A, onCreamMuted #6B6B57.
Forest inks: forestInk #F8F1DE (secondary .65, meta .5), voice #EFE8D2.
Accents: amber #E9A13B/#2A2A20 · sky #9CC0CF/#1E3540 · lavender #E7CFF2/#4A2F5E ·
clay #D08D66/#3B2415.
Rows: fill cream@7%, stroke cream@15%.
Status on forest: warn amber tints, calm cream tints, paid chartreuse tints,
late terracotta tints (#C4744A/#E8A98A).

## Type roles (Baloo 2 named instances)
benTitle XB32/largeTitle · benHeroAmount XB46 · benVoice M18 · benCardTitle B17 ·
benAmount B17 · benBody M16 · benLabel B15 · benMeta M13 · benEyebrow B11+tracking.

## Category chips
electricity/gas amber · internet/phone/water sky · insurance/rent chartreuse ·
council/streaming clay · other lavender · customs hash into the four.

## Hard no's
No flat backgrounds · no SF for display text · no red · chartreuse never as a
text-on-cream colour (use onCreamStrong) · character never repeated per-row,
never near editable numbers or prices · no confetti.
