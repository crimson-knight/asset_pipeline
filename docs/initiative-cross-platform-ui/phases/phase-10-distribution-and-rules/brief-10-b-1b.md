# Phase 10B.1b — :swipe_actions capability honesty audit

**Branch:** `phase-10-b-1b` from `phase-10` (tag `phase-10-batch-2-merged-2026-05-26`).
**Status:** v1. Predecessor: 10B.1a closed.

## Context

`UI::SwipeActionRow` and `UI::InlineActionRow` both declare `:swipe_actions` capabilities. The current declaration on each:

```crystal
declares_capabilities :swipe_actions, {
  supports_edge_trailing:    true,
  supports_role_default:     true,
  supports_role_destructive: :partial,
}
```

`:partial` means "supports some platforms, not all" (the brief left this notion fuzzy). 10B.1b makes the capabilities table honest:

1. Audit each `(widget × platform)` pair for the actual support level of each capability.
2. Replace `:partial` with platform-keyed map `{ios: true, macos: false, ...}` where applicable, OR split into multiple capability keys (e.g., `supports_role_destructive_ios`, `supports_role_destructive_web`, ...).
3. Document the audit results in `docs/initiative-cross-platform-ui/architecture/swipe-actions-capability-audit.md`.
4. Update `UI::Intent::Registry` capability validation to handle the new shape.
5. Add specs proving the audit (overrides fail when claiming unsupported capabilities for the active platform).

## Deliverables

1. **Audit doc** — per-widget × per-platform support matrix for `:swipe_actions` capabilities. Cite renderer code for each cell.
2. **Capability shape change** in `declares_capabilities` calls — either platform-keyed maps OR per-platform keys.
3. **Registry validation update** — capabilities checked at registration are platform-aware.
4. **Specs** — `spec/web/ui/swipe_actions_capability_audit_spec.cr` proving:
   - SwipeActionRow on iOS supports destructive; on macOS does not.
   - InlineActionRow on web_wide supports destructive (renders as button with .danger styling); etc.
   - Registry rejects an override that claims a capability the platform doesn't support.

## Workflow

1. `git checkout -b phase-10-b-1b phase-10`.
2. Read `src/ui/views/swipe_action_row.cr` + `inline_action_row.cr` + all 4 renderers' visit methods.
3. Build audit table. Per cell: read renderer code; classify as `full | none | partial-with-notes`.
4. Decide capability shape — platform-keyed map (recommended for readability) vs per-platform keys (explicit but verbose).
5. Update macro definition + both widget declarations + Registry validation.
6. Write specs.
7. Update close handoff with the audit + change summary.
8. Standard footer.

## Acceptance

- ✅ Audit doc shipped with per-cell rationale + renderer code citations.
- ✅ `declares_capabilities` shape supports platform-aware claims.
- ✅ Registry validates per-platform capability claims correctly.
- ✅ Specs prove honest matrix (and fail if a widget over-claims).
- ✅ `crystal spec spec/web/` regression count at baseline.
- ✅ `crystal run scripts/lint_conventions.cr` green.
- ✅ Codex content review APPROVE.

## Out of scope

- New widgets.
- Android Material3 swipe (10B.1c).
- Other intent capabilities (this is :swipe_actions only).

— Architect (Claude Opus 4.7), 10B.1b brief v1
