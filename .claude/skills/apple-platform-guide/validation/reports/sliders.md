---
slug: sliders
verdict: PASS_WITH_NOTES
validated_at: 2026-04-16T15:35:00Z
iteration: review-2026-04-16
verdict_per_appearance:
  macos_light: PASS_WITH_NOTES
  macos_dark:  PASS_WITH_NOTES
  ios_light:   PASS_WITH_NOTES
  ios_dark:    PASS_WITH_NOTES
---

# Sliders — Visual validation

## HIG reference
![HIG ref](../../../apple-hig/images/components-sliders-intro.png)

## Rendered — macOS (light)
![macOS light](../screenshots/sliders-macos-light.png)

## Rendered — macOS (dark)
![macOS dark](../screenshots/sliders-macos-dark.png)

## Rendered — iOS (light)
![iOS light](../screenshots/sliders-ios-light.png)

## Rendered — iOS (dark)
![iOS dark](../screenshots/sliders-ios-dark.png)

## Verdict: PASS_WITH_NOTES

The slider family is implemented and readable on both platforms. The row stays
PASS_WITH_NOTES because the iOS study is still full-bleed and the macOS
settings shell contributes more chrome than the controls themselves need.

### Evidence manifest
- **Manifest:** `../evidence/sliders.json`
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
- The control anatomy is solid, but the composition still feels like a host
  dump instead of a balanced study.
- This should move to full PASS after the sliders are staged in the same kind
  of centered plate used by the stronger recent previews.

### Source citations
- Apple HIG — "Sliders" (see `apple-hig/pages/sliders.md` in the skill corpus).

### Remediation (if NEEDS_WORK)
N/A — notes only.
