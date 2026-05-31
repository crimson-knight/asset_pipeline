# Gotchas & Troubleshooting

This section collects the non-obvious failure modes you will hit when shipping
an `asset_pipeline` cross-platform app — especially on iOS, where Crystal runs
embedded as a static library under Swift `@main` rather than owning its own
`_main`. Each item lists the symptom, the root cause, and a copy-pasteable fix.

> **Compiler reminder:** native targets (`-Dmacos`, `-Dios`, `-Dandroid`) build
> with `crystal-alpha` (the agent-crystal CLI; also invocable as `acrystal`).
> Web builds use plain `crystal`. Mixing these up is the silent cause of a
> "renderer is Web on macOS" bug — see
> [`02-platform-flags-and-renderers.md`](02-platform-flags-and-renderers.md).

---

## 1. The iOS class-init gap

### Symptom

On iOS your app launches, then crashes — usually `EXC_BAD_ACCESS` /
`KERN_INVALID_ADDRESS` — the first time it touches:

- anything `Crystal::once`-guarded (e.g. `String#to_i?`, which reads the
  `String::CHAR_TO_DIGIT` constant), crashing inside
  `Thread::LinkedList(Fiber)#push` at an address like `0x18`;
- a registry populated by a module-body bootstrap (e.g. screen registration,
  `UI::WidgetRoute::Registry`, `UI::SystemAction` defaults), crashing in
  `Hash#find_entry`;
- a class variable that was declared with an *initializer expression* having a
  side effect (`@@buf = Bytes.new(64)`, `@@items = [] of T`), which reads back
  as `nil`.

### Root cause

To coexist with Swift's `@main`, the iOS cross-compile **hides `_main`** (see
`ios/build_crystal_lib.sh`, Step 4: `ld -r -unexported_symbol _main ...`).
Because `_main` never runs, Crystal's `__crystal_main` → `init_runtime` never
runs either. That means:

1. `Thread`, `Fiber`, and `Crystal::Once` class state is never initialized, so
   any `Crystal::once`-guarded constant walks an uninitialized fiber list and
   segfaults.
2. **Class-variable initializers with side effects are silently skipped.** A
   nilable default (`@@coord : UI::NavigationCoordinator? = nil`) is safe — the
   field is just a tagged-nil pointer. But `@@buf = Bytes.new(64)` never
   allocates; the field stays nil.
3. Module-body bootstrap code (the top-level statements that register screens,
   widget routes, system actions) never executes.

### Fix

In your iOS bridge's one-time init function (called from the C `*_init`
entrypoint **before any render**), do three things explicitly. This mirrors
`samples/initiative-cross-platform-ui-voyager/ios/bridge.cr`
(`VoyagerBridge.initialize_runtime`):

```crystal
module MyAppBridge
  # NO class-var initializer side effects. Nilable `= nil` defaults only.
  @@initialized = false
  @@coord : UI::NavigationCoordinator? = nil
  @@slug_buf : Bytes? = nil    # allocated in initialize_runtime, NOT here

  def self.initialize_runtime
    return if @@initialized
    GC.init

    # (a) Re-run the runtime bootstraps __crystal_main would have called.
    #     Order matters: Crystal::once depends on Fiber + Thread.
    Thread.init
    Fiber.init
    Crystal::Once.init

    # (b) Re-run any module-body bootstraps that registration depends on.
    #     These only fire under _main, which iOS hid.
    UI::WidgetRoute::Bootstrap.install   # if you use widget-route intents
    UI::SystemAction::Bootstrap.install  # if you use system actions
    MyApp.bootstrap!                     # YOUR screen registrations

    # (c) Do every allocation that "should" have happened at load time
    #     HERE, by explicit assignment.
    @@slug_buf = Bytes.new(64)
    coord = UI::NavigationCoordinator.new(MyApp.root_route)
    @@coord = coord

    @@initialized = true
  end
end
```

**Rules of thumb for iOS-embedded Crystal:**

- Never rely on a class-var initializer that *does work* (allocates, mutates,
  calls a method). Convert it to a `= nil` nilable and assign explicitly inside
  `initialize_runtime`.
- Never rely on top-level module-body code running. Give every such bootstrap
  an idempotent `install` (or `bootstrap!`) class method and call it from
  `initialize_runtime`. Idempotency matters because macOS/web *do* run these at
  load and your iOS path re-runs them.
- macOS and web do **not** have this gap (`_main` runs normally). The
  `initialize_runtime` re-installs are harmless there (last-write-wins), but the
  gap itself is iOS-only.

> Background: see the `project_crystal_ios_class_init_gap` note. This is the
> systematic recovery for it; there is no auto-fix in the embedding yet.

---

## 2. Construct the UIKit renderer BEFORE `screen.build`

### Symptom

iOS (and the analogous AppKit path) `SIGSEGV`s with `PC=0x0` the moment a
screen's `build(ctx)` queries device metrics (size class, safe-area insets,
touch-target minimum) — i.e. immediately, for most non-trivial screens.

### Root cause

