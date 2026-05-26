# Phase 10B.2a — Static AX metadata on UI::View base

**Branch:** `phase-10-b-2a` from `phase-10` (tag `phase-10-batch-2-merged-2026-05-26`).
**Status:** v1.

## Context

Currently `UI::View` has `accessibility_label : String?` and `test_id : String?` properties. WCAG 2.2 AA + Apple HIG demand more static metadata for assistive tech:

- `accessibility_hint` — supplemental explanation ("Double-tap to open settings").
- `accessibility_role` — semantic role (`:button`, `:header`, `:list`, `:tab`, `:link`, ...). Falls back to widget-class default if not set.
- `accessibility_traits : Array(Symbol)` — UIKit-style traits (`:selected`, `:not_enabled`, `:plays_sound`, ...).
- `accessibility_value` — current value as string ("On", "75%", "3 of 7").
- `accessibility_identifier` — separate from `test_id`; used by UIKit/AppKit AX tree (XCTest expects this; AXTest uses `test_id` for the asset_pipeline path).

10B.2a adds these as properties + threads them through all 4 renderers.

## Deliverables

1. **Properties on `UI::View`** — add the 5 new properties with sensible defaults.
2. **Renderer threading**:
   - Web: emits `aria-label` (already done), plus `aria-roledescription`, `aria-describedby` (from hint), `role=`, `aria-current="..."` for traits-as-aria, `aria-valuetext` from accessibility_value.
   - AppKit: sets `setAccessibilityLabel:`, `setAccessibilityHelp:` (hint), `setAccessibilityRole:`, `setAccessibilityValue:`, `setAccessibilityIdentifier:` via objc bridge.
   - UIKit: same shape: `accessibilityLabel`, `accessibilityHint`, `accessibilityValue`, `accessibilityIdentifier`, `accessibilityTraits` (bitwise OR of UIAccessibilityTraits values).
   - Android: `setContentDescription` (label + hint concat), `setStateDescription` (value), `setImportantForAccessibility`, etc.
3. **Default role inference per widget class** — `UI::Button` defaults `:button`, `UI::Label` defaults `:text`, `UI::Toggle` defaults `:switch`, etc. Document the defaults in a table.
4. **Trait → platform mapping** — document how each `:trait` symbol maps per platform. Some traits don't have a UIKit/AppKit counterpart; fall through gracefully.
5. **Specs** — `spec/web/ui/accessibility_metadata_spec.cr`:
   - Web rendering with each property produces correct HTML.
   - Renderer threading test: a UI::Button with `accessibility_hint = "..."` produces the right `aria-describedby` output.
   - Default-role inference test: a UI::Toggle without explicit `accessibility_role` defaults to `:switch`.
6. **Close handoff** with the property table + per-platform mapping + Codex verdict.

## Workflow

1. `git checkout -b phase-10-b-2a phase-10`.
2. Read `src/ui/view.cr` for the current property surface.
3. Add the 5 new properties.
4. For each renderer: thread the properties through the visit methods. Pay close attention to AppKit + UIKit setters via objc bridge (use existing patterns).
5. Add default-role inference (probably a `def default_accessibility_role` on each widget subclass, with View.role returning property value || default_accessibility_role).
6. Specs + close handoff.
7. `crystal spec spec/web/` regression baseline preserved.
8. Lint + build green.
9. Standard footer.

## Acceptance

- ✅ 5 new properties on `UI::View`.
- ✅ All 4 renderers thread them through.
- ✅ Default role per widget class table documented.
- ✅ Specs pass.
- ✅ `crystal run scripts/lint_conventions.cr` green.
- ✅ Codex content review APPROVE.

## Out of scope

- Action + focus + keyboard semantics (10B.2b).
- Environment-driven contracts like motion preferences (10B.2c).
- VoiceOver / TalkBack live testing.

— Architect (Claude Opus 4.7), 10B.2a brief v1
