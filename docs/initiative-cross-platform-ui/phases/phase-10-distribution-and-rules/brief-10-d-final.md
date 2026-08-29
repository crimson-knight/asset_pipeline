# Phase 10D-final — Voyager todos as Mail-app demo + Intent → WidgetRoute / SystemAction rename + drag-reorder

**Branch:** `phase-10-d-final` cut from `phase-10-d-refocus` HEAD `49a37f68`.
**Status:** v2. **REVISED after Codex critique of v1.** 14 findings addressed below.
**Owner directive (this session):** "update your plan, make all the updates necessary, review it with codex, and then begin. I want you to start working. I'm going to be gone for about an hour."

## Owner alignment (verbatim, this session)

> "What I want is each todo to be a row and that row can slide back and forth depending on the swipe direction and can be tapped to then open the screen. That's like what you would do if you're reading emails."

> "I still really wanted the drag reorder. But if you absolutely have to defer that, then you know, sure. But it is ultimately a feature that we're going to implement anyway, so it just makes sense to have it here lumped into one."

> "I am all right with your suggestion to split these. There's probably still a better naming convention of capability versus action so that it more clearly tells the story of what's going on."

> "Whatever would make it so that it's easier for another agent to understand without having had this conversation is what we should be naming it."

## Naming — Codex-corrected

**v1 proposal collided with existing code.** `UI::Widget` is already a public class at `src/ui/widgets.cr:116` (with sibling `UI::WidgetPlacement`, `UI::Widgets`). Cannot use as a namespace. `UI::Action` is semantically muddy alongside `UI::ActionResult`, `UI::ActionDispatcher`, `UI::AccessibilityAction`.

**Final names:**

- **`UI::WidgetRoute.resolve(name : Symbol, context : ScreenContext) : UI::View.class`** — routes a feature name to the platform-appropriate widget class.
  - Reads aloud: *"the widget route for swipe-actions resolves to ..."*
  - The metaphor: feature names are routes, and the registry maps them to concrete widget destinations per platform.

- **`UI::SystemAction.perform(name : Symbol, **args) : UI::SystemAction::Result`** — invokes an OS-level binding.
  - Reads aloud: *"perform the system action copy-to-clipboard with these args."*
  - "System" makes it unambiguous that this calls into the operating system, not a controller action.

**Rename map** (all references in `src/`, `samples/`, `spec/`, `scripts/`, `docs/initiative-cross-platform-ui/`, plus file/directory names):

| Old | New |
|---|---|
| `UI::Intent.resolve` | `UI::WidgetRoute.resolve` |
| `UI::Intent.dispatch` | `UI::SystemAction.perform` |
| `UI::Intent::Registry` | `UI::WidgetRoute::Registry` |
| `UI::Intent::ClassCRegistry` | `UI::SystemAction::Registry` |
| `UI::Intent::DispatchResult` | `UI::SystemAction::Result` |
| `UI::Intent::PlatformFeatureBinding` | `UI::SystemAction::PlatformBinding` |
| `UI::Intent::UnresolvableDefault` | `UI::WidgetRoute::UnresolvableDefault` |
| `UI::Intent::IncompatibleOverride` | `UI::WidgetRoute::IncompatibleOverride` |
| `UI::Intent::IncomingDeepLink` | `UI::SystemAction::IncomingDeepLink` |
| `UI::Intent::Bootstrap` | split → `UI::WidgetRoute::Bootstrap` + `UI::SystemAction::Bootstrap` |
| `UI::Intent::ClassCBootstrap` | merged into `UI::SystemAction::Bootstrap` |
| `override_intent` macro | `override_widget` |
| `src/ui/intent.cr` | `src/ui/widget_route.cr` |
| `src/ui/intent/` | `src/ui/widget_route/` + `src/ui/system_action/` (split) |
| `src/ui/intent_bootstrap.cr` | `src/ui/widget_route/bootstrap.cr` |
| `spec/web/ui/intent_*.cr` | `spec/web/ui/widget_route_*.cr` or `spec/web/ui/system_action_*.cr` |
| `lsp_rules/family_3_architectural/intent_resolve_capability_arg_rule.cr` | `widget_route_resolve_capability_arg_rule.cr` (and rename rule name) |
| `lsp_rules/family_3_architectural/override_intent_widget_subclass_rule.cr` | `override_widget_subclass_rule.cr` |

