# Phase 10D-final — Voyager todos as the Mail-app demo + Intent → Widget/Action rename

**Branch:** `phase-10-d-final` from `phase-10-d-refocus` (HEAD `87141b8a` includes the hand-test guide).
**Status:** v1. The final integrated Phase 10 deliverable. Owner-driven; replaces 10D-refocus after a second hand-test surfaced visual + terminology gaps.

## Owner alignment (verbatim, this session)

> "What I want is each todo to be a row and that row can slide back and forth depending on the swipe direction and can be tapped to then open the screen. That's like what you would do if you're reading emails."

> "I still really wanted the drag reorder. But if you absolutely have to defer that, then you know, sure. But it is ultimately a feature that we're going to implement anyway, so it just makes sense to have it here lumped into one."

> "I do think that you've generally gotten everything here correct" — (re: the Mail-app wireframe + dim/strikethrough for completion).

> "I am all right with your suggestion to split these. There's probably still a better naming convention of capability versus action so that it more clearly tells the story of what's going on. We need to make it clearer so that somebody with a much lesser IQ than yourself can come through and actually do all these things."

## Root-cause analysis of why 10D-refocus failed the hand-test

1. **`UI::Checkbox` → SwiftUI `Toggle` mapping.** Crystal author wrote "checkbox", iOS rendered a UISwitch (slide-pill). The Crystal widget catalog has no separate "completion indicator" widget. Adding one is out of scope for this slice (owner explicitly wants no row-level completion indicator per the Mail-app wireframe), so the fix is to *remove* `UI::Checkbox` from the row entirely.
2. **`UI::Button.Borderless` wrapping the title.** Rendered as blue link-styled text on iOS. Wrong idiom for a list row title.
3. **No list chrome.** Rows floated on the background — no separators, no insets, no row backgrounds. SwiftKit's `SwipeActionRowFacade` wrapped each row in its own single-row SwiftUI `List`, which gives swipe-actions support but no inter-row chrome (no shared separator system, no drag-reorder support, etc.).
4. **Naming confusion.** "Intent" overlapped with Apple's App Intents framework. Owner thought it WAS Apple terminology; agents pulled Apple App Intent semantics from training data and mixed it with our different usage.

## Rename: `UI::Intent` → split into `UI::Widget` + `UI::Action`

After review with owner this session:

- **`UI::Widget.for(name : Symbol, context : ScreenContext) : UI::View.class`** — picks the platform-appropriate widget class for a named feature. Returns the class to instantiate.
  - Reads aloud: "give me the UI widget for swipe-actions in this context"
  - Replaces `UI::Intent.resolve`.

- **`UI::Action.perform(name : Symbol, **args) : UI::Action::Result`** — invokes a native OS API binding.
  - Reads aloud: "perform the UI action copy-to-clipboard with these args"
  - Replaces `UI::Intent.dispatch`.

- **Other renames** (mechanical):
  - `UI::Intent::Registry` → `UI::Widget::Registry`
  - `UI::Intent::ClassCRegistry` → `UI::Action::Registry`
  - `UI::Intent::DispatchResult` → `UI::Action::Result`
  - `UI::Intent::PlatformFeatureBinding` → `UI::Action::PlatformBinding`
  - `UI::Intent::UnresolvableDefault` → `UI::Widget::UnresolvableDefault`
  - `UI::Intent::IncompatibleOverride` → `UI::Widget::IncompatibleOverride`
  - `UI::Intent::IncomingDeepLink` → `UI::Action::IncomingDeepLink`
  - `UI::Intent::Bootstrap` → split into `UI::Widget::Bootstrap` + `UI::Action::Bootstrap`
  - `declares_capabilities` macro keeps its name (capabilities are still capabilities the widget supports)
  - `override_intent` → `override_widget`

- **Backwards compatibility**: NONE. Phase 10 is internal-initiative work; consumer code does not yet reference these symbols outside the asset_pipeline + Voyager sample. Rename is mechanical sed across both repos.

- **Docs**: update every reference in `docs/initiative-cross-platform-ui/` to use the new vocabulary. Class A/B/C/D classification language stays in archived docs but new docs use "Widget" (for routing) + "Action" (for OS calls).

## Mail-app row wireframe (LOCKED, owner-confirmed)

