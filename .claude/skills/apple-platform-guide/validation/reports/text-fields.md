---
slug: text-fields
verdict: PASS_WITH_NOTES
validated_at: 2026-04-16T20:45:00Z
iteration: 25
verdict_per_appearance:
  macos_light: PASS_WITH_NOTES
  macos_dark: PASS_WITH_NOTES
  ios_light: PASS_WITH_NOTES
  ios_dark: PASS_WITH_NOTES
---

# Text fields -- Visual validation

## HIG reference
![HIG ref](../../../apple-hig/images/components-text-field-intro.png)

## Rendered -- macOS (light)
![macOS light](../screenshots/text-fields-macos-light.png)

## Rendered -- macOS (dark)
![macOS dark](../screenshots/text-fields-macos-dark.png)

## Rendered -- iOS (light)
![iOS light](../screenshots/text-fields-ios-light.png)

## Rendered -- iOS (dark)
![iOS dark](../screenshots/text-fields-ios-dark.png)

## Verdict: PASS_WITH_NOTES

This is in a much better place. The fields are now presented as a clean, compact form
study instead of a loose stack pressed against the frame.

### What improved
- Both platforms now keep enough surrounding gutter that the form reads as a focused
  component sample.
- Input widths are consistent and the labels align cleanly with the fields beneath.
- Dark-mode rendering is readable on both platforms; filled values and placeholders
  are easy to distinguish.

### Why this is still notes-only
- The iOS secure field still appears visually empty in the static screenshot. That is
  expected from `secureTextEntry`, but it remains a screenshot-specific limitation.
- The form is clean, though still a little more showcase-like than a truly native
  settings or account screen.

### Result
This is a solid default taste baseline now. Leave it at `PASS_WITH_NOTES` until the
host can present secure-field state and surrounding form chrome a little more naturally.
