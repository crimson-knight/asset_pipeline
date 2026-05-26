# Phase 10B.2c close — Environment-driven accessibility contracts

**Branch:** `phase-10-b-2c` (cut from `phase-10` @ `phase-10-batch-3-merged-2026-05-26`).
**Brief:** `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/brief-10-b-2c.md` (v1).
**Status:** Forward-only commits; ready for content review.

---

## What shipped

`UI::Environment` — an immutable, per-render value object carrying the
five system-level user-preference flags that views must honor:
`reduce_motion`, `increase_contrast`, `dynamic_type_size`,
`color_scheme`, `accessibility_enabled`. Threaded through
`UI::ScreenContext` (both `Web` and `Native` subclasses) so every
view's `build(ctx)` can read the user's accommodations and react.

`UI::Animation` — first reactivity helper. `duration_with_environment`
returns `0` when `env.reduce_motion`; widgets that animate read this
instead of raw duration. `UI::Snackbar#effective_duration` is the
canonical reactivity proof — same view + two environments differing
only in `reduce_motion` produces two different durations.

Per-platform sources sketched as named class methods on
`UI::Environment` (`from_request_hints`, `from_uikit`, `from_appkit`,
`from_android`). The web request-hints reader is fully implemented
against `Sec-CH-Prefers-*` HTTP client hints; the native readers
are stubs that accept caller-supplied values so the host app can
populate them from `UIAccessibility` / `NSWorkspace` /
`AccessibilityManager` queries.

## API surface

### `UI::Environment`

```crystal
env = UI::Environment.new(
  reduce_motion: false,
  increase_contrast: false,
  dynamic_type_size: :medium,        # :xsmall .. :xxxlarge / :ax1 .. :ax5
  color_scheme: :light,              # :light, :dark, :high_contrast
  accessibility_enabled: false,
)

UI::Environment.default              # baseline (no accommodations)
UI::Environment.accessibility_active # test preset (reduce_motion + increase_contrast + ax3 + high_contrast)
env.copy_with(reduce_motion: true)   # immutable copy with field overrides
```

### `UI::Animation`

```crystal
UI::Animation.duration_with_environment(env, 250)        # → 0.0 when reduce_motion=true, else 250.0
UI::Animation.duration_seconds_with_environment(env, 4.0) # → 0.0 when reduce_motion=true, else 4.0
```

### `UI::ScreenContext.environment`

```crystal
ctx.environment            # → UI::Environment (defaults to UI::Environment.default)
ctx.environment = new_env  # mutable property — dispatcher swaps mid-mount as needed
```

### `UI::Snackbar#effective_duration` (reactivity proof)

```crystal
snack = UI::Snackbar.new("Saved")
snack.duration = 4.0

snack.effective_duration(UI::Environment.default)                       # → 4.0
snack.effective_duration(UI::Environment.new(reduce_motion: true))      # → 0.0
```

## Per-platform source map

| Platform | Source | OS API | Helper | Status |
|---|---|---|---|---|
| **Web (SSR)** | HTTP client hints | `Sec-CH-Prefers-Reduced-Motion`, `Sec-CH-Prefers-Contrast`, `Sec-CH-Prefers-Color-Scheme`, `Sec-CH-Prefers-Reduced-Transparency` | `UI::Environment.from_request_hints(hints)` | **Fully implemented.** Wired into `ScreenHelpers#environment_from_request` (overridable; default returns `UI::Environment.default` so unit tests without a request compile cleanly). |
| **UIKit (iOS / iPadOS)** | OS query at App boot or per-render | `UIAccessibility.isReduceMotionEnabled`, `UITraitCollection.accessibilityContrast`, `UIContentSizeCategory.preferredContentSizeCategory`, `UITraitCollection.userInterfaceStyle`, `UIAccessibility.isVoiceOverRunning` | `UI::Environment.from_uikit(reduce_motion:, increase_contrast:, dynamic_type_size:, color_scheme:, voice_over_running:)` | **Stub.** Host queries the UIKit values (via the existing ObjC bridge or a new helper); the framework just packages them. The host's `UIAccessibility.reduceMotionStatusDidChangeNotification` observer calls `dispatcher.environment = new_env` on change so the next render reflects the live preference. |
| **AppKit (macOS)** | OS query at App boot or per-render | `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`, `NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast`, `NSApp.effectiveAppearance` | `UI::Environment.from_appkit(reduce_motion:, increase_contrast:, color_scheme:, voice_over_running:)` | **Stub.** Same wiring story as UIKit — the host queries NSWorkspace and AXObserver, passes values in. |
| **Android** | OS query at App boot or per-render | `Settings.Global.ANIMATOR_DURATION_SCALE == 0`, `AccessibilityManager.isHighTextContrastEnabled`, `Configuration.fontScale`, `AccessibilityManager.isTouchExplorationEnabled` | `UI::Environment.from_android(reduce_motion:, increase_contrast:, dynamic_type_size:, color_scheme:, talk_back_active:)` | **Stub.** Host reads Settings.Global / AccessibilityManager via the JNI bridge; the framework packages them. |