> Each todo is a full-width row of plain text — a normal-weight title (regular size, ~17pt iOS default), optionally a smaller secondary-color subtitle below it (~13pt, gray, e.g. "Due Jun 1"). Standard hairline separator below each row. **No circle. No toggle. No completion indicator on the row itself.**
>
> Tap anywhere on the row → opens the todo detail screen.
>
> Swipe **left** (trailing edge) → reveals trailing action tiles sliding out from the right edge, full row height: **Edit**, **Share**, **Mark Done**, **Delete**. Each tile is SF Symbol icon over label, system-tinted (Delete is red/destructive role). Full-left-swipe primary action = **Delete**.
>
> Swipe **right** (leading edge) → reveals leading action tile sliding out from the left edge, full row height: **Archive**. Full-right-swipe primary action = **Archive**.
>
> Completed todos remain visible in the list with **dim color + strikethrough** title. (Completion is set from the detail screen's "Mark Done" button OR from the Mark Done swipe tile.)
>
> Variable row height: title always shown; subtitle line shown only if deadline exists.

## Drag-to-reorder (NEW vs 10D-refocus)

Owner requested re-inclusion. This requires changing the row container architecture:

- **Before (10D-refocus):** `UI::VStack` containing N `UI::SwipeActionRow`s. Each SwipeActionRow wrapped itself in a single-row SwiftUI `List` to activate `.swipeActions(edge:)`. Inter-row chrome (separators, drag) impossible.

- **After (10D-final):** Convert the todos screen's row container to a `UI::ListView` (Crystal's existing list widget). The UIKit renderer for `ListView` produces a SwiftUI `List { ForEach { row ... } }` harness that:
  - Provides system list chrome (separators, insets).
  - Honors `.swipeActions(edge:)` per row natively.
  - Honors `.onMove(perform:)` for drag-to-reorder.
  - Honors `.onDelete(perform:)` if we choose to use it for full-swipe-Delete (or keep that on the trailing swipe action).

**Implementation work for drag-reorder:**

1. Audit current `UI::ListView` UIKit renderer (`src/ui/renderers/uikit_renderer.cr`). Does it already emit a SwiftUI List? If yes, extend with `.onMove`. If no (e.g., emits UIStackView), need to refactor to SwiftUI List path.
2. Add `on_move : Proc(Int32, Int32, Nil)?` to `UI::ListView` (Crystal-side property).
3. SwiftKit facade: thread the `on_move` callback through to the SwiftUI `.onMove { from, to in ... }` modifier.
4. Wire to a new `:move_row` controller action in `todos_controller.cr`; mutate `state.cr` to reorder the todos array.
5. The trigger for drag-reorder on iOS is long-press-then-drag (standard List behavior).

**If `UI::ListView` doesn't have a clean SwiftUI-backed renderer path on iOS today**, falling back to deferring is acceptable but ONLY if the audit reveals it would require a multi-day refactor. Owner approved this as the bar.

## Deliverables

### Deliverable 1 — `UI::Intent` → `UI::Widget` + `UI::Action` rename

Mechanical refactor. Touch every file referencing the old names. Verify with:
- `crystal build src/asset_pipeline.cr` passes
- `crystal run scripts/lint_conventions.cr` passes (will be 19 rules + new file count)
- `crystal spec spec/web/` baseline preserved (4 failures + 2 errors, all pre-existing)

Commit at the end of the rename. **AGGRESSIVE COMMIT DISCIPLINE: don't combine the rename with anything else.**

### Deliverable 2 — `UI::Checkbox` + `UI::Button.Borderless` purged from todos row

The Mail-app wireframe says NO completion indicator on the row. So:
- Remove `UI::Checkbox` from `todos_screen.cr` row construction entirely.
- Remove the `UI::Button.Borderless` wrapper around the title.
- Row content becomes: a tap-target VStack containing a Label (title) and optionally a Label (subtitle).
- The whole row is the tap target. Tap fires `Voyager.dispatch(:edit_row, ...)` to navigate to the detail screen.

Implementation note: iOS-native row tap typically uses NavigationLink or `.onTapGesture`. The SwiftKit facade (whether SwipeActionRowFacade or the new ListView path) needs to thread a single per-row tap callback that fires the dispatcher.

### Deliverable 3 — Convert row container to `UI::ListView`

Per the drag-reorder section above. If `UI::ListView` already supports the SwiftUI List renderer path on iOS, this is small. If not, it's the biggest single piece of work in this brief.

Per-row composition uses the SwiftUI List native chrome:
- `.swipeActions(edge: .trailing)` for Edit / Share / Mark Done / Delete
- `.swipeActions(edge: .leading)` for Archive
- `.onTapGesture` (or `NavigationLink`) for whole-row tap → detail screen
- `.onMove(perform:)` on the List for drag-reorder

### Deliverable 4 — Mark Done + dim/strikethrough completion state

- Add `:mark_done` controller action that toggles `todo.completed`.
- Detail screen (todo_editor_screen.cr) gets a "Mark Done" / "Mark Not Done" button at the bottom that dispatches `:mark_done`.
- Trailing swipe tile "Mark Done" / "Mark Not Done" (text varies based on current completed state) — also dispatches `:mark_done`.
- Row rendering: when `todo.completed`, the title Label uses dim color (UI::LabelRole::Tertiary) + strikethrough = true.

### Deliverable 5 — Subtitle (deadline) humanization

