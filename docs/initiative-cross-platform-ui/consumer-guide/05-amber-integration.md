# Amber Integration (Full-Server Web)

This section covers how to drive the asset_pipeline cross-platform UI
system (`UI::View` tree → `UI::Web::Renderer`) as the view layer of a
full-server **Amber** web app.

Where the native targets (macOS / iOS / Android) run the live action
loop through `UI::ActionDispatcher`, the full-server web target reuses
Amber's own request lifecycle, routing, sessions, flash, and CSRF. The
asset_pipeline integration stays deliberately narrow: it does **not**
wrap `HTTP::Server::Context`, does **not** replace Amber's `render`
macro, and does **not** introduce a new routing layer. It contributes a
screen base class, a per-request context, a controller mixin, and a
compile-time route generator.

The canonical source is
[`src/asset_pipeline/amber_integration.cr`](../../../src/asset_pipeline/amber_integration.cr)
and [`src/asset_pipeline/native_app.cr`](../../../src/asset_pipeline/native_app.cr)
(the `UI::App` + `screen` macro). The working reference app is
[`samples/phase-08-amber-spike`](../../../samples/phase-08-amber-spike).

---

## Target split: Amber full-server vs Voyager static-site

The library ships **two** web targets, and they are intentionally
different. Pick the one that matches how you deploy.

| | Amber full-server | Voyager static-site |
|---|---|---|
| Entry point | `UI::AmberIntegration.routes_for(App)` | `Voyager.build_route(...)` |
| Dispatcher-backed? | **Yes** — Amber's request loop drives actions | **No** — by design |
| Runs Crystal at request time? | Yes (live server) | No (pre-rendered HTML + vanilla JS) |
| State / interactivity | Server round-trips (forms, CSRF, flash, sessions) | Client-side JS shim over static fragments |
| When to use | A real Amber app that needs server state, auth, DB | A static demo / docs site with no server |

The Voyager static-site target is **deliberately NOT dispatcher-backed**.
Static HTML cannot invoke Crystal `Proc`s at request time, so Voyager
pre-renders each route to an HTML fragment at build time and swaps
fragments with a vanilla-JS hash-router shim
(`samples/initiative-cross-platform-ui-voyager/web/static_site.cr`). Do
not try to wire `UI::ActionDispatcher` or `UI::AmberIntegration` into a
Voyager build — that is the wrong target. The rationale lives in
`docs/initiative-cross-platform-ui/architecture/web-target-position.md`.

The rest of this section is about the **Amber full-server** target.

---

## The UI::App + UI::Screen + UI::Controller model

The same three roles describe an app on every platform; only the
*dispatch* differs.

- **`UI::App`** — the declarative route registry. Subclass it and call
  the `screen` macro once per screen. This is the single source of truth
  that both the native dispatcher and the Amber route generator read.
- **`UI::Screen`** — a stateless view builder. Subclass it and implement
  `build(context : UI::ScreenContext) : UI::View`. A screen instance is
  constructed fresh per render; all per-request data arrives on the
  `ScreenContext`.
- **`UI::Controller`** — the *native* action handler. It returns a
  `UI::ActionResult` (Navigate / Pop / Rerender / etc.) that
  `UI::ActionDispatcher` applies. **On the web target you do not write a
  `UI::Controller`** — Amber's own `Amber::Controller::Base` plays the
  controller role, and navigation happens through normal HTTP responses
  (`redirect_to`, render another screen) rather than `ActionResult`.

So a dual-target app has:

- one `UI::App` subclass (shared),
- one `UI::Screen` subclass per screen (shared — renders identically on
  native and web),
- a `UI::Controller` per screen for native dispatch, **and/or** an
  `Amber::Controller::Base` per screen for web.

### Declaring screens on `UI::App`

The `screen` macro accepts a native controller positionally and the web
binding as kwargs. A screen can be native-only, web-only, or both:

```crystal
# config/application.cr
require "asset_pipeline/native_app"   # pulls in amber_integration + UI::App

class SpikeApp < UI::App
  initial_route :sign_in

  # Web-only screen (no native UI::Controller yet).
  screen :sign_in,
         web_controller: SignInController,   # an Amber::Controller::Base subclass
         web_path: "/",
         web_actions: [
           {verb: :get,  action: :index},
           {verb: :post, action: :submit, path: "/sign_in/submit"},
         ]

  # web_path-only shortcut → defaults web_actions to
  # [{verb: :get, action: :index, path: "/about"}]
  screen :about, web_controller: AboutController, web_path: "/about"

  # Dual-target: same class drives native AND web.
  screen :todos, TodosController,
         web_controller: TodosController,
         web_path: "/todos"
end
```

Rules enforced at macro-expansion time (compile errors, not runtime):

- Every `screen` must declare at least one side (a native controller, or
  a web binding).
- Any `web_path` / `web_actions` requires a `web_controller`.
- A bare `web_controller` with no `web_path` and no `web_actions` is a
  compile error (it would route nothing).
- `screen_class` is derived by convention: `SignInController` →
  `SignInScreen`. Override with the third positional or
  `screen_class:`.

### Writing a `UI::Screen`

```crystal
class SignInScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    form = UI::Form.new(
      action: "/sign_in/submit",
      csrf_token: context.csrf_token,   # threaded from the Amber request
    )
    form << UI::TextField.new(placeholder: "Email", name: "email",
                              text: context.params["email"]? || "")
    form << UI::SecureField.new(placeholder: "Password", name: "password")
    form << UI::Button.new("Sign in", type: UI::Button::Type::Submit)
    form
  end
end
```

The same `SignInScreen` renders unchanged on native (through the
dispatcher) and on web (through Amber). The `ScreenContext` carries
`params`, `params_multi`, `flash_data`, `design_tokens`, the request
`csrf_token`, the resolved `platform` (defaults to `:web_wide`), and the
accessibility `environment`.

