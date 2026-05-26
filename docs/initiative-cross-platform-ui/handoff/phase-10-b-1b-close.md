# Phase 10B.1b close — :swipe_actions capability honesty audit

**Branch:** `phase-10-b-1b` (cut from `phase-10` @ `5e50f3be`).
**Brief:** `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/brief-10-b-1b.md` (v1).
**Status:** Iter 2 (REVISE remediation) complete; ready for re-review.

---

## What shipped

10B.1a left every `:swipe_actions` widget declaring
`supports_role_destructive: :partial`. The fuzzy symbol collapsed three
distinct gaps — the iOS SwipeActionRow leading-edge drop, the AppKit
no-destructive-tint, and the Android SwipeActionRow stub — into a
single declaration that the registry could not act on. 10B.1b makes
the declaration platform-honest:

1. **Audit doc** — `docs/initiative-cross-platform-ui/architecture/swipe-actions-capability-audit.md`
   carries a per-`(widget × platform × capability)` matrix with
   renderer-code citations for every cell.
2. **`declares_capabilities` macro** accepts a fourth value shape —
   `Hash(Symbol, Bool)` keyed by platform symbol — alongside the
   existing `true` / `false` / `:partial` values.
3. **Registry validation** is platform-aware. `validate_override_capabilities`
   walks the union of platforms with a registered default for the
   intent and requires the override widget to back the capability on
   each of them; the resolver's `capabilities_required:` kwarg path
   gates per-`context.platform`.
4. **Both library widgets** (`UI::SwipeActionRow`, `UI::InlineActionRow`)
   now declare the honest platform-keyed matrix.
5. **`:swipe_actions` intent requirements** in `intent_bootstrap.cr`
   switch `supports_role_destructive` from `:partial` to a per-platform
   `Hash{ios: true, ipados: true, macos: false, web_wide: true,
   web_narrow: true, android: false}`.
6. **Audit spec** — `spec/web/ui/swipe_actions_capability_audit_spec.cr`
   asserts the resolver and validator behave per the audit matrix and
   rejects platform-specific lies + the legacy `:partial` shortcut.

## Capability shape decision

Two candidate shapes were considered:

| Shape | Pros | Cons | Decision |
|---|---|---|---|
| Per-platform key suffix (`supports_role_destructive_ios`, …) | Compatible with the original `Bool \| Symbol` type. | Quadratic key explosion (5 platforms × 4 caps = 20 keys per intent), and the intent requirement needs the same explosion. | Rejected. |
| Platform-keyed `Hash(Symbol, Bool)` | One key per capability; value shape mirrors the validator's lookup (`hash[context.platform]?`); a new platform is one cell per cap, not four new keys. | Macro must distinguish HashLiteral vs Bool branches. | **Chosen.** |

