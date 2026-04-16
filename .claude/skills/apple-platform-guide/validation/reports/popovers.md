---
slug: popovers
verdict: NEEDS_WORK
validated_at: 2026-04-16T15:35:00Z
iteration: review-2026-04-16
verdict_per_appearance:
  macos_light: PASS_WITH_NOTES
  macos_dark:  PASS_WITH_NOTES
  ios_light:   NEEDS_WORK
  ios_dark:    NEEDS_WORK
---

# Popovers — Visual validation

## HIG reference
![HIG ref](../../../apple-hig/images/components-popovers-intro.png)

## Rendered — macOS (light)
![macOS light](../screenshots/popovers-macos-light.png)

## Rendered — macOS (dark)
![macOS dark](../screenshots/popovers-macos-dark.png)

## Rendered — iOS (light)
![iOS light](../screenshots/popovers-ios-light.png)

## Rendered — iOS (dark)
![iOS dark](../screenshots/popovers-ios-dark.png)

## Verdict: NEEDS_WORK

The macOS popover study is still readable, but both iOS captures miss the
focal popover entirely. This row is back to NEEDS_WORK until the iOS host
captures the presented surface instead of only the ambient backdrop.

### Evidence manifest
- **Manifest:** `../evidence/popovers.json`
- **Required captures:** PASS — all four files present and > 10 KB.
- **Report links:** PASS — all four appearance-specific screenshot filenames
  linked above.

### Light appearance observations
- macOS: the light popover remains identifiable and readable.
- iOS: the light capture shows only the surrounding Amber shell and does not
  include the popover itself.

### Dark appearance observations
- macOS: the dark study still reads as a popover and carries the warm palette
  cleanly.
- iOS: the dark capture repeats the same miss and fails to show the presented
  popover.

### Deviations / notes
- The iOS evidence path is currently not proving popover presentation, so the
  screenshots cannot support a promoted state.
- macOS can remain the baseline reference once the iOS capture path is fixed.

### Source citations
- Apple HIG — "Popovers" (see `apple-hig/pages/popovers.md` in the skill corpus).

### Remediation (if NEEDS_WORK)
- Rework the iOS popover showcase so the presented surface is still in-frame
  when the screenshot is taken.
