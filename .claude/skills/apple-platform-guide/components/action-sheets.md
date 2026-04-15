---
slug: action-sheets
ui_view: UI::Sheet
priority: P0
platforms: [iOS, iPadOS, macOS]
hig_page: ../../apple-hig/pages/action-sheets.md
validation_report: ../validation/reports/action-sheets.md
---

# UI::Sheet (action sheet pattern)

> A modal surface that presents two to four choices people can make in
> response to an intentional action they just took. On iOS / iPadOS this
> presents as the bottom-anchored sheet with destructive choice on top
> and Cancel on the bottom. On macOS it presents as a window-attached
> sheet with the same ordering.

## Feel of the flow
*What this component "means" in a UI, and when to reach for it.*

Reach for an action sheet when the user *initiated* an action (pressing
"Cancel" while editing a draft, tapping "Logout", trying to discard
unsaved changes) and you need to confirm or refine that action with a
small set of related choices.

Don't reach for it when:
- You're *informing* the user about a system event ("battery low",
  "lost connection") -- that's `UI::Alert`.
- You're offering *unrelated* options from a button or icon -- that's a
  `UI::MenuButton`.
- You need a long modal flow with form input -- that's a regular
  `UI::Sheet` (without the action-sheet styling) or full-screen modal.

HIG: *"Use an action sheet -- not an alert -- to offer choices related to
an intentional action."* (Action sheets / Best practices.)

## Quickstart

```crystal
content = UI::VStack.new(spacing: 8.0)
content << UI::Label.new("Are you sure you want to delete the draft?")
content << UI::Button.new("Delete Draft")    # destructive (planned: role: :destructive)
content << UI::Button.new("Save Draft")
content << UI::Button.new("Cancel")          # planned: role: :cancel

sheet = UI::Sheet.new(content)
presenter = UI::SheetPresenter.new(sheet)

# When the user attempts the dangerous action:
presenter.present
# When a choice is made:
presenter.dismiss
```

Renders today:
- **iOS 26 / iPadOS 26**: `UIViewController.present(_:animated:)` with a
  bottom-anchored sheet. Future renderer will switch to
  `UIAlertController(style: .actionSheet)` when the content matches the
  prompt-then-actions shape.
- **macOS 26**: `[NSWindow beginSheet:completionHandler:]` attached to
  the active window. Centered above the parent window content.

## Customization

| Knob | Type | Default | Effect |
|------|------|---------|--------|
| `content` | `UI::View?` | `nil` | The view tree shown inside the sheet. For action sheets, a `UI::VStack` of label + buttons. |
| `is_presented` | `Bool` | `false` | Drives presentation. Use `UI::SheetPresenter` rather than flipping this directly -- the presenter calls `on_dismiss` on close. |
| `shows_drag_indicator` | `Bool` | `true` | iOS only. The drag handle on the top edge that indicates the sheet can be swiped down. Set to `false` for action sheets where dismissal should only happen via the explicit Cancel button. |
| `detents` | `Array(Symbol)` | `[:medium, :large]` | Allowed sheet heights. For a short action sheet, set to `[:small]` so the sheet hugs the action stack. |
| `selected_detent` | `Symbol` | `:medium` | Which detent to start at. |
| `on_dismiss` | `Proc(Nil)?` | `nil` | Called when the sheet dismisses for any reason (Cancel tap, swipe-down, programmatic). |

**Theming (planned, not yet wired):**
- `UI::Theme.action_sheet_corner_radius` -- HIG default ~14pt iOS, 10pt
  macOS.
- `UI::Theme.action_sheet_material` -- defaults to `:regular` glass on
  iOS 26 / macOS 26 per HIG.
- `UI::Theme.action_sheet_destructive_color` -- defaults to system red.

## Light / dark appearance notes

The sheet surface tracks the system appearance automatically because the
renderer composes a real material view in each capture: on macOS an
`NSVisualEffectView` with material `NSVisualEffectMaterial.menu`, and on
iOS a `UIVisualEffectView` preferring `UIGlassEffect` (iOS 26) with
`UIBlurEffect(style: .systemChromeMaterial)` as the fallback. Both
materials are appearance-aware, so a single component renders
light-frosted in light mode and dark-frosted in dark mode.

Text colors today come from `UI::Theme.apple_default.on_surface` (pure
black, see `src/ui/theme.cr:62`) and `UI::Theme.apple_default.primary`
(system blue, `src/ui/theme.cr:55`). Planned — semantic `label_primary`
token tracking `NSColor.labelColor` / `UIColor.labelColor` so titles and
body text auto-resolve for dark mode rather than rendering near-black on
the dark-frosted material. Until that lands, titles may be difficult to
read in dark captures; this is the iteration-12 gap logged in
`validation/gaps.md`.