The macro now emits the appropriate Hash literal at the cap site, and
the registry's `CapabilityValue` type alias is `Bool | Symbol |
Hash(Symbol, Bool)`.

## Per-platform honesty findings (cited in audit doc)

| Widget | Platform | Capability | Verdict | Renderer-code citation |
|---|---|---|---|---|
| `SwipeActionRow` | iOS (UIKit) | `supports_edge_leading` | `false` | `uikit_renderer.cr` L3854 — `view.trailing_actions.each` only; `view.leading_actions` is never read. |
| `SwipeActionRow` | macOS (AppKit) | `supports_edge_leading` | `false` | `appkit_renderer.cr` L3822 — only `view.trailing_actions.each`. |
| `SwipeActionRow` | macOS (AppKit) | `supports_role_destructive` | `false` | `appkit_renderer.cr` L3823-3829 — `action.role` is never read; NSButton receives `setTitle:` only. |
| `SwipeActionRow` | Android | every capability | `false` | `android_renderer.cr` L3154 — visit body is `view.content.accept(self)` (stub). |
| `InlineActionRow` | macOS (AppKit) | `supports_role_destructive` | `false` | `appkit_renderer.cr` L3848-3868 — `action.role` is never read on the leading + trailing NSButton loops. |
| All other cells | — | — | `true` | See audit doc per-cell rationale. |

## Files changed

- `src/ui/view.cr` — `declares_capabilities` macro accepts HashLiteral / NamedTupleLiteral values; emits `Hash(Symbol, Bool)` at the cap site; docstring updated with the new shape semantics.
- `src/ui/intent/registry.cr` — new `CapabilityValue` alias (`Bool | Symbol | Hash(Symbol, Bool)`); `validate_override_capabilities` rewritten to walk platform-keyed requirements and the union of platforms with registered defaults; new helpers `validate_universal_requirement`, `platforms_with_default_for`, `platform_supported?`, `describe_platform_support`.
- `src/ui/intent.cr` — `first_missing_capability` takes a `platform` arg and delegates per-platform queries to `Registry.platform_supported?`.
- `src/ui/intent_bootstrap.cr` — `:swipe_actions` requirement set carries a platform-keyed `supports_role_destructive` Hash instead of `:partial`.
- `src/ui/views/swipe_action_row.cr` — capability declaration replaced with platform-keyed matrix matching the audit.
- `src/ui/views/inline_action_row.cr` — capability declaration replaced with platform-keyed matrix matching the audit.
- `spec/web/ui/intent_spec.cr` — spec widgets' `:partial` declarations rewritten as honest platform-keyed Hashes; `reinstall_intent_bootstrap` helper uses the new requirement shape.
- `spec/web/ui/swipe_actions_capability_audit_spec.cr` — NEW. 16 examples covering matrix-vs-resolver agreement, runtime per-platform gating, three rejection cases (web_wide lie, universal shadow-default lie, legacy `:partial`), and a change-detector that reads the library widgets' declarations directly from the registry.
- `docs/initiative-cross-platform-ui/architecture/swipe-actions-capability-audit.md` — NEW. Per-(widget × platform) matrix with renderer-code citations and the capability-shape decision rationale.

## Verification

```
crystal build src/asset_pipeline.cr
EXIT: 0

crystal spec spec/web/ui/swipe_actions_capability_audit_spec.cr
16 examples, 0 failures, 0 errors, 0 pending

crystal spec spec/web/ui/intent_spec.cr spec/web/ui/intent_reactivity_spec.cr \
             spec/web/ui/views/inline_action_row_spec.cr spec/web/ui/swipe_action_row_spec.cr
47 examples, 0 failures, 0 errors, 0 pending

