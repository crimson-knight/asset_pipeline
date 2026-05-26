# Phase 10B.1a — UI::InlineActionRow widget

**Sub-phase:** 10B.1a — create the macOS / web_wide default for `:swipe_actions`.
**Branch:** `phase-10-b-1a` cut from `phase-10` (tag `phase-10-trio-merged-2026-05-26`).
**Status:** v1.
**Predecessor:** 10B.0 closed.

---

## Critical context

10B.0's intent resolver currently raises `UnresolvableDefault` for `:swipe_actions` on `:macos`, `:web_wide`, and `:android` because there's no honest default. 10B.1a removes the macOS + web_wide error by introducing `UI::InlineActionRow` — a row widget that renders trailing actions as visible inline buttons (the HIG-correct macOS pattern; there's no swipe-to-reveal on the Mac).

Per the `:swipe_actions` capability declaration in `UI::SwipeActionRow`:

```crystal
declares_capabilities :swipe_actions, {
  supports_edge_trailing:    true,
  supports_role_default:     true,
  supports_role_destructive: :partial,
}
```

`UI::InlineActionRow` must declare the same capabilities (or document why a capability is unsupported and the test/registry assertion adapts).

## 1. What you are doing

Build `UI::InlineActionRow` and wire it as the default for `:swipe_actions` on `:macos` + `:web_wide`. After 10B.1a closes:

- `src/ui/views/inline_action_row.cr` — Tier 2 widget. Content + leading + trailing actions, rendered as inline HStack with visible buttons (no swipe gesture).
- `declares_capabilities :swipe_actions, {...}` macro call.
- Renderers: web HTML emission; macOS NSStackView mapping; iOS NSStackView fallback (rarely used since iOS prefers SwipeActionRow but available as override).
- `src/ui/intent_bootstrap.cr` updated: `:swipe_actions` defaults table now resolves macOS + web_wide → `UI::InlineActionRow`.
- Specs: `spec/web/ui/views/inline_action_row_spec.cr` (web rendering) + intent resolver spec asserting macOS resolves to InlineActionRow.
- HIG validation: NOT required for 10B.1a (defer to 10A.final / 10D). Document this in close handoff.

## 2. Read first

1. `src/ui/views/swipe_action_row.cr` — sibling widget; mirror its property + initializer shape (`content`, `leading_actions`, `trailing_actions`).
2. `src/ui/intent_bootstrap.cr` — current `:swipe_actions` defaults table.
3. `src/ui/intent/registry.cr` — capability validation logic.
4. `src/ui/renderers/web_renderer.cr` — pattern for view dispatch.
5. `src/ui/renderers/appkit_renderer.cr` — macOS NSStackView pattern.
6. `.claude/skills/apple-platform-guide/` — HIG references for macOS list rows (don't ship validation in this slice, but follow the spirit).

## 3. Constraints (Hard Rules)

- Forward commits only on `phase-10-b-1a`.
- `UI::InlineActionRow` shares the `SwipeAction` value type with `SwipeActionRow` (same `{label, role, icon, on_tap}` shape) — DO NOT duplicate.
- `declares_capabilities` macro call MUST be present.
- Web renderer must produce valid HTML with proper button elements (accessibility — each button has `aria-label` from the SwipeAction's `label`).
- macOS renderer must use NSStackView + NSButton (matching the pattern in appkit_renderer.cr for other inline button rows).
- iOS renderer is best-effort — same NSStackView pattern.
- Spec: web rendering test + 1 resolver spec assertion. NO HIG screenshot validation (deferred).
- `[[codex-as-architect-antagonist]]` + `[[reactivity-is-table-stakes]]` apply.

## 4. Deliverables

### Deliverable 1 — `src/ui/views/inline_action_row.cr`

```crystal
# Inline trailing-action row. The macOS + web_wide default for the
# :swipe_actions intent — actions are visible inline buttons (no
# swipe-to-reveal gesture on Mac per HIG).

require "../view"
require "./swipe_action_row" # for SwipeAction value type

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

### Deliverable 2 — Renderer dispatch

`PlatformVisitor` gets a new `def visit(view : InlineActionRow)` abstract method.
- `UI::Web::Renderer` — emits `<div role="row">[content][buttons]</div>` (vanilla HTML, action buttons trailing).
- `UI::AppKit::Renderer` — NSStackView (horizontal) containing the content view + NSButton instances for each action.
- `UI::UIKit::Renderer` — UIStackView (horizontal) containing the content view + UIButton instances.
- `UI::Android::Renderer` — LinearLayout (horizontal) with MaterialButtons.

### Deliverable 3 — `src/ui/intent_bootstrap.cr` update

`:swipe_actions` defaults table now reads:
- `:ios → UI::SwipeActionRow`
- `:ipados → UI::SwipeActionRow`
- `:web_narrow → UI::SwipeActionRow`
- `:macos → UI::InlineActionRow` (NEW)
- `:web_wide → UI::InlineActionRow` (NEW)
- `:android → raises UnresolvableDefault` (until 10B.1c installs Material3 swipe)

### Deliverable 4 — Specs

`spec/web/ui/views/inline_action_row_spec.cr`:
- Web renderer test: an `InlineActionRow` with 2 trailing actions renders HTML containing both button labels + aria-labels.
- Test_id on actions surfaces in HTML.

Extend `spec/web/ui/intent_spec.cr`:
- `resolve(:swipe_actions, macos_context)` now returns `UI::InlineActionRow` (not raises). Update the existing macos `raises UnresolvableDefault` spec to instead assert the correct widget.
- Same for web_wide.

### Deliverable 5 — Close handoff

`docs/initiative-cross-platform-ui/handoff/phase-10-b-1a-close.md`:
- API surface (`UI::InlineActionRow` properties + visit method).
- Resolver default table update.
- Spec coverage.
- HIG validation deferred note + which phase will handle.
- Codex content review verdict.

## 5. Workflow

1. `git checkout -b phase-10-b-1a phase-10`.
2. Build `inline_action_row.cr` (Deliverable 1).
3. Add `visit(InlineActionRow)` to `PlatformVisitor` abstract.
4. Implement 4 renderers (Deliverable 2).
5. Update intent_bootstrap (Deliverable 3).
6. Specs (Deliverable 4).
7. `crystal spec spec/web/ui/views/inline_action_row_spec.cr spec/web/ui/intent_spec.cr` — pass.
8. `crystal build src/asset_pipeline.cr` — compile.
9. `crystal run scripts/lint_conventions.cr` — green.
10. Close handoff.
11. Standard footer.

## 6. Acceptance gate

- ✅ `UI::InlineActionRow` exists + has `declares_capabilities` call.
- ✅ All 4 renderers implement `visit(InlineActionRow)`.
- ✅ `:swipe_actions` resolver returns `InlineActionRow` for :macos + :web_wide (no longer raises).
- ✅ Spec assertions updated to match.
- ✅ Lint green.
- ✅ `crystal spec spec/web/` regression count same as merge baseline (4 pre-existing failures).
- ✅ Codex content review APPROVE.

## 7. Out of scope

- HIG validation captures (deferred — 10A.final or 10D).
- Android Material3 swipe — 10B.1c.
- Capability honesty audit — 10B.1b.
- Other widget implementations.

— Architect (Claude Opus 4.7), 10B.1a brief v1