`declares_capabilities` macro keeps its name (capabilities are still what widgets declare).

**Rename verification command:** after the rename, the final grep MUST return zero hits except in archived handoffs:

```
rg -n 'UI::Intent|Intent::Registry|Intent::Class|::Intent\.|override_intent|intent_bootstrap|family_3_architectural/intent_' src samples spec scripts docs/initiative-cross-platform-ui
```

Archived handoffs (`docs/initiative-cross-platform-ui/handoff/phase-10-*-close.md` etc.) MAY keep old names for historical accuracy. New docs MUST use new names.

## Mail-app row wireframe (locked, with Codex tightening)

> Each todo is a full-width SwiftUI List row of plain text — regular-weight title (system default `.body` ~17pt), optionally a smaller secondary-color subtitle below it (~13pt, `Color.secondary`, e.g. "Due Jun 1"). Standard SwiftUI list separator below each row (`.listRowSeparator(.visible)`). **No circle. No toggle. No completion indicator on the row.**
>
> Row content uses native SwiftUI List padding + min row height — do NOT impose custom 60pt cards / chips. Single-line rows (no deadline) use the default list-cell padding; two-line rows (with deadline) get whatever the default expansion is.
>
> Tap anywhere on the row → opens the todo detail screen via `.onTapGesture` (NOT `NavigationLink` — the Voyager nav model uses dispatcher-driven slug navigation, not SwiftUI's NavigationStack).
>
> Swipe **left** (trailing edge): full-row-height tiles slide out from the right edge in this order: **Edit**, **Share**, **Mark Done** (label flips to "Mark Not Done" when already completed), **Delete**.
> - Use `.swipeActions(edge: .trailing, allowsFullSwipe: true)`. SwiftUI's full-swipe fires the **first** action in the closure for that edge.
> - Order matters: **Delete is listed FIRST in the trailing closure**, so it's the full-swipe primary action.
> - But visually we want Edit on the leftmost tile (closest to row body). SwiftUI renders the modifier's first action **rightmost** by default. So tile order in the closure: `Delete, Mark Done, Share, Edit` to get visual order (left→right) Edit, Share, Mark Done, Delete.
> - Delete uses `role: .destructive` so SwiftUI tints it red automatically.
>
> Swipe **right** (leading edge): **Archive** tile slides out from the left edge.
> - Use `.swipeActions(edge: .leading, allowsFullSwipe: true)` with Archive as the only/first action.
>
> Completed todos remain visible in the list with **title in `Color.secondary` + `.strikethrough()` modifier**. Subtitle, if present, also uses `Color.secondary` regardless of completion state (already secondary).
>
> "Mark Done" tile icon: `checkmark.circle`. "Mark Not Done" tile icon: `circle`. Both use system tint (no destructive role).
>
> "Edit" icon: `pencil`. "Share" icon: `square.and.arrow.up`. "Archive" icon: `archivebox`. "Delete" icon: `trash`, destructive role.

## Drag-to-reorder — explicit architecture (Codex tightening)

**Audit results from v1 critique:** `UI::ListView` UIKit renderer at `src/ui/renderers/uikit_renderer.cr:1084` already emits SwiftUI `List` via `apsk_make_list_view` (no UIStackView refactor needed). Good news.

**Bad news:** `ListViewFacade` only hosts child views via `APSKHostedChild` — it does NOT know per-row swipe actions, tap tokens, or move tokens. Putting current `UI::SwipeActionRow`s as children would nest SwiftUI Lists (one List per row inside a parent List), which breaks both `.swipeActions` rendering and the parent List's drag/separator behavior.

**Architectural decision (NEW in v2):** the todos screen will NOT use `UI::SwipeActionRow` at all. Instead:

1. The row container becomes `UI::ListView` directly.
2. Each row is a plain content view (a VStack of Labels) added as a ListView child.
3. `UI::ListView` gains per-row metadata for swipe actions + on_tap + drag handle:
   - `on_item_tap : Proc(Int32, Nil)?` — existing property, but currently NOT wired through to UIKit. Implementer wires the callback token plumbing.
   - `on_move : Proc(Int32, Int32, Nil)?` — NEW property for drag-reorder.
   - `leading_swipe_actions : Proc(Int32, Array(UI::SwipeAction))?` — NEW property; lambda returning the leading-edge actions for the given row index.
   - `trailing_swipe_actions : Proc(Int32, Array(UI::SwipeAction))?` — NEW property.
4. `ListViewFacade.swift` extends to emit `.swipeActions(edge:allowsFullSwipe: true)` per row plus `.onMove(perform:)` on the parent List.
5. The SwiftKit populator gains the new fields + token arrays (parallel labels / icons / tokens / roles per row, OR a more compact per-row override array).

**This is the biggest single piece of work in the brief.** Implementer must produce a written **preflight report** (see Preflight section below) BEFORE writing any code in this area, scoping the actual diff size and confirming feasibility.

**`UI::SwipeActionRow` itself stays in the codebase** — other screens may still use the existing facade. Only the todos screen migrates to the new ListView-with-swipe-actions path. The widget catalog gains a second valid path for swipe gestures.

**If preflight reveals the per-row swipe + onMove integration is genuinely a multi-day refactor**, implementer STOPS and writes a report explaining the blocker. Otherwise drag-reorder is REQUIRED.

## Deliverables (revised order)

### Deliverable 0 — Preflight report (NEW; structural fix per Codex finding #14)

Before any bulk work, implementer creates `docs/initiative-cross-platform-ui/handoff/phase-10-d-final-preflight.md` containing:

1. **Final rename names** confirmed (or proposed alternatives if WidgetRoute / SystemAction also collide somewhere).
2. **`rg UI::Intent` output** scoped to `src samples spec scripts docs/initiative-cross-platform-ui` — count of hits per file, total file count to touch.
3. **`UI::ListView` UIKit + SwiftKit facade audit** — current state, what's missing for per-row swipe + drag, exact files + functions to extend.
4. **Full-swipe primary action ordering** — confirm Delete is first in trailing closure (so it's the full-swipe action) AND tile visual order is Edit / Share / Mark Done / Delete (left to right).
5. **Rough effort estimate** per Deliverable. Flag if drag-reorder appears > 2 hours of work.

**Commit this report before continuing.** This is the artifact the owner can read first when they return.

### Deliverable 1 — Bulk rename: `UI::Intent` → `UI::WidgetRoute` + `UI::SystemAction`

Mechanical refactor. Single focused commit (the rename is too entangled to split cleanly).

After rename, verify:
- `crystal build src/asset_pipeline.cr` passes.
- `crystal run scripts/lint_conventions.cr` passes.
- `crystal spec spec/web/` baseline preserved (4 failures + 2 errors, all pre-existing).
- The verification grep at the top of the brief returns zero hits.

### Deliverable 2 — Take one "before" simulator screenshot (NEW; Codex finding #14)

After Deliverable 1 (and BEFORE touching the row UX), build + launch the iOS app and take a screenshot showing the current (broken) row appearance — toggle + blue text + no separators.

Commit it as `docs/initiative-cross-platform-ui/handoff/phase-10-d-final-screenshots/00_before.png`.

**This is the visual baseline.** Subsequent screenshots compare against this.

### Deliverable 3 — `UI::ListView` extension for per-row swipe + tap + drag

Per the Drag-to-reorder section above. Crystal-side new properties + Swift facade extension + objc bridge entry points.

Subdivide into commits:
- Crystal property additions (no behavior change yet) — commit.
- SwiftKit facade extension — commit.
- objc bridge entry points — commit.
- Populator wiring — commit.

Smoke spec(s) for the new properties (no UI assertions, just that Crystal-side API compiles + reactivity holds).

### Deliverable 4 — Rebuild todos row to Mail-app wireframe

`samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr`:

- Replace `UI::VStack` row container with `UI::ListView`.
- Remove `UI::Checkbox` from row. Remove `UI::Button.Borderless` wrapping. Each row is a plain VStack with one or two Labels.
- Wire `UI::ListView.on_item_tap`, `leading_swipe_actions`, `trailing_swipe_actions`, `on_move` to the controller.

`samples/initiative-cross-platform-ui-voyager/controllers/todos_controller.cr`:

- `:edit_row` (already exists, may need index-arg shape change)
- `:archive_row`, `:share_row`, `:delete_row` (already exist)
- `:mark_done` (NEW) — toggles `todo.completed`
- `:move_row` (already exists per the prior agent — verify implementation matches the new `(from_index, to_index)` shape from SwiftUI `.onMove`)

`samples/initiative-cross-platform-ui-voyager/screens/state.cr`:

- Ensure `Voyager.state.reorder(from, to)` exists (likely already does from prior 10D agent).

### Deliverable 5 — Detail screen Mark Done button + completion styling

`todo_editor_screen.cr`:

- Add Mark Done button below the form (above Save/Cancel). Label flips based on current state. Dispatches `:mark_done`.

Row rendering in todos_screen (already in Deliverable 4):

- When `todo.completed`, the title Label uses `text_color_role = UI::LabelRole::Secondary` AND `strikethrough = true`. Subtitle if present uses Secondary always (no change for completed).

### Deliverable 6 — Subtitle humanization

`humanize_deadline(raw : String) : String?` helper in todos_screen.cr:

- If `raw` parses as `YYYY-MM-DD`, return "Due {short month} {day}" (e.g. "Due Jun 1"). If date is today: "Due Today". If date is tomorrow: "Due Tomorrow".
- If `raw` is empty: return `nil` (caller suppresses the subtitle row).
- If `raw` doesn't parse: return `raw` verbatim (legacy strings still display).

### Deliverable 7 — iOS build + simulator launch + screenshot set

Build commands per established pattern. Launch with `VOYAGER_ROOT_SLUG=voyager-todos`.

Simulator UUID: `92DA97A0-5FEC-46BD-A525-8AFE2A4FDC21` (iPhone 17 Pro / iOS 26.5, already booted).

**Screenshots to capture (commit each):**

- `01_after_rename_blank.png` — todos screen post-rename, before row rebuild (same broken row UX, just verifying rename didn't break the app launch).
- `02_after_row_rebuild_plain.png` — Mail-style rows showing.
- `03_swipe_left_mid.png` — mid-swipe-left showing trailing tiles.
- `04_swipe_right_mid.png` — mid-swipe-right showing Archive tile.
- `05_completed_row.png` — at least one row in completed state (dim + strikethrough).
- `06_detail_screen.png` — detail screen with Mark Done button.
- `07_drag_mid.png` (if drag shipped) — mid-drag visual showing a row being moved.

**DO NOT engage with system permission alerts.** If one appears on launch, document it and move on. Owner dismisses manually.

### Deliverable 8 — Hand-test guide

`docs/initiative-cross-platform-ui/handoff/phase-10-d-final-handtest.md` — replaces the refocus guide. Per-step walkthrough matched to the screenshots. Known-deferred items: native DatePicker.

## Hard commit discipline (Codex finding #13: add STOP commits)

**Mandatory commit points (in order):**

1. **STOP** after Deliverable 0 (preflight). Architect reviews preflight before further work.
2. After Deliverable 1 (rename) compiles green. STOP for verification grep.
3. After Deliverable 2 (before screenshot). STOP — first artifact in evidence trail.
4. After every Crystal file substantially edited.
5. After every Swift file substantially edited.
6. After SwiftKit bridge signature changes (whole-bridge commit so Crystal-side requires can update in next commit).
7. After every successful `swift build`.
8. After every successful `crystal build src/asset_pipeline.cr`.
9. After every successful `xcodebuild`.
10. After every screenshot capture.
11. Before invoking `simctl install` or `simctl launch`.

Commit messages: `[10D-final] D<N> progress: <one-line subject>` is fine.

Standard footer: `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>` on every commit.

## Critical memories

- `[[codex-as-architect-antagonist]]` — Codex will review the close handoff.
- `[[owner-hands-on-finds-real-bugs]]` — owner is the gate; preflight + first screenshot are the early checkpoints to prevent another wasted hand-test cycle.
- `[[reactivity-is-table-stakes]]` — every state mutation triggers Rerender.
- `[[audit-scope-discipline]]` — the rename touches a LOT of files. The verification grep is non-negotiable.
- `[[plan-what-to-understand-not-just-what-to-build]]` — Deliverable 0 (preflight) IS this principle.
- `[[mid-stop-pattern]]` — don't stop mid-action at simulator launch.
- `[[crystal-ios-class-init-gap]]` — already mitigated; don't regress.
- `[[sourcekit-stale-index]]` — trust `swift build` over SourceKit "Cannot find type" errors.
- `[[parallel-agent-worktree-isolation]]` — single agent, single worktree, no parallel sub-implementers in this slice.

## Acceptance gate (Codex finding #11: tightened)

- ✅ `rg UI::Intent` returns zero hits across `src samples spec scripts docs/initiative-cross-platform-ui` (except archived close handoffs explicitly listed in preflight as in-scope-to-keep).
- ✅ Todos row renders Mail-app pattern: plain text, no toggle / no blue link text / no card chrome, native SwiftUI List separators.
- ✅ Whole-row tap → detail screen via dispatcher (NOT SwiftUI NavigationStack).
- ✅ Swipe-left reveals Edit / Share / Mark Done / Delete tiles. Full-left-swipe fires Delete.
- ✅ Swipe-right reveals Archive tile. Full-right-swipe fires Archive.
- ✅ Completed todos render Secondary color + strikethrough title, stay in list.
- ✅ Drag-reorder via long-press works on iOS — OR — preflight documented exact blocker and architect approved deferral. Soft deferral language ("works or honest deferral") is NOT acceptable.
- ✅ Detail screen Mark Done button works.
- ✅ Deadline subtitle humanized ("Due Jun 1" / "Due Today" / "Due Tomorrow").
- ✅ iOS .app launches + the screenshot set captures the full flow.
- ✅ Hand-test guide updated.
- ✅ Lint + build green.
- ✅ `crystal spec spec/web/` baseline preserved.

## Out of scope (Codex finding #12: explicit distraction list)

Do NOT do any of these in this slice:

- Add an archive screen / unarchive flow / archived-items list.
- Expand notification permission behavior beyond what already exists.
- Expand Print intent functionality.
- Redesign the count cards / charts / Settings.
- Add a completion-indicator widget (e.g. CompletionMark).
- Native DatePicker bridge for deadline (still deferred).
- macOS / web / Android parity for the new row.
- Clean up legacy exerciser hub beyond what the rename touches.
- HIG validation captures.
- Fix the 2 documented iOS crashes (`accessibility_actions` + `keyboard_shortcut` via SwiftKit populator).
- Touch any Phase 10 code outside the rename + the todos screen + ListView + detail screen.

## Codex re-review checkpoint

After the implementer reports close, the architect dispatches Codex content review on:

1. Rename completeness (grep, references in docs).
2. Row visual matches the Mail-app wireframe (cross-check against the screenshots).
3. Drag-reorder actually wires through to SwiftUI `.onMove` and the move callback hits `move_row` controller action.
4. Mark Done flips state correctly + the row re-renders with dim + strikethrough.
5. Full-swipe primary action ordering matches the spec.

If Codex returns REVISE, architect dispatches iter 2 with the specific findings.

— Architect (Claude Opus 4.7), 10D-final brief v2 (post-Codex)
