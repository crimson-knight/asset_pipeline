# `:swipe_actions` capability honesty audit (Phase 10B.1b)

**Branch:** `phase-10-b-1b` from `phase-10`.
**Scope:** Per-`(widget × platform)` audit of the capabilities that
each `:swipe_actions` widget actually backs in renderer code today.
Predecessors (10B.0, 10B.1a) declared all `:swipe_actions` capabilities
as `:partial`, which collapsed every nuance (iOS swipe-reveal vs.
macOS visible-inline; AppKit's lack of destructive tint; the Android
SwipeActionRow stub) into a single fuzzy symbol. 10B.1b replaces the
fuzzy declaration with a platform-keyed map so the registry can answer
"does this widget actually back the capability on the platform the
resolver is about to use?"

## Capabilities considered

| Key | Meaning |
|---|---|
| `supports_edge_trailing` | Widget renders / reveals trailing-edge actions (iOS swipe-reveal, macOS inline buttons, etc.). |
| `supports_edge_leading` | Widget renders / reveals leading-edge actions. |
| `supports_role_default` | Default-role action renders with a working tap path (no destructive tint required). |
| `supports_role_destructive` | Destructive-role action is *visually distinguished* in the platform-idiomatic way (red tint / system destructive color). The widget must do more than carry the role symbol — the renderer has to paint it. |

## Matrix

Cells use `true` (full support) / `false` (none / silently absent).

### `UI::SwipeActionRow`

| Capability | iOS | macOS | web_wide | web_narrow | Android |
|---|---|---|---|---|---|
| `supports_edge_trailing` | true | true (inline, visible) | true | true | **false** |
| `supports_edge_leading` | **true** (10D-refocus) | **false** | true | true | **false** |
| `supports_role_default` | true | true | true | true | **false** |
| `supports_role_destructive` | true | **false** | true | true | **false** |

> **Phase 10D-refocus update (2026-05-27):** the iOS `visit(SwipeActionRow)`
> now routes through `APSKSwipeActionRowFacade` (SwiftUI
> `.swipeActions(edge:)`), which iterates **both** `leading_actions` and
> `trailing_actions` and registers each action's `on_tap` via
> `CallbackRegistry.register_action`. The legacy `make_swipe_reveal_row`
> ObjC UIScrollView path is no longer reached. `supports_edge_leading`
> flipped from `false` to `true` for iOS / iPadOS as a result.

### `UI::InlineActionRow`

| Capability | iOS | macOS | web_wide | web_narrow | Android |
|---|---|---|---|---|---|
| `supports_edge_trailing` | true | true | true | true | true |
| `supports_edge_leading` | true | true | true | true | true |
| `supports_role_default` | true | true | true | true | true |
| `supports_role_destructive` | true | **false** | true | true | true |

## Per-cell rationale + renderer-code citations

### `UI::SwipeActionRow`

#### iOS (`src/ui/renderers/uikit_renderer.cr`, `visit(view : UI::SwipeActionRow)` @ ~L3826)

```crystal
view.trailing_actions.each do |action|
  inner = UI::Button.new(action.label, role: action.role, style: UI::ButtonStyle::Prominent)
  ...
end
# build a Pointer(Void*) of action handles and call:
scroll_ptr = LibObjCBridge.make_swipe_reveal_row(
  content_native.handle.ptr!,
  action_buf, action_count, row_width,
)
```

- `supports_edge_trailing: true` — `make_swipe_reveal_row` wires the
  trailing-only swipe-reveal UIScrollView; each trailing action is a
  CallbackRegistry-backed `UI::Button`.
- `supports_edge_leading: false` — `view.leading_actions` is **never
  iterated**. The ObjC helper only takes trailing-action pointers.
  A leading action set on a `SwipeActionRow` is silently dropped on
  iOS today.
- `supports_role_default: true` — default-role `UI::Button` follows
  the SwiftKit `populate_button` path; tap fires through
  `CallbackRegistry`.
