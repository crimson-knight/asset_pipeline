# Phase 10B.2b close — Action + focus + keyboard accessibility

**Branch:** `phase-10-b-2b` (cut from `phase-10` @ `phase-10-batch-3-merged-2026-05-26`).
**Brief:** `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/brief-10-b-2b.md` (v1).
**Status:** Forward-only commits; ready for content review.

---

## What shipped

`UI::View` gains three property families and two new value types for the
*dynamic* slice of accessibility semantics: custom actions, focus
management, and keyboard shortcuts. All four renderers thread the new
properties; the SwiftKit Populator + ViewOverrides surface them to
SwiftUI; the AppKit / UIKit ObjC bridge gains five C-side helpers
(`ap_view_add_accessibility_custom_action`, `ap_view_add_key_command`,
`ap_view_become_first_responder`, `ap_view_resign_first_responder`)
shared between the two platforms via `#if TARGET_OS_IPHONE`.

WCAG gains on web: `data-ax-actions` / `data-ax-action-count` for custom
actions, `autofocus` + `data-focused` for focus requests, `tabindex` for
explicit traversal control, `accesskey` + `data-keyboard-shortcut` for
keystroke bindings.

## New properties (5) + value types (2)

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `accessibility_actions` | `Array(UI::AccessibilityAction)` | `[]` | Custom AX actions surfaced via the rotor / actions menu. |
| `focused` | `Bool` | `false` | Request first-responder / autofocus on render. Mutating to `true` via the dispatcher fires `becomeFirstResponder`. |
| `focusable` | `Bool?` | `nil` (use `default_focusable`) | Override the widget's intrinsic focusability. |
| `tab_index` | `Int32?` | `nil` | Explicit tab order on web; advisory on native. |
| `keyboard_shortcut` | `UI::KeyboardShortcut?` | `nil` | Keystroke binding (key + modifier flags). |

Value types:

- `UI::AccessibilityAction.new(name : String, &block : -> Nil)` —
  records a name + Proc. `call` invokes the underlying callback.
- `UI::KeyboardShortcut.new(key : String | Symbol, modifiers : Array(Symbol) = [])` —
  carries the key + modifier set, derives:
  * `#canonical` -> `"Shift+Command+S"`
  * `#accesskey_char` -> first char of `key` for single-char keys
  * `#uikit_modifier_mask` / `#appkit_modifier_mask` -> raw `UInt64` bit
    flags matching `UIKeyModifierFlags` / `NSEventModifierFlags`.

`default_focusable` is a per-widget hook. 21 interactive widgets override
it to return `true`: Button, IconButton, LinkButton, ToggleButton,
MenuButton, TextField, SecureField, SearchField, TextArea, TextEditor,
Toggle, Checkbox, Slider, Stepper, SegmentedControl, RadioGroup, Picker,
DatePicker, TimePicker, ColorPicker, NavigationLink. Every other view
inherits `default_focusable = false` from `UI::View`.

`effective_focusable` resolves the explicit override-or-default.
`effective_tab_index` returns `nil` when the widget's HTML default
focusability matches caller intent (no attribute needed), `-1` when a
focusable widget is opted out, `0` when a non-focusable widget is opted
in, or the explicit `tab_index` value when set. Renderers call the
`effective_*` helpers so the override-vs-default precedence stays in
lockstep.

## Per-property × per-renderer matrix

| Property | Web | UIKit | AppKit | Android |
|---|---|---|---|---|
| `accessibility_actions` | `data-ax-actions="<names>"` + `data-ax-action-count="<n>"`; commas in names %2C-escaped | `UIAccessibilityCustomAction` (block-based, iOS 13+) appended to `accessibilityCustomActions` | `NSAccessibilityCustomAction` (block-based, macOS 10.13+) appended to `accessibilityCustomActions` | Documented gap (no `AccessibilityNodeInfo.addAction` in current JNI bridge) |
| `focused` | `autofocus` on form controls; `data-focused="true"` on all elements | `[view becomeFirstResponder]` via `ap_view_become_first_responder` | `[[view window] makeFirstResponder:view]` via `ap_view_become_first_responder` | Documented gap (no `android_view_request_focus` in current JNI bridge) |
| `focusable` | tabindex via `effective_tab_index` (skip / `-1` / `0` / explicit) | `setIsAccessibilityElement:` flip on/off | `setAccessibilityElement:` flip on/off | `clear_focus()` on explicit opt-out |
| `tab_index` | `tabindex="<n>"` when set | Advisory (UIKit derives focus order from view hierarchy) | Advisory (AppKit derives from keyView chain) | Advisory |
| `keyboard_shortcut` | `accesskey="<char>"` + `data-keyboard-shortcut="<canonical>"` | `UIKeyCommand` via `addKeyCommand:` on UIViewController hosts; buffered on associated object for plain UIView | `setKeyEquivalent:` + `setKeyEquivalentModifierMask:` on NSButton-derived controls; buffered on associated object otherwise | Documented gap (View.OnKeyListener not bridged) |

