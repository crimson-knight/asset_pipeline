---
slug: pickers
verdict: PASS_WITH_NOTES
validated_at: 2026-04-16T15:35:00Z
iteration: review-2026-04-16
verdict_per_appearance:
  macos_light: PASS_WITH_NOTES
  macos_dark:  PASS_WITH_NOTES
  ios_light:   PASS_WITH_NOTES
  ios_dark:    PASS_WITH_NOTES
---

# Pickers — Visual validation

## HIG reference
![HIG ref](../../../apple-hig/images/components-pickers-intro.png)

## Rendered — macOS (light)
![macOS light](../screenshots/pickers-macos-light.png)

## Rendered — macOS (dark)
![macOS dark](../screenshots/pickers-macos-dark.png)

## Rendered — iOS (light)
![iOS light](../screenshots/pickers-ios-light.png)

## Rendered — iOS (dark)
![iOS dark](../screenshots/pickers-ios-dark.png)

## Verdict: PASS_WITH_NOTES

The picker anatomy is present on both platforms, but the studies are still
more host-driven than component-driven. This row stays PASS_WITH_NOTES while
the macOS settings shell and the iOS leading-edge menu placement are cleaned
up into a calmer, more centered presentation.

### Evidence manifest
- **Manifest:** `../evidence/pickers.json`
- **Required captures:** PASS — all four files present and > 10 KB.
- **Report links:** PASS — all four appearance-specific screenshot filenames
  linked above.

### Light appearance observations
- macOS: focal component sits inside the Amber scene chrome with the shipped
  palette (gold primary, plum destructive). Type hierarchy reads in a single
  glance.
- iOS: component is rendered under the UIKit renderer with HIG-appropriate
  controls and SF Symbol iconography.

### Dark appearance observations
- macOS: dark chrome maintains adequate contrast between the focal component
  and the surrounding Amber surface tokens.
- iOS: dark-mode rendering preserves role distinguishability for destructive
  and primary actions; amber-on-ember scene contrast verified.

### Deviations / notes
- The macOS study still borrows a full settings-window shell instead of
  letting the picker stand on its own.
- The iOS pull-down menu lands hard against the leading edge instead of sitting
  inside a centered study card with visible gutters.

### Source citations
- Apple HIG — "Pickers" (see `apple-hig/pages/pickers.md` in the skill corpus).

### Remediation (if NEEDS_WORK)
N/A — notes only.
