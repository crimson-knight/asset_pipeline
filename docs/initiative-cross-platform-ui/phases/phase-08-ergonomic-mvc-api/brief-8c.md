# Phase 8C — `routes_for(UI::App)` Amber-Router Contribution

**Date opened:** 2026-05-24 (draft, pending 8B close)
**Authored by:** Architect (Codex critique before dispatch)
**Branch:** to be cut as `phase-08c-routes-for-app` from feature branch after Phase 8B merges.
**Codex protocol:** Per-iteration critique. No self-assessment.

---

## Why this phase exists

Phase 8A shipped `UI::ScreenHelpers#compute_screen_html` so Amber controllers can render `UI::Screen` view trees. Phase 8B ships `UI::App` declarative screen registry so native apps can drive navigation declaratively.

**Phase 8C closes the loop:** the SAME `UI::App` declaration that drives native navigation ALSO contributes web routes to an Amber router. Authors write the screen + controller map once; both targets consume it.

Today (post-8A + post-8B):

```crystal
# Web target — config/routes.cr (Amber-style, manual)
Amber::Server.configure do
  routes :web do
    get  "/",               SignInController, :index
    post "/sign_in/submit", SignInController, :submit
    get  "/todos",          TodosController,  :index
    # ... must enumerate every route by hand ...
  end
end

# Native target — separate UI::App declaration
class SpikeApp < UI::App
  initial_route :sign_in
  screen :sign_in, SignInController
  screen :todos,   TodosController
end
```

After 8C:

```crystal
# Single source — used by BOTH web and native
class SpikeApp < UI::App
  initial_route :sign_in
  screen :sign_in, SignInController, path: "/", web_actions: [
    {verb: :get,  action: :index},
    {verb: :post, action: :submit, path: "/sign_in/submit"},
  ]
  screen :todos, TodosController, path: "/todos"
end

# Web target — config/routes.cr
Amber::Server.configure do
  routes :web do
    plug UI::AmberIntegration.routes_for(SpikeApp)
    # Plus any other manual Amber routes the app needs.
  end
end

# Native target — unchanged
SpikeApp.launch_macos  # or launch_ios
```

The `routes_for(UI::App)` helper walks `UI::App.screens` + each registration's `web_actions` and contributes `get`/`post`/`put`/`patch`/`delete` calls to the Amber router. Each route's controller-action binding goes through the Amber controller (the one that inherits `Amber::Controller::Base + include UI::ScreenHelpers` from 8A) — NO wrapping.

---

## Environment assumptions

1. Phase 8B has merged. `UI::App` + `UI::Controller` + `UI::ActionDispatcher` + `UI::FormState` shipped.
2. Phase 8A's `UI::ScreenHelpers` mixin still works as the rendering path on web.
3. `samples/phase-08-amber-spike/` is the proven web spike harness — used here as the test target.
4. The web app's controllers still inherit `Amber::Controller::Base` (not `UI::Controller`). Phase 8C is about ROUTE registration, not controller-class unification.

---

## Scope — 3 items

### Item 1 — Extend `UI::App::ScreenRegistration` with web route metadata

Add optional fields to the existing `ScreenRegistration` record (shipped in Phase 8B):

```crystal
record ScreenRegistration,
  route_id : Symbol,
  controller_class : UI::Controller.class,
  screen_class : UI::Screen.class,
  # NEW IN 8C:
  web_path : String? = nil,         # e.g. "/sign_in" or "/todos/:id"
  web_actions : Array(WebAction) = [] of WebAction

record WebAction,
  verb : Symbol,             # :get / :post / :put / :patch / :delete
  action : Symbol,           # controller method name
  path : String? = nil       # nil => screen's web_path; non-nil overrides
```

Extend `UI::App.screen` macro to accept these as keyword args:

```crystal
class SpikeApp < UI::App
  screen :sign_in, SignInController, path: "/", web_actions: [
    UI::App::WebAction.new(verb: :get,  action: :index),
    UI::App::WebAction.new(verb: :post, action: :submit, path: "/sign_in/submit"),
  ]
end
```

If `web_actions` is empty AND `web_path` is set, default to `:get -> :index` at `web_path`.