## SwiftKit Populator changes

`populate_view_common` extended with:

- `setApskAccessibilityActions` — comma-joined name string
- `setApskAccessibilityActionCount` — count (Int)
- `setApskFocused` — boolean
- `setApskKeyboardShortcutKey` — key (String)
- `setApskKeyboardShortcutModifiers` — `UIKeyModifierFlags`-shaped `UInt64`

Each slot is emitted only when the matching Crystal property is non-
default; nil / empty / false skip the call so SwiftUI's intrinsic
behavior shines through (default-detection invariant per §11).

`ViewOverrides.swift` gains five matching `@objc(apsk*)` properties
(see file for `apskAccessibilityActions`, `apskAccessibilityActionCount`,
`apskFocused`, `apskKeyboardShortcutKey`, `apskKeyboardShortcutModifiers`).
All renamed to the `apsk*` selector prefix to dodge the iOS
`UIAccessibility.*` selector clash — same root cause as the iter 2
fix on `apskAccessibilityLabel`.

`CommonModifiers.apply` extended with three new branches:

- **Actions:** splits the comma-joined name string (unescaping `%2C` ->
  `,`) and emits one `.accessibilityAction(named: Text(name)) { … }`
  modifier per name. The closure is intentionally empty — the UIView
  layer's `accessibilityCustomActions` array (wired by the renderer's
  ObjC bridge) routes activation back to Crystal. We attach the SwiftUI
  modifiers so the rotor surfaces the names; the dispatch path stays
  unified.
- **Keyboard shortcut:** maps `apskKeyboardShortcutModifiers` bits onto
  `EventModifiers` (`.shift`, `.control`, `.option`, `.command`) and
  attaches `.keyboardShortcut(KeyEquivalent, modifiers:)`. Named keys
  (`return`, `escape`, `tab`, `space`, `delete`, arrows) map onto
  SwiftUI's `KeyEquivalent` constants; single-character keys use
  `KeyEquivalent(first)`.