crystal spec spec/web/
1829 examples, 4 failures, 0 errors, 66 pending
```

The 4 failures are the merge-baseline failures inherited from
phase-10:

- `spec/web/ui/views_spec.cr:3283` — `UI::Theme inject_theme_css` empty-theme behaviour.
- `spec/web/components/phase2_verification_spec.cr:52`, `:116`, `:129` — Phase 2 component-system class-name fixtures (`am-counter` vs `counter-component`).

No new failures.

```
crystal run scripts/lint_conventions.cr
lint_conventions: OK (453 files, 14 rules, 0 diagnostics)
EXIT: 0
```

## Format note

`crystal tool format` reports a Crystal formatter bug on two of the
edited files (`src/ui/intent/registry.cr` line 155, and
`spec/web/ui/intent_spec.cr`). The bug is pre-existing — line 155 is
the `(UI::View.class)?` return-type annotation that ships untouched on
`phase-10`. Running `--check` against the rest of the modified files
is green. No further action.

## Out of scope (deferred)

- macOS `supports_role_destructive: true` — requires an AppKit
  button-role facade (analogous to SwiftKit's `APSKButtonFacade`)
  before the cell can flip honestly. Tracked as a future
  Phase 4/5 surface item.
- Android `:swipe_actions` default — 10B.1c installs
  `UI::AndroidSwipeActionRow`; the Android cells in the
  SwipeActionRow row of the matrix will flip to `true` at that
  point.
- Other intents — 10B.1b is `:swipe_actions` only. Other Tier 2
  intents (`:date_picker`, `:tab_bar`, etc.) get their own
  honesty pass in their respective slices.

## Codex content review

Iter-1 Codex review returned **REVISE** with two findings:

1. **(BLOCKER)** `declares_capabilities` macro advertised both
   NamedTupleLiteral and HashLiteral key shapes for the per-capability
   platform map, but the HashLiteral branch was dishonest. Rocket-
   style keys (`:ios => true`) arrive as `SymbolLiteral` and the
   `.symbolize` call wrapped them into `:":ios"`, never matching
   downstream lookups.
2. **(MEDIUM)** The audit doc and spec language over-claimed what
   the registry enforces. The validator walks only required-`true`
   cells (`registry.cr:305` — `next unless needed`), so a widget
   that over-claims `:macos => true` for `supports_role_destructive`
   (while the intent requires `:macos => false`) registers
   successfully. Codex verified this with a dummy widget.

## Iter 2 — remediation

### Finding 1 (Option A — fix the macro)

Updated `src/ui/view.cr` `declares_capabilities` macro:

- For each inner platform key, branch on
  `plat_key.is_a?(SymbolLiteral)`. Rocket-style keys emit directly
  (no `.symbolize`). NamedTupleLiteral keys (MacroId) keep going
  through `.symbolize`.
- Same handling applied to the outer capability key for symmetry —
  both `supports_edge_trailing:` (NamedTuple) and
  `:supports_edge_trailing =>` (rocket Hash) produce
  `caps[:supports_edge_trailing]`.

Added a new spec block, `macro HashLiteral key handling (rocket-
style)`, with 2 examples:

1. A widget declared entirely with rocket-style HashLiteral keys
   stores plain `:ios` / `:macos` / etc. in the registry — verified
   by direct lookup of `value[:ios]`, plus a belt-and-braces check
   that `value[:":ios"]?` is `nil`.
2. The same rocket-style widget passes override validation on macOS
   (the registration path that would have silently dropped pre-fix).

Spec count: **18 examples** (was 16). All pass.

### Finding 2 (Option A — be honest in the docs)

Updated the audit doc's "Registry validation contract update"
section with a new "What the registry enforces (and what it does
NOT)" callout that:

- States plainly that **under-claim rejection is enforced** (widget
  admits it doesn't back a required cell → rejected).
- States plainly that **over-claim is NOT rejected by the registry**
  (widget falsely claims it backs an unrequired cell → registers
  successfully).
- Cites `registry.cr:305`'s `next unless needed` as the source of
  the behavior.
- Explains the design rationale: no runtime oracle for what each
  renderer paints; the audit doc + Codex review of renderer code is
  the over-claim guard.
- Documents the implication: a future requirement flip
  (`:macos => false` → `:macos => true`) re-checks overrides on
  next registration and rejects any over-claim that didn't back the
  renderer.

Also corrected the misleading paragraph at the end of the
"`:swipe_actions` intent-requirement update" section that implied
the registry catches `:macos => true` over-claims. Reworded to
specify under-claim rejection only.

Updated the spec file's top-of-file docstring to (a) restate the
four guarantees the spec proves (the 3 originals plus the iter-2
rocket-Hash regression guard) and (b) carry the same honesty
callout about what the registry does NOT enforce.

No code changes for Finding 2 — it's a documentation honesty fix.

## Iter 2 verification

```
crystal spec spec/web/ui/swipe_actions_capability_audit_spec.cr
18 examples, 0 failures, 0 errors, 0 pending

crystal spec spec/web/ui/intent_spec.cr
25 examples, 0 failures, 0 errors, 0 pending

crystal spec spec/web/ui/intent_reactivity_spec.cr
3 examples, 0 failures, 0 errors, 0 pending

crystal spec spec/web/ui/views/inline_action_row_spec.cr
9 examples, 0 failures, 0 errors, 0 pending

crystal spec spec/web/ui/swipe_action_row_spec.cr
10 examples, 0 failures, 0 errors, 0 pending

crystal build src/asset_pipeline.cr
EXIT: 0

crystal run scripts/lint_conventions.cr
lint_conventions: OK (453 files, 14 rules, 0 diagnostics)
```

## Iter 2 commit log

- `6795e8aa` — Finding 1: macro HashLiteral branch fix + 2 specs.
- `1f82c7e3` — Finding 2: docs honesty about over-claim vs under-claim.
- (final close commit) — handoff iter-2 sections + status flip.

— Implementer (Claude Opus 4.7), 10B.1b iter-1
— Implementer (Claude Opus 4.7), 10B.1b iter-2 (REVISE remediation)
