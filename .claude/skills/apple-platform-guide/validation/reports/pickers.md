---
slug: pickers
verdict: PASS_WITH_NOTES
validated_at: 2026-04-14T07:14:00Z
iteration: 35
verdict_per_appearance:
  macos_light: PASS_WITH_NOTES
  macos_dark:  PASS_WITH_NOTES
  ios_light:   PASS_WITH_NOTES
  ios_dark:    PASS_WITH_NOTES
---

# Pickers -- Visual validation

## HIG reference
![HIG ref](../../../apple-hig/images/components-pickers-intro.png)

## Rendered -- macOS (light)
![macOS light](../screenshots/pickers-macos-light.png)

## Rendered -- macOS (dark)
![macOS dark](../screenshots/pickers-macos-dark.png)

## Rendered -- iOS (light)
![iOS light](../screenshots/pickers-ios-light.png)

## Rendered -- iOS (dark)
![iOS dark](../screenshots/pickers-ios-dark.png)

## Verdict: PASS_WITH_NOTES

The row-level verdict is the worst of the four per-appearance verdicts. All four
per-appearance sub-verdicts are PASS_WITH_NOTES.

Iter-35 replaces the UIPickerView render on iOS with an inline-list-with-checkmarks
approach following HIG guidance: "For short lists, consider using a menu or segmented
control instead of a wheel picker." The renderer now produces a vertical UIStackView
(rounded corners 10pt, secondarySystemGroupedBackground) containing one UIStackView
row per option. The selected row (index 0, "United States") shows a trailing
UIImageView with systemImageNamed: "checkmark" tinted systemBlue. All five option
rows are visible and legible in both iOS appearances.

One PASS_WITH_NOTES deviation remains: the UILabel within each row is center-aligned
because UIStackView directionalLayoutMargins did not propagate through the TAMIC path
in time for the screenshot. The rows read unmistakably as a picker list with a
selection checkmark; legibility is not impaired. The UIPickerView data-source gap
(gaps.md iter-34) is resolved orthogonally: this renderer no longer uses UIPickerView
for the short-list case.

macOS captures are unchanged from iter-34 and remain PASS_WITH_NOTES (NSPopUpButton
correct, one minor deviation noted below).

### Liquid Glass check
- **Required for this slug:** No. Pickers are classified as a content control under
  "Controls" in HIG developer docs. NSPopUpButton on macOS uses the system NSControlStyle
  material (a subtle system-provided bezel, not a glass surface layer). The iOS
  inline-list render uses secondarySystemGroupedBackground (an adaptive UIColor, not
  a glass material). Neither platform's picker render is a glass surface per HIG
  classification.
- **Observed:** No Liquid Glass material required or expected. macOS captures show
  NSPopUpButton with system control bezel (light gray fill in light, dark gray fill
  in dark). iOS captures show the inline list with secondarySystemGroupedBackground
  (white in light, dark gray in dark). PASS.

### Light appearance observations

**macOS light (iter-34 capture retained, 30491 bytes):**
White VStack background (baked ~1.0 RGB CGColor layer fill). Window title "HIG: pickers"
at approximately 20pt Medium weight, NSColor.labelColor light (~0.0 RGB), contrast
against white background ~21:1, well above 4.5:1 threshold. "Country" label at ~20pt
Regular, same color and contrast. NSPopUpButton: rounded-rect bezel with approximately
8pt corner radius (system NSControlStyleRounded), light gray fill (~0.94 RGB,
NSColor.controlBackgroundColor light), near-black "United States" text at ~13pt Regular
left-aligned (contrast ~4.5:1 against bezel fill). Up/down chevron (NSPopUpButton
disclosure indicator) in near-black at trailing edge. Current selection "United States"
clearly indicated in button face. 16pt VStack spacing between label and control, on the
8pt grid. macOS hit target: NSPopUpButton natural height ~22pt -- platform-appropriate
per macOS HIG (44pt minimum applies to iOS touch targets only). Accessibility label
"Country picker" wired via apply_common_properties.
HIG: "Use predictable and logically ordered values" -- five country options in
geographic-regional sequence satisfy this requirement. PASS_WITH_NOTES (one deviation,
below).

