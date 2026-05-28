# UI::SwipeAction

A single edge-swipe action tile attached to a `UI::ListView` row (via `leading_swipe_actions` / `trailing_swipe_actions`) or to a `UI::SwipeActionRow`. Encodes label + icon + role + tap handler.

## Default experience

- **iOS:** Rendered inside SwiftUI `.swipeActions(edge:allowsFullSwipe: true) { ... }`. Each action becomes a `Button(role:)` with `.tint(<color>)` so SwiftUI paints the full-bleed square-corner Mail-style tile chrome. Label uses `Label(label, systemImage: icon).labelStyle(.titleAndIcon)`. First action in the trailing array is the full-swipe target on iOS (per SwiftUI's `.swipeActions` contract).
- **iPadOS:** identical to iOS.
- **macOS:** AppKit renderer emits an inline `NSStackView` of trailing buttons (HIG — macOS doesn't have swipe-to-reveal; explicit inline buttons are the idiomatic equivalent). Destructive role NOT honored on AppKit today (`[[supports_role_destructive: macos: false]]`).
- **web wide:** Inline trailing buttons via `Components::Elements`, CSS class `.swipe-action`. Destructive role honored via `--ap-color-danger-text`.
- **web narrow:** Touch swipe gesture via vanilla JS (CSS transform on touchmove). Destructive role honored.
- **Android:** STUB — `[[supports_edge_trailing: android: false]]`. Backlog: B-LIST-ANDROID-CALLBACKS.

## Crystal API

```crystal
# Minimal invocation
action = UI::SwipeAction.new("Delete", role: :destructive)
```

```crystal
# Realistic Voyager invocation
# samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:180-205
list.trailing_swipe_actions = ->(idx : Int32) : Array(UI::SwipeAction) {
  todo_id = visible_ids[idx]
  [
    UI::SwipeAction.new(
      "Delete",
      on_tap: -> { Voyager.dispatch(:request_delete, {"todo_id" => todo_id}); nil },
      role: :destructive,
      icon: "trash",
    ),
    UI::SwipeAction.new(
      "Done",
      on_tap: -> { Voyager.dispatch(:toggle_row, {"todo_id" => todo_id}); nil },
      icon: "checkmark.circle",
    ),
    UI::SwipeAction.new(
      "Share",
      on_tap: -> { Voyager.dispatch(:request_share, {"todo_id" => todo_id}); nil },
      icon: "square.and.arrow.up",
    ),
    UI::SwipeAction.new(
      "Edit",
      on_tap: -> { Voyager.dispatch(:edit_row, {"todo_id" => todo_id}); nil },
      icon: "pencil",
    ),
  ]
}
```

## Behavior contract

- **Callbacks:**
  - `on_tap : Proc(Nil)?` — fires when the user taps the revealed tile or completes a full-swipe (when it's the full-swipe action).
  - `on_tap_route : String?` — alternative for the static-site web target (Voyager's `web/static_site.cr` cannot invoke Crystal Procs client-side); names a route the client-side JS pushes via `UIRouteHost.push()`.
- **Dismissal paths:** SwiftUI auto-dismisses the swipe panel after tap. Full-swipe fires the first trailing action then dismisses.
- **Focus / keyboard:** VoiceOver reads the row's accessibility label; swipe actions are exposed as VoiceOver "Custom Actions" on iOS (system-provided).
- **Reduced motion:** SwiftUI's swipe-reveal honors reduced motion automatically; full-swipe still works.
- **Reactivity:** The `Proc` callbacks fire synchronously from CallbackBridge into the registered Crystal action. Mutations + dispatcher Rerender produce a new ListView; the same swipe action lambda is re-invoked per render.

## Customization knobs

| Property | Type | Default | Effect |
|----------|------|---------|--------|
| `label` | `String` | (required) | Tile text. |
| `role` | `Symbol` | `:default` | `:default` / `:destructive` / `:cancel`. Destructive paints red on iOS (SwiftUI `.destructive` role); web emits `.--destructive` class. |
| `icon` | `String?` | `nil` | SF Symbol name (iOS / macOS). Empty / nil → label only. |
| `on_tap` | `Proc(Nil)?` | `nil` | Tap handler. |
| `on_tap_route` | `String?` | `nil` | Static-site web fallback route id. |
| `tint` | `Symbol?` | `nil` | **Phase 10D-polish iter 2.** Explicit tile tint override. `:blue` / `:green` / `:orange` / `:red` / `:purple` / `:yellow` / `:pink` / `:gray`. Nil → role-derived default. |
| `label_style` | `Symbol` | `:auto` | **Phase 10D-polish iter 2.** `:auto` (infer from which fields are set), `:icon` (icon only, title becomes accessibilityLabel), `:title` (title only, icon dropped), `:title_and_icon` (force SwiftUI Label combination). |

## Override path

**Tint colors** default to role-derived values when `tint` is unset:

- Leading: `default → green`, `destructive → red` (`src/ui/renderers/uikit_renderer.cr:1238-1243`).
- Trailing: `default → blue`, `destructive → ""` (SwiftUI .destructive paints red automatically) (`src/ui/renderers/uikit_renderer.cr:1246-1253`).

**Override paths:**

- **Different tint per action:** RESOLVED by Phase 10D-polish iter 2 (`B-LIST-SWIPE-TINT`). Set `tint: :orange` (or any of the 8 semantic colors) on `UI::SwipeAction.new`. Voyager demos: Archive orange (leading), Done green, Share gray, Edit blue, Delete role-derived red.
- **Custom label style (icon-only, text-only):** RESOLVED by Phase 10D-polish iter 2 (`B-LIST-SWIPE-LABEL-STYLE`). Set `label_style: :icon` / `:title` / `:title_and_icon` / `:auto`.

## Evidence

- **Canonical example:** `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:180-205`
- **Screenshot:** `docs/initiative-cross-platform-ui/handoff/phase-10-d-polish-screenshots/01_drag_handle_visible.png` (rows wired with trailing swipe actions; mid-swipe screenshots infeasible via simctl per 10D-final agent note)
- **Spec coverage:** `spec/web/ui/views/swipe_action_row_spec.cr`
