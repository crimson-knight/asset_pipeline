# Demo app ladder

**Status:** Authoritative sequence for the demo apps that, taken together, prove every Tier 1 + Tier 2 widget in [tier-matrix.md](tier-matrix.md) meets the [merge-readiness gate](merge-readiness-gate.md).

**Source:** Formalized from Codex's catalog-coverage review (`handoff/2026-05-28-codex-catalog-coverage-review.md`).

**Strategic context:** Path A — every app on the ladder must be on the iPhone simulator home screen at merge time with its canonical screens reachable via deep link (max 4 taps from app launch).

## The 6 apps

### 1. `initiative-cross-platform-ui-voyager` — todos / consumer baseline

**Status:** Exists. Currently demonstrates ~17% of the catalog (13/76 widgets) per Codex's audit.

**Mirrors:** Apple Reminders / generic native iOS productivity app.

**Canonical home for:** Button, Checkbox, ConfirmationDialog (after V1 fix), DatePicker, FullScreenCover, HStack, Inspector, Label, SecureField, Sheet (after V1 fix), Snackbar, Spacer, TextField, Toggle, ToolbarItemGroup, ToolbarSpacer, VStack — plus the Phase 10 developer exerciser screens.

**Screens (existing):** Sign-in, todos list (Mail-app idiom), todo editor, settings, Phase 10 hub + exerciser screens (ax-metadata, class-c-dispatch, environment-reactivity, intent-resolver, new-widgets).

**Cross-widget feature stories (gate H):**
1. Create todo → edit todo → mark complete → delete with confirmation
2. Open editor sheet → adjust date picker → save without dismissing on interactive drag (interactive_dismiss_disabled honored)
3. Swipe-reveal action → archive → undo via snackbar

**Pending gate items to close:** V1 (ConfirmationDialog auto-close), V2 (header sort button crash), usage docs for all Voyager-demonstrated widgets, catalog manifest entries flipped to `documented-with-default-experience` once V1/V2 are fixed + evidence refreshed.

---

### 2. `initiative-cross-platform-ui-notes` — app-structure primitives

**Mirrors:** Apple Notes.

**Elevator pitch:** Local-only notes app where the user browses folders, searches notes, edits rich text, and opens note details in a split layout.

**Canonical home for:** ListView, NavigationStack, NavigationSplitView, NavigationLink, OutlineView, DisclosureGroup, SearchField, TextEditor, RichText, ScrollView, MenuButton, Toolbar.

**Screens:**
- Folders sidebar (split view detail)
- Note list (per folder)
- Note editor (rich text)
- Search results
- Formatting menu
- Note info / detail pane

**Cross-widget feature stories (gate H):**
1. Create folder → create note in folder → search across folders → edit with rich-text formatting → open in split-view detail
2. Outline expand/collapse via DisclosureGroup → drill into nested folder via NavigationLink → back via NavigationStack pop
3. Toolbar menu button → format dropdown → apply bold/italic → SearchField narrow result list

**Reuse plan:** Reuse Voyager's `UI::App`, route registry, `UI::Controller` dispatch, `UI::FormState`, local state machinery, capture-scenario scaffolding. Net-new: folder/note state model, editor screens.

**Estimated complexity:** L. Build effort dominated by NavigationSplitView correctness (sidebar + content + detail panes on iPad/macOS, single-column collapse on iPhone) and the rich-text editor.

---

### 3. `initiative-cross-platform-ui-mailbox` — modal + form composition

**Mirrors:** Apple Mail.

**Elevator pitch:** Local-only mail client where the user reads seeded messages, composes a draft, manages recipients, and confirms destructive actions.

**Canonical home for:** Form, TokenField, ComboBox, TextArea, Sheet, Popover, Alert, ConfirmationDialog, IconButton, ToggleButton, Tooltip, ActivityIndicator, WebViewComponent.

**Screens:**
- Mailbox list
- Message detail (with local HTML rendering via WebViewComponent)
- Compose sheet (presentation modal)
- Recipient editor (TokenField + ComboBox suggestions)
- Message actions popover (anchored to message header IconButton)
- Delete confirmation dialog
- Local sync / loading state (ActivityIndicator)

