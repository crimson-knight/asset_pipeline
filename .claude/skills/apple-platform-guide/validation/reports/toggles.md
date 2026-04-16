---
slug: toggles
verdict: PASS_WITH_NOTES
validated_at: 2026-04-16T15:35:00Z
iteration: review-2026-04-16
verdict_per_appearance:
  macos_light: PASS_WITH_NOTES
  macos_dark:  PASS_WITH_NOTES
  ios_light:   PASS_WITH_NOTES
  ios_dark:    PASS_WITH_NOTES
---

# Toggles — Visual validation

## HIG reference
![HIG ref](../../../apple-hig/images/components-toggles-intro.png)

## Rendered — macOS (light)
![macOS light](../screenshots/toggles-macos-light.png)

## Rendered — macOS (dark)
![macOS dark](../screenshots/toggles-macos-dark.png)

## Rendered — iOS (light)
![iOS light](../screenshots/toggles-ios-light.png)

## Rendered — iOS (dark)
![iOS dark](../screenshots/toggles-ios-dark.png)

## Verdict: PASS_WITH_NOTES

The toggle anatomy is correct and the role states read clearly on both
platforms. The row stays PASS_WITH_NOTES because the iOS study is still
full-bleed and the macOS settings shell contributes more chrome than the
control family needs.

### Evidence manifest
- **Manifest:** `../evidence/toggles.json`
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
- The control work is fine; the remaining issue is compositional.
- This should move to full PASS after the previews are staged in a calmer,
  more centered frame.

### Source citations
- Apple HIG — "Toggles" (see `apple-hig/pages/toggles.md` in the skill corpus).

### Remediation (if NEEDS_WORK)
N/A — notes only.
