# META

The prompt's premise is partly wrong: `tier-matrix.md` is a widget catalog, but `architecture/intent-catalog.md` is not. The intent catalog says it names interaction intents and modifier concepts, split across Classes A-D (`docs/initiative-cross-platform-ui/architecture/intent-catalog.md:5-14`), and its own totals are 92 schema entries / 67 top-level intent concepts (`docs/initiative-cross-platform-ui/architecture/intent-catalog.md:1560-1564`). A merge gate that says "every widget in `intent-catalog.md`" is not mechanically enforceable until there is an explicit widget-to-intent mapping layer. I proceed under the intended premise: Tier 1 + Tier 2 widgets are the rows in `tier-matrix.md`.

# Deliverable 1 - Critique Of The Merge-Readiness Gate

## FINDINGS

- **BLOCKER - The gate conflates widgets and intents.** The gate applies to "every widget in `intent-catalog.md` (and `tier-matrix.md`)" (`docs/initiative-cross-platform-ui/merge-readiness-gate.md:15`), but the intent catalog is a vocabulary of intents, system contracts, and modifier concepts, not just widgets (`docs/initiative-cross-platform-ui/architecture/intent-catalog.md:7-14`). This will get gamed by checking off widget rows while leaving modifier intents such as `:refreshable`, `:searchable`, `:interactive_dismiss_disabled`, `:draggable`, and `:animation` either unimplemented or undocumented. **Suggestion:** split the gate into two scoreboards: widget rows keyed to `tier-matrix.md`, and intent rows keyed to `intent-catalog.md`, joined by a required `widget_intents` mapping field.

- **BLOCKER - The interaction-contract harness is design-only, not executable.** The gate requires specs under `spec/ui_interaction/` and a green interaction-contracts CI job (`docs/initiative-cross-platform-ui/merge-readiness-gate.md:20,43`), while the harness doc describes a future Crystal spec runner under that path (`docs/initiative-cross-platform-ui/architecture/interaction-contracts-harness.md:9-18`) and a future `make test-interaction-contracts` / GitHub Actions job (`docs/initiative-cross-platform-ui/architecture/interaction-contracts-harness.md:122-140`). There is currently no `spec/ui_interaction/` tree in this checkout, and the harness doc itself says it needs a new `accessibility_identifier` property on `UI::View` (`docs/initiative-cross-platform-ui/architecture/interaction-contracts-harness.md:102-110`). **Suggestion:** split the gate into "harness design accepted" and "harness executable with at least one failing-then-passing spec"; only the latter can block merge-readiness.

- **BLOCKER - There are already known P1 violations against the gate.** The presentation lifecycle contract lists owner-reported P1 blockers: `UI::ConfirmationDialog` auto-closes on row tap and the todos header sort buttons crash (`docs/initiative-cross-platform-ui/architecture/presentation-lifecycle-contract.md:88-95`). The gate says no P1 backlog items can remain open against demonstrated widgets (`docs/initiative-cross-platform-ui/merge-readiness-gate.md:35`). **Suggestion:** the merge gate must start from a red scoreboard, not a clean aspirational checklist. Add those P1s to the scoreboard with reproduction status, owner, and blocking widget(s).

- **BLOCKER - The usage-doc requirement is currently all red.** The rubric requires every demonstrated widget to have `.claude/skills/apple-platform-guide/usage/<widget_name>.md` with six sections (`docs/initiative-cross-platform-ui/rubric/widget-demonstration-criteria.md:11-56`). In this checkout, `.claude/skills/apple-platform-guide/usage/` does not exist. **Suggestion:** create the directory and require a CI check that verifies existence, required headings, canonical-example path, and source-line anchors for every Tier 1 + Tier 2 widget row.

