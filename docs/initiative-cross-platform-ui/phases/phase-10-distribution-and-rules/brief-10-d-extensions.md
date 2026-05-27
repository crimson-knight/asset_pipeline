# Phase 10D-extensions — Charts, maps, search, preferences, glass material in todos

**Branch:** `phase-10-d-extensions` from `phase-10-d-polish` (will cut after polish closes).
**Status:** v1. Owner-driven scope expansion after 10D-polish brief was reviewed.
**Predecessor:** 10D-polish MUST close before this dispatches.

## Owner alignment (verbatim, this session)

> "We could do graphs of the amount of to-dos that have been done in the last month. We can seed it with some historical data."

> "I love the activity rings. It would be cool if we could show like progress towards a goal and have three different rings."

> "Could we do a map view and have it be like we have a to-do and it has a location and that map view is a pin of the address. We can do a task to-do to walk the dog at 6 a.m."

> "I think we should do a preferences screen. We could do things in there that are related to like how you would sort to-dos or maybe prioritize them. Maybe you could weight things with the slider."

> "I like the search field. You could use that too for filtering through the to-dos, including the ones that are done."

> "The glass background. ... It should appear in some of the things that we exercise, right? Certain windows or widgets as they pop up should create that glass background."

## Why this is its own brief

10D-polish is already substantial (4 ListView defaults + 5 catalog widget integrations). Adding 6 more surfaces to that single dispatch risks the same stall pattern that happened twice already. Splitting lets each pass be hand-testable independently and gives the owner a checkpoint between layers.

## Deliverables

### Deliverable 1 — Search field on todos list

`UI::SearchField` at the top of the todos screen (above the count cards, below the title).

- Real-time filter: typing into the field narrows the visible list to titles containing the substring (case-insensitive).
- Filter applies even to completed todos (so search is a tool for "find that thing I checked off two weeks ago").
- Empty search = full list (current behavior).
- The hide-completed toggle still applies on top — search is layered on top of that filter.

Wire via `Voyager.state.search_query : String = ""` and update `visible_todos` to apply the filter.

### Deliverable 2 — Insights screen (charts + activity rings)

New screen `Voyager::InsightsScreen` reachable from the todos screen header (a new chart-icon button next to Print/Settings).

Two visible sections:

**Section A — Activity rings (top)**: 3 `UI::ActivityRings` showing progress toward 3 goals (configurable in Preferences in Deliverable 4):
- Today (e.g. complete 3 todos today → fill ring as todos get marked done today)
- This Week (e.g. 15 todos this week)
- This Month (e.g. 60 todos this month)

**Section B — Bar chart (below)**: `UI::ChartView` showing the number of todos completed per day for the last 30 days. **Seeded with mock data** (a `Voyager::State::SeedHistory` module that generates deterministic mock completion counts so the chart isn't empty on first launch).

Add `Voyager.state.completion_history : Hash(Date, Int32)` populated from the seed module on first launch.

Don't try to be analytically accurate — this is a widget demonstration, not a real metrics app.

### Deliverable 3 — Map + location on todos

**Model change**: Add `location : String?` (a free-text address like "Livingston Park, Manchester, NH") to Todo. Optional. Most todos won't have one.

**Editor change**: Editor sheet gains a "Location" `UI::TextField` below the deadline. Below that, a `UI::MapView` that:
- Geocodes the entered address (best-effort, with a documented fallback if geocoding isn't reachable from the simulator) and centers on the result with a single pin.
- Empty location → no MapView visible (or a small "Add location" affordance).

**Row indicator**: If a todo has a location, render a small `mappin.circle` SF Symbol next to the title (between checkbox-region and title — but per Mail-app wireframe there's no checkbox region, so place inline before the title or as a leading inset icon).

**Geocoding**: iOS's `CLGeocoder` works in the simulator. SwiftKit gains a `geocodeAddress(_ address: String)` helper. The Crystal side calls it through a new `UI::MapView` property `address : String?` + a SwiftUI wrapper that does the geocoding.

### Deliverable 4 — Preferences screen overhaul

Expand the existing `Voyager::SettingsScreen` (currently just the hide-completed toggle + Phase 10 Developer Tools link) into a richer preferences surface that exercises selection widgets:

- `UI::Form` (iOS Settings.app-style grouped sections) as the container.
- **Section "Sort"**: `UI::Picker` with options (Newest, Oldest, Alphabetical, Deadline ascending, Deadline descending, Weight).
- **Section "Default View"**: `UI::RadioGroup` with options (All, Open only, Completed only).
- **Section "Weighting"**: `UI::Slider` (0-10) labeled "How aggressively does deadline affect sort?" — affects the Deadline sort algorithm.
- **Section "Goals"** (NEW, for Insights): three `UI::Stepper` fields (Daily target, Weekly target, Monthly target). These feed Deliverable 2's activity rings.
- Existing hide-completed toggle stays.
- Phase 10 Developer Tools link stays (under a "Developer" section at the bottom).

Plumb each new setting into `Voyager.state` so it persists across renders (in-memory, not disk — explicit non-persistence per the existing pattern).

### Deliverable 5 — Glass background on appropriate chrome

Add `UI::GlassBackground` material treatment to:
- The `UI::Sheet` modal (editor sheet from 10D-polish B3) — background uses the `regular` SwiftUI Material so the host content shows through.
- The `UI::Popover` (overflow menu from 10D-polish B5) — `regularMaterial`.
- `UI::ActionSheet` — already uses system-default Material via SwiftUI, may not need explicit work.
- `UI::Alert` — system-default Material, leave alone.

For each surface that gets glass:
- Verify the iOS render shows the blur/translucent effect.
- Verify completed-row text + chart axis labels remain readable through the glass (contrast check).
- Document any cases where glass doesn't work or feels wrong.

This is a SwiftKit facade adjustment, not a Crystal-side property change — the host views already exist; we're just configuring their background material.

### Deliverable 6 — Build + screenshots + hand-test guide update

Per established pattern. New screenshots:

- `01_search_filter.png` — todos screen with search field active and list filtered.
- `02_insights_rings.png` — Insights screen with activity rings.
- `03_insights_chart.png` — Insights screen with bar chart (or combine with `02`).
- `04_editor_with_map.png` — editor sheet with location field + MapView pin.
- `05_row_with_pin.png` — todos row showing the pin indicator for a located todo.
- `06_preferences_form.png` — full preferences screen with all new controls.
- `07_glass_sheet.png` — editor sheet with visible glass material effect.

Update hand-test guide with new sections.

## Hard commit discipline

Same as 10D-polish + 10D-final. Standard footer: `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`.

## Acceptance gate

- ✅ Search field filters across all todos including completed.
- ✅ Insights screen renders activity rings + bar chart with mock history.
- ✅ Todos can carry an optional location; editor exposes MapView with pin; rows with location show pin icon.
- ✅ Preferences screen uses Form + Picker + RadioGroup + Slider + Stepper + Toggle.
- ✅ Sheet + Popover use glass material on iOS.
- ✅ All new screens reachable + rendering without crash.
- ✅ Lint + build green.
- ✅ Screenshots committed.
- ✅ Hand-test guide updated.

## Out of scope

- Persisting state to disk (still in-memory only).
- Real geocoding service (best-effort CLGeocoder; document if it doesn't work).
- iOS home-screen widgets (Phase 11).
- Media, drawing, messaging demos (separate phases).
- macOS / web / Android parity.

— Architect (Claude Opus 4.7), 10D-extensions brief v1
