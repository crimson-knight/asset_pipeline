# Phase 10B.0 — Tier 2 Resolver + Reactivity Contract (DRAFT v1)

**Sub-phase:** 10B.0 — make the Tier 2 translation contract real Crystal.
**Branch:** `phase-10-b-0` cut from `phase-10`.
**Status:** DRAFT v1 — pending Codex antagonist + reconciliation.
**Predecessor:** 10-pre.1 + 10-pre.2 closed. Catalog accurately describes today's framework.

---

## 1. What you are doing

Turn `tier-2-translation-contract.md`'s pseudocode into real Crystal. Establish the resolver pattern that lets a screen author write `UI::Intent.resolve(:swipe_actions, ctx).build(...)` and get the platform-appropriate widget — with override support and capability validation. Establish the **reactivity contract** as a binding invariant: every routed widget supports state-mutation → re-render with override preserved.

After 10B.0 closes, the framework has:
- `UI::Intent.resolve(intent_id, context, capabilities_required:)` API in Crystal.
- App-level override registry: `UI::App.override_intent(:foo, MyClass, capabilities: {...})`.
- Screen-local override mechanism with precedence: screen > app > default.
- Capability validation that rejects overrides that don't satisfy declared capabilities.
- Reactivity invariant: `resolve()` runs at every `screen.build(ctx)`; state mutation triggers `screen.build(ctx)` → `resolve()` re-runs; override change preserved across re-render.