**Cross-widget feature stories (gate H):**
1. Read message → compose reply → add recipients via TokenField with ComboBox autocomplete → send (confirm)
2. Open message → tap overflow IconButton → popover anchored to button → archive
3. Delete message → Alert confirmation → list updates → undo via Snackbar

**Reuse plan:** Reuse Voyager shell, state, dispatcher patterns. Net-new: compose state, local message fixtures (seeded), modal lifecycle probes, HTML-message fixture for WebViewComponent (NO remote fetching).

**Estimated complexity:** L. Build effort dominated by modal lifecycle correctness (Sheet + Popover + Alert + ConfirmationDialog all coexisting; precise dismiss flows) and TokenField/ComboBox composition.

---

### 4. `initiative-cross-platform-ui-health-log` — value controls + data viz

**Mirrors:** Apple Health and Fitness.

**Elevator pitch:** Local Health-style dashboard where the user reviews activity metrics, adjusts targets, and logs scheduled habits.

**Canonical home for:** ActivityRing, ActivityRings, ProgressView, Gauge, ChartView, SegmentedControl, Picker, DatePicker (graphical style), TimePicker, Slider, Stepper, RadioGroup, TabView.

**Screens:**
- Summary dashboard (TabView root: Summary, Browse, Favorites)
- Activity rings detail (full-screen ActivityRings)
- Trends chart (ChartView with time-window SegmentedControl)
- Log entry form (Slider + Stepper + DatePicker + TimePicker + RadioGroup for activity type)
- Goal adjustment (Slider + Stepper + Picker)
- Schedule picker (DatePicker graphical + RadioGroup repeat-cadence)

**Cross-widget feature stories (gate H):**
1. View dashboard → tap activity ring → drill into Rings detail → adjust goal via Slider → save
2. Switch tabs via TabView → log custom entry → entry shows in Summary chart
3. Adjust time window via SegmentedControl → chart re-renders → tap data point → opens entry detail

**Reuse plan:** Reuse Voyager app shell and route dispatch. Net-new: metric fixtures (seeded synthetic data, NO HealthKit), chart data model, value-control interaction specs.

**Estimated complexity:** L. Build effort dominated by ChartView correctness across light/dark/dynamic-type and the activity ring math.

---

### 5. `initiative-cross-platform-ui-photos` — media + maps + share

**Mirrors:** Apple Photos.

**Elevator pitch:** Local Photos-style gallery where the user browses bundled images/videos, views places, pages through memories, and shares an item.

**Canonical home for:** Image, AsyncImage, ImageWell, VideoPlayer, PageControl, MapView, ActivityView, LinkButton, RatingIndicator.

**Screens:**
- Library grid (Image lazy grid)
- Photo detail (full-screen Image + RatingIndicator + ActivityView share)
- Memory carousel (PageControl over Image)
- Places map (MapView with photo location pins)
- Local media inspector (Inspector if rejected from Voyager, otherwise reuse)
- Share surface (ActivityView)
- Rating / favorite panel

**Cross-widget feature stories (gate H):**
1. Browse grid → tap photo → swipe through carousel via PageControl → favorite via RatingIndicator
2. Open places map → tap pin → photo detail → share via ActivityView
3. Open memory carousel → tap photo → play video (VideoPlayer) → return to carousel

