# Phase 10B.1a close — UI::InlineActionRow widget

**Branch:** `phase-10-b-1a` (cut from `phase-10` @ `e9e4a7e2`).
**Brief:** `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/brief-10-b-1a.md` (v1).
**Status:** Forward-only commits; ready for content review.

---

## What shipped

10B.0 closed with `:swipe_actions` raising `UnresolvableDefault` on
`:macos`, `:web_wide`, and `:android`. 10B.1a closes the first two
gaps by introducing `UI::InlineActionRow` — a Tier 2 widget that
renders leading + trailing actions as visible inline buttons (the
HIG-correct macOS pattern; mouse-driven desktop-web mirrors the
convention).

The resolver now returns:

| Platform | `:swipe_actions` → |
|----------|--------------------|
| `:ios` | `UI::SwipeActionRow` |
| `:ipados` | `UI::SwipeActionRow` |
| `:web_narrow` | `UI::SwipeActionRow` |
| `:macos` | `UI::InlineActionRow` *(NEW — Phase 10B.1a)* |
| `:web_wide` | `UI::InlineActionRow` *(NEW — Phase 10B.1a)* |
| `:android` | `UnresolvableDefault` *(closed in 10B.1c)* |

## API surface

`src/ui/views/inline_action_row.cr`:

```crystal
module UI
  class InlineActionRow < View
    declares_capabilities :swipe_actions, {
      supports_edge_trailing:    true,
      supports_role_default:     true,
      supports_role_destructive: :partial,
    }

    property content : View
    property leading_actions : Array(SwipeAction)
    property trailing_actions : Array(SwipeAction)

    def initialize(@content : View)
      @leading_actions = [] of SwipeAction
      @trailing_actions = [] of SwipeAction
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
```

Shares the `UI::SwipeAction` value type with `UI::SwipeActionRow`
(no duplication). Capability bag is identical so the registry treats
the two widgets as interchangeable on their respective platforms.

## Renderer dispatch (all 4 covered)

| Renderer | Implementation |
|---|---|
| `UI::Web::Renderer` | `<div role="row">` with leading panel + content cell + trailing panel; each action is a `<button>` carrying `aria-label`, `data-action-role`, `data-action-edge`, and (optionally) `data-on-tap-route`. CSS + a tiny route-dispatch JS shim emitted once per renderer instance. |
| `UI::AppKit::Renderer` | Horizontal `NSStackView` containing leading `NSButton`s + content view + trailing `NSButton`s. Mirrors the inline pattern `visit(SwipeActionRow)` already used on macOS. |
| `UI::UIKit::Renderer` | Horizontal `UIStackView` with leading + content + trailing children rendered through the standard `UI::Button` path (CallbackRegistry-backed taps). Best-effort coverage for explicit-override use; iOS default remains `UI::SwipeActionRow`. |
| `UI::Android::Renderer` | Best-effort dispatch: each leading / trailing action becomes a `UI::Button` and is accepted by the visitor, then content is dispatched. The platform default for `:swipe_actions` on Android still raises `UnresolvableDefault` until 10B.1c. |

`PlatformVisitor` gained `abstract def visit(view : InlineActionRow)`
so any future renderer must implement it.

## Resolver default table update

`src/ui/intent_bootstrap.cr` adds:

```crystal
UI::Intent::Registry.register_default(:swipe_actions, :macos, UI::InlineActionRow)
UI::Intent::Registry.register_default(:swipe_actions, :web_wide, UI::InlineActionRow)
```

## Spec coverage

**`spec/web/ui/views/inline_action_row_spec.cr`** — 9 examples covering:

- Construction + default empty action lists.
- `UI::SwipeAction` value-type sharing.
- Both leading + trailing action lists.
- Visitor dispatch.
- Web rendering: content + action buttons + `aria-label`s +
  destructive class + `data-action-edge`.
- Leading-only path.
- Chrome emitted exactly once per renderer instance.
- `on_tap_route` surfaces as `data-on-tap-route`.
- **Reactivity contract:** mutating `trailing_actions` between
  renders surfaces the change in the next render pass
  (`[[reactivity-is-table-stakes]]`).

**`spec/web/ui/intent_spec.cr`** — updated:

- `:swipe_actions` on `:macos` and `:web_wide` now assert the
  resolver returns `UI::InlineActionRow` (was: `expect_raises
  UnresolvableDefault`).
- The "skips the app tier when app_class is nil" spec switched from
  `:macos` to `:android` (now the only platform without a registered
  default for `:swipe_actions`).
