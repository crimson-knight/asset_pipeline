# Merge-readiness gate (cross-platform UI initiative)

**Status:** Authoritative gate for merging `feature/utility-first-css-asset-pipeline` into `main`.

**Strategic path (owner-confirmed 2026-05-28):** Path A — one merge to main when the full revised gate is met across all Tier 1+2 widgets. No partial ships.

**Revision history:**
- v1 (2026-05-28) — initial draft.
- v2 (2026-05-28) — revised per Codex catalog-coverage review (`handoff/2026-05-28-codex-catalog-coverage-review.md`) to address 5 BLOCKERs + material CONCERNs.

## The bar

> When someone using `asset_pipeline` writes a `UI::View`, it must just work and compile a good-enough interface with a minimum expected experience.
>
> — owner directive, 2026-05-28

This document operationalizes that bar as a mechanically-checkable contract. Every Tier 1 and Tier 2 widget in [tier-matrix.md](tier-matrix.md), and every Class A/B/C/D intent in [intent-catalog.md](architecture/intent-catalog.md), must satisfy this gate before the initiative branch can merge.

## Two scoreboards, one manifest

Codex correctly identified that the widget catalog (`tier-matrix.md`) and the intent catalog (`intent-catalog.md`) are different vocabularies and cannot share a single scoreboard. v2 splits them:

- **Widget coverage scoreboard** — one row per Tier 1 + Tier 2 widget. Tracks demo coverage, usage doc, interaction contract, override path.
- **Intent coverage scoreboard** — one row per Class A/B/C/D intent. Tracks framework implementation, modifier mapping, accessibility honoring.

The two scoreboards join via a required `widget_intents` mapping on every widget row. Both scoreboards are materialized from one source of truth:

### The catalog-coverage manifest

`docs/initiative-cross-platform-ui/catalog-coverage.yml` — machine-readable, lint-validated, source-hash-checked.

**Schema (v1):**

```yaml
schema_version: 1
generated_at: <ISO 8601 timestamp from last lint pass>
widgets:
  - name: ConfirmationDialog
    tier: 2
    widget_class: modal-presentation
    canonical_example:
      file: samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr
      line: 318
      deep_link: voyager://todos?action_sheet=share&todo=1
      capture_scenario: spec/native_ios/ui_interaction/scenarios/confirmation_dialog_share.md
      source_hash: <sha256 of the example file at last evidence refresh>
    usage_doc:
      path: .claude/skills/apple-platform-guide/usage/confirmation-dialog.md
      last_source_hash: <sha256 of usage doc at last evidence refresh>
    evidence:
      screenshot_ios_light: docs/.../confirmation-dialog-ios-light.png
      screenshot_ios_dark:  docs/.../confirmation-dialog-ios-dark.png
      screenshot_macos_light: docs/.../confirmation-dialog-macos-light.png
      screenshot_macos_dark:  docs/.../confirmation-dialog-macos-dark.png
      screenshot_source_hashes: { ... }
    override_path_status: public-knobs
    demo_status: documented-with-default-experience
    blocking_p1s: []
    widget_intents: [:confirm_destructive_action, :present_action_sheet]
intents:
  - identifier: :confirm_destructive_action
    class: A
    primary_apple_name: confirmationDialog
    owning_widgets: [ConfirmationDialog, Alert]
    coverage_status: covered-by-canonical-example
```

A new script `scripts/validate_catalog_coverage.cr` validates the manifest against `tier-matrix.md` (every Tier 1+2 widget present), against `intent-catalog.md` (every Class A/B/C/D intent present), and against the filesystem (every cited path resolves; every source hash matches current file content). Lint failure blocks merge.

The catalog manifest is the single source of truth for both scoreboards. Pseudo-fields embedded in prose markdown (the prior approach) are explicitly rejected per Codex BLOCKER 5.

## Widget class taxonomy

Every widget belongs to exactly one class. The class determines its evidence requirements (Codex CONCERN 6):

