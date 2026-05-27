# UI::Popover

A lightweight transient overlay anchored to a host view. On iPad / macOS / desktop web it renders as a positioned floating panel with an arrow pointing at the anchor; on iPhone / mobile web SwiftUI falls back to a sheet.

## Default experience

- **iOS:** SwiftUI `.popover` falls back to a `.sheet` on iPhone (per Apple SwiftUI behavior). Renders as a bottom-anchored sheet covering the lower half of the screen.
- **iPadOS:** SwiftUI `.popover` proper — a floating panel with an arrow pointing at the anchor view. Liquid Glass material on iOS 26+ (`UIGlassEffect`); `UIBlurEffectStyleSystemChromeMaterial` fallback on pre-26.
- **macOS:** `NSPopover` proper — floating panel with an arrow, NSVisualEffectMaterial.popover.
- **web wide:** CSS-positioned floating panel via vanilla JS positioning; HTML `<dialog popover>` on supporting browsers.
- **web narrow:** falls back to bottom-anchored sheet (per `popovers.md` HIG note).
- **Android:** Material `DropdownMenu` (functional analog).

## Crystal API

```crystal
# Minimal invocation
popover = UI::Popover.new(my_menu_view, :bottom)
popover.is_presented = true
```

```crystal
# Realistic Voyager invocation
# samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:296-340
if state.show_overflow_menu
  menu_content = UI::VStack.new(spacing: 4.0)
  menu_content.alignment = UI::Alignment::Leading
  menu_content.padding = UI::EdgeInsets.new(top: 8.0, trailing: 12.0, bottom: 8.0, leading: 12.0)
  menu_content.minimum_width = 220.0

  sort_btn = UI::Button.new("Sort by deadline")
  sort_btn.role = :secondary
  sort_btn.on_tap = -> { Voyager.dispatch(:sort_by_deadline) }
  menu_content << sort_btn.as(UI::View)
  # ... hide_btn, clear_btn ...

  overflow_popover = UI::Popover.new(menu_content.as(UI::View), :bottom)
  overflow_popover.preferred_width = 240.0
  overflow_popover.on_dismiss = -> { Voyager.dispatch(:hide_overflow); nil }
  overflow_popover.is_presented = true
  overflow_popover.test_id = "voyager-todos-overflow-popover"
  overflow_popover.accessibility_label = "More actions menu"
  root << overflow_popover.as(UI::View)
end
```

## Behavior contract

- **Callbacks:**
  - `on_dismiss : Proc(Nil)?` — fires when the popover dismisses (tap outside, programmatic close, escape on macOS).
- **Dismissal paths:**
  - Tap outside the popover → fires `on_dismiss`.
  - Programmatic `is_presented = false` → dismisses.
  - Escape (macOS) → dismisses.
  - Action inside popover → typically the action handler clears the `show_overflow_menu` flag in app state.
- **Focus / keyboard:** Popover content takes focus on mount; tab navigates within. macOS uses NSPopover's auto-focus.
- **Reduced motion:** SwiftUI / AppKit handle automatically.
- **Reactivity:** `is_presented` is NOT reactive-setter today (unlike `UI::Sheet`). The Voyager pattern mutates `show_overflow_menu` + dispatches Rerender to re-emit the popover with the new state.

## Customization knobs

| Property | Type | Default | Effect |
|----------|------|---------|--------|
| `content` | `View?` | `nil` | Popover body. |
| `is_presented` | `Bool` | `false` | Visibility. |
| `arrow_edge` | `Symbol` | `:bottom` | Where the arrow points. `:top` / `:bottom` / `:leading` / `:trailing`. |
| `preferred_width` | `Float64?` | `nil` | Preferred popover width (pt). |
| `preferred_height` | `Float64?` | `nil` | Preferred popover height (pt). |
| `on_dismiss` | `Proc(Nil)?` | `nil` | Dismiss handler. |
| `material_semantic` | `Symbol?` | `nil` | HIG-canonical default is `:popover` (NSVisualEffectMaterialPopover / regularMaterial). Override with other Phase 5 v2 keys. |

## Override path

**Public knobs cover arrow direction + size + material.**

**Override paths:**

- **Anchor binding:** SwiftUI's `.popover(isPresented:attachmentAnchor:arrowEdge:)` supports anchoring to a specific source view via `PopoverPresenter#anchor`. Today the `UI::PopoverPresenter` accepts an anchor but the SwiftKit facade does not yet wire it through — popover renders centered on the host. **Backlog item: `B-POPOVER-ANCHOR-VIEW`** — `docs/initiative-cross-platform-ui/architecture/intent-backlog.md`.
- **iPhone behavior (force popover, no sheet fallback):** SwiftUI's `.popover(arrowEdge:)` accepts a `presentationCompactAdaptation(.popover)` modifier on iOS 16.4+. Not yet exposed via knob. **Backlog item: `B-POPOVER-COMPACT-ADAPTATION`**.
- **iOS 26 Liquid Glass override:** override `material_semantic` to one of the Phase 5 v2 keys.
- **Reactive `is_presented`:** like `UI::Toggle#is_on=` and `UI::Sheet#is_presented=`, a reactive setter would dispatch through the SwiftKit bridge to flip an `@Published` field. Not yet wired. **Backlog item: `B-POPOVER-REACTIVE-PRESENTED`**.

## Evidence

- **Canonical example:** `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:296-340`
- **Screenshot:** `docs/initiative-cross-platform-ui/handoff/phase-10-d-polish-screenshots/07_popover_overflow.png` (note: iPhone falls back to sheet-like full-screen overlay per SwiftUI default)
- **Spec coverage:** `spec/web/ui/views/popover_spec.cr`