- **Focused:** read-only no-op at the modifier layer (SwiftUI's
  `.accessibilityFocused` requires a `@FocusState` binding which we
  can't synthesise from outside the facade). The native renderer's
  `ap_view_become_first_responder` helper handles the actual focus
  request on the resolved UIView / NSView.

## ObjC bridge additions (`src/ui/native/objc_bridge.m`)

New C helpers (each `#if TARGET_OS_IPHONE` / `#else` branched between
UIKit and AppKit):

| Helper | UIKit | AppKit |
|---|---|---|
| `ap_view_add_accessibility_custom_action(view, name, token)` | `UIAccessibilityCustomAction` initWithName:actionHandler:; appended to `accessibilityCustomActions` | `NSAccessibilityCustomAction` initWithName:handler:; appended to `accessibilityCustomActions` |
| `ap_view_add_key_command(view, input, mask, token)` | `UIKeyCommand` via `addKeyCommand:` (UIViewController) OR buffered on `apsk_pending_key_commands` associated array | `setKeyEquivalent:` + `setKeyEquivalentModifierMask:` (NSButton) OR `apsk_keyboard_shortcut` associated dict |
| `ap_view_become_first_responder(view)` | `[view becomeFirstResponder]` | `[[view window] makeFirstResponder:view]` |
| `ap_view_resign_first_responder(view)` | `[view resignFirstResponder]` | `[win makeFirstResponder:nil]` when win.firstResponder == view |

Each helper takes a callback token (UInt64) the Crystal-side
`UI::CallbackRegistry` returns from `register(&block)`. Activation
of the action / key command fires
`crystal_ui_callback_dispatch(token)` which routes back to Crystal's
registered Proc. For NSButton-style controls in the AppKit
key-equivalent path the token is advisory — the button's existing
target/action already wires Crystal callbacks; the modifier mask is
the differentiator.

The Crystal-side `LibObjCBridge` declarations live in both
`uikit_renderer.cr` and `appkit_renderer.cr` (mirrored, since the two
renderers don't share a `lib` block).

## Spec coverage

**`spec/web/ui/accessibility_actions_spec.cr` — 6 examples, all green:**
property surface (3) + web renderer threading (3).

**`spec/web/ui/accessibility_focus_spec.cr` — 15 examples, all green:**
property surface (9 — focus / focusable / tab_index, default_focusable,
effective_focusable, effective_tab_index) + web renderer threading (6).

**`spec/web/ui/accessibility_keyboard_spec.cr` — 13 examples, all green:**
`UI::KeyboardShortcut` value type (6 — canonical / accesskey_char /
modifier masks) + property surface (3) + web renderer threading (4).

**`spec/web/ui/renderers/swiftkit/accessibility_action_focus_keyboard_overrides_spec.cr` — 7 examples, all green:**
SwiftKit Populator forwarding for actions, focused, and keyboard
shortcut, with skip-when-default invariant assertions.

```
crystal spec spec/web/ui/accessibility_actions_spec.cr \
            spec/web/ui/accessibility_focus_spec.cr \
            spec/web/ui/accessibility_keyboard_spec.cr \
            spec/web/ui/renderers/swiftkit/accessibility_action_focus_keyboard_overrides_spec.cr
41 examples, 0 failures, 0 errors, 0 pending
```

**Combined 10B.2a + 10B.2b coverage (no regression):**

```
crystal spec spec/web/ui/accessibility_actions_spec.cr \
            spec/web/ui/accessibility_focus_spec.cr \
            spec/web/ui/accessibility_keyboard_spec.cr \
            spec/web/ui/accessibility_metadata_spec.cr \
            spec/web/ui/renderers/swiftkit/accessibility_action_focus_keyboard_overrides_spec.cr \
            spec/web/ui/renderers/swiftkit/accessibility_metadata_overrides_spec.cr
80 examples, 0 failures, 0 errors, 0 pending
```

**Full web spec regression:**

```
crystal spec spec/web/
1920 examples, 4 failures, 2 errors, 66 pending
```

The 4 failures + 2 errors match the pre-merge baseline at
`phase-10-batch-3-merged-2026-05-26`. Confirmed by running `git stash`
+ baseline measurement: same numbers (1134 + 41 new = 1175 in the ui
subtree, identical failure profile). Failures:
- 1 `UI::Theme inject_theme_css returns empty string with no theme` (pre-existing).
- 3 Phase 2 fixture mismatches in `phase2_verification_spec.cr` (pre-existing).
- 2 `:swipe_actions` android-registration ordering errors (pre-existing
  test-isolation issue; specs pass individually).

## Lint + format

```
crystal run scripts/lint_conventions.cr
lint_conventions: OK (461 files, 14 rules, 0 diagnostics)

crystal tool format --check (10B.2b files)
EXIT: 0
```

(The `format --check` over the whole repo flags ~10 pre-existing files
in `src/components/` and `src/generators/` that have been baseline-stale
since long before 10B.2b — out of scope for this brief.)

## Build

```
crystal build src/asset_pipeline.cr --no-codegen
(success)
```

(`crystal-alpha build -Dmacos` requires the ObjC bridge to be recompiled
and re-linked; the brief explicitly defers VoiceOver / TalkBack runtime
validation, so the macOS / iOS host build is left to a follow-up
verification phase per the 10B.2a precedent.)

## Honest limitations

1. **Android focus + actions + keyboard shortcuts are documented gaps.**
   `android_view_request_focus`, `AccessibilityNodeInfo.addAction`, and
   `View.OnKeyListener` are not exposed through the current
   `LibAndroidBridge` surface. The Crystal data stays on the `UI::View`
   so an app wiring its own JNI can honor it; the Android renderer's
   `apply_common_non_surface_properties` only honors `focusable = false`
   via `android_view_clear_focus`. JNI bridge upgrade is a follow-up.
2. **UIKit `UIKeyCommand` on plain UIView is buffered, not active.**
   UIKit attaches key commands to UIResponder subclasses (typically
   UIViewController). For UIViews that aren't VCs we store the
   `UIKeyCommand` on an associated `apsk_pending_key_commands`
   NSMutableArray so a containing VC can read + install it. The Crystal
   side fires the request; whether the host wires the array is its
   call.
3. **AppKit `keyEquivalent` is NSButton-only.** Non-button controls
   get the value stored on an associated `apsk_keyboard_shortcut`
   dictionary for the responder chain / menu builder to consult later.
   This matches the macOS HIG convention that keyboard equivalents
   typically live on menu items, not arbitrary views.
4. **`focused = true` mutation triggering rerender** relies on the
   `UI::ActionDispatcher`'s rerender path being invoked by the
   controller's `ActionResult::Rerender`. The renderer applies
   `becomeFirstResponder` during `apply_common_properties`, so a
   reactive mutation that re-renders the tree fires the focus
   request fresh on every render. There is no separate "focus
   change" event hook — the brief explicitly scopes that out
   (it lists the focus *change* surface as a property mutation, not
   a callback).
5. **SwiftUI `.accessibilityFocused` requires a `@FocusState`** binding
   inside the View itself. We cannot synthesise that from
   `CommonModifiers.apply` because the binding's identity must be
   stable across renders. The UIView-layer `becomeFirstResponder`
   path covers the iOS / macOS native cases; SwiftUI host scenarios
   (where the SwiftUI view IS the leaf) rely on the underlying
   UIHostingController accepting first-responder requests, which it
   does for any interactive child. Future SwiftKit facades that own
   their own `@FocusState` can consume `apskFocused` directly.

These are documented per `[[plan-what-to-understand-not-just-what-to-build]]`
so the gaps surface explicitly rather than ship as silent skips.

## Out of scope (deferred to follow-on briefs)

- **Environment-driven contracts** (motion, contrast, dynamic type) —
  10B.2c.
- **VoiceOver / TalkBack live testing** — separate validation phase.
- **Android JNI focus / actions / keyboard bridge upgrade** — follow-up.
- **Apple-host snapshot validation** of the new `apsk*` slots —
  `OverridesPropagationTests.swift` extension when a Swift build host
  is available.

— Implementer (Claude Opus 4.7), 10B.2b iter-1

---

## Iter 2 — Codex REVISE remediation

**Finding (BLOCKER):** Web `accessibility_actions` weren't keyboard-
reachable. A non-interactive view (Label, Image, Spacer, …) carrying
custom `accessibility_actions` emitted `data-ax-actions` but no
`tabindex`, so keyboard-only AT users could not focus the element to
invoke its actions. The contract is: *an element with custom
accessibility actions MUST be keyboard-reachable so AT users can
invoke those actions.*

**Fix (web-only, `src/ui/renderers/web_renderer.cr`):** After the
existing `effective_tab_index` resolution, promote the element into
the tab order when ALL of the following hold:

1. The resolver returned `nil` (no explicit `tab_index`, no opt-in / opt-out override), AND
2. The view has a non-empty `accessibility_actions` array, AND
3. The view is NOT intrinsically focusable (`!effective_focusable`).

When that triad fires, the renderer emits `tabindex="0"`. Explicit
overrides win — a caller-set `tab_index` is preserved verbatim, and a
`focusable = false` opt-out on an intrinsically focusable widget still
emits `tabindex="-1"`. Intrinsically focusable widgets (Button,
TextField, …) that carry actions are already keyboard-reachable, so
no redundant `tabindex="0"` is emitted; the existing "skip tabindex
on a focusable widget with no override" invariant holds.

UIKit / AppKit are not touched — they have their own focus model
(`isAccessibilityElement` / `accessibilityElement` + responder chain)
and the `ax_view_add_accessibility_custom_action` helpers already
wire actions into the accessibility tree where AT users discover
them via the rotor / actions menu.

**Rendering rule (precedence top-down):**

| Condition | tabindex emitted |
|---|---|
| `tab_index = N` (explicit) | `N` |
| `focusable = false` on focusable-by-default widget | `-1` |
| `focusable = true` on non-focusable-by-default widget | `0` |
| `accessibility_actions` non-empty AND not intrinsically focusable | `0` |
| otherwise | (no attribute) |

**Spec coverage (5 new examples in `spec/web/ui/accessibility_actions_spec.cr`):**

- Label with `accessibility_actions` -> `tabindex="0"` (the primary contract).
- Label without `accessibility_actions` -> no `tabindex` (no false promotion).
- Label with explicit `tab_index = 4` + actions -> `tabindex="4"` (caller wins).
- Button with `focusable = false` + actions -> `tabindex="-1"` (opt-out wins over implicit promotion).
- Button with actions -> no `tabindex` (already reachable; no noise).

```
crystal spec spec/web/ui/accessibility_actions_spec.cr \
            spec/web/ui/accessibility_focus_spec.cr \
            spec/web/ui/accessibility_keyboard_spec.cr
39 examples, 0 failures, 0 errors, 0 pending
```

(11 in actions + 15 in focus + 13 in keyboard = 39; previously 34 across
the same three files. Iter 1's handoff cited 41 across four files
including the SwiftKit overrides spec — that fourth file is unchanged
in iter 2 and still green.)

**Full web spec regression:** `1925 examples, 4 failures, 2 errors,
66 pending`. The 4 failures + 2 errors match the pre-iter-2 baseline
exactly (verified via `git stash` / re-run): one `UI::Theme
inject_theme_css` empty-string check, three Phase 2 fixture mismatches
in `phase2_verification_spec.cr`, and two `:swipe_actions` android
registration ordering issues. None touch the focus / actions
surface; iter 2 introduces zero new failures.

**Lint:** `lint_conventions: OK (461 files, 14 rules, 0 diagnostics)`.

**Build:** `crystal build src/asset_pipeline.cr --no-codegen` → success.

— Implementer (Claude Opus 4.7), 10B.2b iter-2