You are NOT implementing Class A widgets yet (that's 10B.1a). You are NOT implementing Class B accessibility (10B.2x). You ARE building the substrate that all subsequent 10B slices depend on.

## 2. Read first

Working directory: `/Users/crimsonknight/open_source_coding_projects/asset_pipeline`.

1. `docs/initiative-cross-platform-ui/architecture/tier-2-translation-contract.md` — the pseudocode you're making real.
2. `docs/initiative-cross-platform-ui/architecture/intent-routing-candidates.md` — the `:swipe_actions` capability block (after 10-pre.1's trim).
3. `docs/initiative-cross-platform-ui/architecture/intent-catalog.md` — Class A row (the only one for now).
4. `src/ui/views/swipe_action_row.cr` — the existing Class A widget.
5. `src/ui/native_app.cr` (`UI::App`) — where the override registry hooks in.
6. `src/ui/views/screen.cr` (`UI::Screen`) — where `build(ctx)` runs.
7. `src/asset_pipeline/action_dispatcher.cr` — for the reactivity loop reference.
8. `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/scoping-10.md` v3 §"10B.0".
9. `[[reactivity-is-table-stakes]]` memory — binding invariant.

## 3. Constraints (Hard Rules)

- **Forward commits only** on `phase-10-b-0` branch (`git checkout -b phase-10-b-0 phase-10`).
- **Reactivity invariant is binding.** Per `[[reactivity-is-table-stakes]]`: `UI::Intent.resolve` MUST run at every `screen.build(ctx)`, NOT memoized at app boot. State mutation MUST trigger re-resolve. Specs MUST prove this — override change + state change + rerender preserves current platform override.
- **Public API only.** The resolver is a public surface; consumers (Voyager, future apps) read it. Design it with care.
- **No widget implementation in this slice.** The 1 existing Class A widget (`UI::SwipeActionRow`) wires into the resolver, but 10B.0 doesn't build new widgets.
- **No catalog changes.** 10-pre.1 and 10-pre.2 froze the catalog; 10B.0 reads from it but doesn't edit it.
- **Spec coverage required.** Resolver behavior + override precedence + capability validation + reactivity each get specs. Specs land in `spec/web/` (default — the resolver isn't platform-gated for testing) per 10C.0's directory split (will happen in parallel; for now write specs assuming the new directory layout exists OR coordinate with 10C.0 implementer).
- Per `[[codex-as-architect-antagonist]]`: Codex critiques every brief, dispatch decision, reflection.
- Per `[[complete-phase-arc-before-review]]`: no owner involvement.
- Per `[[plan-what-to-understand-not-just-what-to-build]]`: if reactivity-preservation surfaces an architectural conflict with current `UI::App` / `UI::Screen` design, surface to architect — don't paper over.

## 4. Deliverables

### Deliverable 1 — `src/ui/intent.cr` — The resolver

Public API:

```crystal
module UI
  module Intent
    # Resolve an intent to a widget class for the current context.
    # MUST run at screen.build(ctx) time; never memoize across renders.
    def self.resolve(intent_id : Symbol, context : ScreenContext, capabilities_required : Hash(Symbol, Bool)? = nil) : View.class
      # ...
    end

    # Internal: capability validation
    def self.validate_override(intent_id, widget_class, declared_capabilities) : Bool
      # ...
    end
  end
end
```

Internal data structures:
- `Intent::Defaults` — class-level lookup table: `intent_id → {platform → widget_class}`.
- `Intent::Capabilities` — per-intent capability descriptor.
- `Intent::Registry` — app + screen override stores.

### Deliverable 2 — `src/ui/native_app.cr` — Override registration

Extend `UI::App` with:

```crystal
class UI::App
  # App-level intent override
  def override_intent(intent_id : Symbol, widget_class : View.class, capabilities : Hash(Symbol, Bool))
    # ...
  end
end
```

### Deliverable 3 — Screen-local override

Extend `UI::Screen` (or `ScreenContext`) with:

```crystal
class UI::Screen
  # Screen-local override (highest precedence)
  def override_intent(intent_id, widget_class, capabilities)
    # ...
  end
end
```

Precedence: screen > app > default. Documented in code comment.

### Deliverable 4 — Reactivity contract

`UI::Intent.resolve` runs every time `screen.build(ctx)` is called. The framework's existing render loop (via `ActionDispatcher` → `screen.build`) calls `build` after state mutation. Verify the existing loop honors this; if not, document the gap as a 10B finding (NOT a fix in 10B.0).

Specs MUST cover:
- Override change + rerender → new platform widget appears.
- State change + rerender (no override change) → same platform widget rebuilt.
- Override change + state change + rerender → both preserved.

### Deliverable 5 — Wire existing `UI::SwipeActionRow` into the resolver

The catalog's only Class A intent is `:swipe_actions`. The existing `UI::SwipeActionRow` becomes the default for iOS/iPadOS/web_narrow. Other platforms read `UI::InlineActionRow` as default — but that class doesn't exist yet (10B.1a). For 10B.0, the resolver returns `UI::SwipeActionRow` for all platforms as a placeholder + emits a runtime warning when platform != iOS/iPadOS/web_narrow:

```crystal
# In UI::Intent.resolve for :swipe_actions:
case context.platform
when :ios, :ipados, :web_narrow
  UI::SwipeActionRow
else
  # Phase 10B.1a target: UI::InlineActionRow is missing.
  Log.warn { "UI::InlineActionRow not yet implemented (10B.1a target); falling back to SwipeActionRow on #{context.platform}" }
  UI::SwipeActionRow
end
```

This is the bridge state — 10B.1a removes the warning by introducing `UI::InlineActionRow`.

### Deliverable 6 — Capability validation

When an app/screen registers an override, the registry validates:
- The override widget class has methods matching the declared capabilities.
- If validation fails, raise at registration time (NOT at resolve time) so apps fail fast.

Capabilities are declared per-intent in `intent-routing-candidates.md`. For `:swipe_actions` (after 10-pre.1 trim): 7 active capabilities.

### Deliverable 7 — Specs

Spec coverage:

- `spec/web/ui/intent_spec.cr`:
  - `resolve(:swipe_actions, ios_context)` returns `UI::SwipeActionRow`.
  - `resolve(:swipe_actions, macos_context)` returns `UI::SwipeActionRow` with warning (placeholder for 10B.1a).
  - Override at app-level overrides default.
  - Override at screen-level overrides app-level.
  - Capability validation rejects malformed override.

- `spec/web/ui/intent_reactivity_spec.cr`:
  - Build screen → resolve runs.
  - Mutate state → rebuild screen → resolve runs again (verify via spy/mock).
  - Register override → rebuild → new widget.
  - Mutate state + override change → rebuild → both reflected.

### Deliverable 8 — Close handoff

`docs/initiative-cross-platform-ui/handoff/phase-10-b-0-close.md`:

- API surface summary.
- Spec coverage report.
- Reactivity proof: specs demonstrate state-mutation-then-rerender.
- Any architectural gaps surfaced (e.g. if `ActionDispatcher` doesn't actually call `screen.build(ctx)` after every mutation).
- Codex content review verdict.

## 5. Workflow

1. `git checkout -b phase-10-b-0 phase-10`.
2. Read all the listed files. Map the existing `UI::App` / `UI::Screen` / `ActionDispatcher` loop.
3. Implement `src/ui/intent.cr` (Deliverable 1).
4. Extend `UI::App` with override API (Deliverable 2).
5. Extend `UI::Screen` with override API (Deliverable 3).
6. Wire `:swipe_actions` resolver case (Deliverable 5).
7. Add capability validation (Deliverable 6).
8. Specs (Deliverable 7) — write reactivity specs FIRST to drive the design.
9. Run `crystal spec spec/web/ui/intent_spec.cr spec/web/ui/intent_reactivity_spec.cr` — must pass.
10. Verify `crystal build src/asset_pipeline.cr` still passes (no regression).
11. Write close handoff (Deliverable 8).
12. Incremental commits per deliverable.
13. Standard footer.

## 6. Acceptance gate

- ✅ `UI::Intent.resolve` API exists + tested.
- ✅ App + screen override APIs exist + tested with precedence.
- ✅ Capability validation rejects malformed override (spec proves).
- ✅ Reactivity specs pass — state mutation + rerender preserves override.
- ✅ Existing `UI::SwipeActionRow` wired via resolver (with placeholder warning for non-iOS).
- ✅ `crystal spec` passes including new specs.
- ✅ `crystal build src/asset_pipeline.cr` passes.
- ✅ Codex content review APPROVE.

## 7. Out of scope

- New widget implementations (10B.1a–10B.5).
- LSP rules (10A.0).
- Spec directory reorganization (10C.0 — parallel sub-phase).
- Catalog or backlog edits.
- Owner involvement.

## 8. What success looks like

After 10B.0, an app author can write:

```crystal
# In app code
MyApp.override_intent(:swipe_actions, MyCustomActionRow, capabilities: {supports_edge_trailing: true})

# In screen build
def build(ctx)
  action_row_class = UI::Intent.resolve(:swipe_actions, ctx)
  action_row = action_row_class.new(content: row_content, trailing_actions: [...])
  # ...
end
```

And it works. State mutation triggers re-render. Override changes apply on next render. Capabilities are validated upfront. The keystone Class A contract has a real implementation.

— Architect (Claude Opus 4.7), 10B.0 brief v1
