# Phase 10B.4 close — Missing widgets

**Branch:** `phase-10-b-4` (cut from `phase-10` @ `dbdf592b`, tag
`phase-10-batch-4-merged-2026-05-26`).
**Brief:** `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/brief-10-b-4.md` (v1).
**Status:** Forward-only commits; ready for content review.

---

## Headline

**4 widget classes shipped + 4 renderer visit methods each (16
visitor methods total) + 4 specs (35 examples, all green). 0 lint
violations. 4 catalog rows + tier-matrix row + tier-matrix change log
updated.**

The brief asked: identify the actual missing-widget gap surfaced by
the Phase 10-pre catalog freshness audit, ship them, document them.
The freshness audit (`handoff/phase-10-pre-catalog-freshness-2026-05-25.md`)
identified `UI::Inspector`, `UI::FullScreenCover`,
`UI::ToolbarItemGroup`, and `UI::ToolbarSpacer` as the
"`coverage_today: missing` with a named-but-non-existent `UI::X` class"
gap. The 10B.1a/b/c work had already closed the keystone Class A
gaps (`UI::InlineActionRow`, `UI::AndroidSwipeActionRow`); the four
Class D widgets above were the remaining "named-class doesn't exist"
catalog liars.

## Widget identification audit (10B.4 step 1 per brief)

Per the brief workflow §2, I cross-referenced `src/ui/views/*.cr`
against:

* `docs/initiative-cross-platform-ui/architecture/intent-routing-candidates.md` —
  Class A `:swipe_actions` defaults. All Class A widgets shipped
  through 10B.1a-c (`UI::InlineActionRow`, `UI::AndroidSwipeActionRow`).
  No remaining Class A widget gap.
* `docs/initiative-cross-platform-ui/handoff/phase-10-pre-catalog-freshness-2026-05-25.md` —
  the "Missing widgets" table (rows 13-23) identified 10 catalog claims
  referencing non-existent `UI::X` classes. After accounting for what
  10B.1a/b/c shipped + what's `coverage_today: missing` (no class
  promise to keep), the residual gap is 4 widgets:

| Catalog claim | Class name | Backlog ID |
|---|---|---|
| `:inspector` | `UI::Inspector` | B-009 |
| `:full_screen_cover` | `UI::FullScreenCover` | B-010 |
| `:toolbar_item_group` | `UI::ToolbarItemGroup` | B-011 |
| `:toolbar_spacer` | `UI::ToolbarSpacer` | B-011 |

* `docs/initiative-cross-platform-ui/tier-matrix.md` — declared
  widget surface. All declared widgets were already shipped on the
  base; the matrix had not been updated with the four new ones (no
  one had committed them yet). The matrix now reflects the four.
* `find src/ui/views -name '*.cr' | sort` vs declared list:
  on the base, 81 shipped vs 78 declared (the 3 extras —
  `swipe_action_row`, `inline_action_row`, `android_swipe_action_row`
  — were not in tier-matrix because the matrix predates 10B.1a/b/c).
  10B.4 adds the 4 widgets here and updates the matrix in lockstep.

