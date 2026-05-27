# UI::ActionSheet

A modal sheet of choices presented at the bottom of the screen on iOS. **Tier 3 (iOS-gated).** Cross-platform code uses `UI::ActionSheetWithWebFallback` which delegates to the iOS gated class on `-Dios` builds and an accessible web fallback elsewhere.

## Default experience

- **iOS:** Currently routes through SwiftKit's `ConfirmationDialogFacade` which exposes a **binary confirm/cancel surface**. An ActionSheet with more than one non-cancel action degrades to `{first non-cancel action, cancel action}` pending a Phase 5 multi-action SwiftUI facade. The bottom-anchored sheet with title + message + button card uses SwiftUI's `.confirmationDialog(titleKey:isPresented:titleVisibility:actions:message:)`.
- **iPadOS:** Same as iOS but presented as a popover anchored to the source view by SwiftUI default.
- **macOS:** `NSAlert(alertStyle: .informational)` with the actions as alert buttons (system-drawn).
- **web (wide / narrow):** Use `UI::ActionSheetWithWebFallback`. Wide → modal centered card; narrow → bottom-anchored sheet with vanilla-JS swipe-to-dismiss.
- **Android:** Material `BottomSheetDialogFragment`.

## Crystal API

```crystal
# Minimal invocation (iOS only — Tier 3 gate)
sheet = UI::ActionSheet.new("Title", "Optional message")
sheet.add_action("Primary") { do_thing }
sheet.add_action("Cancel", :cancel)
sheet.is_presented = true

# Cross-platform — use the with-fallback wrapper
sheet = UI::ActionSheetWithWebFallback.new("Title", "Optional message")
sheet.add_action("Primary") { do_thing }
sheet.add_action("Cancel", :cancel)
sheet.is_presented = true
```

```crystal
# Realistic Voyager invocation
# samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:249-275
if share_id = state.pending_share_todo_id
  target = state.find_todo(share_id)
  sheet_title = target ? "Share \"#{target.title}\"" : "Share todo"
  share_sheet = UI::ActionSheetWithWebFallback.new(sheet_title, "Choose how to share this todo.")
  share_sheet.add_action("Copy to Clipboard") {
    Voyager.dispatch(:copy_pending_share)
    nil
  }
  share_sheet.add_action("Print This Todo") {
    Voyager.dispatch(:print_pending_share)
    nil
  }
  share_sheet.add_action("Cancel", :cancel) {
    Voyager.dispatch(:cancel_pending)
    nil
  }
  share_sheet.is_presented = true
  share_sheet.test_id = "voyager-todos-share-sheet"
  share_sheet.accessibility_label = "Share options"
  root << share_sheet.as(UI::View)
end
```

## Behavior contract

- **Callbacks:** Each `Action#action : Proc(Nil)?` fires when the user taps that button. Today on iOS only the first non-cancel action AND the cancel action actually fire — additional actions are dropped by the ConfirmationDialogFacade degradation path.
- **Dismissal paths:**
  - Tap action → dismisses, fires the chosen action's Proc.
  - Tap Cancel → dismisses, fires cancel action (if any).
  - iOS swipe-down from sheet handle → fires no action; the screen is responsible for clearing the pending flag.
- **Focus / keyboard:** System-managed. Destructive style highlights the action red (iOS).
- **Reduced motion:** SwiftUI handles automatically.
- **Reactivity:** `is_presented` is a plain property today (not reactive like `UI::Sheet`); the Voyager pattern is to mutate state + Rerender, which produces a new ActionSheet view tree.

## Customization knobs

| Property | Type | Default | Effect |
|----------|------|---------|--------|
| `title` | `String` | `""` | Sheet title. Empty hides the title row. |
| `message` | `String` | `""` | Secondary message. Empty hides the message row. |
| `actions` | `Array(Action)` | `[]` | Action list. Each carries `label`, `style` (`:default` / `:destructive` / `:cancel`), and optional `Proc(Nil)?`. |
| `is_presented` | `Bool` | `false` | Modal visibility. |

## Override path

**Default chrome is system-resolved.** ActionSheet inherits SwiftUI's `.confirmationDialog` chrome which is system-drawn.

**Override paths:**

- **Multi-action support beyond binary:** today's iOS path only honors `primary_action + cancel_action`. To present a >2-action sheet, render a `UI::Sheet` with `surface_style: :grouped_card` containing a VStack of buttons. **Backlog item: `B-ACTIONSHEET-MULTI-ACTION`** — `docs/initiative-cross-platform-ui/architecture/intent-backlog.md`.
- **Material override:** ActionSheet does not currently support material override (the Tier 3 gate has no material knob today). Tracked under same backlog.
- **Tier 3 gating:** building without `-Dios` fails compile at any `UI::ActionSheet.new(...)` site. Use `UI::ActionSheetWithWebFallback` for cross-platform code.

## Evidence

- **Canonical example:** `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:249-275`
- **Screenshot:** `docs/initiative-cross-platform-ui/handoff/phase-10-d-polish-screenshots/04_actionsheet_share.png`
- **Spec coverage:** `spec/web/ui/views/action_sheet_with_web_fallback_spec.cr`
