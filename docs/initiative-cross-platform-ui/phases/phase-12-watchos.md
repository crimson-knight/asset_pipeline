# Phase 12 — watchOS Target (WatchKit Renderer + Complications)

**Status:** Draft brief, queued. Begins after Phase 11 (Home-Screen Widgets) closes.
**Owner directive:** "I want a complication on my watch that syncs with the phone app." This phase delivers that — and the watchOS *target* it requires.

This phase is consistent with the
[Platform Capability & Usability Guide](../platform-capability-matrix.md):
its three organizing principles (foundation→prove→abstract; the type-system
safety rail; cross-platform parity), §8 (the watchOS roadmap), and §9 (parity
opportunities). watchOS is **confirmed entirely greenfield** (§8): zero
`flag?(:watchos)`, no `WatchKit::Renderer`, no `UI::Complication`, no
`WCSession`. This phase moves the first watchOS rows off ⚪.

## What this phase ships

1. **`UI::WatchKit::Renderer`** — a `PlatformVisitor` subclass under
   `{% if flag?(:watchos) %}`, **SwiftUI-only** (architecturally closer to the
   WidgetKit/Phase 11 path than to the UIKit renderer — watchOS app UI is
   SwiftUI, with no UIKit view-host equivalent). It walks the same `UI::View`
   tree every other renderer walks and produces SwiftUI through the same
   SwiftKit facade seam (`apsk_make_*` / the `*Facade.swift` classes), restricted
   to the watch-applicable subset of the catalog.
