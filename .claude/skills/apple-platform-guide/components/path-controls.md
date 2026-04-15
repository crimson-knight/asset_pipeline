---
slug: path-controls
ui_view: null
ui_view_planned: UI::PathControl
priority: P2
platforms: [macOS]
hig_page: ../../../apple-hig/pages/path-controls.md
validation_report: ../validation/reports/path-controls.md
---

# Path controls (UI::PathControl -- planned)

> A path control shows the file system path of a selected file or folder as a
> horizontal breadcrumb list of icon-and-name segments separated by chevrons;
> on macOS it maps to NSPathControl and uses no Liquid Glass material -- it is
> a window-body content control, not a surface overlay.

NOTE: This view does not yet exist in the library. The validation loop found
that the worklist incorrectly mapped this slug to `UI::PathView`, which is a
vector drawing / Bezier-path shape view (SVG MoveTo/LineTo/CurveTo/Close
commands). The HIG path-controls slug maps to NSPathControl -- a separate,
unimplemented component. This document describes the planned API.

The HIG explicitly states path controls are "Not supported in iOS, iPadOS, tvOS,
visionOS, or watchOS." Only macOS is in scope for the native control; an iOS
fallback using a custom HStack of label + chevron pairs is the documented
workaround.

## Feel of the flow
_What this component "means" in a UI, and when to reach for it._

A path control communicates location within a file system hierarchy. It is used
in document windows and file-browsing panels to show users exactly where the
focused file or folder lives: disk, then each parent folder, then the selected
item. Clicking any segment in the standard style opens the folder in Finder;
clicking in the popup style reveals a hierarchical dropdown menu.

This is a specialized, file-system-oriented control. Do not use it for general
breadcrumb navigation (that is a custom HStack pattern) or in toolbars or status
bars (the HIG prohibits that placement). The Finder's path bar at the bottom of
the window body is the canonical use case.

(HIG: "Use a path control in the window body, not the window frame. Path controls
aren't intended for use in toolbars or status bars." -- Path controls / Best
practices.)

## Quickstart

```crystal
# Planned API -- not yet implemented. Shown for design intent only.
# UI::PathControl does not exist; this is what the implementation should look like.

path = UI::PathControl.new(
  style: :standard,
  components: [
    {icon: "externaldrive", name: "Macintosh HD"},
    {icon: "folder",        name: "Users"},
    {icon: "folder",        name: "Documents"},
    {icon: "folder",        name: "Projects"},
    {icon: "folder.fill",   name: "asset_pipeline"},
  ],
  editable: false
)
path.accessibility_label = "File path: Macintosh HD / Users / Documents / Projects / asset_pipeline"
```

Renders: on macOS, `NSPathControl` with the `.standard` path style, each component
rendered by AppKit as a rounded pill containing an NSImage (SF Symbol) and an NSTextField
with the segment name, separated by right-pointing chevron images. No Liquid Glass material
is used -- NSPathControl uses the standard control background from the window content area.
iOS: not supported natively; render as a horizontal `UIStackView` of `UILabel` + SF Symbol
`chevron.right` `UIImageView` pairs.

## Customization

| Knob | Type | Default | Effect |
|------|------|---------|--------|
| `style` | `:standard` or `:popup` | `:standard` | Standard shows the full linear list; popup shows only the selected item and opens a dropdown on click. |
| `components` | `Array({icon: String, name: String})` | `[]` | Each entry becomes one segment: an SF Symbol icon followed by the folder or file name. |
| `editable` | `Bool` | `false` | When true, the control accepts drag-and-drop of items and shows a Choose command in the popup menu. |
| `accessibility_label` | `String?` | `nil` | VoiceOver announcement for the entire control; should spell out the full path as a sentence. |

**Theming**: Path controls derive their foreground from `NSColor.labelColor` and their
background from the window content area -- no separate theme tokens are needed. No Liquid
Glass material is involved. See `foundations/color-and-theming.md` for system color semantics.

## Light / dark appearance notes

NSPathControl fully participates in the macOS appearance system via `NSVisualEffectView`
and semantic colors:

**Light appearance:** The control background is the window content white (~1.0 RGB).
Segment text uses `NSColor.labelColor` which resolves to near-black (~0.0 RGB) in light
mode, giving approximately 21:1 contrast. Chevron separators use `NSColor.secondaryLabelColor`
(~0.56 RGB gray). SF Symbol icons render in template mode, inheriting the label color.

**Dark appearance:** The window content background shifts to DarkAqua (~0.12 RGB).
`NSColor.labelColor` resolves to near-white (~0.92 RGB), maintaining ~15:1 contrast.
`NSColor.secondaryLabelColor` resolves to ~0.60 RGB -- still clearly visible against
the dark background. NSPathControl adapts automatically because it uses semantic colors
throughout; no explicit appearance branch is required in the renderer.

**SF Symbol variants:** Folder icons should use `folder` (outline, unselected) and
`folder.fill` (filled, selected/last segment). Drive icons use `externaldrive` or
`internaldrive`. All render as template images so they track the label color in both
appearances.

