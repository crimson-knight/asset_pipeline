---
slug: image-wells
verdict: pending
validated_at: 2026-04-17T00:36:00Z
iteration: 0
verdict_per_appearance:
  macos_light: pending
  macos_dark: pending
  ios_light: pending
  ios_dark: pending
---

# Image wells -- Visual validation

## HIG reference
![HIG ref](../../../apple-hig/images/components-image-well-intro.png)

## Rendered -- macOS (light)
![macOS light](../screenshots/image-wells-macos-light.png)

## Rendered -- macOS (dark)
![macOS dark](../screenshots/image-wells-macos-dark.png)

## Rendered -- iOS (light)
![iOS light](../screenshots/image-wells-ios-light.png)

## Rendered -- iOS (dark)
![iOS dark](../screenshots/image-wells-ios-dark.png)

## Verdict: PENDING

`UI::ImageWell` now exists as a shared fallback primitive, but this component
has not yet gone through a meaningful visual validation pass. The current
captures are still placeholder host output, not a real image-well study. The
next step is to wire explicit image-well showcase scenes on both hosts,
regenerate all four appearances, and judge the result against the HIG's framed
drop-target feel.
