# UI::Sheet

A modal sheet that slides up from the bottom on iOS (with detents + drag-to-dismiss) or appears as a floating dialog on macOS. The default chrome is Liquid Glass material with grouped-card content padding.

## Default experience

- **iOS:** SwiftUI `.sheet(isPresented:onDismiss:content:)` wrapping the child view in a `UIHostingController`. Default detents `[:medium, :large]`, drag indicator visible at the top, drag-to-dismiss enabled. On iOS 26+, the sheet body uses `.glassEffect()` for Liquid Glass; pre-26 falls back to `.presentationBackground(.thickMaterial)`.
- **iPadOS:** Same as iOS but presented as a centered card with rounded corners on the larger canvas.
- **macOS:** Presented as a modal sheet attached to the host window (`NSViewController.presentAsSheet(_:)`), NSVisualEffectMaterial.sheet.
- **web (wide / narrow):** HTML overlay; framework renders the sheet body inline with `surface_style: :grouped_card` chrome (rounded corners + grouped-background fill + 16pt padding).
- **Android:** Material `ModalBottomSheet`.

## Crystal API

```crystal
# Minimal invocation
sheet = UI::Sheet.new(my_content_view)
sheet.is_presented = true
```

```crystal
# Realistic Voyager invocation
# samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:277-294
if editor_id = state.pending_editor_todo_id
  editor_view = build_editor_content(state, editor_id)
  editor_sheet = UI::Sheet.new(editor_view, surface_style: :grouped_card)
  editor_sheet.detents = [:medium, :large]
  editor_sheet.shows_drag_indicator = true
  editor_sheet.on_dismiss = -> { Voyager.dispatch(:close_editor_sheet); nil }
  editor_sheet.is_presented = true
  editor_sheet.test_id = "voyager-todos-editor-sheet"
  editor_sheet.accessibility_label = "Edit todo"
  root << editor_sheet.as(UI::View)
end
```

## Behavior contract

- **Callbacks:**
  - `on_dismiss : Proc(Nil)?` — fires when the sheet dismisses (drag-down, programmatic close, or system close). The Voyager pattern clears the pending-flag in this handler so a stale state doesn't immediately re-present.
- **Dismissal paths:**
  - Drag-down (iOS) → fires `on_dismiss`.
  - Programmatic `sheet.is_presented = false` → drives `apsk_sheet_set_presented(false)` → SwiftUI dismisses → fires `on_dismiss`.
  - Tap-outside (macOS) → fires `on_dismiss`.
- **Focus / keyboard:** Sheet body gets keyboard focus on mount; iOS keyboard-avoidance is automatic. Escape on macOS dismisses.
- **Reduced motion:** SwiftUI handles automatically (sheet still slides but with reduced spring physics).
- **Reactivity:** **`is_presented=` IS reactive.** Setting it after the renderer has emitted the SwiftKit hosting view dispatches through `apsk_sheet_set_presented`, which flips the `APSKSheetState.isPresented` `@Published` field on the main queue. SwiftUI observes via `@ObservedObject` and presents / dismisses without rebuilding the tree (`src/ui/views/sheet.cr:25-35`).

## Customization knobs

| Property | Type | Default | Effect |
|----------|------|---------|--------|
| `content` | `View?` | `nil` | The view rendered inside the sheet. |
| `is_presented` | `Bool` | `false` | **Reactive.** Modal visibility. |
| `shows_drag_indicator` | `Bool` | `true` | Show / hide the drag-handle bar at the top. |
| `detents` | `Array(Symbol)` | `[:medium, :large]` | iOS sheet sizes. Supports `:small` (160pt), `:medium`, `:large`. |
| `selected_detent` | `Symbol` | `:medium` | Initial detent on mount. |
| `on_dismiss` | `Proc(Nil)?` | `nil` | Dismiss callback. |
| `surface_style` | `Symbol` | `:auto` | Controls inline (non-presented) chrome. `:auto` / `:grouped_card` → HIG-style grouped card; `:plain` → bare container. |
| `material_semantic` | `Symbol?` | `nil` | HIG-canonical default is `:sheet` (NSVisualEffectMaterialSheet on macOS; `.thickMaterial` via `.presentationBackground` on iOS 16.4+). Override with `:menu`, `:hud`, etc. per the Phase 5 v2 semantic material palette. |

## Override path

**Public knobs cover most cases.** Detent sizes, drag indicator, dismiss handler, surface style, and material are all knobs.

**Override paths:**

- **Custom detent height:** today only `[:small, :medium, :large]` are accepted by the facade (`SheetFacade.swift:applyDetents`). A custom `.height(Pt)` requires extending the facade switch. **Backlog item: `B-SHEET-CUSTOM-DETENT-HEIGHT`** — `docs/initiative-cross-platform-ui/architecture/intent-backlog.md`.
- **Disable drag-to-dismiss:** today not exposed; SwiftUI offers `.interactiveDismissDisabled(true)`. **Backlog item: `B-SHEET-INTERACTIVE-DISMISS-DISABLED`** — tracked separately in the catalog under `:interactive_dismiss_disabled`.
- **Edge-to-edge content (no padding):** use `surface_style: :plain`.
- **Custom Liquid Glass on iOS 26:** override `material_semantic` to one of the Phase 5 v2 keys (`:menu`, `:hud`, `:sidebar`, etc.). For a fully custom material, wrap content in `UI::GlassBackground` and pass `surface_style: :plain`.

## Evidence

- **Canonical example:** `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:277-294`
- **Screenshot:** `docs/initiative-cross-platform-ui/handoff/phase-10-d-polish-screenshots/05_sheet_editor_new.png` (new-todo path) and `06_datepicker_deadline.png` (edit path)
- **Spec coverage:** `spec/web/ui/views/sheet_spec.cr`