**iOS fallback:** A custom HStack of UILabel + UIImageView(chevron.right) pairs should
use `UIColor.label` for text (resolves to near-black in light, near-white in dark) and
`UIColor.secondaryLabel` for the chevron separator. This ensures automatic dark mode
adaptation without any explicit appearance override.

**Contrast caveat:** If a brand override substitutes a custom accent color for the segment
text (e.g., brand blue on a light-gray segment background), verify the contrast in both
appearances. `NSColor.labelColor` at 21:1 is generous; a brand color at 3:1 may pass
large-text WCAG but fail body-text requirements if segment names are short and small.

## Customization / brand override
_How to go from the HIG-default look to your brand voice, without giving up HIG's
legibility, hit targets, or appearance-tracking._

Note: the following snippets show the intended API for the planned `UI::PathControl`.
They cannot be compiled today because the view does not yet exist.

**Swap the accent to your brand primary.**
```crystal
# Override the tint color applied to the selected segment's background pill.
# All other HIG defaults (NSColor.labelColor text, chevron sizing, hit targets)
# remain untouched.
path = UI::PathControl.new(style: :standard, components: [...])
# When UI::PathControl is implemented, expose an accent_color knob:
# path.accent_color = UI::Color.new(r: 0.2, g: 0.4, b: 0.9)  # brand blue
# The segment name text MUST remain NSColor.labelColor; do not tint text to brand color
# without verifying contrast in both light and dark.
```

**Replace the standard list with a popup for compact layouts.**
```crystal
# The popup style shows only the selected item (last component) and reveals the
# full hierarchy in a dropdown menu on click. Useful when horizontal space is limited.
path = UI::PathControl.new(
  style: :popup,
  components: [
    {icon: "externaldrive", name: "Macintosh HD"},
    {icon: "folder",        name: "Users"},
    {icon: "folder.fill",   name: "asset_pipeline"},  # shown in the button face
  ],
  editable: false
)
# Note: popup style removes Liquid Glass considerations entirely -- NSPathControl
# uses the system popup button rendering (NSBezelStyleRounded), not a glass surface.
```

**Override typography while keeping HIG spacing.**
```crystal
# NSPathControl does not expose a public font API in AppKit; font size is set
# by the control's cell. The HIG does not prescribe a specific type size -- the
# control uses the system default (~13pt on macOS). If a brand spec requires a
# different size, use the planned font knob:
# path.font = UI::Font.system(size: 15.0, weight: :regular)
# Do NOT increase font size beyond 17pt without also increasing the control height
# to maintain the chevron-to-text vertical alignment that NSPathControl provides.
```

## Feel recipes
Short examples that map design intent to code.

**"I want to show a Finder-style path bar at the bottom of a document window."**
-> Use `style: :standard` with all path components from disk root to current file.
-> Place the PathControl in a `HStack` at the bottom of the window's content VStack,
   below the main content area (not in the toolbar or status bar).
-> Set `editable: false` for read-only display.

**"I want a compact path selector that reveals the full hierarchy on click."**
-> Use `style: :popup` with the full component chain.
-> Set `editable: true` to include a Choose command in the popup menu, letting the
   user navigate to a new location.
-> Place in a form row alongside a label: `HStack([Label("Location:"), pathControl])`.

## What happens on each platform
- **iOS 26**: Not supported by HIG. The planned implementation renders a horizontal
  `UIStackView` of `UILabel` + SF Symbol `chevron.right` `UIImageView` pairs as a
  fallback. No UIKit native equivalent of NSPathControl exists.
- **iPadOS 26**: Same fallback as iOS. No native breadcrumb path control.
- **macOS 26**: `NSPathControl` with `.NSPathStyleStandard` or `.NSPathStylePopUp`.
  Appearance-adaptive via semantic `NSColor` values. No Liquid Glass material -- window
  body content control, not a surface overlay.

## HIG citations (validated)
- Path controls: "A path control shows the file system path of a selected file or folder."
- Path controls -- Best practices: "Use a path control in the window body, not the window
  frame. Path controls aren't intended for use in toolbars or status bars."
- Path controls -- Platform considerations: "Not supported in iOS, iPadOS, tvOS, visionOS,
  or watchOS."
- Path controls -- Standard style: "A linear list that includes the root disk, parent folders,
  and selected item. Each item appears with an icon and a name."
- Path controls -- Pop up style: "A control similar to a pop-up button that shows the icon
  and name of the selected item. People can click the item to open a menu containing the root
  disk, parent folders, and selected item."

Validation report:
[validation/reports/path-controls.md](../validation/reports/path-controls.md)

## Related
- `UI::PathView` -- the vector drawing / Bezier-path shape view (not a breadcrumb control);
  named similarly but serves a completely different purpose.
- `UI::HStack` -- use for a custom iOS breadcrumb fallback composed of Label + chevron pairs.
- `UI::NavigationStack` -- for hierarchical in-app navigation (not file system paths).
- `recipes/file-browser.md` -- multi-component pattern combining PathControl, ListView, and
  toolbar for a document-browser window layout.
