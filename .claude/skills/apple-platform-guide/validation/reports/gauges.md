---
slug: gauges
verdict: pending
validated_at: 2026-04-17T01:30:00Z
iteration: 0
verdict_per_appearance:
  macos_light: pending
  macos_dark: pending
  ios_light: pending
  ios_dark: pending
---

# Gauges -- Visual validation

## HIG reference
![HIG ref](../../../apple-hig/images/components-gauges-intro.png)

## Rendered -- macOS (light)
![macOS light](../screenshots/gauges-macos-light.png)

## Rendered -- macOS (dark)
![macOS dark](../screenshots/gauges-macos-dark.png)

## Rendered -- iOS (light)
![iOS light](../screenshots/gauges-ios-light.png)

## Rendered -- iOS (dark)
![iOS dark](../screenshots/gauges-ios-dark.png)

## Verdict: PENDING

`UI::Gauge` now exists as a shared fallback primitive built from `UI::Canvas`
arc drawing plus labels, but it has not yet gone through a meaningful showcase
and capture pass. The next step is to stage a focused gauge study on both hosts,
regenerate all four appearances, and judge whether the ring reads as a calm,
instrument-like control rather than a decorative badge.
