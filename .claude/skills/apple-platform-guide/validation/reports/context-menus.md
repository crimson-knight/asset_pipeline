---
slug: context-menus
verdict: PENDING
validated_at: 2026-04-16T00:00:00Z
iteration: review-2026-04-16d
verdict_per_appearance:
  macos_light: PASS_WITH_NOTES
  macos_dark:  PASS_WITH_NOTES
  ios_light:   PASS_WITH_NOTES
  ios_dark:    PASS_WITH_NOTES
---

# Context menus -- Visual validation

## HIG reference
![HIG ref](../../../apple-hig/images/components-context-menu-intro.png)

## Rendered -- macOS (light)
![macOS light](../screenshots/context-menus-macos-light.png)

## Rendered -- macOS (dark)
![macOS dark](../screenshots/context-menus-macos-dark.png)

## Rendered -- iOS (light)
![iOS light](../screenshots/context-menus-ios-light.png)

## Rendered -- iOS (dark)
![iOS dark](../screenshots/context-menus-ios-dark.png)

## Verdict: PENDING

`UI::ContextMenu` now exists and both native renderers visit it directly, so the
backlog should no longer pretend this slug is still a `UI::MenuButton` mapping
problem. The current captures are structurally recognizable, but the studies are
still too loose and over-contextualized to call finished. This row stays
`PENDING` until the next cleanup wave rebuilds the composition around a calmer,
more isolated menu surface.

### Evidence manifest
- **Manifest:** `../evidence/context-menus.json`
- **Required captures:** PASS -- all four files present and linked above.
- **Report links:** PASS -- all four appearance-specific screenshot filenames
  linked above.

### Light appearance observations
- macOS: the menu structure and destructive row read correctly, but the study is
  still embedded in too much document chrome and the surrounding layout steals
  attention from the menu surface itself.
- iOS: the menu card is readable and the red destructive action separates well,
  but the preview still feels pinned to the page instead of presented as a more
  deliberate focal study.

### Dark appearance observations
- macOS: the dark menu remains legible, though the oversized host scene and
  leftover supporting content make the capture feel more like a screenshot of an
  app than a study of the menu component.
- iOS: the dark surface keeps the warm Amber palette, but the framing still
  wants more breathing room around the menu card.

### Deviations / notes
- The implementation is now based on `UI::ContextMenu`, not `UI::MenuButton`.
- The next pass should tighten the backdrop, reduce unrelated host content, and
  decide whether the menu should be centered as a study plate or anchored from a
  simpler trigger target.

### Source citations
- Apple HIG -- "Context menus" (see `apple-hig/pages/context-menus.md` in the
  skill corpus).

### Remediation (if NEEDS_WORK)
N/A -- pending cleanup.
