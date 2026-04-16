---
slug: path-controls
verdict: NEEDS_WORK
validated_at: 2026-04-16T20:45:00Z
iteration: 25
verdict_per_appearance:
  macos_light: NEEDS_WORK
  macos_dark: NEEDS_WORK
  ios_light: NEEDS_WORK
  ios_dark: NEEDS_WORK
---

# Path controls -- Visual validation

## HIG reference
![HIG ref](../../../apple-hig/images/components-path-controls-intro.png)

## Rendered -- macOS (light)
![macOS light](../screenshots/path-controls-macos-light.png)

## Rendered -- macOS (dark)
![macOS dark](../screenshots/path-controls-macos-dark.png)

## Rendered -- iOS (light)
![iOS light](../screenshots/path-controls-ios-light.png)

## Rendered -- iOS (dark)
![iOS dark](../screenshots/path-controls-ios-dark.png)

## Verdict: NEEDS_WORK

The capture path is working now, which is useful, but the visual result is still not
close enough to Apple’s path-control taste to pass.

### What improved
- We now have real evidence on both platforms instead of a missing or broken capture.
- The breadcrumb data itself is visible and the iOS capture no longer disappears.

### Why it still fails
- The macOS study reads like a tall stack of breadcrumb rows rather than a restrained
  path control embedded in context.
- The iOS preview is still an oversized horizontal strip pinned near the top of the
  card, with too much dead space underneath.
- Neither platform yet captures the compact Finder-style hierarchy rhythm that makes
  the HIG example feel effortless.

### Result
Keep this row in `NEEDS_WORK`. The primitive exists, but the default composition and
presentation still need a dedicated taste pass before this should be promoted.