### Host responsibility split

**asset_pipeline provides:**

- The `UI::Environment` value type + per-platform packaging helpers.
- The `ScreenContext.environment` field and threading through the
  dispatcher / Amber integration.
- The `Animation.duration_with_environment` reactivity helper.
- The `Snackbar#effective_duration` reactivity proof.

**Consumer apps wire:**

- The OS-query observer (e.g. `UIAccessibility.reduceMotionStatus
  DidChangeNotification` on iOS, AXObserver on macOS, `ContentObserver`
  on Android). The framework does not auto-observe — the App's
  lifecycle knows when it's safe to query and when to re-dispatch.
- The web `request.headers` → hints hash conversion if they want
  the out-of-the-box client-hints path. Default is
  accessibility-conservative (no accommodations); apps override
  `ScreenHelpers#environment_from_request` to read `request.headers`.

### Why the native readers are stubs (not full bridges)

The brief mandates "at least web + macOS / iOS implementations
sketched in code." The stubs satisfy the sketch requirement while
keeping the native OS-query path under the host App's control — same
pattern as the existing renderer initialization (`UIKit::Renderer.new`
runs in the host's main, not from inside the framework). Pushing
`UIAccessibility.isReduceMotionEnabled` through to a renderer-side
call would add an iOS-only auto-observe surface that doesn't compose
with the existing `Settings.Global` / NSWorkspace paths. Keeping the
stubs symmetric across all four platforms preserves the contract:
"framework packages the value; host queries the OS."

## ScreenContext + dispatcher wiring

### Web (`compute_screen_html`)

```crystal
# Default per-request source: request hints → Environment.
private def build_screen_context : UI::ScreenContext::Web
  UI::ScreenContext::Web.new(
    params: ...,
    csrf_token: ...,
    environment: environment_from_request,   # ← new
  )
end

# Override hook: explicit kwarg wins over the seeded value.
compute_screen_html(MyScreen, environment: UI::Environment.accessibility_active)
```

### Native (`UI::ActionDispatcher`)

```crystal
dispatcher = UI::ActionDispatcher.new(
  app: MyApp,
  navigation: coord,
  session: session,
  flash: flash,
  design_tokens: tokens,
  environment: UI::Environment.from_uikit(...),   # ← new
)

# Host updates on OS-preference change:
dispatcher.environment = UI::Environment.from_uikit(
  reduce_motion: UIAccessibility.isReduceMotionEnabled,
  ...
)
# next dispatch picks up the new env via build_context.
```

## Reactivity proof: `UI::Snackbar`

Why Snackbar:

- It has an existing `duration : Float64` property (auto-dismiss
  timer) — the most obviously environment-sensitive widget surface.
- It already has a `default_accessibility_role` of `:status`
  (Phase 10B.2a), so the AX semantics layer underneath this
  reactivity work is intact.
- The reactive value (`effective_duration(env)`) is read by the
  host's animation driver (Web JS, NSAnimationContext, UIView.animate,
  Compose LaunchedEffect), not by the renderer at render time —
  matching the existing snackbar lifecycle.

Proof (from `spec/web/ui/environment_spec.cr`):

```crystal
snack = UI::Snackbar.new("Saved")
snack.duration = 3.5

ctx_default = UI::ScreenContext::Web.new(..., environment: UI::Environment.default)
ctx_reduce_motion = UI::ScreenContext::Web.new(..., environment: UI::Environment.new(reduce_motion: true))

snack.effective_duration(ctx_default.environment).should eq(3.5)
snack.effective_duration(ctx_reduce_motion.environment).should eq(0.0)
```

Same view + two contexts differing only in `environment.reduce_motion`
→ two different effective values. The brief's reactivity acceptance
criterion is satisfied.

## Spec coverage

`spec/web/ui/environment_spec.cr` — 28 examples, all green:

```
crystal spec spec/web/ui/environment_spec.cr
28 examples, 0 failures, 0 errors, 0 pending
```