- `supports_role_destructive: true` — `role: action.role` is passed
  into `UI::Button.new`. The iOS `UI::Button` visit routes through
  `APSKButtonOverrides` (`uikit_renderer.cr` L302–353), which applies
  SwiftUI's `.role(.destructive)` tint. Verified in renderer L3855:
  `inner = UI::Button.new(action.label, role: action.role, ...)`.

#### macOS (`src/ui/renderers/appkit_renderer.cr`, `visit(view : UI::SwipeActionRow)` @ ~L3809)

```crystal
view.trailing_actions.each do |action|
  btn = alloc_init("NSButton")
  title_ns = LibObjCBridge.nsstring_from_cstr(action.label.to_unsafe)
  LibObjCBridge.objc_send_id(btn, sel("setTitle:"), title_ns)
  LibObjCBridge.objc_send_id(ptr, sel("addArrangedSubview:"), btn)
  ...
end
```

- `supports_edge_trailing: true` — trailing actions are appended as
  visible `NSButton`s to the row's `NSStackView`. HIG-correct for
  macOS (no swipe-to-reveal gesture); the inline pattern is the
  idiomatic equivalent.
- `supports_edge_leading: false` — leading actions are **never
  iterated**. Silently dropped on macOS today.
- `supports_role_default: true` — `NSButton` with `setTitle:` is a
  working tappable control. (Note: tap dispatch wiring through the
  CallbackRegistry on macOS for these NSButtons is a separate item
  outside this audit's scope — the capability assesses *visual + role
  fidelity*, not tap callback wiring.)
- `supports_role_destructive: false` — **`action.role` is never
  read** in the AppKit visit. NSButtons receive only `setTitle:`; no
  destructive tint (no `setBezelStyle:`, no `setContentTintColor:`,
  no foreground-color override). A destructive action renders
  identically to a default action. This is the most material
  honesty correction in this audit.

#### Web (`src/ui/renderers/web_renderer.cr`, `visit(view : UI::SwipeActionRow)` @ ~L2890, `swipe_action_panel` @ ~L3085)

```crystal
if !view.trailing_actions.empty?
  wrap.add_child(swipe_action_panel(view.trailing_actions, "trailing"))
end
if !view.leading_actions.empty?
  wrap.add_child(swipe_action_panel(view.leading_actions, "leading"))
end
...
btn.add_class("ap-swipe-row__action--destructive") if action.role == :destructive
```

- `supports_edge_trailing: true` (both web_wide + web_narrow) — both
  panels emitted unconditionally; mobile-mode CSS reveals them via
  the touch-swipe shim.
- `supports_edge_leading: true` (both web_wide + web_narrow) — leading
  panel emitted symmetrically. Web is the *only* surface where
  leading actions are actually rendered on `SwipeActionRow`.
- `supports_role_default: true` — buttons render with neutral
  `ap-swipe-row__action` chrome.
- `supports_role_destructive: true` — `--destructive` class adds
  `color: var(--ap-color-danger-text)` + matching border (see
  `swipe_action_chrome_html` L3158-3161).

#### Android (`src/ui/renderers/android_renderer.cr`, `visit(view : UI::SwipeActionRow)` @ ~L3154)

```crystal
def visit(view : UI::SwipeActionRow)
  view.content.accept(self)
end
```

- Every capability `false` — the visit is a stub that renders
  `view.content` only and silently drops all leading + trailing
  actions of every role. Replacement is 10B.1c's
  `UI::AndroidSwipeActionRow`.

### `UI::InlineActionRow`

#### iOS (`src/ui/renderers/uikit_renderer.cr`, `visit(view : UI::InlineActionRow)` @ ~L3895)

Three symmetric loops (`leading_actions.each`, `content`, `trailing_actions.each`); each iteration builds a `UI::Button.new(action.label, role: action.role, style: UI::ButtonStyle::Prominent)` and `addArrangedSubview:`s it onto the horizontal UIStackView.

- All four capabilities `true` — leading + trailing both iterate;
  `role:` propagates into the SwiftKit-backed button visit.