Destructive actions use `UI::Theme.apple_default.error`
(1.0, 0.23, 0.19 — system red). It is distinguishable from the primary
accent (0.0, 0.478, 1.0 — system blue) in both appearances. No SF Symbol
glyphs are applied today; a future `UI::Button#symbol` knob will prepend
`trash` on the destructive row and `xmark.circle` on Cancel following
HIG convention.

## Customization / brand override
_How to go from the HIG-default look to your brand voice, without giving
up HIG's legibility, hit targets, or appearance-tracking._

**Swap the accent to your brand primary.**
```crystal
theme = UI::Theme.apple_default
theme.primary = UI::ThemeColor.new(r: 0.95, g: 0.26, b: 0.21)   # brand red
# keep theme.error (destructive) and all font_size_* / corner_radius_*
# untouched so hit targets, spacing, and destructive signalling stay HIG.
```

**Replace the glass material with a flat brand surface.**
```crystal
# Planned API — once UI::Sheet#surface_style: :plain lands:
sheet = UI::Sheet.new(content, surface_style: :plain)
theme.surface = UI::ThemeColor.new(r: 0.12, g: 0.12, b: 0.14)  # brand card
# Trade-off: removes the HIG Liquid Glass (the feature that makes the
# sheet feel Apple-native). Only use when your brand demands an opaque,
# non-translucent modal surface.
```

**Override typography while keeping HIG spacing.**
```crystal
theme.font_family = "GT-America"        # brand font
theme.font_size_body = 17.0             # keep HIG body size
# Do NOT override corner_radius_* or spacing tokens — HIG-mandated
# geometry keeps the sheet feeling right.
```

## Feel recipes
Short examples that map design intent to code.

**"Discard / save / cancel after an Esc tap on an unsaved doc"**
```crystal
content = UI::VStack.new(spacing: 8.0)
content << UI::Label.new("Discard unsaved changes?")
content << UI::Button.new("Discard")   # planned: role: :destructive
content << UI::Button.new("Save Draft")
content << UI::Button.new("Cancel")    # planned: role: :cancel
sheet = UI::Sheet.new(content)
sheet.shows_drag_indicator = false     # force explicit Cancel
sheet.detents = [:small]               # hug the actions
```

**"Quick actions menu from a context menu (iOS)"**
```crystal
# Wrong tool -- use UI::MenuButton instead. Menus are for choosing
# operations to perform; action sheets are for confirming an action
# you've already initiated.
```

## What happens on each platform
- **iOS 26 / iPadOS 26**: bottom-anchored modal sheet (today renders
  via `UIViewController.present`; planned upgrade to true
  `UIAlertController.actionSheet` once `UI::Button` has `role`). Tap
  outside dismisses and fires `on_dismiss`.
- **macOS 26**: window-attached `NSWindow` sheet centered over the
  parent. Esc / Cmd-. / Cancel button all dismiss.
- **Validation host renders inline.** For visual validation only, the
  showcase host renders the sheet's content surface as a plain `VStack`
  on the host window (skipping the modal lifecycle) so the screenshot
  pipeline can capture the content. This is a host convention, NOT a
  recommended app pattern -- always present via `SheetPresenter` in
  real code.

## HIG citations (validated)
- *"Use an action sheet -- not an alert -- to offer choices related to
  an intentional action."* -- Action sheets / Best practices.
- *"Make destructive choices visually prominent. Use the destructive
  style for buttons that perform destructive actions, and place these
  buttons at the top of the action sheet where they tend to be most
  noticeable."* -- Action sheets / Best practices.
- *"Place the Cancel button at the bottom of the action sheet."* --
  Action sheets / Best practices.
- *"Aim to keep titles short enough to display on a single line."* --
  Action sheets / Best practices.
- *"Avoid letting an action sheet scroll. The more buttons an action
  sheet has, the more time and effort it takes for people to make a
  choice."* -- Action sheets / iOS, iPadOS.

Validation report with side-by-side HIG ref and live screenshots:
[validation/reports/action-sheets.md](../validation/reports/action-sheets.md)

## Related
- `UI::Alert` -- for system-initiated information (not user-initiated
  choices).
- `UI::MenuButton` -- for unrelated options dropped from a button.
- `UI::ConfirmationDialog` -- for destructive single-question
  confirmations without action variants.
- `UI::Sheet` (this same view, with `is_presented` + non-action
  content) -- for longer modal flows.
- `foundations/hierarchy-and-emphasis.md` -- on choosing destructive vs
  cancel framing.