Coverage:

- 4 construction / default / preset / `copy_with` specs.
- 7 web request-hint reader specs (each header recognized; missing /
  unknown → conservative default; case-insensitive lookup; contrast
  + scheme escalation; reduced-transparency-as-contrast signal).
- 3 native source specs (`from_uikit` / `from_appkit` / `from_android`
  thread caller-supplied values).
- 3 `Animation` helper specs (`duration_with_environment` /
  `duration_seconds_with_environment` × on / off).
- 5 `ScreenContext.environment` threading specs (Web + Native default,
  explicit kwarg, mutability for dispatcher swap).
- 3 `ActionDispatcher.environment` specs (property settability,
  threading into the dispatch path via a captured context, swap
  between dispatches yields different captured envs).
- 3 `Snackbar#effective_duration` reactivity specs (off / on / same
  view + two contexts → two outputs).

**Full regression vs. baseline:**

```
crystal spec
1907 examples, 4 failures, 2 errors, 66 pending
```

Baseline (phase-10-batch-3-merged-2026-05-26 without this branch):

```
1879 examples, 4 failures, 2 errors, 66 pending
```

Net change: **+28 examples, ±0 failures, ±0 errors.** The 4 failures
and 2 errors are pre-existing on the baseline tag (Phase 2 component
fixture mismatches, Theme inject_theme_css, intent-resolver Android
swipe-row defaults). My changes neither regress nor heal them.

## Build + lint

```
crystal build --no-codegen src/asset_pipeline.cr   (success)
crystal build --no-codegen src/ui.cr               (success)

crystal run scripts/lint_conventions.cr
lint_conventions: OK (459 files, 14 rules, 0 diagnostics)

crystal tool format --check
  (clean on all files I touched; the pre-existing formatter bug
   on src/asset_pipeline/amber_integration.cr also occurs on
   baseline — same backtrace, same exit code, not new.)
```

## Honest limitations

1. **Native OS-query bridges are stubs.** `from_uikit`,
   `from_appkit`, `from_android` accept caller-supplied values; the
   framework does not auto-query `UIAccessibility` /
   `NSWorkspace` / `Settings.Global`. Host apps wire the observers
   (`UIAccessibility.*StatusDidChangeNotification`, AXObserver,
   `ContentObserver`) and call `dispatcher.environment = ...`.
   Brief explicitly accepted "sketched in code" for this iteration.
2. **Web client-hints are an HTTP-only path.** The current
   `Sec-CH-Prefers-*` family is opt-in (server sends `Accept-CH:`
   in a prior response, client sends hints on the next request).
   First-render of a fresh session falls back to the conservative
   default. Apps that need first-render preference should serve a
   tiny JS that reads `window.matchMedia('(prefers-reduced-motion:
   reduce)')` and rebuilds with the explicit pref — that's a
   consumer-side wiring choice, not a framework gap.
3. **`accessibility_enabled` (VoiceOver / TalkBack active) has no
   web source.** No standard HTTP header surfaces AT activation.
   The web reader leaves it `false`; apps that need it override.
4. **The reactivity proof is single-widget.** Only `Snackbar#effective_
   duration` reads `env` today. Other animation-bearing widgets
   (`Sheet` presentation transition, `Snackbar` slide-in, list
   reorders) will adopt the same pattern in follow-on briefs as
   their renderer-side animation hooks are added. The framework
   contract is in place; the per-widget adoption is incremental.
5. **`dynamic_type_size` is symbolic only.** The framework doesn't
   yet emit CSS variable updates from the size symbol. The web
   renderer will need an `inject_dynamic_type_css(env)` pass in a
   follow-on brief; native renderers already honor the OS-level
   text-size signal via `UIFontMetrics` / `NSFontDescriptor` so the
   symbol carries advisory weight only on those targets.

These limits are surfaced explicitly per `[[plan-what-to-understand-
not-just-what-to-build]]` — the framework MUST tell the consumer
what asset_pipeline provides vs. what the host has to wire.

## Out of scope (deferred to follow-on briefs)

- Per-renderer `inject_dynamic_type_css(env)` (web target).
- Native auto-observers for `UIAccessibility` / `NSWorkspace` /
  `Settings.Global` (host-app wiring today).
- Reactivity adoption across other animation-bearing widgets
  (Sheet, Popover, ListView reorder, ProgressView pulse).
- VoiceOver / TalkBack live testing.
- Runtime AT testing (deferred per brief Out-of-scope).

— Implementer (Claude Opus 4.7), 10B.2c iter-1