| Class | Examples | Evidence required |
|---|---|---|
| **static-primitive** | Spacer, Divider, Circle, Rectangle, Capsule, RoundedRectangle, PathView | Layout snapshot in light + dark on iOS + macOS. No interaction contract (no behavior to exercise). |
| **container-layout** | VStack, HStack, ZStack, Grid, ColumnView, ScrollView, Panel, Surface, Card | Composition snapshot containing ≥3 heterogeneous children. Light + dark, iOS + macOS. |
| **form-control** | TextField, SecureField, TextArea, Toggle, Checkbox, RadioGroup, Picker, ComboBox, Slider, Stepper, ColorPicker, DatePicker, TimePicker, TokenField, SearchField, SegmentedControl | Default + interacted + disabled + error (where applicable) states. Keyboard / VoiceOver path. Dynamic type at AX1. Reduced motion respected. Light + dark, iOS + macOS. |
| **button-cluster** | Button, IconButton, LinkButton, ToggleButton, MenuButton | Default + pressed + disabled + destructive-role states. Keyboard / VoiceOver. Light + dark. |
| **modal-presentation** | Sheet, Popover, Alert, ConfirmationDialog, FullScreenCover, Inspector | C1–C5 interaction contracts from [presentation-lifecycle-contract.md](architecture/presentation-lifecycle-contract.md) MUST pass. Present + dismissed states. Light + dark. |
| **navigation** | NavigationStack, NavigationSplitView, NavigationLink, TabView, Toolbar, ToolbarItemGroup, ToolbarSpacer | Route transition spec. Accessibility navigation. Light + dark. |
| **list-presentation** | ListView, OutlineView, DisclosureGroup, Label, RichText, TextEditor, Snackbar, Tooltip | Empty + populated + scrolled states. Swipe actions where applicable. Light + dark. |
| **media** | Image, AsyncImage, ImageWell, VideoPlayer, Canvas, MapView, PageControl, WebViewComponent | Default + loading + error (where applicable). Light + dark. |
| **data-viz** | ChartView, ActivityRing, ActivityRings, ProgressView, Gauge, RatingIndicator | Realistic data + empty + extreme data. Light + dark. |
| **system-bridge** | ActivityView, GlassBackground | Invocation succeeds. Cancel path honored. |

The catalog manifest's `widget_class` field MUST match this taxonomy. Lint enforces.

## Default-experience checklist

Every widget — regardless of class — must satisfy this checklist (Codex CONCERN 7):

- [ ] Default state renders without configuration beyond required args
- [ ] Light + dark appearance both pass design-critic
- [ ] iOS + macOS both render (Android may be stub-marked per Tier 3 rules below)
- [ ] Disabled state (if applicable to class)
- [ ] Error / loading state (if applicable to class)
- [ ] Keyboard navigation path on macOS; VoiceOver path on iOS
- [ ] Dynamic Type at AX1 (largest accessibility size) does not clip primary content
- [ ] Reduced motion respected
- [ ] Appears in at least one real workflow use (not just an isolated demo screen)

The checklist is enforced per widget by the evidence packet recorded in the manifest.

## Per-widget gate

For every Tier 1 + Tier 2 widget in the manifest:

1. **Usage doc shipped** — `.claude/skills/apple-platform-guide/usage/<widget>.md` exists with all six sections per the [widget-demonstration-criteria](rubric/widget-demonstration-criteria.md) rubric. CI validates existence, required headings (`## Default experience`, `## Crystal API`, `## Behavior contract`, `## Customization knobs`, `## Override path`, `## Evidence`), and that the cited `canonical_example` line is reachable from the file at that path (Codex BLOCKER 4).

2. **Canonical example with deep link** — recorded in the manifest's `canonical_example`. The example MUST be reachable via deep link or capture scenario from app launch with max tap count recorded (Codex CONCERN 8). "Icon-launchable" alone is not sufficient evidence the canonical screen is reachable.