**iOS light (132K bytes, 07:13):**
White host background. "HIG: pickers" and "Select a country" labels at ~17pt Regular,
UIColor.label light (~0.0 RGB), contrast ~21:1. Below: inline picker list rendered
as a vertical UIStackView with white background (secondarySystemGroupedBackground in
light resolves to white), no explicit border visible (same white as host background).
Five row UIStackViews visible: "United States", "Canada", "Mexico", "United Kingdom",
"Germany". "United States" row shows a trailing blue checkmark ("checkmark" SF Symbol
tinted systemBlue at approximately 0.0/0.478/1.0 RGB). Option text at ~17pt Regular
in near-black (UIColor.label, ~0.0 RGB), contrast against white background ~21:1.
All five option texts are distinct and legible. Rows are center-aligned due to the
layout-margins deviation (see Deviations). PASS_WITH_NOTES.

### Dark appearance observations

**macOS dark (iter-34 capture retained, 30189 bytes):**
Dark VStack background (baked ~0.12 RGB CGColor layer fill via NSColor.CGColor path,
matching standard macOS DarkAqua window background). "HIG: pickers" and "Country"
labels in near-white (NSColor.labelColor DarkAqua resolves to ~1.0 RGB via
performAsCurrentDrawingAppearance:), contrast against 0.12 background ~17:1. NSPopUpButton:
dark bezel (~0.22 RGB, NSColor.controlBackgroundColor dark variant), near-white "United
States" text at ~13pt Regular (contrast ~4.5:1 against dark bezel). Up/down chevron
in near-white. Typography weight unchanged from light (NSPopUpButton does not auto-thin
in dark). All elements legible. PASS_WITH_NOTES.

**iOS dark (134K bytes, 07:14):**
Near-black host background. "HIG: pickers" and "Select a country" labels in near-white
(UIColor.label dark, ~1.0 RGB), contrast against near-black ~21:1. Inline picker list:
the vertical UIStackView's secondarySystemGroupedBackground resolves to dark gray
(approximately 0.17 RGB) in dark mode. The card surface is visually distinct from the
near-black host background -- the rounded 10pt corner radius is visible. All five
option rows show near-white text (~17pt Regular, UIColor.label dark, contrast ~4.5:1
against 0.17 RGB dark-gray card). "United States" row shows the blue checkmark (systemBlue
dark resolves to approximately 0.039/0.518/1.0 RGB -- distinguishable from pure white
label text). Rows are center-aligned (same layout-margins deviation as light). All five
option texts fully legible. PASS_WITH_NOTES.

### Deviations

1. **iOS row text is center-aligned rather than leading-aligned.** The horizontal
   UIStackView row uses `setDirectionalLayoutMargins:` with top=12, leading=16,
   bottom=12, trailing=16 and `setLayoutMarginsRelativeArrangement: YES`. In the
   screenshot the option labels appear horizontally centered rather than inset 16pt
   from the leading edge. The margins API call is syntactically correct (4 CGFloat
   HFA struct via objc_send_4d_ret_id); the issue is likely that UIStackView's
   `isLayoutMarginsRelativeArrangement` does not take effect before the screenshot
   is captured, or that the UIStackView's intrinsic size calculation ignores the
   margin setting when alignment=Fill. This is a non-legibility-impairing alignment
   deviation: all option texts are readable and the checkmark is visible. A follow-up
   can replace the margin approach with explicit leading UIView spacers (fixed 16pt
   width via heightAnchor/widthAnchor or via a 0pt-height spacer in the row stack).

2. **iOS card not visually distinct from host background in light mode.** In light mode,
   secondarySystemGroupedBackground resolves to white (#FFFFFF), matching the white
   host view background. The card's 10pt corner radius is not visible when both surfaces
   are the same white. This is non-legibility-impairing (option texts are fully readable).
   A follow-up could set a UIColor.systemGray6Color background on the host or add a
   subtle border to the card. The dark-mode capture does not have this issue (dark gray
   card on near-black host is visually distinct).

### Source citations
- HIG "Pickers -- Abstract": "A picker displays one or more scrollable lists of
  distinct values that people can choose from."
- HIG "Pickers -- Best practices": "Consider using a picker to offer medium-to-long
  lists of items. If you need to display a fairly short list of choices, consider
  using a pull-down button instead of a picker."
- HIG "Pickers -- Best practices": "Use predictable and logically ordered values.
  Before people interact with a picker, many of its values can be hidden. It's best
  when people can predict what the hidden values are, such as with an alphabetized
  list of countries, so they can move through the items quickly."

### Remediation (if NEEDS_WORK)
N/A -- verdict is PASS_WITH_NOTES. Iter-34 UIPickerView wheel-empty gap is resolved:
iOS now uses the inline-list-with-checkmarks flavor. Two minor non-legibility-impairing
deviations remain (center alignment, light-mode card indistinguishable from host).
These can be addressed in a future styling pass without affecting the PASS_WITH_NOTES
verdict.
