# Phase 11 — iOS Home-Screen Widgets (WidgetKit)

**Status:** Draft brief, queued. Begins after Phase 10D-polish closes.
**Owner directive (this session):** "I'd like you to draft a separate phase brief so that we can do that after we're done with the current catalog demonstration."

## What this phase ships

A `UI::HomeScreenWidget` widget primitive in asset_pipeline, plus the Swift / Xcode plumbing to expose it as a real iOS home-screen widget through Apple's WidgetKit framework. The Voyager sample app gets at least one widget of each size class (small, medium, large) demonstrating that the cross-platform Crystal source can drive native home-screen surfaces.

## Why this is its own phase, not part of 10D

Adding iOS home-screen widgets is materially heavier than adding an in-app widget:

1. **New Xcode target.** Widgets ship as a separate "Widget Extension" target inside the host app's `.xcodeproj`. xcodegen needs the new target spec.
2. **App Group entitlement.** The main app and widget extension share data via App Groups (`group.com.assetpipeline.voyager.shared`). Both targets need the entitlement, both `.app` and the widget extension binary need code-signing aware of it.
3. **Timeline provider.** WidgetKit's update model is fundamentally different from in-app rendering — the widget runs in a separate process, on a schedule (`TimelineProvider`), with a budget. Crystal can't run inside this extension process directly (no Crystal runtime in WidgetKit's restricted environment), so the bridge model is: Crystal in the main app writes JSON snapshots to the App Group container; Swift in the widget extension reads those snapshots and renders SwiftUI views directly.
4. **SwiftUI-only renderer.** WidgetKit only accepts SwiftUI views — no UIKit, no UIHostingController. So `UI::HomeScreenWidget`'s renderer path is pure Swift, driven by the Crystal-produced JSON snapshot.
5. **Size classes.** `.systemSmall`, `.systemMedium`, `.systemLarge`, `.systemExtraLarge` (iPad only). Each has different layout constraints and content budgets.
6. **iOS 17+ Interactive Widgets.** Buttons and toggles in widgets work via App Intents (the real Apple framework — separate from our renamed `UI::SystemAction`). This means we may want a small App Intents bridge in the Swift side that maps widget button taps back to the host app's launch URL + action.

## Architecture sketch (subject to revision during a real preflight)

### Crystal side

- New widget: `UI::HomeScreenWidget`. Properties: `kind : Symbol` (e.g. `:upcoming_todos`), `family : Symbol` (`:small` | `:medium` | `:large`), `content : UI::View`. The `content` view tree is a SUBSET of the catalog — only widgets that have a SwiftUI-only equivalent (Label, VStack, HStack, Image, etc., not stateful widgets like TextField).
- New sample namespace: `Voyager::Widgets`. Each kind has a `build_snapshot(state) : Hash` method that produces the JSON snapshot the Swift widget reads.
- A snapshot publisher: when state mutates, the host app writes the latest snapshot to the App Group container. WidgetKit's `WidgetCenter.shared.reloadAllTimelines()` is called via the SwiftKit bridge.

### Swift side

- New Xcode target: `VoyagerWidgets.appex`.
- A SwiftUI `WidgetBundle` declaring one `Widget` per kind.
- Each `Widget` has a `TimelineProvider` that reads the latest snapshot from the App Group container.
- The view body is a SwiftUI view that interprets the snapshot JSON (a small JSON-to-SwiftUI mini-renderer, or simpler: hand-coded SwiftUI for each kind, with the snapshot providing the data).

### Build chain

- xcodegen spec gets a new target.
- `build_crystal_lib.sh` may need to produce a second library variant if the widget extension links a subset of Crystal code, OR we go pure-Swift in the widget process (read JSON, render SwiftUI, no Crystal runtime in the extension).
- App Group entitlement file + signing settings.

## Deliverables (draft)

### D1 — Crystal-side `UI::HomeScreenWidget` + snapshot mechanism

- New `src/ui/views/home_screen_widget.cr` with size-class enum.
- A `UI::HomeScreenWidget::SnapshotWriter` class that serializes a snapshot to JSON and writes it to a configurable path (the App Group container path on iOS, a temp dir elsewhere).
- Reactive integration: when host app state changes, the screen layer calls `snapshot.publish` and the writer fires.

### D2 — Voyager widget snapshots

- `samples/initiative-cross-platform-ui-voyager/widgets/upcoming_todos.cr` — produces JSON for the next 3 todos by deadline.
- `samples/initiative-cross-platform-ui-voyager/widgets/todo_count.cr` — produces JSON for the open todo count.
- (Optionally more — recently archived, today's focus, etc.)
- Each registered in `Voyager.app` so the host app emits the snapshot on relevant state mutations.

### D3 — Swift widget extension target

- New Xcode target `VoyagerWidgets` in `project.yml`.
- `Widgets/VoyagerWidgetBundle.swift` declaring the `@main` bundle.
- Per-kind widget definitions reading from the App Group + rendering SwiftUI.
- Code-signing + entitlements wired so the target builds + runs on simulator.

### D4 — App Group plumbing

- `Voyager-Bridging-Header.h` or equivalent shared header.
- Both `VoyagerDemo` and `VoyagerWidgets` targets in xcodegen have App Group entitlements.
- A shared path constant for the snapshot file location.

### D5 — Interactive widget action (optional, iOS 17+)

- A "Mark Done" button inside the upcoming-todos widget that, when tapped, opens the host app with a deep link `voyager://mark-done?id=N`.
- The host app's `IncomingDeepLink` action (already wired in Phase 10) handles the link + dispatches `:mark_done`.
- App Intent for the button → URL launch.

### D6 — Build + install + screenshot

- iOS simulator: add the widget to the home screen via long-press + edit mode.
- Screenshot each size class showing the Voyager widget.
- Hand-test guide for adding the widget, testing the deep link, verifying snapshot refresh.

### D7 — Documentation (per widget-demonstration-criteria rubric)

Per `docs/initiative-cross-platform-ui/rubric/widget-demonstration-criteria.md`, this phase MUST ship:

1. **Per-widget usage doc** at `.claude/skills/apple-platform-guide/usage/home-screen-widget.md` with all six sections (default experience per size class, Crystal API + Voyager invocation, behavior contract including the snapshot-publish model, customization knobs, override path, evidence).

2. **`component-api` skill entry** for `UI::HomeScreenWidget` mirroring the docs of other Tier 2 widgets.

3. **Catalog status update** in `docs/initiative-cross-platform-ui/architecture/intent-catalog.md` (and `tier-matrix.md` where applicable):
   - `demo_status: documented-with-default-experience`
   - `usage_doc`, `canonical_example` (the Voyager widget source path), `evidence` (screenshot path), `override_path_status`.

4. **Architecture doc** at `docs/initiative-cross-platform-ui/architecture/home-screen-widgets.md` covering:
   - The WidgetKit snapshot-publish model (Crystal writes JSON to App Group container, Swift extension reads).
   - Why Crystal can't run inside the extension process.
   - Supported size families (`small`/`medium`/`large`/`extraLarge` — iPad only).
   - Timeline refresh policy.
   - Deep-link / App Intents bridge model (for interactive iOS 17+ widgets).
   - Override / customization limits.
   - Backlog items for lock-screen widgets, Live Activities, macOS Desktop widgets.

## Effort estimate (very rough — actual preflight required)

- D1 (Crystal snapshot mechanism): 1-2 hours
- D2 (Voyager widget kinds): 1 hour
- D3 (Swift widget extension target + xcodegen): 2-3 hours (most likely to surprise — Xcode target wiring is finicky)
- D4 (App Groups): 1 hour
- D5 (Interactive widget, optional): 2 hours
- D6 (Build + screenshots): 1 hour
- D7 (Docs): 0.5 hour

**Total: ~8-10 hours.** Could split into two dispatches: substrate (D1-D4) and one widget kind, then a second pass for D5 + more widget kinds.

## Open questions to resolve before dispatching

1. **Snapshot format:** rigid JSON schema per widget kind (one schema per kind), OR a structural SwiftUI-tree JSON that the Swift side interprets generically? Latter is more flexible but more complex. Owner preference TBD.
2. **Widget refresh policy:** "atEnd" (refresh when timeline expires), "afterDate" (specific date), or "never" (manual reload only via `WidgetCenter.shared.reloadAllTimelines()` from the host app)? For todos, `never` + explicit reload on state mutation is probably right.
3. **macOS Sonoma+ also supports home-screen-like widgets** through Notification Center / Desktop. Do we want macOS parity in this phase, or iOS-only first?
4. **Android home-screen widgets** (App Widgets) are a real but very different API. Defer until iOS lands, possibly indefinitely.

## Out of scope

- Lock-screen widgets (a separate `accessoryCircular` / `accessoryRectangular` / `accessoryInline` family — could land in a follow-up phase).
- StandBy mode widgets.
- Always-on display variants.
- Live Activities / Dynamic Island (these are their own framework, not WidgetKit).

— Architect (Claude Opus 4.7), Phase 11 draft brief
