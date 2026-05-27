# UI::Alert

A modal alert dialog for critical confirmations — title, message, and a small set of role-differentiated action buttons. SwiftUI's `.alert(...)` is fully system-drawn; the framework forwards the title + message + buttons and lets the platform paint the chrome.

## Default experience

- **iOS:** SwiftUI `.alert(title, isPresented:, actions:, message:)`. System-drawn modal card centered over the host scene, blurred backdrop, vibrant title, secondary message, role-coloured buttons (destructive = red, cancel = bold/blue). Tapping any button dismisses the alert.
- **iPadOS:** identical to iOS.
- **macOS:** AppKit visit emits `NSAlert` (system-drawn modal sheet attached to the host window). Destructive role uses NSAlert critical style.
- **web wide:** HTML `<dialog>` overlay with backdrop; framework-rendered (no SwiftUI). Role buttons styled via `.--destructive` / `.--cancel` CSS classes.
- **web narrow:** same as web wide.
- **Android:** Material `AlertDialog`.

## Crystal API

```crystal
# Minimal invocation
alert = UI::Alert.new("Delete?", "This action cannot be undone.")
alert.add_button("Cancel", :cancel)
alert.add_button("Delete", :destructive) { state.delete }
alert.is_presented = true
```

```crystal
# Realistic Voyager invocation
# samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:225-247
if delete_id = state.pending_delete_todo_id
  target = state.find_todo(delete_id)
  title_text = target ? "Delete \"#{target.title}\"?" : "Delete this todo?"
  alert = UI::Alert.new(title_text, "This can't be undone.")
  alert.add_button("Cancel", :cancel) {
    Voyager.dispatch(:cancel_pending)
    nil
  }
  alert.add_button("Delete", :destructive) {
    Voyager.dispatch(:confirm_delete)
    nil
  }
  alert.is_presented = true
  alert.test_id = "voyager-todos-delete-alert"
  alert.accessibility_label = "Confirm delete"
  root << alert.as(UI::View)
end
```

## Behavior contract

- **Callbacks:** Each `AlertButton#action : Proc(Nil)?` fires synchronously when the user taps the corresponding button. No callback fires on system-dismiss (escape on macOS, tap-outside on web); the convention is to wire dismiss-equivalent to the Cancel button.
- **Dismissal paths:**
  - Button tap → dismisses, fires action.
  - macOS escape key → triggers the `:cancel`-roled button if any; else dismisses without action.
  - iOS swipe-to-dismiss NOT applicable (system alerts are modal-only).
- **Focus / keyboard:** System-managed. Default focus on the trailing button (typically destructive or confirmation) per HIG.
- **Reduced motion:** SwiftUI / AppKit handle reduced motion automatically; alerts already use minimal animation.
- **Reactivity:** `is_presented=` is reactive — the property setter pushes through the SwiftKit bridge so post-render mutation drives the alert presentation. The Voyager pattern: mutate `state.pending_delete_todo_id` + dispatch Rerender → the screen's `build(ctx)` re-emits the alert with `is_presented = true`.

## Customization knobs

| Property | Type | Default | Effect |
|----------|------|---------|--------|
| `title` | `String` | (required) | Bold title. |
| `message` | `String` | `""` | Secondary message. Empty = no message line. |
| `buttons` | `Array(AlertButton)` | `[]` | Action buttons (label + style symbol + optional `Proc(Nil)?`). |
| `is_presented` | `Bool` | `false` | Modal visibility. Reactive setter. |
| `material_semantic` | `Symbol?` | `nil` | Per HIG, alert chrome is `:system_resolved` — this property is inert on the active SwiftUI `.alert` path; preserved for cross-platform symmetry. |

`AlertButton#style` accepts `:default`, `:cancel`, `:destructive`. SwiftUI maps these to `ButtonRole.destructive` / `.cancel` / nil.

## Override path

**Default chrome is system-resolved.** Apple HIG explicitly recommends letting the system paint alert chrome — overriding is generally inappropriate.

**Override paths:**

- **Button order:** SwiftUI controls placement based on role. To force a specific order, ship buttons in the order you want (the framework preserves the array order).
- **Custom backdrop / colors:** NOT supported. The `material_semantic` property is preserved for API symmetry but does nothing on the active `.alert` path (documented in `swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/AlertFacade.swift:7-15`). If a brand needs custom alert chrome, use `UI::Sheet` with `surface_style: :grouped_card` and a custom button row instead. **Backlog item: `B-ALERT-CUSTOM-CHROME`** — `docs/initiative-cross-platform-ui/architecture/intent-backlog.md`.
- **Confirmation alerts with destructive default focus:** ship the destructive button last; SwiftUI auto-focuses the trailing action.

## Evidence

- **Canonical example:** `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:225-247`
- **Screenshot:** `docs/initiative-cross-platform-ui/handoff/phase-10-d-polish-screenshots/03_alert_delete_confirm.png`
- **Spec coverage:** `spec/web/ui/views/alert_spec.cr`