---

## How a UI::App maps to Amber routes: `routes_for`

`UI::AmberIntegration.routes_for(App)` is a macro that expands inside an
Amber `routes :web do ... end` block into one `get` / `post` / `put` /
`patch` / `delete` call per `web_actions` entry on every screen that
declared web metadata. Native-only screens emit nothing.

```crystal
# config/routes.cr
Amber::Server.configure do
  pipeline :web do
    plug Amber::Pipe::Error.new
    plug Amber::Pipe::Logger.new
    plug Amber::Pipe::Session.new
    plug Amber::Pipe::Flash.new
    plug Amber::Pipe::CSRF.new     # required for context.csrf_token to work
  end

  routes :web do
    UI::AmberIntegration.routes_for(SpikeApp)
    # Hand-rolled get/post lines may still be added alongside this call.
  end
end
```

If no screen has web metadata, `routes_for` expands to nothing — no
error, no warning — which lets native-first apps opt into web routes
incrementally.

---

## Wiring the controller side

Include `UI::ScreenHelpers` once in your application controller. It adds
`compute_screen_html(ScreenClass)`, which builds the screen's view tree,
renders it to HTML via `UI::Web::Renderer`, and stashes the result in the
`@screen_html` ivar.

```crystal
# src/controllers/application_controller.cr
class ApplicationController < Amber::Controller::Base
  include UI::ScreenHelpers
  LAYOUT = "application.ecr"
end
```

```crystal
# src/controllers/sign_in_controller.cr
class SignInController < ApplicationController
  def index
    compute_screen_html SignInScreen
    render("index.ecr")
  end

  def submit
    # ... authenticate using params["email"] / params["password"] ...
    compute_screen_html SignInScreen   # re-render with flash / errors
    render("index.ecr")
  end
end
```

### The shim ECR template

Amber's `render(...)` resolves the template path at **compile time**
(via Kilt), before any macro-emitted file could land on disk — so the
integration cannot synthesize templates from a macro. Instead each
controller action gets a one-line static shim you check in at
`src/views/{controller}/{action}.ecr`:

```erb
<%= @screen_html %>
```

Generate these mechanically rather than hand-writing them:

```bash
crystal run bin/asset_pipeline_amber -- generate sign_in index
```

(The generator source is
[`src/asset_pipeline/cli/amber_generator.cr`](../../../src/asset_pipeline/cli/amber_generator.cr).)

---

## App-wide configuration

Bind the active app and design tokens once at boot, typically in
`config/initializers/asset_pipeline.cr`:

```crystal
UI::AmberConfig.design_tokens = UI::DesignTokens::Tokens
  .default.with_brand(AcmeBrand.new)
UI::AmberConfig.active_app = SpikeApp
```

`compute_screen_html` seeds the renderer's `design_tokens` from
`UI::AmberConfig.design_tokens` (so a brand override is picked up
everywhere) and threads `ctx.app_class` from `UI::AmberConfig.active_app`
(so app-scoped Tier 2 widget overrides resolve correctly).

### Accessibility environment (optional)

By default `ScreenContext.environment` is the conservative
no-preference baseline. To honor HTTP client-hint headers, override
`environment_from_request` in your application controller:

```crystal
class ApplicationController < Amber::Controller::Base
  include UI::ScreenHelpers

  private def environment_from_request : UI::Environment
    hints = {} of String => String
    {"Sec-CH-Prefers-Reduced-Motion",
     "Sec-CH-Prefers-Contrast",
     "Sec-CH-Prefers-Color-Scheme",
     "Sec-CH-Prefers-Reduced-Transparency"}.each do |name|
      if value = request.headers[name]?
        hints[name] = value.to_s
      end
    end
    UI::Environment.from_request_hints(hints)
  end
end
```

---

## Requires and dependencies

In a consumer app, require the integration through the shard
(`require "asset_pipeline/native_app"` pulls in `amber_integration`,
`action_result`, and the full `UI` tree). `amber_integration.cr` itself
requires only `asset_pipeline/ui` — it does **not** require `amber`.
Amber is a *peer* dependency: add it to your own `shard.yml` and require
it separately. The mixin methods duck-type on
`params` / `flash` / `session` / `csrf_token`, which any
`Amber::Controller::Base` already provides.

The web target is pure Crystal — build and run it with **plain
`crystal`** (the vanilla compiler), not `crystal-alpha` / `acrystal`.
There are **no native flags** (`-Dmacos` / `-Dios` / `-Dandroid`) and
**no ObjC bridge compilation** for the web target; those are only for the
native renderers. The `UI::Web::Renderer` is the default when no platform
flag is set. A typical full-server build/run follows Amber's own
conventions:

```bash
crystal build src/server.cr -o bin/app   # or `shards build`
./bin/app
```

---

## Summary

- Define one `UI::App` subclass with `screen` declarations; share
  `UI::Screen` subclasses across native and web.
- On web, Amber controllers play the controller role (no `UI::Controller`
  / `UI::ActionResult`); include `UI::ScreenHelpers` and call
  `compute_screen_html(Screen)` then `render("action.ecr")` against a
  one-line `<%= @screen_html %>` shim.
- `UI::AmberIntegration.routes_for(App)` generates the Amber routes from
  the app's `web_actions` at compile time.
- Build/run the web target with **plain `crystal`** — no native flags, no
  ObjC bridge.
- The **Amber full-server** target is dispatcher-backed via Amber's
  request loop; the **Voyager static-site** target
  (`Voyager.build_route`) is deliberately NOT dispatcher-backed and
  pre-renders fragments with a vanilla-JS shim. Choose by deployment.