2. **`UI::Complication`** — a watch-exclusive view/model that mirrors
   `UI::HomeScreenWidget` (Phase 11) with the *watch* family set, **gated so that
   naming it in a non-watchOS build is a compile error** (the type-system safety
   rail, principle #2). The `accessory*` families it needs already exist as
   `String → Swift` mappings in `src/ui/widgets.cr` — that is the reuse seam.
3. **A watch-app catalog SUBSET** — the watch-idiomatic slice of the 59+ view
   types, with the non-applicable types explicitly enumerated.
4. **Watch↔phone sync** — `WatchConnectivity` (`WCSession`) over the shared App
   Group, reusing Phase 11's snapshot bridge, ending in
   `WidgetCenter.shared.reloadAllTimelines()` (which reloads complications).

### Catalog subset on watch

watchOS gets a real *subset*. The renderer implements `visit` for the
watch-applicable types and routes the rest through the existing
`fallback_view` mechanism in `platform_visitor.cr` (the same way `ColumnView`,
`Gauge`, `ActivityRing`, etc. degrade today, `platform_visitor.cr:46-72`) or
omits them with a documented note.

**Applies on watch (build the facades for these first):**
`Label`, `Button`, `VStack`, `HStack`, `ZStack`, `Image`, `Spacer`, `Toggle`,
`Slider`, `Picker` (wheel-style), `DatePicker`/`TimePicker` (compact),
`ProgressView`, `ActivityIndicator`, `Divider`, shapes
(`Circle`/`Rectangle`/`RoundedRectangle`/`Capsule`), `Gauge`, `ActivityRing(s)`
(watch-defining), `ListView` (the dominant watch container),
`NavigationStack` (push navigation), `TabView` (watch-idiomatic **page**/
vertical-paging style, *not* a bottom tab bar), `TextField` (dictation/scribble
entry), `SecureField`.

**Does NOT apply on watch (omit or fall back, documented):**
`TextEditor`/`TextArea` (no multi-line editor affordance on watch — entry is
dictation/scribble only), `NavigationSplitView`, `Toolbar` (macOS/iPad chrome),
`Popover`, `ContextMenu`, `PathControl` (macOS-only already), `MapView`/
`WebViewComponent`/`VideoPlayer` (heavy media; defer), `Tooltip`,
`MenuBar`/`StatusBar`/`Window` capability surfaces (app-shell, not watch),
`SegmentedControl` (use page TabView/Picker instead).

This subset is the watch analog of Phase 11's "content view tree is a SUBSET of
the catalog — only widgets that have a SwiftUI-only equivalent."

## Why this is its own phase, not part of Phase 11

watchOS is heavier than widening WidgetKit by a family set:

1. **A whole new platform flag and renderer.** `flag?(:watchos)` does not exist
   anywhere in `src/` today (§8). The `PlatformVisitor` contract grows a new
   concrete subclass, and the watch-only `UI::Complication` view requires a new
   gated `visit` overload behind `{% if flag?(:watchos) %}` (mirroring how
   `visit(view : PathControl)` is gated `{% if flag?(:macos) %}` in
   `platform_visitor.cr:112-114`).
2. **A new app target *and* a complication (widget) extension target** in the
   `.xcodeproj`, on top of the phone app — see [§5](#5-xcodeswift-plumbing).
3. **Two-process + two-device data flow.** Phase 11 is one device, two processes
   (app + widget extension, sharing an App Group). Phase 12 adds a *second
   device*: phone ⇄ watch over `WCSession`, then watch-app ⇄ watch-complication
   over the App Group. Phase 11 must land first so the cross-process snapshot
   bridge is already de-risked.
4. **Crystal runtime is absent in the complication extension** — exactly the
   WidgetKit constraint (capability guide §7: "WidgetKit / ActivityKit / ClockKit
   run in a separate process with no Crystal runtime"). Same bridge, same
   limitation.

## Dependency on Phase 11 (sequencing)

> **Sequencing (capability guide §8):** watchOS follows Phase 11 — complications
> *are* the WidgetKit / App-Group snapshot model applied to a new family set.

Phase 11 de-risks: (a) writing a JSON snapshot from Crystal in the main app to a
shared App Group container; (b) reading it from a SwiftUI extension with no
Crystal runtime; (c) the xcodegen target + App Group entitlement + code-signing
mechanics; (d) reload-on-mutation via `WidgetCenter`. Phase 12 reuses all four
and adds the watch family set + `WCSession` cross-device hop.

**Deep-link dependency the guide flags (§11.5):** deep links are catalogued
`missing` (`:open_url`/`:on_open_url` = `coverage_today: missing`), *yet Phase
11's interactive-widget deliverable D5 assumes a deep-link handler exists.* A
tappable complication that launches the watch app to a route has the same
dependency. **Wire/verify the deep-link handler before relying on a tappable
complication.** If Phase 11 ships the handler, Phase 12 inherits it; if not,
this phase owns it.

## Type-system safety rail (critical — principle #2)

> Capability guide §0 #2: "Naming `UI::PathControl` in a non-macOS build is a
> compile error… A future `UI::Complication` must be gated the same way: a
> watch-only complication referenced from a desktop target must fail to
> *compile*, not fail at runtime."

`UI::Complication` follows the **exact `PathControl` template**
(`src/ui/views/path_control.cr` + `src/ui/views/_gate_stubs/path_control.cr`):

**`src/ui/views/complication.cr`:**

```crystal
require "../view"

{% if flag?(:watchos) %}
  module UI
    enum ComplicationFamily
      AccessoryCircular
      AccessoryRectangular
      AccessoryInline
      AccessoryCorner
    end

    # Tier 3 — watchOS-only. Use UI::ComplicationWithWebFallback to render an
    # accessible glance card on every other target.
    #
    # On every other build, naming this class is a compile-time error
    # (see _gate_stubs/complication.cr).
    class Complication < View
      property kind : Symbol
      property family : ComplicationFamily
      property content : UI::View
      # ...
      def accept(visitor : PlatformVisitor)
        visitor.visit(self)
      end
    end
  end
{% else %}
  # ComplicationFamily is universal data (no platform behavior); expose it so
  # non-watchOS code can still annotate types. The gated stub for the
  # Complication class itself lives in _gate_stubs/complication.cr.
  module UI
    enum ComplicationFamily
      AccessoryCircular
      AccessoryRectangular
      AccessoryInline
      AccessoryCorner
    end
  end

  require "./_gate_stubs/complication"
{% end %}
```

**`src/ui/views/_gate_stubs/complication.cr`** (the `{% raise %}` must live
*outside* an `{% if flag?(...) %}` so it fires at the *construction site*, not at
class-definition time — the same reason `_gate_stubs/path_control.cr` exists):

```crystal
module UI
  class Complication
    macro new(*args, **kwargs)
      {% raise <<-MSG
        UI::Complication is watchOS-only (Tier 3). A watch complication has no
        honest cross-platform analog. This build does not have -Dwatchos.

        Pick one:
        1. Build with -Dwatchos:
             crystal build my_app.cr -Dwatchos
        2. Use the explicit fallback class instead:
             UI::ComplicationWithWebFallback.new(...)
           which renders a native watch complication on -Dwatchos and an
           accessible glance card (small Card with the same kind/content) on
           every other target.
        3. Guard the usage at the call site:
             {% if flag?(:watchos) %}
               c = UI::Complication.new(...)
             {% end %}

        See docs/initiative-cross-platform-ui/tier-matrix.md for the full tier
        classification and which widgets require which flags.
        MSG
      %}
    end
  end
end
```

**`visit(view : Complication)`** is added to `PlatformVisitor` behind
`{% if flag?(:watchos) %}`, mirroring the macOS `PathControl` gate at
`platform_visitor.cr:112-114`. Android and the other renderers define **no**
`visit` for it (just as they define none for `PathControl`).

**Companion class — `UI::ComplicationWithWebFallback`** (the `*WithWebFallback`
sibling, per the Tier 3 contract): renders the native complication on
`-Dwatchos` and a small accessible "glance card" (a `Card` with the same
`kind`/`content`, the same data the complication shows) on every other target,
so a cross-platform screen can reference one symbol without `{% if %}` at the
call site. New tier-matrix row added in the same commit.

## Complications architecture (reuses Phase 11's App-Group snapshot bridge)

`UI::Complication` mirrors `UI::HomeScreenWidget`: `kind : Symbol` (e.g.
`:next_todo`), `family : ComplicationFamily`, `content : UI::View` (a watch
subset tree — Label/Image/shapes/`Gauge`/`ActivityRing`, not stateful inputs).
The data flow is identical to Phase 11, with the **watch family set**:

### Crystal side (watch app, has runtime)

- `UI::Complication::SnapshotWriter` (or reuse Phase 11's
  `HomeScreenWidget::SnapshotWriter`, generalized) serializes the complication
  snapshot to JSON and writes it to the shared App Group container path.
- On state mutation, the watch app's screen layer calls `snapshot.publish`, and
  the writer fires `WidgetCenter.shared.reloadAllTimelines()` through the
  SwiftKit bridge — on watchOS this reloads **complications**.

### Swift side (complication extension, no Crystal runtime)

- A watch **Widget Extension** (`WidgetBundle`) where each `Widget` declares
  `.supportedFamilies([.accessoryCircular, .accessoryRectangular,
  .accessoryInline, .accessoryCorner])`.
- A `TimelineProvider` reads the latest snapshot from the App Group container
  and renders SwiftUI — the same JSON-snapshot-to-SwiftUI pattern Phase 11
  builds.

### The family reuse seam (cite the real method names)

The watch families are **already** wired as `String → Swift` mappings in
`src/ui/widgets.cr` — this is why Phase 11 de-risks complications. Both methods
that emit a `WidgetFamily` case already handle the accessory set:

- `WidgetPlacement#swift_family_case` (`widgets.cr:80-102`) maps
  `"accessory_circular" → "accessoryCircular"`, `"accessory_rectangular" →
  "accessoryRectangular"`, `"accessory_inline" → "accessoryInline"`,
  `"accessory_corner" → "accessoryCorner"` (plus `accessory_angular`).
- `Widget#normalize_widgetkit_family` (`widgets.cr:287-309`) has the **identical**
  `accessory*` switch, feeding `widgetkit_supported_families` (`widgets.cr:211-220`)
  → `.supportedFamilies([...])` in `export_widgetkit_scaffold`
  (`widgets.cr:222-263`).

Phase 12 routes `UI::Complication#family` through these existing mappings; no new
family-name translation is invented.

## Watch↔phone sync (the "syncs with the phone app" deliverable)

This is the explicit owner ask. Data flow:

```
[iPhone app, Crystal]
   state mutates → write shared state JSON to App Group container
                 → WCSession.transferUserInfo / updateApplicationContext
                          │  (WatchConnectivity, cross-device)
                          ▼
[Apple Watch app, Crystal]  receives via WCSessionDelegate
   → write complication snapshot JSON to the (watch-side) App Group container
   → WidgetCenter.shared.reloadAllTimelines()   ← reloads complications
                          │  (App Group, cross-process, same device)
                          ▼
[Watch complication extension, SwiftUI, no Crystal runtime]
   TimelineProvider reads snapshot → renders accessory* SwiftUI
```

- **`WCSession`** is a new Swift-side bridge (a small `*Facade.swift` +
  `apsk_wcsession_*` trampolines through `swiftkit_bridge.cr` /
  `swiftkit_bridge.m`, the same pattern as every other facade). `WCSession`
  works in *both* directions; phone→watch is the primary path for "the
  complication reflects the phone app's state."
- The App Group is shared across **phone app, watch app, and watch complication
  extension** so the snapshot lives in one place per device.
- `WidgetCenter.shared.reloadAllTimelines()` (already the Phase 11 reload call)
  reloads complications on watchOS — no separate ClockKit call is needed on
  modern watchOS (ClockKit complications are deprecated in favor of WidgetKit
  accessory families, which is exactly why the `accessory*` seam fits).

## Xcode / Swift plumbing

Mirrors Phase 11's target/entitlement discussion, scaled to two new targets:

1. **New watchOS app target** in `project.yml` (xcodegen) — `VoyagerWatch`
   (a watchOS app, paired with the existing phone app). Links the Crystal
   static lib built with `-Dwatchos` (see [§risks](#risks--open-questions) for
   the watch-arch build note).
2. **New complication (widget) extension target** — `VoyagerWatchComplications`
   (a Widget Extension with `WidgetFamily` accessory families). **Pure Swift, no
   Crystal** in this process (WidgetKit constraint).
3. **App Group entitlement shared across phone + watch + complication extension**
   (`group.com.assetpipeline.voyager.shared`, extending the Phase 11 group). All
   three targets carry the entitlement; code-signing must be App-Group-aware for
   each (the Phase 11 signing notes generalize to the watch targets).
4. **`build_crystal_lib.sh`** gains a watch-arch variant for the watch app target
   (arm64 watchOS / the simulator arch); the complication extension links **no**
   Crystal (Phase 11 already chose "pure-Swift in the extension process").

## Beauty-by-default obligations

Per the library's North Star and capability guide §8's
"opinionated-beauty obligations," a `UI::Complication` and a watch `UI::Screen`
must produce the most beautiful HIG-authentic Apple-watch render with **zero
config**, light + dark:

- **SF-Symbols-first compact layouts** — accessory families are tiny; default to
  an SF Symbol + a single value, not text labels.
- **Smart-stack tint** — complications adopt the Smart Stack / accent tint via
  the existing brand-tint cascade (`apsk_runtime_set_brand_tint`,
  `swiftkit_bridge.cr:52`) so a brand swap flows through with no per-widget color.
- **`.privacySensitive` redaction** — sensitive content auto-redacts on the
  wrist-down / locked state by default.
- **`.containerBackground`** — required for accessory widgets on modern watchOS;
  applied by default so complications render correctly in every placement.
- **Digital-Crown-aware scrolling** — watch `ListView`/`ScrollView` facades wire
  Crown rotation by default (HIG-authentic scroll), zero config.

Every component usage doc for the watch subset must carry both the
"Light / dark appearance notes" and "Customization / brand override" sections,
per the project's beauty-by-default-overridable-for-brand contract.

## Usability bar applies (capability guide §1)

A watch surface is **not** "passing" on a still frame. Per §1 (the too-fast
sheet root cause) and the missing motion/interaction evidence class (§1.3): a
complication tap that launches the app, a Crown scroll, and a sync-driven
reload all need the **timed motion/interaction evidence class** — a
before/during/after triptych or short recording **plus** a timed behavior test
(U4) driving the real control through the accessibility API, **plus** a
reduce-motion variant asserting a fade, not a snap. Until that evidence ships,
every watchOS row stays 🟢/🟡 — **no still frame promotes a watch row to ✅**
(capability guide §12). Specifically:

- **Sync is behavior-proven, not "returns success"** (the SecureField/§11
  lesson, U8): write a real value on the phone, assert it *reaches the watch
  complication snapshot and the rendered complication updates* — never a
  synthetic "something changed" signal.
- The **deep-link from a tappable complication** must actually navigate the
  watch app to the target route (§11.5 risk), proven by a behavior test.

## Cross-platform parity note (vision, not this phase)

Per principle #3 and capability guide §9 (parity opportunities): the
"**Glanceable timeline surface**" row is the highest-leverage parity seam —
Apple WidgetKit ↔ Android App Widgets/Glance ↔ **complications / tiles**, all
sharing the property *out-of-process, snapshot-driven, no app runtime*. Structure
`UI::Complication` and its `SnapshotWriter` so the snapshot model is **family-set-
agnostic**: a future **Wear OS complications/tiles** target can reuse the same
Crystal snapshot abstraction with a different family enum and a different
(Kotlin/Glance) reader. Do *not* hard-bind the snapshot schema to WidgetKit
field names. This is vision, not in-scope work for Phase 12.

## Deliverables (draft)

### D1 — `UI::Complication` view + gating (type-system safety rail)
- `src/ui/views/complication.cr` (gated `{% if flag?(:watchos) %}`) + enum.
- `src/ui/views/_gate_stubs/complication.cr` (compile-error `macro new`).
- `UI::ComplicationWithWebFallback` companion.
- `visit(view : Complication)` added to `PlatformVisitor` behind the watch flag.
- New tier-matrix row + capability-guide §4a/§7 status update, same commit.

### D2 — `UI::WatchKit::Renderer`
- `src/ui/watchkit_renderer.cr` (or `src/ui/watchkit/renderer.cr`), a
  `PlatformVisitor` subclass under `{% if flag?(:watchos) %}`, SwiftUI-only.
- `visit` for the watch catalog subset; fallback for the rest.
- Renderer-provider install ordering respected (renderer `.new` installs the
  `DesignTokens::Device` provider screens query — same gotcha as UIKit; build the
  renderer *before* `screen.build`).

> ## ⚠️ PREFLIGHT FINDING (2026-06-01) — the SwiftKit facade layer is UIKit/AppKit-bound; it does NOT extend to watchOS as-is. READ BEFORE STARTING D2.
>
> **Toolchain is fine** — `WatchSimulator26.5.sdk` is installed and `crystal-alpha`
> can target a watchOS triple, so the build path exists.
>
> **But the Swift facade layer cannot be reused unchanged.** Evidence from the
> current tree:
> - `APSKPlatformView` (the type every `apsk_make_*` facade returns) is declared
>   `#if canImport(UIKit) → UIView / #elseif canImport(AppKit) → NSView / #endif`
>   (`Overrides/ViewOverrides.swift:18-26`). **watchOS has neither UIKit nor
>   AppKit**, so `APSKPlatformView` is *undefined* there → the whole package
>   fails to compile for watchOS.
> - SwiftUI is hosted into that platform view via `UIHostingController` /
>   `NSHostingView` (`HostingHelpers.swift:26,34`). **Neither exists on watchOS**
>   (modern watchOS apps are pure SwiftUI — SwiftUI *is* the native layer, there
>   is no UIView host).
> - `Package.swift` declares only `.iOS(.v16)` and `.macOS(.v13)` — **no
>   `.watchOS`** platform at all.
>
> **Implication:** D2 is NOT "add a renderer subclass that reuses the facades."
> It requires a foundational decision on the watchOS output model FIRST.
> **Recommended architecture (lowest divergence):** on watchOS, make
> `APSKPlatformView = AnyView` (a type-erased SwiftUI view) and
> `HostingHelpers.host(_:)` a passthrough (`AnyView(view)`, no UIView wrapping),
> both gated `#elseif os(watchOS)`; add `.watchOS(.v10)` to `Package.swift`; then
> **audit every facade** — most compose SwiftUI internally and will work through
> the AnyView passthrough, but any that touch UIView/objc-bridge APIs
> (focus/first-responder, accessibility custom actions, the ObjC-drawn views like
> ActivityRings/Canvas/Map/WebView/Video) must be gated out or given a
> SwiftUI-native watch path. The watch catalog subset (§"Catalog subset on watch")
> is deliberately small precisely so this audit is tractable.
> **De-risking step before full D2:** add the watchOS typealias + passthrough host
> + `.watchOS` platform, gate the facade layer down to the watch subset, and
> compile `swift build --triple arm64-apple-watchos-simulator` green with ONE
> facade (Label) — that validates the model before building the renderer. This
> preflight is itself a deliverable; do it first.

### Facade-bucket audit — REAL watchOS-build errors (2026-06-01)

`.watchOS(.v10)` added to `Package.swift` (macOS build unaffected, verified). A
`swift build --triple arm64-apple-watchos-simulator` produces the concrete audit
below (error counts per file). The macOS/iOS builds are untouched — watchOS only
compiles when explicitly targeted.

**Root blockers (must fix FIRST — nothing compiles until then):**
- `Overrides/ViewOverrides.swift` — `APSKPlatformView` typealias is undefined on
  watchOS (`#if canImport(UIKit)`/`#elseif canImport(AppKit)`, neither true).
- `HostingHelpers.swift` (29 errors) — `UIView`/`UIViewController`/`UIHostingController`
  are `API_UNAVAILABLE(watchos)`. The `host(_:)` seam must become a passthrough
  (`APSKPlatformView = AnyView` or a watch box; `host(v) = AnyView(v)`).

**Watch-specific bucket (hard UIKit / SwiftUI-unavailable — reimpl or gate out):**
- `PopoverFacade` (26 — `AnchoredPopoverHost: UIView` + `UIPopoverPresentationController`)
- `NavigationStackFacade` (20) / `NavigationSplitViewFacade` (4) — `UIViewController`
- `ToggleFacade` (11 — `UISwitch` unavailable on watchOS)
- `TextFieldFacade` (9 — `.keyboardType`), `PickerFacade`/`DatePickerFacade`/`ColorPickerFacade`
- `ToolbarFacade` (6) / `GridFacade` (6) / `ListViewFacade` (5) — SwiftUI `Grid`/`Table`/
  `inset` list style unavailable on watchOS
- `SwipeActionRowFacade` (4), `MenuButtonFacade` (4)
- `Modifiers/MaterialSemantic.swift` (3 — `Material.bar` unavailable),
  `Modifiers/CommonModifiers.swift` (3 — `APSKPlatformColor`)
- `TabViewFacade`/`SheetFacade`/`GlassBackgroundFacade` (2 each — mostly transitive
  via `APSKPlatformView`; likely compile once the root is fixed)

**Portable bucket (not in the error list — work once the root compiles):**
`LabelFacade`, `ButtonFacade`, and the other leaf facades that compose pure SwiftUI.

**Implication:** D2 ≈ fix the 2 root files + a `#if os(watchOS)` gate/reimpl on the
~12 watch-specific facades (most of which are NOT in the watch catalog subset
anyway — Popover/Nav/Grid/Toolbar/Toggle-as-UISwitch). Then the portable facades
+ the watch subset compile, and the `WatchKit::Renderer` can be built on top.

**UPDATE (2026-06-01): the SwiftKit layer is now GREEN for watchOS** (root + shared
modifiers fixed; 22 watch-specific facades gated `#if !os(watchOS)`; Label/Button +
all portable facades compile). `swift build --triple arm64-apple-watchos-simulator`
→ Build complete!, 0 errors. macOS/iOS unaffected.

### ✅ RESOLVED (2026-06-01) — Crystal UI lib now cross-compiles for watchOS

Both layers compile for watchOS. **Recipe:** `crystal-alpha build <require ./src/ui>
--cross-compile --target=arm64-apple-watchos-simulator -Dwatchos -Ddarwin -Dunix`
→ green `.o`. Needs: (1) watchOS `lib_c` dirs in the crystal-alpha stdlib (copies
of `aarch64-ios[-simulator]`); (2) the `-Ddarwin -Dunix` flags (the `*-watchos`
triple sets `:apple` but not `:darwin`/`:unix`, so they must be supplied to select
the Kqueue event loop); (3) the watchos-gated `visit(Complication)` Web-renderer
fallback (web_renderer.cr). **Source-repo TODO** (for clean-machine builds):
`github.com/crimson-knight/crystal@incremental-compilation` — add the `lib_c/
aarch64-watchos*` dirs + derive `darwin`/`unix`/`apple` from a `*-watchos` triple
(then `-Ddarwin -Dunix` is unnecessary). Until then the lib_c dirs are a local
Cellar mod. The blocker write-up below is kept for history.

### ⚠️ (HISTORICAL) Crystal toolchain blocker — `crystal-alpha` cannot target watchOS yet

The Swift layer compiles, but the **Crystal `WatchKit::Renderer` cannot be built
because `crystal-alpha` (agent-crystal) has no watchOS target support.** Probed via
`crystal-alpha build … --cross-compile --target=arm64-apple-watchos-simulator
-Dwatchos`:
1. **`lib_c` gap:** `can't find file 'c/dlfcn'`. `src/lib_c/` has `aarch64-ios`,
   `aarch64-ios-simulator`, `aarch64-darwin`, `x86_64-*` — but **no `*-watchos*`**.
   *PROVEN FIX:* copying `aarch64-ios[-simulator]` → `aarch64-watchos[-simulator]`
   gets past this (watchOS shares iOS's Darwin C ABI). A reversible test confirmed
   it; the test copies were removed (the real fix belongs in agent-crystal source).
2. **Event-loop gap (next blocker, surfaced after #1):** `Error: Event loop not
   supported` — `src/crystal/event_loop.cr` has no watchOS branch (watchOS is
   Darwin and should select the same kqueue/libevent loop as iOS/macOS; likely a
   flag guard that excludes watchOS).
3. Expect more, one at a time (like the Swift facade audit).

**These are `crimson-knight/homebrew-agent-crystal` (compiler) changes, not
asset_pipeline changes** — and they're the gate for the WatchKit renderer. Until
agent-crystal gains a watchOS target (lib_c + event_loop, both small since watchOS
≈ iOS-on-Darwin), Phase D cannot proceed past the (now-green) Swift layer. Owner
owns that tap; this is a heads-up that finishing watch requires a compiler-side
watchOS target first. Meanwhile the UNBLOCKED high-value work is the beauty /
full-adaptive-layout north star (the whole design must adapt — inputs/spacing/
reflow — not just window resize) on Mac/iOS, per the foundational model's
"Phase B implementation findings".

### D3 — WCSession + complication snapshot bridge
- `WCSessionFacade.swift` + `apsk_wcsession_*` in `swiftkit_bridge.cr`/`.m`.
- Reuse/generalize Phase 11's `SnapshotWriter` for the watch App Group path.
- Reload via `WidgetCenter.shared.reloadAllTimelines()`.

### D4 — Xcode targets + App Group
- `VoyagerWatch` app target + `VoyagerWatchComplications` extension in
  `project.yml`; App Group entitlement across phone + watch + extension;
  code-signing wired; `build_crystal_lib.sh` watch-arch variant.

### D5 — Voyager watch demo
- A watch-app catalog subset screen (the watch-applicable slice).
- At least one complication per accessory family, driven by a phone-app state
  mutation that syncs to the watch (the owner's "syncs with the phone app").

### D6 — Build + install + timed evidence
- watchOS simulator (paired with the iOS simulator): add the complication to a
  watch face, mutate state on the phone, observe the complication update.
- Capture the **motion/interaction evidence class** (§1.3): triptych/recording +
  timed behavior test (U4) + reduce-motion variant. Light + dark.

### D7 — Documentation (per the widget-demonstration-criteria rubric)
- Per-component usage doc for `UI::Complication` and the watch subset at
  `.claude/skills/apple-platform-guide/usage/` (six sections incl. light/dark +
  brand override).
- `component-api` skill entries for `UI::Complication` /
  `UI::ComplicationWithWebFallback` + watch-renderer notes.
- Catalog status updates: `tier-matrix.md`, capability-guide §4a/§7/§8 (move
  watchOS rows off ⚪), `APPLE_NATIVE_UI_STATUS.md`.
- Architecture doc at
  `docs/initiative-cross-platform-ui/architecture/watchos-complications.md`
  (the snapshot bridge, no-Crystal-in-extension, accessory families, WCSession
  sync, reload policy, parity-with-Wear-OS note, override limits).

## Effort estimate (very rough — actual preflight required)

- D1 (Complication + gating): 1-2 hours (PathControl is a tight template)
- D2 (WatchKit renderer + facades for subset): 3-4 hours (most likely to surprise)
- D3 (WCSession bridge + snapshot reuse): 2-3 hours
- D4 (Xcode watch targets + App Group + signing): 2-3 hours (Xcode wiring finicky)
- D5 (Voyager watch demo): 1-2 hours
- D6 (Build + timed evidence): 1-2 hours
- D7 (Docs): 1 hour

**Total: ~11-17 hours.** Split into substrate (D1-D4) then demo + evidence
(D5-D7), per the owner's "complete the full phase arc before review" preference.

## Risks / open questions

1. **Crystal runtime absent in the complication extension** — same as WidgetKit
   (capability guide §7, §11.4). The extension is pure Swift reading the JSON
   snapshot; no Crystal there. Confirmed constraint, not a risk to discover — but
   the watch **app** target *does* run Crystal, and the iOS class-init gap (memory:
   `project_crystal_ios_class_init_gap` — embedded Crystal hides `_main`; class-var
   initializers + `Crystal::once` lookup tables don't run) **likely recurs on
   watchOS embedding**. Budget the same workaround the iOS bridge needed.
2. **watchOS deployment-target minimum** — pick the floor (the `accessory*`
   WidgetKit complication families require recent watchOS; align with the
   project's macOS 14+/iOS 16+ minimums from memory `project_platform_minimums`).
   Open question: exact watchOS minimum.
3. **Simulator / testing path** — XCUITest on the watchOS simulator (paired with
   the iOS simulator) is the working interaction-test path, consistent with the
   "Voyager iOS actually works / XCUITest is the working path" finding (memory:
   `project_voyager_ios_actually_works`); the Crystal simctl coord-harness is a
   dead-end. Open question: whether `UI::AXTest` reaches the watch simulator or
   XCUITest is the only behavior-test route.
4. **Crystal build for watch archs** — `build_crystal_lib.sh` must emit a
   watchOS arm64 + simulator-arch slice; confirm `crystal-alpha`/`acrystal`
   cross-compiles for watchOS (memory: `reference_agent_crystal`). Risk if the
   toolchain lacks a watchOS target triple.
5. **Snapshot reload latency vs. the usability bar** — WidgetKit reload budgets
   are throttled; a "synced complication" may not update instantly. Verify the
   sync path meets a *perceptible, bounded* update (U1) and document the real
   refresh latency rather than implying real-time.
6. **WCSession reachability** — `WCSession` transfers are best-effort/queued when
   the counterpart is unreachable. The sync deliverable must handle the
   not-reachable case (queue + reconcile on next activation), not assume a live
   link.

## Out of scope

- Standalone watch apps with no paired phone (phone-sync is the deliverable).
- Watch-face *creation* / custom clock faces (Apple does not allow third-party
  faces; complications attach to system faces).
- Wear OS complications/tiles (parity vision only — §9; not built here).
- Audio/media/`MapView` on watch, always-on-display tuning, NavigationSplitView.

— Architect, Phase 12 draft brief
