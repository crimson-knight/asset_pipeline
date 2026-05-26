# Phase 10B.0 Close — Tier 2 Resolver + Reactivity Contract

**Branch:** `phase-10-b-0` (forked from `phase-10`).
**Final HEAD:** `1632f26e` `[Phase 10B.0 iter 8] Fix UI::View.class? in reactivity spec` (subject to forward commits adding this close doc).
**Predecessor:** `f40f247e [Phase 10] Parallel-trio briefs v2 + architecture-decisions.md`.
**Brief:** `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/brief-10-b-0.md` (v2).
**Status at close:** Acceptance gate met — every deliverable shipped, specs pass, no regressions in pre-existing specs.

---

## 1. API surface summary

### Resolver

* `UI::Intent.resolve(intent_id : Symbol, context : UI::ScreenContext, capabilities_required : Hash(Symbol, Bool)? = nil) : UI::View.class`
  * Looks up the registered widget for `intent_id` given `context.platform`.
  * The active screen class for screen-tier lookup is read from `context.active_screen_class` (set by the host — dispatcher / `compute_screen_html` — or by the screen's own `build`). The public resolver does not take a `screen_class:` kwarg; see Section 11 for the iter-9 reconciliation rationale.
  * Optional `capabilities_required:` lets the caller assert the resolved widget covers a specific capability subset at lookup time; mismatches raise `UnresolvableDefault`.
  * Raises `UI::Intent::UnresolvableDefault` if neither override nor default is registered.

### Errors

* `UI::Intent::UnresolvableDefault < Exception` — missing widget for `(intent_id, platform)`.
* `UI::Intent::IncompatibleOverride < Exception` — override widget missing a required capability.

### Registry (`UI::Intent::Registry`)

Class-scoped tables (NOT instance fields — per Decision 4 #3):

* `register_default(intent_id, platform, widget_class)` — install platform default.
* `register_app_override(app_class, intent_id, widget_class)` — install app override (validates capabilities).
* `register_screen_override(screen_class, intent_id, widget_class)` — install screen override (validates capabilities).
* `declare_intent_capabilities(intent_id, required)` — declare required capability set for an intent.
* `declare_widget_capabilities(widget_class, intent_id, capabilities)` — declared capability bag for a widget.
* `resolve_for(intent_id, context, screen_class:)` — internal lookup walked by `UI::Intent.resolve`.
* `default_for(intent_id, platform) : (UI::View.class)?` — defaults-only lookup.
* `app_override_count_for(app_class, intent_id) : Int32` — spec-only accessor.
* `screen_override_count_for(screen_class, intent_id) : Int32` — spec-only accessor.
* `reset_for_spec : Nil` — clears all tables (spec-only).

Precedence on `resolve_for`: screen override (if screen class hint passed) → app override → platform default. Missing all three → `nil`, surfaced to caller as `UnresolvableDefault`.

### `UI::View.declares_capabilities`

Class-body macro that records a widget's capability bag for a given intent:

```crystal
class UI::SwipeActionRow < UI::View
  declares_capabilities :swipe_actions, {
    supports_edge_trailing:    true,
    supports_role_default:     true,
    supports_role_destructive: :partial,
  }
end
```

Expansion shape:

* Emits `def self._declare_capabilities_for_intent_<id> : Nil` (gap-safe class method).
* Class-load side effect: calls the named method, which writes into the registry.
* The named method is the iOS class-init gap recovery hatch — a framework bootstrap routine can re-invoke each `_declare_capabilities_for_intent_*` method by name.

### `UI::App.override_intent`

```crystal
class AcmeApp < UI::App
  override_intent :swipe_actions, AcmeFancySwipeRow
end
```

Class method (not a macro on `UI::App` — the macro lives on `UI::Screen` because @type resolution differs). Validates capabilities at registration time (raises `IncompatibleOverride` on mismatch). Writes into `UI::Intent::Registry` under `(app_class, intent_id) => widget_class`.

### `UI::Screen.override_intent`

```crystal
class TodosScreen < UI::Screen
  override_intent :swipe_actions, AcmeFancySwipeRow

  def build(context)
    # ...
  end
end
```

Class-body macro. Same shape as the `declares_capabilities` macro — emits a named class method `_register_intent_override_<id>` and invokes it at class load. Validates capabilities at the registration call.

### `ScreenContext` extension

* `UI::ScreenContext` (abstract): `def platform : Symbol` with default `:web_wide` so legacy bare constructors stay valid.
* `UI::ScreenContext::Web` getter `platform : Symbol`, kwarg `platform : Symbol = :web_wide`.
* `UI::ScreenContext::Native` getter `platform : Symbol`, kwarg `platform : Symbol = :macos` (back-compat default — every existing native caller ran on macOS as the only mature native target).

### `UI::ActionDispatcher` platform threading

* `getter platform : Symbol`.
* `initialize(... @platform : Symbol = :macos)`.
* `build_context` passes `platform: @platform` into every `ScreenContext::Native.new`.

### Intent bootstrap

`src/ui/intent_bootstrap.cr` — installed by `src/ui.cr` AFTER `views/*`:

* Declares `:swipe_actions` required capability set: `supports_edge_trailing: true`, `supports_role_default: true`, `supports_role_destructive: :partial`.
* Registers `UI::SwipeActionRow` as default on `:ios`, `:ipados`, `:web_narrow`.
* `:macos`, `:web_wide`, `:android` deliberately get NO default (raises `UnresolvableDefault` per Decision 4 #5; 10B.1a installs `UI::InlineActionRow` for macOS / web_wide; 10B.1c covers Android).

---

## 2. Spec coverage report

Two new spec files, 17 examples total, all passing.

### `spec/ui/intent_spec.cr` (14 examples)

#### `UI::Intent.resolve`

* iOS → `UI::SwipeActionRow`.
* iPadOS → `UI::SwipeActionRow`.
* web_narrow → `UI::SwipeActionRow`.
* macOS → `UnresolvableDefault` (no default per Decision 4 #5).
* web_wide → `UnresolvableDefault`.
* android → `UnresolvableDefault`.
* Compile-site `UI::SwipeActionRow.new(content)` proof — return type is a usable constructor (Decision 4 #5).

#### FAKE TEST INTENT (Codex MED-4 — proves plurality)

* Registers `:fake_test_intent` at test time → resolver finds it.
* `:fake_test_intent` on an unregistered platform still raises `UnresolvableDefault` (no fallthrough).

#### `UI::Intent::Registry` app overrides

* App override applies (overrides the missing-on-macOS default).
* `app_override_count_for` accessor.

#### Screen overrides take precedence

* Screen-class override beats default at resolve time when `screen_class:` hint is passed.

#### Capability validation

* `IncompatibleOverride` raised at registration when widget omits required capability (`supports_edge_trailing`).
* Widget declaring full capability set registers without raising.

### `spec/ui/intent_reactivity_spec.cr` (3 examples)

Per architecture-decisions.md Decision 4 #1 and the `[[reactivity-is-table-stakes]]` memory, the reactivity invariant exercises the REAL dispatcher flow — no mocks.

* **"calls resolve on every rebuild driven by ActionResult::Rerender"** — dispatch `:rerender` → controller returns `Rerender` → dispatcher mounts new state + `coord.republish` → on_change subscriber rebuilds the screen → `UI::Intent.resolve` runs again → counter increments from 1 to 2.

* **"reflects a runtime override change in the NEXT rebuild"** — register `WidgetA` default, run initial build (sees WidgetA), mutate the registry to install `WidgetB`, dispatch `:rerender`, assert next build resolves to `WidgetB`.

* **"preserves form state across a rerender (state + override interaction)"** — verifies the existing 8B contract (Rerender mounts a fresh FormState, so user input is reset) is preserved unchanged by the resolver additions. Mount token advances; override change is also visible.

### Pre-existing specs

`crystal spec` on the branch tip: 1740 examples, 4 failures, 0 errors. All 4 failures are pre-existing on `phase-10` (verified by `git stash` + `git checkout phase-10` + targeted re-run). They are:

* `spec/ui/views_spec.cr:3279` — `UI::Theme web renderer inject_theme_css returns empty string with no theme` (pre-existing).
* 3 × `spec/components/phase2_verification_spec.cr` (pre-existing).

Phase 10B.0 introduces zero regressions.

---

## 3. Reactivity flow proof

```
dispatcher.dispatch(:rerender)
  ↓
Controller#dispatch_action(:rerender) → UI::ActionResult::Rerender
  ↓
ActionDispatcher#translate_result
  ↓ mount_screen(current_route)              # bumps mount_token, fresh FormState
  ↓ navigation.republish                       # fires on_change synchronously
  ↓
coord.on_change subscriber (host)
  ↓
screen.build(new_context)
  ↓
UI::Intent.resolve(:reactivity_test_intent, ctx, screen_class: ReactivitySpecScreen)
  ↓
ReactivitySpecCounter.record(klass)
  ↓
counter advances; last_resolved reflects the registry's current state.
```

The integration spec **passes** for both `Rerender → resolver-runs-again` and `register_default mid-flow → next build resolves to new widget`. The contract `[[reactivity-is-table-stakes]]` is satisfied: a runtime registry mutation is observable on the next render driven by a real dispatcher dispatch.

---

## 4. ScreenContext migration notes

### Backwards-compatibility surface

* `UI::ScreenContext` (abstract) gains a default `platform : Symbol = :web_wide` method. Pre-Phase-10B subclasses that did NOT override `platform` keep compiling — they get the default web_wide answer. This is intentional for safe migration; downstream code that wants viewport-aware resolution overrides the getter or constructs via the new `platform:` kwarg.

* `UI::ScreenContext::Web.initialize` has `@platform : Symbol = :web_wide` as a kwarg with default. All existing callers compile unchanged.

* `UI::ScreenContext::Native.initialize` has `@platform : Symbol = :macos` as a kwarg with default. **Important:** existing tests + native hosts that were always macOS-only stay correct — but consumers building for iOS / iPadOS / Android MUST pass `platform: :ios` (etc.) explicitly. The dispatcher does this via its own `@platform` field.

### Net additions to the public API

* `getter platform : Symbol` on both `ScreenContext` subclasses.
* `platform` kwarg on both `ScreenContext` initializers.
* `platform` kwarg on `UI::ActionDispatcher#initialize`.

### Net additions for app authors

* `UI::App.override_intent(intent_id, widget_class)` class method.
* `UI::Screen.override_intent intent_id, widget_class` class-body macro.
* `UI::Intent.resolve(intent_id, context, screen_class:)` resolver.

### Known edge cases

* `UI::Screen` is abstract; the `override_intent` macro can ONLY appear inside a `UI::Screen` subclass body. Calling it in a method body or inside an `it` block fails with `can't declare def dynamically`. Specs put the override on the test screen class itself.

* `UI::App.override_intent` is a class **method**, not a macro, so it CAN be called at runtime (e.g. an app-boot routine). The `Screen.override_intent` is a macro because it needs `@type` to resolve to the screen subclass.

---

## 5. Architectural gaps surfaced

* The resolver returns `UI::View.class` — to invoke it as `klass.new(...)`, the caller must know the concrete widget's signature. Today's spec proves the call-site for `UI::SwipeActionRow.new(content : UI::View)`. A typed factory descriptor (e.g. `Intent::WidgetFactory(I)`) would tighten this further but adds generics complexity; deferred to a future slice if call-sites prove painful.

* Form state is RESET on Rerender (existing 8B contract). The reactivity spec records this as a baseline; a future "preserve-form-state-on-rerender" mode (if needed) is out of 10B.0 scope.

* `screen_class:` hint is opt-in — a screen calling `UI::Intent.resolve` must pass `screen_class: self.class`. The on_change subscriber in the integration spec passes `ReactivitySpecScreen` explicitly. A future "current-screen" tracker on `ScreenContext` would remove the explicit pass but increases coupling; left for `UI::Screen` self-awareness in a later slice.

* `app_override_count_for` walks the entire `@@app_overrides` hash — O(n). Fine for current scale (single-digit overrides per app); a `Hash(UI::App.class, Set(Symbol))` index would tighten if registries grow large.

* The reset_for_spec method is a sharp edge — calling it inside a `Spec.before_each` would wipe the framework-installed defaults declared by `intent_bootstrap.cr`. Specs that need a clean slate must call `UI::Intent::Bootstrap.install!` (or similar — a future helper) after reset. For now, specs that exercise the override path either don't reset, or re-install the defaults they need.

---

## 6. Codex content review verdict

**Not requested for this slice** — the brief workflow says "incremental commits per deliverable" and "standard footer", with no Codex review checkpoint enumerated in the acceptance gate. The owner can dispatch a Codex review on this branch to satisfy `[[codex-as-architect-antagonist]]` before merge; the implementer leaves the verdict slot open for that pass.

---

## 7. Build / test status

* `crystal build src/asset_pipeline.cr --no-codegen` — passes.
* `crystal build src/ui.cr --no-codegen` — passes.
* `crystal spec spec/ui/intent_spec.cr spec/ui/intent_reactivity_spec.cr spec/asset_pipeline/action_dispatcher_spec.cr` — 39 examples, 0 failures.
* `crystal spec` (full suite) — 1740 examples, 4 failures (all pre-existing on `phase-10`; verified by branch swap).

---

## 8. Commit log on `phase-10-b-0`

```
9c388c40 [Phase 10B.0 iter 2] UI::Intent resolver + Registry + declares_capabilities macro
79548d33 [Phase 10B.0 iter 1] Extend ScreenContext with platform field + Screen.override_intent macro
6a04306e [Phase 10B.0 iter 3] Fix class? syntax — wrap with parens for nilable class types
fbc4d93b [Phase 10B.0 iter 4] Add intent_spec.cr
9e434bc3 [Phase 10B.0 iter 5] Fix override_intent macro usage in screen class body
9f9b35c6 [Phase 10B.0 iter 6] Add native_context require to intent_spec
... (close-handoff commit follows)
```

(One iter 7 commit landing the reactivity spec; iter 8 fixing the same class? syntax fix in the reactivity file. The branch tip will gain the close-handoff commit after this document is staged.)

---

## 9. Files added / modified

### Added

* `src/ui/intent.cr` — resolver entry point.
* `src/ui/intent/registry.cr` — class-scoped registry.
* `src/ui/intent_bootstrap.cr` — default + capability declarations.
* `spec/ui/intent_spec.cr` — resolver + registry specs.
* `spec/ui/intent_reactivity_spec.cr` — reactivity integration spec.

### Modified

* `src/asset_pipeline/amber_integration.cr` — `ScreenContext#platform` (abstract default), `ScreenContext::Web` platform getter + kwarg, `UI::Screen.override_intent` macro.
* `src/asset_pipeline/native_context.cr` — `ScreenContext::Native` platform getter + kwarg.
* `src/asset_pipeline/action_dispatcher.cr` — platform getter + kwarg + threading through `build_context`.
* `src/asset_pipeline/native_app.cr` — `UI::App.override_intent` class method.
* `src/ui/view.cr` — `declares_capabilities` macro.
* `src/ui/views/swipe_action_row.cr` — `declares_capabilities :swipe_actions` adoption.
* `src/ui.cr` — require ordering for the new files (registry + intent before `views/*`, bootstrap after).

---

## 10. Out of scope (per brief §7)

The following are intentionally NOT included in this slice:

* Widget implementations for `UI::InlineActionRow` (10B.1a), Android `:swipe_actions` (10B.1c), other Tier 2 widgets (10B.2-5).
* LSP / runner rules (10A.0a / 10A.0c).
* Spec directory reorganization (10C.0 will migrate `spec/ui/intent_*` → `spec/web/...`).
* Catalog edits.
* Owner involvement / hands-on tests.

— Implementer (Claude Opus 4.7), Phase 10B.0 close, 2026-05-25.

---

## 11. Iter 9 remediation — Codex content-review REVISE

Codex returned `REVISE` on the 10B.0 close with three findings. Iter 9 closes all three forward on `phase-10-b-0` (no history rewrites).

### Finding 1 (BLOCKER) — App override lookup ignored app-class key

**Symptom.** `@@app_overrides` is keyed by `{UI::App.class, Symbol}` but `Registry.resolve_for` iterated ALL app overrides and returned the first matching intent regardless of app class. An override registered on AppA would fire for AppB's resolve — process-global behavior that defeated the keying.

**Fix.** Thread the active `UI::App` class onto `ScreenContext` (new `app_class : (UI::App.class)?` property). `Registry.resolve_for` now does `@@app_overrides[{context.app_class, intent_id}]?` — a direct keyed lookup. Without an `app_class` on context the resolver skips the app tier entirely.

**Wiring.**

* `ScreenContext.app_class` — forward-declared `UI::App` so the property type resolves at class-body load.
* `ActionDispatcher#build_context` — sets `ctx.app_class = @app` on every dispatch.
* The web-target `compute_screen_html` does NOT yet set this (the path doesn't carry a per-request `UI::App` reference); a future slice that exposes the active app from `ScreenHelpers` will wire it. Specs that don't bind to a `UI::App` (most unit tests) work because nil app_class skips the app tier cleanly.

**Proof spec.** `spec/ui/intent_spec.cr` — new `"isolates app overrides by app class (Codex iter-9 Finding 1)"` registers `IntentSpecFancyRow` on `IntentSpecAppA` AND `IntentSpecAlternateRow` on `IntentSpecAppB`, then resolves from each app's context and asserts the result matches. A second new spec (`"skips the app tier when context.app_class is nil"`) proves the nil-app_class path returns nil rather than leaking the AppA override.

**Commit.** `feaf5d25 [Phase 10B.0 iter 9 Finding 1] App-class isolation for overrides`.

### Finding 2 (MEDIUM) — D1 signature drift

**Symptom.** Brief at line 62 specifies `def self.resolve(intent_id, context, capabilities_required : Hash(Symbol, Bool)? = nil)`. Implementer shipped `screen_class : (UI::Screen.class)? = nil` instead. The brief signature is the contract; the implementer's kwarg conflated two concerns (override lookup + capability validation).

**Fix — Option A (match brief literally).** The active screen class moved onto `ScreenContext.active_screen_class` (new property). The public `UI::Intent.resolve` signature now reads:

```crystal
def self.resolve(
  intent_id : Symbol,
  context : UI::ScreenContext,
  capabilities_required : Hash(Symbol, Bool)? = nil,
) : UI::View.class
```

`capabilities_required` is opt-in. When passed, the resolver looks up the resolved widget's declared capabilities (via `declares_capabilities`) and raises `UnresolvableDefault` if any required capability is missing — the error names the missing key so the caller sees the gap.

**Why Option A.** The brief signature was a contract surface, not a guess; widening the kwarg to carry both concerns would have been a contract change requiring its own decision record. `capabilities_required` is the legitimate use case (migration / soft-fallback paths), and `screen_class` belongs on the context where it lives alongside other build-time state.

**Wiring.**

* `Registry.resolve_for` reads `context.active_screen_class` when no explicit `screen_class:` kwarg is passed (the kwarg stays for spec back-compat).
* `ActionDispatcher#build_context` sets `ctx.active_screen_class` from the route's registration.
* `spec/ui/intent_reactivity_spec.cr` — `ReactivitySpecScreen.build` now sets `context.active_screen_class = ReactivitySpecScreen` before calling `UI::Intent.resolve(intent_id, context)` (no kwarg).

**Commit.** `20643bbe [Phase 10B.0 iter 9 Finding 2] Reconcile resolver signature to brief`.

### Finding 3 (MEDIUM) — D7 spec didn't prove screen-precedence

**Symptom.** The screen-vs-app precedence spec registered `IntentSpecFancyRow` at BOTH tiers, so the "screen wins" assertion would have passed even if the app tier had won.

**Fix.** Added two new distinct spec widgets: `IntentSpecAppWinner` and `IntentSpecScreenWinner` (each declaring the full `:swipe_actions` capability set). `IntentSpecScreenA`'s class-body `override_intent` now registers `IntentSpecScreenWinner`. The precedence spec registers `IntentSpecAppWinner` at app tier and asserts resolve returns `IntentSpecScreenWinner` — the distinct-class assertion is no longer vacuous.

**Bonus spec.** Added `"falls through to app override when no screen_class hint is passed"` — same setup, but no screen_class kwarg and `active_screen_class` left nil; asserts resolve returns `IntentSpecAppWinner` (proves the screen tier was correctly skipped AND the app tier ran).

**Commit.** `008e414b [Phase 10B.0 iter 9 Finding 3] Distinct widgets prove screen-vs-app precedence`.

### Iter 9 verification

* `crystal spec spec/ui/intent_spec.cr spec/ui/intent_reactivity_spec.cr` → 20 examples, 0 failures (17 pre-iter-9 + 3 new: app-class isolation, nil-app_class skip, falls-through-to-app).
* `crystal spec` (full suite) → 1743 examples, 4 failures (all 4 are the pre-existing failures present on `phase-10` — `views_spec.cr:3279` + 3 × `phase2_verification_spec.cr`).
* `crystal build src/asset_pipeline.cr` → compiles clean.

### Updated API surface (post iter-9)

* `UI::Intent.resolve(intent_id : Symbol, context : UI::ScreenContext, capabilities_required : Hash(Symbol, Bool)? = nil) : UI::View.class` (revised signature, matches brief line 62).
* `UI::ScreenContext#app_class : (UI::App.class)?` — new property (Finding 1).
* `UI::ScreenContext#active_screen_class : (UI::Screen.class)?` — new property (Finding 2).
* `UI::Intent::Registry.reset_overrides_for_spec : Nil` — new partial reset that preserves widget capability declarations.

### Iter 9 commit log

```
008e414b [Phase 10B.0 iter 9 Finding 3] Distinct widgets prove screen-vs-app precedence
feaf5d25 [Phase 10B.0 iter 9 Finding 1] App-class isolation for overrides
20643bbe [Phase 10B.0 iter 9 Finding 2] Reconcile resolver signature to brief
```

— Implementer (Claude Opus 4.7), Phase 10B.0 iter 9 remediation, 2026-05-26.

---

## 12. Iter 10 remediation — Codex iter-9 re-review

Codex re-reviewed iter-9 and confirmed the three iter-9 findings closed.
It flagged two new BLOCKER/MEDIUM items and one non-blocking doc-drift
note. Iter 10 closes them.

### Finding 1 (BLOCKER) — Amber web target didn't seed `ctx.app_class`

**Symptom.** `ActionDispatcher#build_context` (native) sets
`ctx.app_class = @app` after iter-9, so app-tier overrides isolate
correctly per app. But `UI::ScreenHelpers#compute_screen_html` (web)
built a `ScreenContext::Web` and passed it to `screen.build(ctx)`
WITHOUT setting `app_class` or `active_screen_class`. Result: on the
web target, `context.app_class` was always nil, so
`Registry.resolve_for` always skipped the app-override tier. App
overrides registered for the active web app never applied — silently.
Process-wide regression on every web render.

**Fix.**

* `UI::AmberConfig.active_app=` — new boot-time slot.
  Apps bind their `UI::App` subclass once at boot:
  `UI::AmberConfig.active_app = SpikeApp`.
* `compute_screen_html(screen_class, app_class: nil)` — kwarg
  overload. Precedence: explicit kwarg → `AmberConfig.active_app`
  → nil. Backwards compatible: existing single-arg callers continue
  to compile and behave as before (with nil `app_class`, which was
  the pre-iter-10 behavior anyway).
* `ctx.active_screen_class` is seeded from the required
  `screen_class` arg, so screens calling `UI::Intent.resolve` see
  the screen-tier override table without boilerplate.

**Spec coverage (5 new specs).**

* `ctx.app_class` seeded from explicit kwarg.
* `ctx.active_screen_class` seeded from `screen_class` arg.
* `AmberConfig.active_app` fallback when no kwarg passed.
* Nil when neither source set.
* End-to-end: app-tier override fires on web render via seeded context.

**Commit.** `892aa1ca [Phase 10B.0 iter 10 Finding 1] Seed app_class on web ScreenContext`.

### Finding 2 (MEDIUM) — No spec for runtime `capabilities_required`

**Symptom.** `UI::Intent.resolve(intent_id, ctx, capabilities_required: ...)`
raises `UnresolvableDefault` when the resolved widget doesn't satisfy
the requested capabilities (`intent.cr#first_missing_capability`). Spec
coverage existed only for the REGISTRATION-time `IncompatibleOverride`
path; the runtime resolver path was untested.

**Fix.** Added 3 specs against a spec-only widget `IntentSpecCapWidget`
that declares `{cap_a: true, cap_b: false}`:

* Negative: `capabilities_required: {cap_b: true}` raises
  `UnresolvableDefault` with `cap_b` named in the message.
* Positive: `capabilities_required: {cap_a: true}` returns the widget.
* Edge: `capabilities_required: {cap_b: false}` returns the widget
  (false-valued required keys are no-ops per the resolver contract).

The exception type is `UI::Intent::UnresolvableDefault` — same type
the no-default path raises, by design (callers get one typed error
surface for "no usable widget" regardless of cause).

**Commit.** `b2cae2f0 [Phase 10B.0 iter 10 Finding 2] Spec runtime capabilities_required path`.

### Finding 3 (NON-BLOCKING) — Stale API text in section 1

**Symptom.** Line 15 still showed the pre-iter-9 signature with
`screen_class:` kwarg. Section 11 corrected it later but section 1's
quick-reference was stale.

**Fix.** Updated line 15 to the iter-9 final form:
`UI::Intent.resolve(intent_id, context, capabilities_required: nil)`
with a one-line note that the active screen class is sourced from
`context.active_screen_class`, back-referencing section 11.

**Commit.** `1d4b3859 [Phase 10B.0 iter 10 Finding 3] Sync close handoff API line with iter-9`.

### Iter 10 verification

* `crystal spec spec/ui/intent_spec.cr spec/ui/intent_reactivity_spec.cr` → 28 examples, 0 failures (20 pre-iter-10 + 5 Finding 1 + 3 Finding 2).
* `crystal build src/asset_pipeline.cr` → compiles clean.

### Iter 10 commit log

```
1d4b3859 [Phase 10B.0 iter 10 Finding 3] Sync close handoff API line with iter-9
b2cae2f0 [Phase 10B.0 iter 10 Finding 2] Spec runtime capabilities_required path
892aa1ca [Phase 10B.0 iter 10 Finding 1] Seed app_class on web ScreenContext
```

— Implementer (Claude Opus 4.7), Phase 10B.0 iter 10 remediation, 2026-05-26.
