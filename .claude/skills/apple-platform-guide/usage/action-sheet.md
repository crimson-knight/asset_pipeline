# UI::ActionSheet

A modal sheet of choices presented at the bottom of the screen on iOS. **Tier 3 (iOS-gated).** Cross-platform code uses `UI::ActionSheetWithWebFallback` which delegates to the iOS gated class on `-Dios` builds and an accessible web fallback elsewhere.

## Default experience

- **iOS:** Routes through SwiftKit's `ConfirmationDialogFacade` which uses SwiftUI's `.confirmationDialog(titleKey:isPresented:titleVisibility:actions:message:)`. **Phase 10D-polish iter 2 (2026-05-27)** extended the facade to take parallel `actionLabels` / `actionStyles` / `actionTokens` arrays so the iOS surface honors any number of actions. The cancel-style button is automatically pinned at the bottom by SwiftUI; destructive-style buttons render in red.
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

- **Callbacks:** Each `Action#action : Proc(Nil)?` fires when the user taps that button. **Phase 10D-polish iter 2:** all actions fire (no longer dropped at the binary-degradation boundary).
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

- **Multi-action support:** RESOLVED by Phase 10D-polish iter 2 (`B-ACTIONSHEET-MULTI-ACTION`). The iOS facade now iterates `view.actions` natively; all actions render and fire callbacks. The action list can be any length; SwiftUI handles layout.
- **Material override:** ActionSheet does not support material override (system-drawn chrome by HIG mandate).
- **Tier 3 gating:** building without `-Dios` fails compile at any `UI::ActionSheet.new(...)` site. Use `UI::ActionSheetWithWebFallback` for cross-platform code.

## Evidence

- **Canonical example:** `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:249-275`
- **Screenshot:** `docs/initiative-cross-platform-ui/handoff/phase-10-d-polish-screenshots/04_actionsheet_share.png`
- **Spec coverage:** `spec/web/ui/views/action_sheet_with_web_fallback_spec.cr`