- `reinstall_intent_bootstrap` helper extended to install the new
  `:macos` + `:web_wide` defaults so mid-flow `reset_overrides_for_spec`
  calls leave the bootstrap state honest.

**Targeted spec result:**

```
crystal spec spec/web/ui/views/inline_action_row_spec.cr spec/web/ui/intent_spec.cr
34 examples, 0 failures, 0 errors, 0 pending
```

**Full web spec regression:**

```
crystal spec spec/web/
1771 examples, 4 failures, 0 errors, 66 pending
```

The 4 failures match the merge-baseline pre-existing failures
(`UI::Theme inject_theme_css` returns empty string; three Phase 2
component-system fixture mismatches).

## Compile + lint

```
crystal build src/asset_pipeline.cr
EXIT: 0

crystal run scripts/lint_conventions.cr
lint_conventions: OK (442 files, 6 rules, 0 diagnostics)
EXIT: 0
```

## HIG validation deferred

Per brief §1 + §7, HIG screenshot validation is **NOT in scope** for
10B.1a. The widget ships with renderer dispatch + capability declaration
+ web rendering specs; the macOS NSButton chrome relies on the existing
`apply_common_properties` path used by the sibling `SwipeActionRow` and
inherits its appearance defaults.

Validation will be picked up by:

- **10A.final** if it adds an Apple-platform-designer validation pass
  for the inline-row pattern, or
- **10D** (final polish phase) if 10A.final declines.

The widget is functionally complete for the resolver-honesty close;
visual proofs remain pending.

## Codex content review

*Pending invocation — implementer-side iter-1 evidence captured in this
handoff. Architect runs `scripts/codex_hig_review.sh` or equivalent
content critique before the merge tag is cut.*

## Out of scope (deferred)

- HIG visual validation (above).
- Android `:swipe_actions` default — 10B.1c installs
  `UI::AndroidSwipeActionRow`.
- Capability honesty audit of `UI::InlineActionRow` vs.
  `UI::SwipeActionRow` divergences — 10B.1b.
- iOS hand-test of the inline-row override path — covered by the
  hands-on capture matrix once the apple-platform-designer reaches
  this slug.

— Implementer (Claude Opus 4.7), 10B.1a iter-1

## Iter 2 — Codex REVISE remediation (Android renderer)

**Codex finding (BLOCKER):** The Android `visit(UI::InlineActionRow)`
in `src/ui/renderers/android_renderer.cr` visited leading buttons,
content, and trailing buttons sequentially without composing them into
a parent container. Because `push_native` either sets `@result` (no
parent) or attaches to the current parent, a top-level `InlineActionRow`
resolved to its last visited child, and a nested `InlineActionRow`
leaked its buttons + content as separate parent siblings. Not a
reasonable row renderer.

**Fix:** Rewrote the Android visit to mirror the established
`visit(UI::HStack)` LinearLayout pattern (renderer line ~480):

1. Create a horizontal `LinearLayout` (orientation = 0) with
   center-vertical gravity (16).
2. `apply_common_properties` so frame / background / padding still
   apply.
3. Wrap as `NativeView` and `push_stack` as a linear parent.
4. Visit leading actions → content → trailing actions; each child
   attaches to the row LinearLayout via `push_native` while the row
   is the current stack parent.
5. `pop_stack` then `push_native(native, ll)` so the row itself is
   either set as `@result` (top-level case) or registered with its
   own parent (nested case).

The Android renderer remains a best-effort path until 10B.1c installs
`UI::AndroidSwipeActionRow` as the resolver default for
`:swipe_actions` on `:android`; the resolver still raises
`UnresolvableDefault` there. This visit covers apps that explicitly
mount `UI::InlineActionRow` on Android.

**Affected file:** `src/ui/renderers/android_renderer.cr` (visit method
spanning the InlineActionRow block, container + push_stack + child
visits + pop_stack + push_native composition).

**Verification:**

- `crystal build src/asset_pipeline.cr` — green.
- `crystal run scripts/lint_conventions.cr` — `OK (442 files, 6 rules,
  0 diagnostics)`.
- `crystal spec spec/web/` — 1771 examples, 4 failures (baseline),
  0 errors. No regression.
- `crystal spec spec/web/ui/intent_spec.cr
  spec/web/ui/intent_reactivity_spec.cr
  spec/web/ui/views/inline_action_row_spec.cr` —
  37 examples, 0 failures.

— Implementer (Claude Opus 4.7), 10B.1a iter-2