- **BLOCKER - `canonical_example` and catalog status fields do not exist in the current catalogs.** The gate requires each canonical example path to be recorded in the catalog and each status to be `documented-with-default-experience` (`docs/initiative-cross-platform-ui/merge-readiness-gate.md:18,22`), while the rubric says to add `demo_status`, `usage_doc`, `canonical_example`, `evidence`, and `override_path_status` fields (`docs/initiative-cross-platform-ui/rubric/widget-demonstration-criteria.md:58-68`). `tier-matrix.md` is still a plain markdown table with widget/source/facade/notes columns (`docs/initiative-cross-platform-ui/tier-matrix.md:30-48,56-116`). **Suggestion:** define a machine-readable manifest, for example `docs/initiative-cross-platform-ui/catalog-coverage.yml`, rather than adding pseudo-fields to prose markdown tables.

- **CONCERN - The per-widget gate is over-specified for passive primitives and under-specified for interactive widgets.** Requiring an interaction-contract spec for `Spacer`, `Divider`, `Circle`, and `Rectangle` is busywork unless the contract is layout/a11y snapshot based; requiring the same single item for `Sheet`, `Popover`, `FullScreenCover`, `ListView`, `TextField`, and `VideoPlayer` is too vague. The validation rubric already distinguishes presence, behavior, conformance, and regression checks (`docs/initiative-cross-platform-ui/rubric/validation_criteria.md:31-65`). **Suggestion:** classify widgets as static primitive, container/layout, form control, modal/presentation, navigation, media, data viz, and system bridge; require a different evidence packet per class.

- **CONCERN - "Good-enough interface" is still vibes unless the default-experience bar is enumerated.** The gate repeats the owner bar (`docs/initiative-cross-platform-ui/merge-readiness-gate.md:7-11`) but does not define default rendering, minimum state coverage, empty/loading/error states, platform affordances, or content realism. **Suggestion:** every widget row needs a default-experience checklist: default state, disabled/read-only if applicable, error/loading if applicable, keyboard/VoiceOver path, dynamic type, reduced motion, dark mode, and one real workflow use.

- **CONCERN - The home-screen ladder is realistic only for demo-app coverage, not for Tier 3 fallback logic.** Cross-cutting gate A says the iPhone simulator home screen has an icon for every demo app (`docs/initiative-cross-platform-ui/merge-readiness-gate.md:31-34`). The "not a coverage gate" section then says Tier 3 widgets can be exempt from the home-screen-ladder requirement on web (`docs/initiative-cross-platform-ui/merge-readiness-gate.md:49-53`). That mixes iPhone home-screen icons with web fallback routes. **Suggestion:** make two separate gates: iOS simulator app-icon ladder for native demo apps, and web fallback route manifest for `*WithWebFallback` companions.

- **CONCERN - "Icon-launchable" does not prove the canonical screen is reachable.** The gate says tapping the demo app icon launches it to the screen that contains the canonical example (`docs/initiative-cross-platform-ui/merge-readiness-gate.md:19`). If a demo app contains 12 canonical widgets across 5 screens, this sentence cannot be true for every widget. **Suggestion:** require each canonical example to have a deep link, capture scenario, or UITest path from app launch to the screen, with max tap count and route id recorded.

- **CONCERN - "Override path documented" is gameable.** The gate allows "public-knobs path OR facade-extension instructions OR a named backlog item" (`docs/initiative-cross-platform-ui/merge-readiness-gate.md:21`). A phase can pass by filing backlog tickets for every hard override. **Suggestion:** only allow backlog-item override status for non-default or non-critical customization. If the default experience depends on a value, the public knob or extension point must exist before merge.

- **CONCERN - Screenshot freshness is not measurable as written.** The gate says screenshot evidence must be current, "not older than the last source-of-truth change to the widget" (`docs/initiative-cross-platform-ui/merge-readiness-gate.md:22`). Humans will argue about source-of-truth changes. **Suggestion:** record source hashes for widget source, renderer files, usage doc, and screenshot artifact in the coverage manifest; CI can fail when a hash changes without refreshed evidence.

- **CONCERN - The final merge can pass while the real user journey still fails.** The gate is per-widget, but the owner's actual bar is "when someone builds a view with [the component system], it will just work." Widget demos can be isolated and still miss composition failures: nested forms inside sheets, toolbar actions mutating list state, modal rerenders, and navigation state restoration. The presentation lifecycle doc already shows this exact class of failure (`docs/initiative-cross-platform-ui/architecture/presentation-lifecycle-contract.md:21-27`). **Suggestion:** add 3-5 cross-widget feature stories as merge blockers: create/edit/delete in Voyager, compose/send draft in Mailbox, edit note with inspector, filter Health chart, share Photos item.

