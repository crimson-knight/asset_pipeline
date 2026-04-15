---
slug: path-controls
verdict: SKIPPED
validated_at: 2026-04-13T00:00:00Z
iteration: 56
verdict_per_appearance:
  macos_light: SKIPPED
  macos_dark:  SKIPPED
  ios_light:   SKIPPED
  ios_dark:    SKIPPED
skip_reason: mapping_mismatch
---

# Path controls -- Visual validation

## HIG reference
![HIG ref](../../../apple-hig/images/components-path-control-intro.png)

## Rendered -- macOS (light)
No screenshot. Slug skipped due to mapping mismatch -- see Finding below.

## Rendered -- macOS (dark)
No screenshot. Slug skipped due to mapping mismatch -- see Finding below.

## Rendered -- iOS (light)
No screenshot. HIG explicitly states path controls are not supported on iOS.

## Rendered -- iOS (dark)
No screenshot. HIG explicitly states path controls are not supported on iOS.

## Verdict: SKIPPED

### Finding: mapping mismatch

The worklist assigned this slug to `UI::PathView` (`src/ui/views/path_view.cr`).
On inspection, `UI::PathView` is a vector drawing / Bezier-path shape view. It stores
an array of `PathSegment` records whose commands are `MoveTo`, `LineTo`, `QuadCurveTo`,
`CurveTo`, and `Close`. Its `to_svg_path` method emits SVG path data strings (M, L, Q,
C, Z commands). This is an SVG-style drawing primitive, analogous to a `<path>` element
or Core Graphics `CGPath`. It is not a breadcrumb navigation control.

The HIG `path-controls` slug documents `NSPathControl` -- a macOS AppKit control that
displays a file system hierarchy as a horizontal list of icon-and-name segments separated
by chevrons. The HIG page abstract is: "A path control shows the file system path of a
selected file or folder." Two styles exist: Standard (linear breadcrumb list) and Pop up
(a popup-button variant). The HIG explicitly states: "Not supported in iOS, iPadOS, tvOS,
visionOS, or watchOS."

The prior worklist mapping was therefore incorrect on two dimensions:
1. `UI::PathView` renders SVG paths, not file system breadcrumbs.
2. Even if a breadcrumb view existed, the iOS captures would be meaningless because the
   HIG provides no iOS equivalent for NSPathControl.

### AppKit renderer visit method (current)
`appkit_renderer.cr` line 2757: `def visit(view : UI::PathView)` allocates a plain `NSView`,
sets `wantsLayer: true`, sets the frame to `view.width x view.height`, and calls
`apply_common_properties`. No CAShapeLayer or CGPath is drawn. No NSPathControl is created.
This is a stub that would produce a blank rectangle.

### UIKit renderer visit method (current)
`uikit_renderer.cr` line 3186: `def visit(view : UI::PathView)` allocates a plain `UIView`,
sets its frame, and calls `apply_common_properties`. Same blank-rectangle stub.

### iOS platform status
HIG path-controls page, Platform considerations: "Not supported in iOS, iPadOS, tvOS,
visionOS, or watchOS." An iOS fallback (custom HStack of Label + chevron pairs) would be a
custom composition, not a native platform control, and is not present in the library.

### Liquid Glass check
- **Required for this slug:** No. NSPathControl is a content-area control, not a surface
  overlay component. No Liquid Glass material is called for by HIG.

### Light appearance observations
Not applicable. No screenshot captured; slug skipped.

### Dark appearance observations
Not applicable. No screenshot captured; slug skipped.

### Deviations
1. **Worklist mapping mismatch (blocking).** `UI::PathView` is a vector drawing view, not a
   breadcrumb path control. The slug cannot be validated against the HIG illustration because
   the view does not implement the described component. Logged in gaps.md as
   PATH-CONTROLS-MAPPING-MISMATCH.

2. **AppKit visit stub (blocking).** The `appkit_renderer.cr` visit for `UI::PathView` does
   not draw a CGPath/CAShapeLayer, let alone an NSPathControl. A valid render of either the
   drawing view or the breadcrumb control requires a non-stub implementation.

3. **iOS: not supported per HIG (informational).** Path controls have no native iOS equivalent.
   A custom HStack fallback would need to be specified if the library wants to expose an
   iOS-compatible API for this pattern.

### Source citations
- HIG "Path controls": "A path control shows the file system path of a selected file or folder."
- HIG "Path controls -- Best practices": "Use a path control in the window body, not the window
  frame. Path controls aren't intended for use in toolbars or status bars."
- HIG "Path controls -- Platform considerations": "Not supported in iOS, iPadOS, tvOS, visionOS,
  or watchOS."

### Remediation
This slug requires two distinct efforts before it can be validated:

1. **Implement `UI::PathControl`** as a new, separate view class in `src/ui/views/`.
   - AppKit: back it with `NSPathControl`. Expose `style` (`:standard` / `:popup`),
     `components` (array of `{icon: String, name: String}` tuples), `editable: Bool`.
   - The `appkit_renderer.cr` visit should call `NSPathControl alloc init`, set the path
     items via `setPathItems:`, and apply the style.
   - iOS: no native equivalent. The UIKit visit should build a horizontal `UIStackView`
     of `UILabel` + chevron `UIImageView` pairs using SF Symbol `chevron.right`.

2. **Fix `UI::PathView`** (the drawing view) separately:
   - The AppKit renderer visit should create a `CAShapeLayer`, construct a `CGPath` from
     the segments array, and attach it to the view's layer. It is a shape-drawing view, not
     a breadcrumb control.

3. **Update the worklist** once `UI::PathControl` is implemented:
   - Add a new worklist row with `slug: "path-controls"`, `ui_view: "UI::PathControl"`.
   - The current slug row has been corrected to `ui_view: null`, `status: "missing"`,
     `validation_state: "skipped"`.
