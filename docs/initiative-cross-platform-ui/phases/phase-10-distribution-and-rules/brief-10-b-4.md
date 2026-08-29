# Phase 10B.4 — Missing widgets

**Branch:** `phase-10-b-4` from `phase-10` (tag `phase-10-batch-4-merged-2026-05-26`).
**Status:** v1.

## Context

The Phase 10-pre.1 audit identified widget gaps in the asset_pipeline catalog vs. its declared Tier 2 surface. 10B.4 ships the widgets identified as missing. Read `docs/initiative-cross-platform-ui/architecture/intent-routing-candidates.md` and the Phase 10-pre.1 close handoff for the canonical list.

## Deliverables

For each missing widget identified in the audit (typically 3-6 widgets):

1. **`UI::<WidgetName>`** in `src/ui/views/<widget_name>.cr`:
   - Subclass of `UI::View`.
   - Constructor + properties matching the cross-platform-mapping-matrix's canonical API.
   - `accept(visitor)` dispatch.
   - `declares_capabilities` if the widget participates in an intent.
   - `default_accessibility_role` override (per 10B.2a contract).
   - `default_focusable` override (per 10B.2b contract).

2. **Platform renderer dispatch** — `visit(view : UI::<WidgetName>)` in each of the 4 renderers:
   - Web: HTML emission with proper aria + role.
   - AppKit: NSView mapping via objc bridge.
   - UIKit: UIView mapping via objc bridge.
   - Android: Android View mapping via JNI (best-effort; document gaps).

3. **`PlatformVisitor`** abstract method added per widget.

4. **Spec** — `spec/web/ui/views/<widget_name>_spec.cr` per widget.

5. **Close handoff** — list of widgets shipped + per-platform implementation status + Codex verdict.

## Workflow

1. `git checkout -b phase-10-b-4 phase-10`.
2. Audit: read `intent-routing-candidates.md` + Phase 10-pre.1 handoff + tier-matrix.md. Compile the actual list of missing widgets.
3. Implement widget-by-widget. After each: full renderer dispatch + spec + lint.
4. Close handoff with per-widget status table.
5. Standard footer.

## Acceptance

- ✅ Each identified missing widget exists in `src/ui/views/`.
- ✅ All 4 renderers handle each widget (or document explicit gaps).
- ✅ Specs pass.
- ✅ Lint + build green.
- ✅ Codex content review APPROVE.

## Out of scope

- HIG validation captures.
- Public docs (10A.final).
- Class C features (10B.3.x).
- Remaining Class D implementations (10B.5).

— Architect (Claude Opus 4.7), 10B.4 brief v1