- **NIT - The scoreboard ownership text is inconsistent with this handoff.** The gate says the architect maintains `merge-readiness-scoreboard.md`, "created by Codex's catalog review as deliverable 1" (`docs/initiative-cross-platform-ui/merge-readiness-gate.md:55-59`), but this requested handoff's deliverable 1 is critique, not scoreboard creation. **Suggestion:** correct the gate doc to say this review proposes coverage scope and that a follow-up implementation creates the scoreboard.

# Deliverable 2 - Coverage Gap Analysis

Method: I counted only concrete `UI::<Widget>.new` call sites or route-registered `UI::Screen` examples under `samples/initiative-cross-platform-ui-voyager/`. I did not count comments, renderer internals, intent dispatches that do not instantiate the widget, or the older `samples/initiative-cross-platform-ui-demo/` directory. The requested usage-doc directory `.claude/skills/apple-platform-guide/usage/` is absent in this checkout, so every usage-doc cell is `NO`.

| widget name | tier | has-canonical-example? | has-usage-doc? | coverage gap |
|---|---:|---|---|---|
| Capsule | 1 | NO | NO | YES |
| Card | 1 | NO | NO | YES |
| Circle | 1 | NO | NO | YES |
| ColumnView | 1 | NO | NO | YES |
| Divider | 1 | NO | NO | YES |
| Grid | 1 | NO | NO | YES |
| HStack | 1 | YES - `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:61` | NO | NO |
| Image | 1 | NO | NO | YES |
| Label | 1 | YES - `samples/initiative-cross-platform-ui-voyager/screens/sign_in_screen.cr:36` | NO | NO |
| Panel | 1 | NO | NO | YES |
| PathView | 1 | NO | NO | YES |
| Rectangle | 1 | NO | NO | YES |
| RoundedRectangle | 1 | NO | NO | YES |
| Spacer | 1 | YES - `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:70` | NO | NO |
| Surface | 1 | NO | NO | YES |
| VStack | 1 | YES - `samples/initiative-cross-platform-ui-voyager/screens/sign_in_screen.cr:24` | NO | NO |
| ZStack | 1 | NO | NO | YES |
| ActivityIndicator | 2 | NO | NO | YES |
| ActivityRing | 2 | NO | NO | YES |
| ActivityRings | 2 | NO | NO | YES |
| ActivityView | 2 | NO | NO | YES |
| Alert | 2 | NO | NO | YES |
| AsyncImage | 2 | NO | NO | YES |
| Button | 2 | YES - `samples/initiative-cross-platform-ui-voyager/screens/sign_in_screen.cr:80` | NO | NO |
| Canvas | 2 | NO | NO | YES |
| ChartView | 2 | NO | NO | YES |
| Checkbox | 2 | YES - `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:206` | NO | NO |
| ColorPicker | 2 | NO | NO | YES |
| ComboBox | 2 | NO | NO | YES |
| ConfirmationDialog | 2 | NO | NO | YES |
| DatePicker | 2 | NO | NO | YES |
| DisclosureGroup | 2 | NO | NO | YES |
| Form | 2 | NO | NO | YES |
| FullScreenCover | 2 | YES - `samples/initiative-cross-platform-ui-voyager/screens/phase_10/new_widgets_screen.cr:114` | NO | NO |
| Gauge | 2 | NO | NO | YES |
| GlassBackground | 2 | NO | NO | YES |
| IconButton | 2 | NO | NO | YES |
| ImageWell | 2 | NO | NO | YES |
| Inspector | 2 | YES - `samples/initiative-cross-platform-ui-voyager/screens/phase_10/new_widgets_screen.cr:156` | NO | NO |
| LinkButton | 2 | NO | NO | YES |
| ListView | 2 | NO | NO | YES |
| MapView | 2 | NO | NO | YES |
| MenuButton | 2 | NO | NO | YES |
| NavigationLink | 2 | NO | NO | YES |
| NavigationSplitView | 2 | NO | NO | YES |
| NavigationStack | 2 | NO | NO | YES |
| OutlineView | 2 | NO | NO | YES |
| PageControl | 2 | NO | NO | YES |
| Picker | 2 | NO | NO | YES |
| Popover | 2 | NO | NO | YES |
| ProgressView | 2 | NO | NO | YES |
| RadioGroup | 2 | NO | NO | YES |
| RatingIndicator | 2 | NO | NO | YES |
| RichText | 2 | NO | NO | YES |
| ScrollView | 2 | NO | NO | YES |
| SearchField | 2 | NO | NO | YES |
| SecureField | 2 | YES - `samples/initiative-cross-platform-ui-voyager/screens/sign_in_screen.cr:71` | NO | NO |
| SegmentedControl | 2 | NO | NO | YES |
| Sheet | 2 | NO | NO | YES |
| Slider | 2 | NO | NO | YES |
| Snackbar | 2 | YES - `samples/initiative-cross-platform-ui-voyager/screens/phase_10/environment_reactivity_screen.cr:115` | NO | NO |
| Stepper | 2 | NO | NO | YES |
| TabView | 2 | NO | NO | YES |
| TextArea | 2 | NO | NO | YES |
| TextEditor | 2 | NO | NO | YES |
| TextField | 2 | YES - `samples/initiative-cross-platform-ui-voyager/screens/sign_in_screen.cr:58` | NO | NO |
| TimePicker | 2 | NO | NO | YES |
| Toggle | 2 | YES - `samples/initiative-cross-platform-ui-voyager/screens/settings_screen.cr:37` | NO | NO |
| ToggleButton | 2 | NO | NO | YES |
| TokenField | 2 | NO | NO | YES |
| Toolbar | 2 | NO | NO | YES |
| ToolbarItemGroup | 2 | YES - `samples/initiative-cross-platform-ui-voyager/screens/phase_10/new_widgets_screen.cr:54` | NO | NO |
| ToolbarSpacer | 2 | YES - `samples/initiative-cross-platform-ui-voyager/screens/phase_10/new_widgets_screen.cr:66` | NO | NO |
| Tooltip | 2 | NO | NO | YES |
| VideoPlayer | 2 | NO | NO | YES |
| WebViewComponent | 2 | NO | NO | YES |