3. **Demo app is icon-launchable on iOS simulator** — the demo app builds, installs, appears on the iPhone simulator home screen, and tapping its icon launches it without crash. This is the iOS gate; web fallback routes are gated separately (cross-cutting gate B below) (Codex CONCERN 8).

4. **Interaction contract spec passes** — applies to widget classes where the taxonomy requires it (modal-presentation, form-control, button-cluster, navigation, list-presentation). The spec lives under `spec/native_ios/ui_interaction/` and is exercised by the harness defined in [interaction-contracts-harness.md](architecture/interaction-contracts-harness.md). The harness MUST be executable, not design-only, before this item can pass (Codex BLOCKER 2).

5. **Override path documented with hard restrictions** — `override_path_status` is one of `public-knobs` or `facade-extension-required`. The backlog-item escape (`no-override-yet-tracked-in-backlog`) is permitted ONLY for non-default, non-critical customization. If the default experience depends on a value, the public knob or facade extension MUST exist before merge (Codex CONCERN 10).

6. **Catalog manifest entry valid** — the widget's manifest row passes `scripts/validate_catalog_coverage.cr` including source-hash freshness check. Source hashes are computed against widget source file, renderer files referenced, usage doc, and each screenshot artifact. Drift in any source hash without refreshed evidence fails the lint (Codex CONCERN 11).

## Per-widget gate (Tier 3)

Tier 3 widgets (`*WithWebFallback` family — gated by `{% if flag?(...) %}`) satisfy the gate via:

- **The native variant** ships items 1, 5, 6 above and gets an interaction-contract spec on the supported platform (the native target).
- **The `*WithWebFallback` companion** ships items 1, 2, 3, 4 above on the web target. Its fallback route is recorded in the web fallback route manifest (cross-cutting gate B below), NOT the iOS app-icon ladder.

## Cross-cutting gates

### A. iOS simulator app-icon ladder (native demos only)

The iPhone simulator's home screen at merge time has an icon for every native demo app. Tapping the icon launches the app to its home screen without crash. Each canonical example inside the app is reachable via a deep link with `max_tap_count ≤ 4` from the app's home screen, recorded in the manifest. Codex CONCERN 8 + 9 enforced.

The demo app ladder is proposed in Codex's review (Voyager → Notes → Mailbox → Health-log → Photos → Freeform-board) and frozen in `docs/initiative-cross-platform-ui/demo-app-ladder.md` (created as the first Phase 12 deliverable).

### B. Web fallback route manifest

Separate from gate A. Every `*WithWebFallback` companion has a route registered in `docs/initiative-cross-platform-ui/web-fallback-routes.yml`. Manifest validated by lint. This gate exists because mixing iOS app icons with web fallback routes was a v1 mistake (Codex CONCERN 8 explicit recommendation).

### C. Scoreboard starts red, not aspirational

The widget coverage scoreboard and intent coverage scoreboard MUST be initialized in a red state on first generation. Codex BLOCKER 3.

Already-filed P1 violations against demonstrated widgets MUST be on the scoreboard from initialization:

- **V1** — `UI::ConfirmationDialog` auto-closes on row tap (`presentation-lifecycle-contract.md` §V1)
- **V2** — Voyager todos header sort buttons crash (`presentation-lifecycle-contract.md` §V2)

No P1 backlog item against a demonstrated widget may be open at merge time. P2/P3 items are permitted but listed on the scoreboard.

### D. Lint clean

`crystal run scripts/lint_conventions.cr` returns `0 diagnostics`.
`crystal run scripts/validate_catalog_coverage.cr` returns `0 diagnostics`.

### E. Audit clean

Phase 6.5's audit harness against the committed baselines passes (`docs/initiative-cross-platform-ui/verification-runbook.md`).

### F. Build green on per-platform compiler matrix

`crystal build` (web), `crystal-alpha build -Dmacos`, `crystal-alpha build -Dios`, `swift build` (SwiftKit facade) all succeed.