#### macOS (`src/ui/renderers/appkit_renderer.cr`, `visit(view : UI::InlineActionRow)` @ ~L3840)

```crystal
view.leading_actions.each do |action|
  btn = alloc_init("NSButton")
  ...
  LibObjCBridge.objc_send_id(btn, sel("setTitle:"), title_ns)
  ...
end
# (content)
view.trailing_actions.each do |action|
  btn = alloc_init("NSButton")
  ...
end
```

- `supports_edge_leading: true` / `supports_edge_trailing: true` —
  both loops emit visible NSButton children.
- `supports_role_default: true`.
- `supports_role_destructive: false` — same gap as the macOS
  `SwipeActionRow` visit: `action.role` is **never read**, no
  destructive tint applied to the NSButton. A destructive action on
  macOS InlineActionRow renders identically to default. This is a
  known limitation pending a Phase 4/5 macOS button-role facade.

#### Web (`src/ui/renderers/web_renderer.cr`, `visit(view : UI::InlineActionRow)` @ ~L2934, `inline_action_panel` @ ~L2975)

Symmetric to web `SwipeActionRow` but without the mobile touch-reveal
shim. `--destructive` CSS class fires when `action.role == :destructive`
(inline chrome L3042-3045).

- All four capabilities `true` on both `web_wide` and `web_narrow`.

#### Android (`src/ui/renderers/android_renderer.cr`, `visit(view : UI::InlineActionRow)` @ ~L3172)

Full LinearLayout implementation that visits leading actions, content,
and trailing actions. Each action becomes a `UI::Button.new(action.label,
role: action.role)`. The Android `UI::Button` visit (renderer L338, role
handling at L358, L366, L375, L379, L384) honors `:destructive` with
`material_color(:error)` for foreground.

- All four capabilities `true`.

## Capability-value shape decision

The previous shape allowed `Bool | Symbol`, with `:partial` meaning
"some platforms, fuzzy on which." The fuzziness lost the iOS-only
leading-edge gap, the macOS destructive-tint gap, and the Android
SwipeActionRow stub — all three were collapsed into "partial enough
to satisfy the intent's partial requirement."

10B.1b adopts a **platform-keyed `Hash(Symbol, Bool)`** as a new
permitted value alongside the existing `Bool | Symbol` shape:

```crystal
declares_capabilities :swipe_actions, {
  supports_edge_trailing: {
    ios: true, ipados: true, macos: true,
    web_wide: true, web_narrow: true, android: false,
  },
  supports_edge_leading: {
    ios: false, ipados: false, macos: false,
    web_wide: true, web_narrow: true, android: false,
  },
  supports_role_default: {
    ios: true, ipados: true, macos: true,
    web_wide: true, web_narrow: true, android: false,
  },
  supports_role_destructive: {
    ios: true, ipados: true, macos: false,
    web_wide: true, web_narrow: true, android: false,
  },
}
```

### Why platform-keyed maps (not per-platform key suffixes)

Considered: `supports_role_destructive_ios: true,
supports_role_destructive_macos: false, ...` (split into one key per
platform). Rejected because:

1. Quadratic key explosion. With 5 platforms × 4 capabilities the
   widget declaration grows from 4 keys to 20, and a sixth platform
   adds 4 more keys per intent.
2. Intent requirements (`declare_intent_capabilities`) would need the
   same explosion to stay symmetric, and the lint rule that checks
   `declares_capabilities` would have to know how to alias
   `supports_X` ↔ `supports_X_<platform>`.
3. The platform-keyed map is exactly the shape the registry's
   resolve-time validator needs (`hash[context.platform]?`), so the
   value's shape mirrors its consumer.

### Registry validation contract update

The validator (`UI::WidgetRoute::Registry.validate_override_capabilities`)
handles the three permitted shapes:

| Required value | Declared value | Result |
|---|---|---|
| `true` | `true` | OK |
| `true` | `:partial` | FAIL (the old `:partial` half-pass is no longer accepted when the intent demands universal support) |
| `true` | `Hash` covering every platform with a registered default for the intent with `true` | OK |
| `true` | `Hash` missing or `false` for a platform that has a default | FAIL — names the missing platform |
| `:partial` | anything that has at least one `true` cell | OK |
| `Hash{ios: true, ...}` | widget hash must declare `true` for each platform the required hash declares `true` for | OK / FAIL |

The validator is invoked at registration time as today, but now it
walks the union of platforms where defaults are installed for the
intent (so an override shadowing the iOS + macOS + web_wide defaults
must honestly back the capability on iOS + macOS + web_wide).

The resolver also gains a per-context check: when
`capabilities_required:` is passed, the platform of `context.platform`
is the single platform the validator gates on.

#### What the registry enforces (and what it does NOT)

**Under-claim rejection (enforced).** A widget that declares it does
NOT back a capability the intent requires is rejected at registration.
Concrete cases the spec proves:

* Required `true` (universal), widget declares `:partial` — rejected.
* Required `true` (universal), widget declares a `Hash` with `false`
  (or missing) on a platform that has a registered default — rejected,
  naming the missing platform.
* Required `Hash{web_wide: true, ...}`, widget declares
  `Hash{web_wide: false, ...}` — rejected per-platform.

**Over-claim is NOT rejected by the registry.** When the intent
requirement is `{macos: false, ...}` (e.g.,
`supports_role_destructive` on `:macos`), the per-platform validator
walks only the cells where the requirement is `true`
(`registry.cr:305`'s `next unless needed`). A widget that claims
`{macos: true, ...}` for the same capability passes registration
even when the macOS renderer paints no destructive tint.

This is intentional. The registry cannot prove a renderer-side
implementation claim is honest without a ground-truth oracle of what
each renderer paints — that oracle does not exist as code; it lives
in the audit doc and the renderer-code citations in the matrix above.
**The audit doc + code review are the over-claim guard, not the
runtime validator.** The library widgets (`UI::SwipeActionRow`,
`UI::InlineActionRow`) are honest because the cited renderer code was
inspected per-cell; future overrides earn the same trust through the
same review.

Implications for downstream apps:

* If you add a custom override that backs every required cell, the
  registry accepts it — even cells beyond the requirement set. If you
  later turn `:macos` from `false` to `true` in the intent
  requirement (e.g., once an AppKit button-role facade lands), the
  registry will RE-CHECK your override at the next registration and
  reject it if you over-claimed `:macos => true` without backing the
  renderer.
* If you want to spot over-claims in your own widgets before that
  flip happens, exercise them under `capabilities_required:` in a
  spec that asserts the correct render output (the renderer must
  prove the cell, not the declaration).

### `:swipe_actions` intent-requirement update

`src/ui/widget_route/bootstrap.cr` previously declared:

```crystal
:supports_role_destructive => :partial,
```

10B.1b makes the requirement honest:

```crystal
:supports_role_destructive => {
  ios: true, ipados: true, macos: false,
  web_wide: true, web_narrow: true, android: false,
},
```

iOS / iPadOS / web_wide / web_narrow demand destructive tint; macOS
does not until the AppKit button-role facade lands; Android does not
until 10B.1c's `UI::AndroidSwipeActionRow`. Existing widgets
(`SwipeActionRow`, `InlineActionRow`) declare their honest matrices
above and pass validation. A would-be override that **under-claims**
a required cell (e.g., declared `supports_role_destructive` as a
Hash with `:web_wide => false` while the intent requires
`:web_wide => true`) fails registration — that's the rejection
tests in `swipe_actions_capability_audit_spec.cr`.

The registry does NOT reject **over-claims** — a widget declaring
`:macos => true` for `supports_role_destructive` (while macOS is
required `false`) registers successfully today. The runtime validator
walks only required-`true` cells; honesty for unrequired cells is
enforced by the audit doc + Codex review, not the runtime. See the
"What the registry enforces" callout above.

— Architect-implementer (Claude Opus 4.7), 10B.1b iter 1