# Deliverable 3 - Demo-App Ladder Proposal

Voyager should stay the first app and the canonical home for the existing todos idiom: sign-in, list-row checkbox completion, edit form, settings toggle, Phase 10 developer surfaces, `FullScreenCover`, `Inspector`, `ToolbarItemGroup`, `ToolbarSpacer`, and `Snackbar`. Its current route registry already includes the end-user screens plus Phase 10 exercisers (`samples/initiative-cross-platform-ui-voyager/app.cr:68-80,207-224`).

## Proposed Additional Demo Apps

### `initiative-cross-platform-ui-notes`

- **Elevator pitch:** A local-only notes app where the user browses folders, searches notes, edits rich text, and opens note details in a split layout.
- **Canonical home for:** `ListView`, `NavigationStack`, `NavigationSplitView`, `NavigationLink`, `OutlineView`, `DisclosureGroup`, `SearchField`, `TextEditor`, `RichText`, `ScrollView`, `MenuButton`, `Toolbar`.
- **Mirrors:** Apple Notes.
- **Screens:** Folders sidebar, note list, note editor, search results, formatting menu, note info/detail pane.
- **Estimated build effort:** L.
- **Reuse:** Reuse Voyager's `UI::App`, route registry, controller dispatch, local state, and capture-scenario machinery; net-new note/folder state and editor screens.

### `initiative-cross-platform-ui-mailbox`