### G. Interaction-contracts CI job green and executable

`make test-interaction-contracts` exists, runs on a `macos-latest` runner, exercises `spec/native_ios/ui_interaction/`, exits 0. The CI job MUST be executable — not design-only. Codex BLOCKER 2.

### H. Cross-widget feature stories pass

3–5 cross-widget feature stories per demo app exercise widget composition. The gate is per-widget AND per-composition. Codex CONCERN 12 — the gate cannot pass widget-by-widget while real consumer journeys still fail.

Per-app story examples (formalized in each demo app's brief):

- **Voyager** — create todo → edit todo → mark complete → delete with confirmation
- **Notes** — create folder → create note in folder → search across folders → edit with rich-text formatting → split-view detail
- **Mailbox** — read message → compose draft → add recipients via token field → send confirmation
- **Health-log** — view dashboard → tap activity ring → adjust goal via slider → log custom entry
- **Photos** — browse grid → tap photo → swipe through carousel → invoke share

Story specs live under `spec/ui_feature_stories/`. Story failure = merge-blocker.

### I. Design-critic verdict on every visual surface

`PASS` or `PASS_WITH_NOTES` from June (`.claude/agents/design-critic/agent.md`) with checkpoint commits per `CLAUDE.md` discipline. No surfaces in `NEEDS_WORK`.

### J. Codex final architect-antagonist review of the merge-readiness PR

A final `codex exec` review against the full merge-readiness PR. The architect addresses findings or documents why each is wrong before requesting owner sign-off.

## What this gate is NOT

- **Not a coverage gate on Tier 3 web fallbacks across all widgets.** Where a `*WithWebFallback` doesn't exist, the catalog records `web_fallback: n/a` for the widget and the widget is exempt from gate B — but still subject to gate A (if it's part of an iOS demo) and the per-widget gates 1, 4, 5, 6.
- **Not a gate on theme/brand-override coverage.** Brand overrides ship behind the design-tokens system and are exercised by the design-critic rubric, not this gate.
- **Not a perfection gate on Android.** Android renderer coverage is tracked separately; widgets with `coverage_today: android STUB` do not block the merge IF the stub state is documented in the usage doc's "Default experience" Android line.

## How to use this gate

- **Briefs** authored for any phase remaining in the initiative MUST cite this doc in their acceptance section and identify which gate items they advance.
- **The architect** maintains the catalog-coverage manifest and ensures lint passes after every phase. The scoreboard is generated from the manifest, not authored separately (correcting Codex NIT 13).
- **The owner** is the only person who can declare the gate met. The architect proposes; the owner disposes.

## Cross-references

- [widget-demonstration-criteria.md](rubric/widget-demonstration-criteria.md) — the per-widget rubric this gate composes
- [intent-catalog.md](architecture/intent-catalog.md) — the intent vocabulary the intent scoreboard tracks
- [tier-matrix.md](tier-matrix.md) — the Tier 1 / 2 / 3 classification this gate keys off
- [presentation-lifecycle-contract.md](architecture/presentation-lifecycle-contract.md) — the formal invariant for modal-presentation widgets
- [interaction-contracts-harness.md](architecture/interaction-contracts-harness.md) — the harness that exercises per-widget gate item 4 and cross-cutting gate G
- [handoff/2026-05-28-codex-catalog-coverage-review.md](handoff/2026-05-28-codex-catalog-coverage-review.md) — the antagonist review that drove this v2 revision
- `docs/initiative-cross-platform-ui/demo-app-ladder.md` — created as first Phase 12 deliverable; sequences the demo apps Codex proposed
- `docs/initiative-cross-platform-ui/catalog-coverage.yml` — created as second Phase 12 deliverable; the manifest both scoreboards materialize from
- `scripts/validate_catalog_coverage.cr` — created with the manifest; lint enforcer

— Architect (Claude Opus 4.7), merge-readiness gate v2, 2026-05-28