Other catalog rows mention `UI::Menu`, `UI::UIMenu`, `UI::UIAction`,
`UI::ToolbarItemGroup` (handled), `UI::ToolbarSpacer` (handled),
`UI::FullScreenCover` (handled), `UI::Inspector` (handled),
`UI::NavigationPath`. Of those, `UI::NavigationPath` is `shipped` via
`UI::NavigationCoordinator#routes` (`navigation_coordinator.cr:38`).
`UI::Menu` / `UI::UIMenu` / `UI::UIAction` are tagged `partial` with
explicit Phase 10-pre.2 design-decision pointers ("today's analog is
`UI::MenuButton::MenuItem`"), not "named-class-doesn't-exist" liars.
Out of scope for 10B.4 per the brief's "don't invent widgets" rule.

## Per-widget × per-platform status

| Widget | Crystal class | Visitor abstract | Web | UIKit | AppKit | Android | Spec |
|---|---|---|---|---|---|---|---|
| `UI::FullScreenCover` | ✅ `src/ui/views/full_screen_cover.cr:50` | ✅ `platform_visitor.cr:163` | ✅ `web_renderer.cr:3196` (fixed-inset overlay, `role="dialog"`, hidden-when-not-presented) | ✅ `uikit_renderer.cr:4087` (UIView with visibility flag — full UIVC presentation deferred) | ✅ `appkit_renderer.cr:3976` (NSView with `setHidden:` — full NSWindow modal deferred) | ✅ `android_renderer.cr:3318` (FrameLayout with `android_view_set_visibility`) | ✅ `spec/web/ui/views/full_screen_cover_spec.cr` (9 examples) |
| `UI::Inspector` | ✅ `src/ui/views/inspector.cr:51` | ✅ `platform_visitor.cr:164` | ✅ `web_renderer.cr:3231` (CSS grid `1fr <width>px`, trailing `<aside role="complementary">`) | ✅ `uikit_renderer.cr:4117` (horizontal UIStackView — `UISplitViewController` deferred) | ✅ `appkit_renderer.cr:4011` (horizontal NSStackView — `NSSplitViewController` deferred) | ✅ `android_renderer.cr:3354` (horizontal LinearLayout) | ✅ `spec/web/ui/views/inspector_spec.cr` (9 examples) |
| `UI::ToolbarItemGroup` | ✅ `src/ui/views/toolbar_item_group.cr:60` | ✅ `platform_visitor.cr:165` | ✅ `web_renderer.cr:3272` (`<div role="group" aria-label="...">`, button siblings, divider span) | ✅ `uikit_renderer.cr:4153` (horizontal UIStackView routing through `UI::Button` so role tinting flows) | ✅ `appkit_renderer.cr:4047` (horizontal NSStackView with NSButton siblings; group label = AX label) | ✅ `android_renderer.cr:3391` (horizontal LinearLayout routing through `UI::Button`) | ✅ `spec/web/ui/views/toolbar_item_group_spec.cr` (11 examples) |
| `UI::ToolbarSpacer` | ✅ `src/ui/views/toolbar_spacer.cr:36` | ✅ `platform_visitor.cr:166` | ✅ `web_renderer.cr:3307` (`<div aria-hidden="true">` with `flex` rule per mode) | ✅ `uikit_renderer.cr:4193` (UIView placeholder; stack distribution drives flex) | ✅ `appkit_renderer.cr:4087` (NSView placeholder) | ✅ `android_renderer.cr:3429` (`android.widget.Space`) | ✅ `spec/web/ui/views/toolbar_spacer_spec.cr` (8 examples) |

**Renderer count: 4/4 per widget = 16 visitor methods.**
**Spec count: 4 files, 37 total examples (35 + 2 visitor-dispatch
helpers shared across them).** All green on `crystal spec`.

## What's deferred (and where it's tracked)

These deferrals are deliberate and tracked under existing backlog
items. The 10B.4 brief explicitly accepted them ("Android: best-effort
JNI bridge with documented gaps") and only required the data path
and visit dispatch:

| Deferral | Reason | Tracked under |
|---|---|---|
| `UI::FullScreenCover` native presentation lifecycle (UIViewController `.fullScreen` / NSWindow `beginSheet:`) | Requires SwiftKit facade (`apsk_make_full_screen_cover`) parallel to `apsk_make_sheet_reactive`. Same pattern; out of scope this slice. | B-010 |
| `UI::Inspector` native split-view binding (`UISplitViewController` inspector column / `NSSplitViewController` pane) | Requires SwiftKit facade. Today's horizontal-stack fallback covers the data path; full split-view interop is a follow-up. | B-009 |
| `UI::ToolbarItemGroup` inline-within-`UI::Toolbar` placement | Today the group renders standalone (its visitor produces a horizontal cluster). To embed inside a `UI::Toolbar`'s items array, `UI::Toolbar` itself needs an item-list type union (item OR group) and the Toolbar visitor needs to walk groups. Mechanical follow-up. | B-011 |
| `UI::ToolbarSpacer` mapping to NSToolbar `flexibleSpace` / UIToolbar `flexibleSpace` identifiers | Same shape as the group inline-binding: requires `UI::Toolbar` item-list union. | B-011 |
| Android Compose-host integration | Same JNI-Compose-bridge blocker called out in 10B.1c close for `UI::AndroidSwipeActionRow`. All four 10B.4 widgets use the existing View-system bridge; Compose facades land when the bridge does. | (covered by 10B.1c JNI write-up) |

The catalog rows now read `partial` with citations to the visit
methods AND a `# was: missing — Phase 10B.4 shipped ...` audit
history suffix that the intent catalog linter accepts (verified
against `scripts/lint_intent_catalog.cr` — 92 entries PASS).

## API surface

### `UI::FullScreenCover`

```crystal
cover = UI::FullScreenCover.new(content_view)
cover.is_presented = true
cover.on_dismiss = -> { puts "dismissed" }
```

- `content : View?`
- `is_presented : Bool = false`
- `on_dismiss : Proc(Nil)?`
- `default_accessibility_role => :dialog`
- `default_focusable => true`

### `UI::Inspector`

```crystal
insp = UI::Inspector.new(primary_view, inspector_pane)
insp.is_presented = true
insp.preferred_width = 320.0
```

- `content : View?` — primary surface
- `inspector_content : View?` — trailing pane
- `is_presented : Bool = true`
- `preferred_width : Float64?` — nil = renderer default
- `on_dismiss : Proc(Nil)?`
- `default_accessibility_role => :none` (the pane's
  `role="complementary"` is emitted by the web visitor on the
  inner aside; the wrapper carries no role itself)

### `UI::ToolbarItemGroup`

```crystal
g = UI::ToolbarItemGroup.new("Formatting")
g.add_item("bold", "Bold") { state.toggle_bold }
g.add_item("italic", "Italic") { state.toggle_italic }
g.with_divider = false
```

- `items : Array(Toolbar::ToolbarItem)` — shares the existing
  `Toolbar::ToolbarItem` record (no duplicate value type)
- `label : String?` — group label (emitted as `aria-label` /
  `setAccessibilityLabel:`)
- `with_divider : Bool = true` — visual divider boundary
- `add_item(id, label, icon = nil) { ... }` — block form
- `add_item(id, label, icon = nil)` — no-action form
- `default_accessibility_role => :group`

### `UI::ToolbarSpacer`

```crystal
flex_spacer  = UI::ToolbarSpacer.new          # flexible (consumes remaining space)
fixed_spacer = UI::ToolbarSpacer.new(16.0)    # fixed 16pt
```

- `fixed_size : Float64?` — nil = flexible
- `flexible? : Bool` — convenience predicate
- `default_accessibility_role => :none` (web emits `aria-hidden`
  so screen readers skip)

## Reactivity contract (per the `[[reactivity-is-table-stakes]]` memory)

Every widget's spec includes a "mutate-then-re-render" test. Setting
`is_presented = true/false` after construction, or appending to
`items` / `trailing_actions`, MUST surface in the next render pass.
The visitor implementations read the current property values at
visit time — they do not cache state. The web renderer's
mutate-then-re-render contract is verified by passing a fresh
`UI::Web::Renderer.new` and asserting the new output reflects the
mutation; the native renderers follow the same pattern (re-render
on `accept(self)` re-entry).

The full SwiftKit-state-handle path (parallel to `UI::Sheet#is_presented=`
dispatching through `LibSwiftKitBridge.apsk_sheet_set_presented`) is
deferred to the follow-up facade phase. Today's reactivity contract
is satisfied via the standard re-render path.

## Audit-scope discipline (per the `[[audit-scope-discipline]]` memory)

Each widget was implemented across all four renderers in the same
commit. The visit methods were added by grepping the existing
renderer for similar lookalike widgets (e.g. `visit(view :
UI::InlineActionRow)` as the template, `visit(view : UI::Snackbar)`
as the simpler fallback template) and then walking each renderer to
add the four new methods. Compilation verified across web, macOS
(`-Dmacos`), and iOS (`-Dios`); Android cross-compile requires the
NDK + epoll shim, not a regression.

## Branch state

```
phase-10-b-4 commits (forward only, all signed Co-Authored-By):
  Phase 10B.4 — add UI::FullScreenCover widget + 4 renderer visits + spec
  Phase 10B.4 — add UI::Inspector widget + 4 renderer visits + spec
  Phase 10B.4 — add UI::ToolbarItemGroup widget + 4 renderer visits + spec
  Phase 10B.4 — add UI::ToolbarSpacer widget + 4 renderer visits + spec
  Phase 10B.4 — update PlatformVisitor abstract dispatch
  Phase 10B.4 — update intent-catalog + tier-matrix + existing test visitors
  Phase 10B.4 — close handoff
```

(Initial implementation is bundled — see commit log on HEAD; this
listing shows the logical breakdown.)

## Acceptance gate (final)

- ✅ Each identified missing widget exists in `src/ui/views/`
  (`full_screen_cover.cr`, `inspector.cr`, `toolbar_item_group.cr`,
  `toolbar_spacer.cr`).
- ✅ All 4 renderers handle each widget (16/16 visit methods
  shipped; native lifecycle deferrals documented).
- ✅ Specs pass — 35 widget-specific examples + 2 visitor-dispatch
  helpers, all green on `crystal spec`.
- ✅ Lint + build green — `scripts/lint_conventions.cr` OK (476
  files, 14 rules, 0 diagnostics); `scripts/lint_intent_catalog.cr`
  PASS (92 entries); web + macOS + iOS builds compile clean.
- ☐ Codex content review — pending architect dispatch.

— Phase 10B.4 implementer, Claude Opus 4.7, 2026-05-26.

---

## Iter 2 — Codex REVISE remediation (2026-05-26)

Codex returned REVISE on the iter-1 ship with 3 findings. All three
addressed in this iteration; no other changes.

### Finding 1 (BLOCKER) — FullScreenCover web missing aria-modal + tabindex

**Root cause.** The visit method docstring promised `role="dialog"
aria-modal="true"` with `tabindex="-1"`, but only `role="dialog"` was
actually being emitted (via `apply_common_styles` reading
`default_accessibility_role`). The two extra attributes were never
explicitly set, and `effective_tab_index` returns `nil` for default-
focusable widgets (the View base intentionally skips emitting
`tabindex="0"` to avoid noise on form controls), so the documented
`tabindex="-1"` promise was being silently dropped.

**Fix.** `src/ui/renderers/web_renderer.cr:3208-3242` —
`visit(view : UI::FullScreenCover)` now explicitly emits
`aria-modal="true"` and `tabindex="-1"` via `set_attribute` BEFORE
the `apply_common_styles` call (which only sets tabindex when
`effective_tab_index` is non-nil, so the pre-set attribute survives).
A multi-line comment documents the rationale so a future maintainer
who reaches for "move this to `effective_tab_index = -1` as the
widget default" understands the intentional explicit-emission choice.

**Spec.** Two new examples in
`spec/web/ui/views/full_screen_cover_spec.cr`:
- `"emits aria-modal=\"true\" and tabindex=\"-1\" (modal-dialog contract)"` — presented state
- `"emits the modal-dialog ARIA contract even when not presented"` — hidden state (`display: none` wrapper still carries the ARIA contract so reactive flips don't churn it)

### Finding 2 (MEDIUM) — 3 widgets missing default_focusable overrides

The brief required `default_focusable` overrides per widget; only
`FullScreenCover` had one (returning `true`). The other three relied
on the View base default (`false`), which happens to be the right
value but was not explicitly documented as the widget's intent —
making the contract fragile against a future change to the View
base default.

**Fix.**
- `src/ui/views/inspector.cr:90-95` — added
  `def default_focusable : Bool; false; end` with rationale comment
  (structural container; focus belongs to primary + pane children).
- `src/ui/views/toolbar_item_group.cr:96-102` — added
  `def default_focusable : Bool; false; end` with rationale comment
  (clustering wrapper; items inside carry their own tab stops).
- `src/ui/views/toolbar_spacer.cr:73-79` — added
  `def default_focusable : Bool; false; end` with rationale comment
  (decorative `aria-hidden` chrome).

**Specs.** One assertion per widget:
- `spec/web/ui/views/inspector_spec.cr` — `"is non-focusable by default (focus lives on child content, not the wrapper)"`
- `spec/web/ui/views/toolbar_item_group_spec.cr` — `"is non-focusable by default (items inside carry the tab stops)"`
- `spec/web/ui/views/toolbar_spacer_spec.cr` — `"is non-focusable by default (decorative chrome stays out of tab order)"`

### Finding 3 (MINOR) — Stale catalog platforms line for `:full_screen_cover`

The catalog's `platforms:` line said `ios, ipados, android; macos+web
use sheets at appropriate size`, but the 10B.4 ship landed visit
methods on web + AppKit. The platforms line now reflects reality:

`docs/initiative-cross-platform-ui/architecture/intent-catalog.md:671`

```diff
- - **platforms:** ios, ipados, android; macos+web use sheets at appropriate size
+ - **platforms:** ios, ipados, android (native modal); macos, web (fallback container with role=dialog)
```

### Iter 2 acceptance

- ✅ Spec result: `crystal spec spec/web/ui/views/full_screen_cover_spec.cr
  spec/web/ui/views/inspector_spec.cr
  spec/web/ui/views/toolbar_item_group_spec.cr
  spec/web/ui/views/toolbar_spacer_spec.cr` →
  **40 examples, 0 failures, 0 errors** (was 35; +5 new assertions
  per the findings).
- ✅ Wider spec sweep: `crystal spec spec/web/ui/views/` →
  **81 examples, 0 failures, 0 errors**.
- ✅ `crystal run scripts/lint_conventions.cr` →
  **OK (477 files, 14 rules, 0 diagnostics)**.
- ✅ `crystal run scripts/lint_intent_catalog.cr` →
  **PASS (92 catalog entries)**.
- ✅ Forward-only commits on `phase-10-b-4`; no rebase, no amend.

— Phase 10B.4 iter 2 implementer, Claude Opus 4.7, 2026-05-26.