If `todo.deadline` is a parseable ISO date (YYYY-MM-DD), render as "Due Jun 1" (or "Due Tomorrow" / "Due Today" if it's near). Otherwise render the raw string. Skip the subtitle if deadline is empty.

Crystal-side: a `humanize_deadline(raw : String) : String?` helper in todos_screen.cr is fine.

### Deliverable 6 — Detail screen update

`todo_editor_screen.cr` already exists. Add:
- A "Mark Done" / "Mark Not Done" button at the bottom (above Save / Cancel) that dispatches `:mark_done`.
- The deadline field stays a text field (TextField) — native DatePicker integration is still deferred (separate Phase 11+ work).

### Deliverable 7 — iOS build + simulator launch + screenshots

Simulator: iPhone 17 Pro / iOS 26.5 / UUID `92DA97A0-5FEC-46BD-A525-8AFE2A4FDC21` (already booted in owner's environment).

Build commands per the established pattern. Install + launch with `VOYAGER_ROOT_SLUG=voyager-todos`.

**Screenshots to capture** (commit each):
- Empty / fresh todos screen.
- Todos screen with rows visible (showing Mail-app row appearance).
- Mid-swipe-left (showing trailing tiles).
- Mid-swipe-right (showing leading Archive tile).
- After tap → detail screen.
- A row in completed state (dim + strikethrough).
- (If drag-reorder shipped) Mid-drag visual.

**Critical: DO NOT engage with system permission alerts.** If the notification-permission alert appears during launch, leave it alone. Document in the hand-test guide that the owner dismisses it manually.

### Deliverable 8 — Updated hand-test guide

Replace `phase-10-d-refocus-handtest.md` with `phase-10-d-final-handtest.md`. Per-step walkthrough, expected visuals (matched to your screenshots), known-deferred items.

## Hard commit discipline

Same as 10D-refocus dispatch: commit after every meaningful unit of work. Specifically:

- After Deliverable 1 (rename): commit.
- After Deliverable 2 (Checkbox/Button purge): commit.
- After every Crystal file you create OR substantially edit: commit.
- After every Swift file you create OR substantially edit: commit.
- After every successful Crystal compile: commit if anything is uncommitted.
- After every successful Swift typecheck or `swift build`: commit if anything is uncommitted.
- After every successful xcodebuild: commit if anything is uncommitted.
- After every screenshot you capture: commit.
- Before invoking simctl install or launch: commit any pending work.

Commit messages can be brief: `[10D-final] D3 progress: ListView SwiftUI renderer` is fine.

Standard footer: `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`

## Critical memories
- `[[codex-as-architect-antagonist]]` — Codex will review.
- `[[owner-hands-on-finds-real-bugs]]` — owner's feedback IS the bug list.
- `[[reactivity-is-table-stakes]]` — state mutations must trigger Rerender.
- `[[audit-scope-discipline]]` — audit ALL platforms when touching shared widget code.
- `[[plan-what-to-understand-not-just-what-to-build]]` — investigate existing UI::ListView UIKit renderer BEFORE deciding the drag-reorder approach. Understand the codebase before producing new files.
- `[[mid-stop-pattern]]` — don't stop mid-action at simulator launch.
- `[[crystal-ios-class-init-gap]]` — already mitigated; don't regress.
- `[[sourcekit-stale-index]]` — trust `swift build` output over SourceKit "Cannot find type" errors.
- `[[parallel-agent-worktree-isolation]]` — single agent, single worktree, no parallel implementers in this slice.

## Acceptance gate

- ✅ `UI::Intent` references gone from `src/` and `samples/`. New names in use throughout.
- ✅ Todos row renders Mail-app pattern (plain text title + optional subtitle + hairline separator, no toggle, no blue link text).
- ✅ Whole-row tap → detail screen.
- ✅ Swipe-left reveals Edit / Share / Mark Done / Delete tiles, full row height, system-tinted, Delete red.
- ✅ Swipe-right reveals Archive tile, full row height.
- ✅ Full-swipe primary actions wire correctly.
- ✅ Completed todos render dim + strikethrough, stay in list.
- ✅ Drag-reorder via long-press works on iOS (or honest deferral with reason).
- ✅ Detail screen has Mark Done button.
- ✅ iOS .app launches + the todos screen exercises the full flow.
- ✅ Screenshots committed.
- ✅ Hand-test guide updated.
- ✅ Lint + build green.
- ✅ `crystal spec spec/web/` baseline preserved.

## Out of scope (do not touch)

- Native DatePicker bridge for deadline (Phase 11+).
- Cross-platform refocus (only iOS hand-tested; macOS InlineActionRow is "good enough for now" per owner).
- HIG validation captures.
- The 2 documented iOS crashes (`accessibility_actions` + `keyboard_shortcut` via SwiftKit populator) — leave as-is.
- Codex content review of this brief: architect dispatches separately before implementer.

— Architect (Claude Opus 4.7), 10D-final brief v1