**Reuse plan:** Reuse Voyager shell and local state. Net-new: bundled media fixtures (small images shipped with the sample), no-network async-image fixture path (local file:// URLs).

**Estimated complexity:** M/L. Build effort moderate; MapView is the highest-risk widget here (MapKit on iOS, fallback on web).

---

### 6. `initiative-cross-platform-ui-freeform-board` — canvas + shapes + glass

**Mirrors:** Apple Freeform.

**Elevator pitch:** Local Freeform-style board where the user arranges shapes, sketches paths, changes colors, and inspects a layered canvas.

**Canonical home for:** Capsule, Card, Circle, ColumnView, Divider, Grid, Panel, PathView, Rectangle, RoundedRectangle, Surface, ZStack, Canvas, ColorPicker, GlassBackground.

**Screens:**
- Board canvas (Canvas + Path overlays + Shape placements)
- Shape palette (ColumnView of shape primitives)
- Color/material inspector (Inspector pane with ColorPicker + GlassBackground sample)
- Layers panel (DisclosureGroup nested ZStack inspector)
- Grid/snap settings
- Presentation preview (full-screen with GlassBackground toolbar)

**Cross-widget feature stories (gate H):**
1. Place shape (Circle / Rectangle / RoundedRectangle / Capsule) on Canvas → pick color via ColorPicker → save
2. Sketch path via PathView → adjust stroke color → reorder layer
3. Toggle GlassBackground on toolbar → verify glass renders correctly across light/dark

**Reuse plan:** Can reuse Voyager shell and route registration. Net-new: board state, canvas/shape model, pointer interactions (the only demo app that requires gesture composition beyond tap), screenshot comparisons.

**Estimated complexity:** XL. Highest-effort app on the ladder. Canvas + ColorPicker + GlassBackground + gesture composition is the densest widget cluster.

---

## Home-screen ladder order

```
Row 1: [Voyager]    [Notes]     [Mailbox]
Row 2: [Health-Log] [Photos]    [Freeform]
```

**Rationale for the order** (most-broadly-demonstrative first):

1. **Voyager** — proves the broadest consumer story (create/edit/manage local data with real navigation, form input, settings, the existing Phase 10 exerciser screens).
2. **Notes** — proves the main app-structure primitives consumers will reach for after todos (lists, split navigation, search, outline, rich editor, toolbar/menu).
3. **Mailbox** — proves modal/transient surfaces and composition (sheet, popover, alert, confirmation dialog, token fields, HTML rendering, icon/tooltip actions).
4. **Health-log** — proves value controls and data visualization (rings, gauges, charts, pickers, date/time, sliders, steppers, tabs).
5. **Photos** — proves media, maps, paging, share, local async/loading behavior.
6. **Freeform-board** — visually broadest and highest-effort; sequenced last because it should not block proving the more common app-structure and form/control surfaces first.

## Authoring order for Phase 12+

Demo apps are authored in ladder order. Each demo app is its own phase brief:

- **Phase 12.A** — Harness foundation (interaction-contracts-harness.md §Phase 12.A). Unblocks every subsequent app's interaction-contract specs.
- **Phase 12.B** — V1 + V2 fixes via the harness as regression test. Closes the lifecycle-contract violations against Voyager.
- **Phase 12.C** — Voyager usage doc backlog + cross-widget feature story spec for the 3 Voyager stories. Brings Voyager to `documented-with-default-experience` status on the manifest.
- **Phase 13** — Notes (initiative-cross-platform-ui-notes). All widgets in its canonical-home cluster brought to `documented-with-default-experience`.
- **Phase 14** — Mailbox.
- **Phase 15** — Health-log.
- **Phase 16** — Photos.
- **Phase 17** — Freeform-board.

Each phase ends with the gate's per-widget items satisfied for that phase's canonical-home cluster, and the manifest's source hashes refreshed.

## Honesty principles

From Codex's review (verbatim): "This ladder is honest only if each icon opens the app and each app has a deterministic route/capture scenario to every canonical widget screen. Do not accept 'the app icon exists' as coverage for any widget."

Acceptance for each demo-app phase MUST include:
- App icon installed on the simulator home screen at the named phase's checkpoint commit.
- Tap on icon launches without crash.
- Every canonical widget in the app's cluster has a recorded deep link / capture scenario in the manifest's `canonical_example.deep_link` field with `max_tap_count ≤ 4`.
- The interaction-contract spec for each interactive widget passes under the CI job.

## Cross-references

- [merge-readiness-gate.md](merge-readiness-gate.md) — the gate this ladder serves
- [catalog-coverage.yml](catalog-coverage.yml) — the manifest each app's widgets flip rows in
- [tier-matrix.md](tier-matrix.md) — the widget inventory the ladder must collectively cover
- [handoff/2026-05-28-codex-catalog-coverage-review.md](handoff/2026-05-28-codex-catalog-coverage-review.md) — the antagonist review this ladder formalizes

— Architect (Claude Opus 4.7), demo-app-ladder v1, 2026-05-28
