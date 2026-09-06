# Android accessibility and keyboard contract

Status: development implementation. This is a bounded native contract, not a
claim that every renderer control or TalkBack interaction is Tier A supported.

`UI::Android::Semantics` serializes shared View metadata through the checked,
length-delimited `android_view_semantics` bridge. `NativeSemantics` decorates the
existing Android/Material accessibility delegate on the actual native control.
It does not replace editable text, range information, checked state, native
actions, collection data or virtual-node providers with a generic label node.

## Labels, values and identifiers

- `accessibility_label` supplies a non-editor's content description. With no
  explicit label, native text remains native text; test IDs are never used as
  spoken fallback labels.
- For `EditText`, including Material text inputs and SearchView's query editor,
  the semantic label is the accessibility hint. Entered text and editing actions
  remain supplied by the native delegate. Neither the editor nor its wrapper
  receives an overriding content description. A filled editor retains its text;
  an empty editor can expose the label as its hint/text.
- `accessibility_value` maps to state description. `accessibility_hint` maps to
  node tooltip/help text. These remain separate fields; the runtime does not
  concatenate label, hint, value and identifiers into one spoken string.
- `:header` role/trait marks a heading. `:selected` and `:not_enabled` map to
  selected/disabled native state. Explicit concrete roles can override the node
  class; implicit roles retain the platform widget class. `:none` excludes that
  node, not its entire descendant subtree. Unknown roles and unmapped traits
  produce fixed diagnostics without including application metadata.
- `test_id` and `accessibility_identifier` remain distinct per-owner metadata and
  namespaced node extras (`dev.assetpipeline.test_id` and
  `dev.assetpipeline.accessibility_identifier`). `NativeSemantics.identifier`
  resolves the explicit accessibility identifier first, then the test ID.
  `NativeTestIds.withTestId` is the canonical Espresso matcher. Existing
  `withContentDescription(testId)` tests must migrate; actual spoken descriptions
  such as the toolbar's “Navigate up” remain ordinary accessibility labels.

Metadata is attached to the shared widget owner, while its accessibility
delegate is attached to the real editor or menu Spinner inside the wrapper.
Automation matching the owner therefore does not ambiguously match both the
wrapper and its editor. Menu Picker targeting is bounded; alternate picker
styles and more complex internal children need their own contract tests.
Hosts must include the canonical runtime resource directory, including the
metadata/action ID resources. The current verified hosts do not enable code or
resource shrinking; shrinking/obfuscation needs separate JNI/resource keep-rule
and release-runtime validation before being advertised as supported.

Android's guidance specifically discourages content descriptions on editable
fields because they interfere with reading and editing. See the official
[editable-field guidance](https://support.google.com/accessibility/android/answer/6378120?hl=en-GB),
[native accessibility principles](https://developer.android.com/guide/topics/ui/accessibility/views/principles-views)
and the [delegate wrapper API](https://developer.android.com/reference/androidx/core/view/AccessibilityDelegateCompat).
Populating the native node is not proof of a particular TalkBack utterance or
screen-reader configuration; audible/manual validation remains a separate gate.

## Focus and shortcuts

`focusable = false` is a real native keyboard-focus opt-out. Explicit false wins
over widget defaults, a focus request and the presence of custom actions. It does
not hide an otherwise meaningful node from accessibility exploration.

`focused = true` requests focus after the newly mounted tree is attached and
laid out. The first eligible request in shared tree order wins; hidden, disabled
and explicitly non-focusable candidates are skipped. An eligible explicit request
overrides previously saved native focus. If the application keeps the request
true, it requests focus again on each full-tree render; clear the flag when a
one-shot request has been fulfilled in application state. After old scroll
positions are restored, the host requests that all scrollable ancestors reveal
the newly explicitly focused target.

Without an explicit request, the existing keyed/shape-checked view-state policy
also restores focus on non-editor native targets. It still restores editor
selection without saving entered text. SearchView resolves to its native editor
and a menu Picker resolves to its native Spinner. This is keyboard input focus,
not screen-reader accessibility focus. Radio/segmented options now have a bounded
ordinal/catalog-signature locator: an unchanged catalog restores the exact focused
option without changing selection; a changed catalog discards it. Group-wide
focus opt-out and disabled state apply to actual options, and the group itself
is not an extra keyboard stop. Other compound descendants still need independent
contracts. See the [view-state metadata policy](android-view-state.md).

`tab_index` remains advisory on native platforms, as specified by `UI::View`;
it is exposed as `dev.assetpipeline.tab_index`, not used to invent a numerical
Android traversal order. Actual keyboard traversal uses Android's focus engine.

Hosts forward both Activity key-event methods to `NativeSemantics.dispatchShortcut`:

- Modified shortcuts use `dispatchKeyShortcutEvent`; control, command/meta,
  option/alt and shift map to Android modifier masks. Matching is exact and the
  first eligible clickable native target wins.
- Unmodified keys use `dispatchKeyEvent` with `unmodifiedOnly = true`. They only
  activate their already-focused clickable non-editor target. They are not global
  accelerators and cannot steal normal typing from a focused editor.
- The existing native click listener is activated once on the initial key-down.
  Matching repeat/release events are consumed without additional activations.
  No synthetic empty callback is registered. Detached, hidden, disabled and
  non-foreground targets are ineligible.
- Supported keys resolve through Android's key-code names, with shared aliases
  for Return, Escape, Space, arrows, Delete and Backspace. Unknown keys and
  non-clickable shortcut owners cannot activate. Rich command routing, shortcut
  menus, international keyboard layouts and conflict customization remain open.

## Bounds and callback ownership

Metadata packets are at most 32 KiB UTF-8; labels 4096 bytes; hints/values 2048
bytes each; identifiers 1024 bytes each. At most 16 custom actions are allowed,
each with a nonblank name of at most 256 bytes and a distinct positive token.
Trait/shortcut fields also have explicit count and byte limits. Invalid packet
errors use fixed messages with no input or JSON-parser cause attached.

Each custom action uses an application resource ID and the ordinary checked
Crystal void-callback path. Before dispatch, the view must still be attached,
shown and enabled, and the host session must be foreground. Old detached views
cannot invoke callbacks after replacement. The renderer accounts for callback
tokens before native metadata setup, transfers them to the owned NativeView
before bounds wrapping, and unregisters both pending and adopted tokens if any
later native or Crystal construction step fails. Teardown does not depend on GC.

The existing view-state traversal budgets also bound focus/shortcut traversal.
Over-budget shortcuts are skipped with a fixed diagnostic. The native metadata
contains no entered text unless the application explicitly places it in an
accessibility property; applications remain responsible for safe labels/values.

## Remaining promotion gates

Do not call this complete accessibility or Tier A parity. Still required:
TalkBack/device speech and exploration; accessibility-focus retention; complete
role/trait and compound-control semantics; all picker styles; disabled ancestor
policy; touch-target bounds; RTL and large-font traversal; keyboard reopening
across window-focus changes; non-Latin hardware keyboards; all core controls,
themes, screen sizes and supported Android versions. Full-tree replacement and
the existing conservative native view-state limitations still apply.
