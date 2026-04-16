---
slug: charts
verdict: NEEDS_WORK
validated_at: 2026-04-16T15:35:00Z
iteration: review-2026-04-16
verdict_per_appearance:
  macos_light: PASS_WITH_NOTES
  macos_dark:  PASS_WITH_NOTES
  ios_light:   NEEDS_WORK
  ios_dark:    NEEDS_WORK
---

# Charts — Visual validation

## HIG reference
![HIG ref](../../../apple-hig/images/components-charts-intro.png)

## Rendered — macOS (light)
![macOS light](../screenshots/charts-macos-light.png)

## Rendered — macOS (dark)
![macOS dark](../screenshots/charts-macos-dark.png)

## Rendered — iOS (light)
![iOS light](../screenshots/charts-ios-light.png)

## Rendered — iOS (dark)
![iOS dark](../screenshots/charts-ios-dark.png)

## Verdict: NEEDS_WORK

The current screenshots are not trustworthy enough for promotion. macOS shows
the chart as a small insert inside a much larger shell, and both iOS captures
render as backdrop-only frames with no visible chart at all.

### Evidence manifest
- **Manifest:** `../evidence/charts.json`
- **Required captures:** PASS — all four files present and > 10 KB.
- **Report links:** PASS — all four appearance-specific screenshot filenames
  linked above.

### Light appearance observations
- macOS: the chart exists, but it is under-scaled relative to the amount of
  surrounding chrome, so the study does not read as a confident focal preview.
- iOS: the exported PNG is effectively blank aside from the backdrop.

### Dark appearance observations
- macOS: the dark chart remains visible, but it is still framed as a small
  insert rather than the primary object under review.
- iOS: the dark capture is also backdrop-only and does not prove chart output.

### Deviations / notes
- The iOS evidence path is currently broken for charts and fails to capture the
  component in either appearance.
- The macOS study also needs a more disciplined focal scale so the chart
  occupies the visual center instead of a small corner of a larger shell.

### Source citations
- Apple HIG — "Charts" (see `apple-hig/pages/charts.md` in the skill corpus).

### Remediation (if NEEDS_WORK)
- Fix the iOS chart showcase so the chart is visible in the exported PNGs.
- Reframe the macOS chart study so the chart itself, not the surrounding shell,
  is the thing being judged.