**Acceptance:** `UI::App::ScreenRegistration` carries the new fields. Specs cover the convention + override behavior.

### Item 2 — `UI::AmberIntegration.routes_for(UI::App.class)` helper

`src/asset_pipeline/amber_integration.cr` already has `UI::ScreenHelpers` + `UI::ScreenContext::Web`. Phase 8C extends with `UI::AmberIntegration` module + a `routes_for` macro that emits Amber router calls at compile time:

```crystal
module UI::AmberIntegration
  # Contribute UI::App's screen registry to an Amber router as web
  # routes. Used inside Amber::Server.configure { routes :web do ... } }.
  #
  # Compile-time: walks the UI::App class's SCREENS hash and emits
  # `get`/`post`/`put`/etc. calls per screen's web_actions.
  #
  # Usage:
  #   routes :web do
  #     UI::AmberIntegration.routes_for(SpikeApp)
  #   end
  macro routes_for(app_class)
    {% screens = app_class.resolve.constant(:SCREENS) %}
    {% for route_id, reg in screens %}
      {% for action in reg.web_actions %}
        {% verb = action.verb %}
        {% path = action.path || reg.web_path %}
        {% next unless path %}
        {{ verb.id }} {{ path }}, {{ reg.controller_class }}, {{ action.action }}
      {% end %}
    {% end %}
  end
end
```

**Caveat (Codex critique target):** Amber's routes DSL accepts `get path, Controller, :method` only inside its `routes :web do ... end` block. The macro expansion must produce that exact form. The Implementer verifies via the spike's `config/routes.cr` — replacing manual route calls with `UI::AmberIntegration.routes_for(SpikeApp)` should produce identical routing behavior.

**Acceptance:** spike app's `config/routes.cr` replaces its manual `get`/`post` block with `UI::AmberIntegration.routes_for(SpikeApp)`. Browser GET + POST gates from Phase 8A still pass. `crystal spec` preserved.

### Item 3 — Spike migration + browser regression proof

Update `samples/phase-08-amber-spike/`:

1. Add `class SpikeApp < UI::App` declaration with `screen :sign_in, SignInController, path: "/", web_actions: [...]`.
2. Replace `config/routes.cr` manual route block with `UI::AmberIntegration.routes_for(SpikeApp)`.
3. Rebuild + re-run + re-run the Phase 8A browser POST proof (Selenium driver). Confirm same behavior.
4. New screenshot evidence: `findings-browser-after-routes-for.png` showing the routes-for-driven app behaves identically.

**Acceptance:** browser POST proof still passes. Same HTTP 200 + flash notice. `findings-browser-after-routes-for.png` captured.

---

## Codex protocol — NO EXCEPTIONS

Per-iteration Codex review at `handoff/phase-08c-codex-N.md`. No self-assessment.

Iteration boundaries:
- iter 1: Items 1 + 2 (extend ScreenRegistration + ship routes_for macro)
- iter 2: Item 3 (spike migration + browser regression proof)

---

## Acceptance you must meet

- `crystal spec` baseline preserved.
- Spike's `config/routes.cr` uses `UI::AmberIntegration.routes_for(SpikeApp)` (no manual `get`/`post` per route).
- Browser POST proof passes (regression check vs Phase 8A baseline).
- 2 Codex reviews committed.
- Voyager UNCHANGED.
- `grep -rE "voyager-(save-chain|interaction-proof)"` returns 0.

## Hard rules

- Forward commits only on `phase-08c-routes-for-app`.
- NO native side changes — Phase 8B's UI::App/Controller/Dispatcher stay.
- NO new sentinels or design-token changes.
- NO macro file generation (Codex rejected in Phase 8A; same rule).
- Standard Claude co-author footer.
- If the routes_for macro can't emit valid Amber router calls (e.g. Amber's DSL refuses the macro-expanded form), STOP and escalate — do NOT introduce a runtime route-registration shim as a workaround. The compile-time macro IS the design.

## Reporting

Write `handoff/phase-08c-implementer-report.md`. Return to architect with: branch HEAD, commit count, Codex verdicts, screenshot paths.

---

**Status: DRAFT — awaiting Phase 8B close before Codex critique pass.**