- **Elevator pitch:** A local-only mail client where the user reads seeded messages, composes a draft, manages recipients, and confirms destructive actions.
- **Canonical home for:** `Form`, `TokenField`, `ComboBox`, `TextArea`, `Sheet`, `Popover`, `Alert`, `ConfirmationDialog`, `IconButton`, `ToggleButton`, `Tooltip`, `ActivityIndicator`, `WebViewComponent`.
- **Mirrors:** Apple Mail.
- **Screens:** Mailbox list, message detail with local HTML message rendering, compose sheet, recipient editor, message actions popover, delete confirmation dialog, local sync/loading state.
- **Estimated build effort:** L.
- **Reuse:** Reuse Voyager shell/state/dispatcher patterns; needs net-new compose state, local message fixtures, modal lifecycle probes, and HTML-message fixture for `WebViewComponent`.

### `initiative-cross-platform-ui-health-log`

- **Elevator pitch:** A local Health-style dashboard where the user reviews activity metrics, adjusts targets, and logs scheduled habits.
- **Canonical home for:** `ActivityRing`, `ActivityRings`, `ProgressView`, `Gauge`, `ChartView`, `SegmentedControl`, `Picker`, `DatePicker`, `TimePicker`, `Slider`, `Stepper`, `RadioGroup`, `TabView`.
- **Mirrors:** Apple Health and Fitness.
- **Screens:** Summary dashboard, activity rings detail, trends chart, log-entry form, goal adjustment, schedule picker, tabbed Browse/Summary/Favorites shell.
- **Estimated build effort:** L.
- **Reuse:** Reuse Voyager app shell and route dispatch; net-new metric fixtures, chart data model, and value-control interaction specs.

### `initiative-cross-platform-ui-photos`

- **Elevator pitch:** A local Photos-style gallery where the user browses bundled images/videos, views places, pages through memories, imports a local image placeholder, and shares an item.
- **Canonical home for:** `Image`, `AsyncImage`, `ImageWell`, `VideoPlayer`, `PageControl`, `MapView`, `ActivityView`, `LinkButton`, `RatingIndicator`.
- **Mirrors:** Apple Photos.
- **Screens:** Library grid, photo detail, memory carousel, places map, local media inspector, share surface, rating/favorite panel.
- **Estimated build effort:** M/L.
- **Reuse:** Reuse Voyager shell and local state; needs bundled media fixtures and a no-network async-image fixture path.

### `initiative-cross-platform-ui-freeform-board`

- **Elevator pitch:** A local Freeform-style board where the user arranges shapes, sketches paths, changes colors, and inspects a layered canvas.
- **Canonical home for:** `Capsule`, `Card`, `Circle`, `ColumnView`, `Divider`, `Grid`, `Panel`, `PathView`, `Rectangle`, `RoundedRectangle`, `Surface`, `ZStack`, `Canvas`, `ColorPicker`, `GlassBackground`.
- **Mirrors:** Apple Freeform.
- **Screens:** Board canvas, shape palette, color/material inspector, layers panel, grid/snap settings, presentation preview.
- **Estimated build effort:** XL.
- **Reuse:** Can reuse Voyager shell and route registration, but the board state, canvas/shape model, pointer interactions, and screenshot comparisons are net-new.

## Home-Screen Ladder

1. `initiative-cross-platform-ui-voyager` - first because it proves the broadest consumer story: create/edit/manage local data with real navigation, form input, settings, and the existing Phase 10 exercisers.
2. `initiative-cross-platform-ui-notes` - second because it proves the main app-structure primitives consumers will reach for after todos: lists, split navigation, search, outline, rich editor, toolbar/menu.
3. `initiative-cross-platform-ui-mailbox` - third because it stresses modal/transient surfaces and composition: sheet, popover, alert, confirmation dialog, token fields, HTML message rendering, and icon/tooltip actions.
4. `initiative-cross-platform-ui-health-log` - fourth because it concentrates value controls and data visualization: rings, gauges, charts, pickers, date/time, sliders, steppers, tabs.
5. `initiative-cross-platform-ui-photos` - fifth because it covers media, maps, paging, share, and local async/loading behavior without requiring remote services.
6. `initiative-cross-platform-ui-freeform-board` - sixth because it is visually broad and important, but it is also the highest-effort app and should not block proving the more common app-structure and form/control surfaces first.

This ladder is honest only if each icon opens the app and each app has a deterministic route/capture scenario to every canonical widget screen. Do not accept "the app icon exists" as coverage for any widget.
