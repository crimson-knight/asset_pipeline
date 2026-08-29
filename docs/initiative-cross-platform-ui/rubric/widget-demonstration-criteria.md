# Widget demonstration criteria (rubric)

**Status:** Authoritative rubric inherited by every brief that demonstrates a widget in the Voyager sample (or any future sample app). Codex-driven this session; addresses the social-contract gap surfaced during 10D hand-test.

## The rule

> **Every widget demonstration MUST ship a consumer usage doc, API reference update, canonical example link, catalog status update, and override-path note. If a widget is internal or undemonstrable, the brief must say so explicitly and explain why.**

This rubric is non-negotiable. Briefs that demonstrate widgets without it have shipped a screenshot gallery, not a product contract. The next agent reading the catalog is the customer; their experience reading it is the deliverable.

## Per-widget usage doc template

Every demonstrated widget gets a doc at `.claude/skills/apple-platform-guide/usage/<widget_name>.md` containing **all six** sections below. Briefs MUST require this for each widget they demonstrate. No widget ships demonstrated without it.

```markdown
# UI::<WidgetName>

## Default experience
- iOS: <describe rendered chrome + interaction>
- iPadOS: <if different from iOS>
- macOS: <describe>
- web (wide / narrow): <describe or "deferred — see backlog item X">
- Android: <describe or "deferred — see backlog item X">

## Crystal API
\`\`\`crystal
# Minimal invocation
widget = UI::<WidgetName>.new(...)

# Realistic Voyager invocation
<paste a real invocation from Voyager source>
\`\`\`

## Behavior contract
- Callbacks: <list every Proc property + what fires it>
- Dismissal paths: <how does it close / cancel>
- Focus / keyboard: <how accessibility wiring works>
- Reduced motion: <how it responds to env.reduce_motion>
- Reactivity: <how state mutations re-render the widget>

## Customization knobs
- <every public property + what it controls>
- <every style enum or design-token hook>
- <every glass / material / color option>

## Override path
**If public knobs are insufficient:**
- <exact file:line where the default lives (renderer or facade)>
- <process to override: subclass / facade extension / backlog item to file>
- If no override exists today: state explicitly + name the backlog item that tracks adding one.

## Evidence
- Canonical example: `samples/initiative-cross-platform-ui-voyager/<exact_path>:<line>`
- Screenshot: `docs/initiative-cross-platform-ui/handoff/<phase>-screenshots/<exact_filename>.png`
- Spec coverage: `spec/web/ui/<exact_spec_path>` (if applicable)
```

## Catalog status update

When a widget is demonstrated, `docs/initiative-cross-platform-ui/architecture/intent-catalog.md` (and any sibling catalog like `tier-matrix.md`) MUST have its entry updated with these fields:

- `demo_status`: one of `not-demonstrated` | `demonstrated-in-Voyager` | `documented-with-default-experience` | `internal-only`
- `usage_doc`: relative path to `.claude/skills/apple-platform-guide/usage/<widget>.md` OR `n/a` if status is `internal-only`
- `canonical_example`: relative path to the Voyager source file + line range
- `evidence`: relative path to the screenshot
- `override_path_status`: one of `public-knobs` | `facade-extension-required` | `no-override-yet-tracked-in-backlog` | `n/a`

Status MUST be `documented-with-default-experience` (not just `demonstrated-in-Voyager`) by the time a phase closes. Hand-test passing without the usage doc shipped means the phase is incomplete.

## Voyager is the canonical demo

For every widget demonstrated, the Voyager source IS the canonical example invocation. Per-widget usage docs MUST cross-link to the exact Voyager file + line where the widget is used. If a widget is demonstrated in multiple places, the doc names the most idiomatic one as canonical and lists the others.

Briefs that add new widget demonstrations MUST identify which Voyager source file (or new file) carries the canonical example before the implementer starts work. This is part of every brief's preflight.

## Acceptance gate addition

Every brief that demonstrates widgets MUST include this acceptance bullet:

> ✅ Per-widget usage doc shipped at `.claude/skills/apple-platform-guide/usage/<widget>.md` with all six sections populated for each widget demonstrated. Catalog status flipped to `documented-with-default-experience` for each. Override path explicitly documented (public knobs OR facade-extension instructions OR backlog item) — no evasive language like "future consumer can override later".

## What "social contract" means here

The owner named this gap explicitly: when we demonstrate a widget, we're defining the **canonical default experience** that ships to every consumer of asset_pipeline. Future agents reading the catalog must be able to:

1. **Discover** the widget exists.
2. **Read** its API + default behavior.
3. **See** the canonical default visual / interaction (via the linked screenshot + Voyager source).
4. **Know** how to override or customize.

If any of those four is unmet, the social contract with the next agent is broken. The screenshot gallery is necessary but not sufficient.

— Architect (Claude Opus 4.7), widget-demonstration-criteria rubric v1