`UI::UIKit::Renderer.new` (and `UI::AppKit::Renderer.new`) installs a
`DesignTokens::Device` provider during its initializer. Screens read that
provider via `DeviceMetrics.current` while building. If you build the view tree
*before* constructing the renderer, `DeviceMetrics.current` has no provider
installed and you jump through a null pointer.

### Fix

Always construct the renderer first, then build, then render:

```crystal
renderer = UI::UIKit::Renderer.new     # installs the DeviceMetrics provider
view     = screen.build(ctx)           # safe: provider is now live
native   = renderer.render(view)
```

Do **not** hoist `screen.build` above the renderer construction, even if it
reads more naturally. In a bridge, the renderer is typically constructed
per-render call (a fresh renderer per render/reconcile is also required to avoid
iOS layout inversion — see §3), so make sure the construction happens before the
build inside that call.

> Background: see the `project_renderer_provider_install_ordering` note.

---

## 3. Reactivity: per-keystroke `Rerender` of a text field

### Symptom

You wire a `TextField`'s `on_change` to mutate state and dispatch
`UI::ActionResult::Rerender` (a live-search box, an inline validator, an
"Echo:" mirror label). On iOS the keyboard **dismisses after every keystroke**:
the field loses first-responder focus because the whole host subtree is town
down and rebuilt on each rerender.

### Root cause

The naive iOS host keys its hosting view by `"\(slug)#\(renderVersion)"` and
bumps `renderVersion` on *every* route change — including same-route
`Rerender`. Bumping the SwiftUI `.id` destroys and recreates the hosted
`UIView`, which drops keyboard focus.

### Fix — it's already handled (in-place reconciliation)

As of 2026-05-31 the iOS path distinguishes a **navigation** change (host
teardown is correct) from a same-route **`Rerender`** (must preserve focus).
The `NavigationCoordinator` publishes a `ChangeKind` (`Navigation` vs
`Rerender`); on a `Rerender` the Swift host does **not** bump its `.id` and
instead calls an in-place reconcile that updates text leaves without
re-creating them. A focused text input's live buffer wins; model text is only
written back when the field is *not* first responder, so you never clobber what
the user is typing.

What you need to do as a consumer:

- Give every reactive interactive widget a stable identity:
  `accessibility_identifier` (preferred) or `test_id`. Reconciliation matches
  reused leaves by that key — without it, the field can't be reused in place.
- Keep the tree shape stable across a `Rerender`. Stage-1 reconciliation
  reuses `Label` and `TextField` leaves only and falls back to destructive
  rebuild on a structural signature change (added/removed/reordered nodes). If
  your `Rerender` also restructures the tree, focus will still drop — keep the
  per-keystroke path to leaf-text updates.
- Dispatch `Rerender` for the same route, not `Navigate`/`ReplaceRoot`.
  Navigation changes intentionally tear down the host.

Full staged design, risk guards, and the XCUITest that proves focus survives a
per-keystroke rerender:
[`../handoff/inplace-reconciliation-design-2026-05-31.md`](../handoff/inplace-reconciliation-design-2026-05-31.md).

---

## 4. AXTest: link flags + Accessibility permission

Native macOS UI tests use the built-in `UI::AXTest` library, which queries the
*real* accessibility tree of the running app. Two setup gotchas trip every
first run.

### Required link flags

AXTest links against `ApplicationServices` and `CoreFoundation`. Run the suite
with:

```bash
crystal-alpha spec spec/ui/ -Dmacos \
  --link-flags="-framework ApplicationServices -framework CoreFoundation"
```

Convention: native UI tests live in `spec/ui/` and run via `make test-ui`. Do
not ship a native build without running them — if windows don't render or
accessibility-labeled elements are missing, these tests fail.

If your test launches an app that itself uses the AppKit renderer, you also need
the ObjC bridge object compiled and linked (see
[`03-native-bridge-compilation.md`](03-native-bridge-compilation.md)). The
bridge is compiled with:

```bash
clang -c lib/asset_pipeline/src/ui/native/objc_bridge.m \
  -o lib/asset_pipeline/src/ui/native/objc_bridge.o -fno-objc-arc
```

### Accessibility permission (the silent-failure trap)

The terminal/process that runs the AXTest suite must be granted **Accessibility**
permission, or the AX tree comes back empty and every `find(...)` returns nil
with no obvious error.

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Add (and enable) the app that launches the tests — your terminal emulator
   (Terminal.app, iTerm, Ghostty, …) or your IDE.
3. Re-run the suite. A toggle that was already on sometimes needs to be toggled
   off/on after a Crystal/CLI upgrade because the binary identity changed.

### Minimal AXTest shape

```crystal
require "asset_pipeline/ui/ax_test"

app = UI::AXTest::App.launch("/Applications/MyApp.app")
prefs = app.window("Preferences").not_nil!
prefs.find(label: "Save").should_not be_nil   # every interactive el needs a label
app.screenshot("/tmp/prefs.png")              # capture for visual review
app.terminate
```

**Every interactive element must have `accessibility_label` set** — AXTest finds
elements by their accessibility label, and VoiceOver discovery depends on the
same. See the `ax-test` skill for the full API.
