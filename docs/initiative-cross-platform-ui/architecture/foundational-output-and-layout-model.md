# Foundational output + layout model (cross-platform)

**Status:** Design proposal, 2026-06-01, **revised after Codex (gpt-5.5) review.**
Written because the Phase 12 watchOS preflight exposed that the SwiftKit facade
layer is UIKit/AppKit-bound, which forces a foundational decision the remaining
phases (B adaptive layout, C designed demo, D watchOS) all rest on.

> **Codex verdict on the v1 model: NOT safe to build on as-is.** Three corrections
> are now incorporated below (search "[Codex]"):
> 1. The watchOS boundary is **not** a bare `class { AnyView }` — the Crystal
>    bridge requires an explicit ownership + **identity** contract: a stable
>    `view_kind` (reconciliation infers kind from the handle debug label and
>    *aborts* if nil/mismatched — `native_view.cr:70-109`, `ios/bridge.cr:304-323`),
>    child topology, an update channel, and a release strategy matching either
>    `ObjCRelease` or the `Unmanaged.passRetained`/`apsk_*_release` pattern
>    (`ReactiveState.swift:18-27,352-363`). So watchOS needs a real **Apple output
>    node**, not a value-type box.
> 2. **B must be additive, not a replacement.** The iOS/macOS path deliberately
>    uses exact/min/max Auto-Layout constraints + root-fill pins
>    (`uikit_renderer.cr:5008-5050`, `appkit_renderer.cr:4550-4582`); button hit
>    targets need host constraints *because* SwiftUI `.frame(minHeight:)` was
>    insufficient (`uikit_renderer.cr:421-434`). Replacing Auto-Layout with SwiftUI
>    intrinsic sizing would destabilize stack sizing, row widths, AX frames, and
>    screenshots. B = map `Fluid` *into* the existing constraint model.
> 3. **Not "one facade body."** Core `VStack`/`HStack` compose imperatively in
>    `UIStackView`/`NSStackView` (`uikit_renderer.cr:445-525`), not via facades;
>    ~3 facades are hard UIView-bound (Toggle=`UISwitch`, Popover, SwipeActionRow).
>    Facades classify into **portable / child-adapter / watch-specific** buckets.

## The problem this resolves

The `UI::View` tree + compile-time `PlatformVisitor` backbone is sound. The
question is the **output model** below the renderers, which currently does not
span watchOS and does not do adaptive layout:

- Every SwiftKit facade returns `APSKPlatformView`, declared
  `#if canImport(UIKit) → UIView / #elseif canImport(AppKit) → NSView`
  (`Overrides/ViewOverrides.swift:18-26`) — **undefined on watchOS** (neither
  framework exists there).
- SwiftUI is hosted into that platform view via `UIHostingController` /
  `NSHostingView` (`HostingHelpers.swift:26,34`) — **neither exists on watchOS**.
- Native layout uses fixed sizes (screens pick `content_width = compact ? 340 :
  480` by hand) and carries known gotchas (stack max-width/padding drop — fixed
  via `objc_constrain_required_width`; Card width-pin via `preferredMaxLayoutWidth`
  — not yet). `Fluid` (min/ideal/max) realizes only on web (`clamp()`); native is
  "later phases."

## The key grounding observation

On Apple platforms **SwiftUI is already the real output layer.** The facades
build SwiftUI internally and only wrap it in a UIView/NSView at the boundary
(`HostingHelpers.host`). And composition is already declarative-ish: a parent
facade takes `childViews: [APSKPlatformView]` and composes them **in SwiftUI**
(e.g. `CardFacade.makeCard(childViews:…)`). So the renderer pattern is already
"build children → pass the array up → parent facade composes in SwiftUI." The
UIView/NSView wrapping is a **boundary adapter**, not the substance.

## The foundational model

### Principle 1 — SwiftUI is canonical for the Apple family; the platform-view wrapping is a per-platform boundary adapter.

`APSKPlatformView` becomes a per-platform boundary type, with `HostingHelpers.host`
the single adapter:

| Platform | `APSKPlatformView` | `host(swiftUIView)` | Why |
|---|---|---|---|
| iOS | `UIView` | `UIHostingController().view` | renderer threads UIView pointers via ObjC |
| macOS | `NSView` | `NSHostingView` | same |
| **watchOS** | **`APSKWatchNode`** — an `NSObject` subclass carrying `content: AnyView` **plus the bridge contract** (see below) | `APSKWatchNode(content: AnyView(view), kind: …)` | watchOS is pure SwiftUI — no UIView host. |

**[Codex] The watchOS boundary is an explicit Apple output node, not a bare box.**
`APSKWatchNode` must satisfy the same contract a `UIView`/`NSView` handle does for
the Crystal bridge + reconciler, or it breaks ownership and identity:
- **Ownership:** be an `NSObject` with a real ObjC retain/release path
  (`NativeHandle` → `ReleaseStrategy::ObjCRelease` → `objc_release`,
  `native_handle.cr:111-117`), **or** adopt the reactive
  `Unmanaged.passRetained`/`apsk_*_release` contract (`ReactiveState.swift:18-27`).
  A bare Swift value-type box has neither.
- **Identity / `view_kind`:** carry a stable kind discoverable the way
  `native_view.cr:70-109` infers it (debug label), because the in-place reconciler
  **aborts** when `view_kind` is nil or mismatched (`ios/bridge.cr:304-323`).
- **Child topology + update channel:** hold its children and a way to be updated
  in place, so reconcile (which preserves focus across rerender) works on watch
  too.

With that contract, parent facades compose children by reading each node's
`content` `AnyView` into a SwiftUI container — the *composition shape* is shared,
but the node is a first-class bridge object, not a thin wrapper. `Package.swift`
gains `.watchOS(.v10)`.

> **STATUS (2026-06-02): Principle 1's boundary node satisfies the full Codex
> contract.** `APSKWatchHostView` (`Overrides/ViewOverrides.swift`) is now an
> `NSObject, ObservableObject` carrying all three required facets, not just
> `content`: (1) **identity** — a settable `kind: String` (the watch analog of the
> iOS/macOS debug-label `view_kind`, which the reconciler aborts on if nil/mismatched);
> (2) **topology** — an ordered `children: [APSKWatchHostView]` with `appendChild` /
> `setChildren` / `child(at:)` / `childCount` for the renderer walk; (3) **update
> channel** — `content` is `@Published` and `APSKHostedChild` `@ObservedObject`s the
> node, so an in-place `update(content:)` swap re-renders while the subtree stays
> mounted (focus-preserving reconcile). `HostingHelpers.host(_:kind:)` gained an
> additive defaulted `kind` param (no facade churn). **Proven:** clean release
> compile on watchOS-sim + iOS-sim + macOS, and the test target compiles against the
> new API. Still pending for D: the Crystal-side `WatchKit::Renderer` that stamps
> `kind` and composes via these facets, the facade-bucket audit, and a one-facade
> end-to-end watch render.

### Principle 2 — `Fluid` maps INTO the existing constraint model (additive). [Codex-corrected]

**[Codex] Do NOT replace Auto-Layout with SwiftUI intrinsic sizing** — the
iOS/macOS path's exact/min/max constraints and root-fill pins are load-bearing
(hit targets, row widths, AX frames, screenshots). Adaptive layout is *additive*:

- `Fluid(min, ideal, max)` → on Apple, drive the **existing** constraint helpers
  (`objc_constrain_required_width` and the min/max-width pins,
  `uikit_renderer.cr:5008-5050`) with the resolved value instead of a hard-coded
  pixel; on web, `clamp(min, ideal, max)` (already real, `web_renderer.cr:2544`).
- Size-class: resolve `Fluid`'s value per `@Environment(\.horizontalSizeClass)` /
  `DeviceMetrics.compact_horizontal`, so screens express *intent* ("readable
  column", "fill") and the renderer picks the width — replacing the hand-coded
  `content_width = compact ? 340 : 480` in the Voyager screens.
- The Card width-pin (`preferredMaxLayoutWidth`) is still needed where NSStackView
  Auto-Layout governs; B does **not** remove the pins, it feeds them `Fluid`.

This keeps the AX-proven path intact (no host-identity / constraint / focus
changes) while making screens genuinely resizable — the safe B.

### Principle 3 — Classify facades into three buckets (not "one body"). [Codex-corrected]

**[Codex] 40 facades; "one unchanged body" is false.** The honest split, which
scopes the watchOS work per-bucket:

- **Portable (pure SwiftUI):** Label, Button, the controls that are already
  SwiftUI inside — watch path is the passthrough host, minimal change.
- **Child-adapter (~14):** Card, Form, GlassBackground, Grid, ListView,
  Navigation{Link,SplitView,Stack}, Popover, Sheet, Surface, SwipeActionRow,
  TabView, Toolbar — they embed children via `APSKHostedChild`
  (`CardFacade.swift:17-28`). On watch, the child-embed adapter changes
  (`APSKWatchNode.content` instead of `UIViewRepresentable`); the composition
  shape stays.
- **Watch-specific (hard UIView-bound):** `ToggleFacade` (wraps `UISwitch`
  because SwiftUI Toggle failed XCUITest, `ToggleFacade.swift:7-23`),
  `PopoverFacade` (`UIPopoverPresentationController`), `SwipeActionRowFacade`
  (`intrinsicContentSize` from platform views), `ImageFacade` (`UIImage`/`NSImage`
  probe), and `CommonModifiers`'s `APSKPlatformColor` — each needs a SwiftUI-native
  watch reimplementation or to be out of the watch catalog subset.

Also note: **core `VStack`/`HStack` compose imperatively in `UIStackView`/
`NSStackView`** on iOS/macOS (`uikit_renderer.cr:445-525`), *not* via facades — so
the watchOS renderer's stack composition is genuinely a separate (declarative)
implementation, not a facade reuse. The shared asset is the SwiftUI *content* of
leaf facades, not the container composition.

### What must be gated per platform (the audit)

Facades/paths that touch UIKit/AppKit-only APIs need a watchOS-native path or a
gate:
- Focus / first-responder (`ap_view_become_first_responder`) → SwiftUI `.focused()`
  on watchOS.
- Accessibility custom actions / key commands (ObjC bridge) → SwiftUI a11y
  modifiers or omit on watch.
- ObjC-drawn views (ActivityRings, Canvas, PathView, MapView, WebView, Video) —
  most are out of the watch catalog subset; the in-subset ones (e.g. ActivityRings,
  watch-defining) need a SwiftUI-native draw.
The watch catalog subset is deliberately small (Phase 12 brief) precisely so this
audit is tractable.

> **STATUS (2026-06-02): the facade-bucket audit is DONE and grounded in an
> authoritative reachability scan** — see
> [`watch-facade-bucket-audit.md`](./watch-facade-bucket-audit.md). Headline:
> **18 of 40 facades are reachable on watch today; 22 are compiled out.** Bucket 1
> (18 reachable) is the WatchKit renderer's initial catalog. Bucket 2 (~11) are a
> *not-yet-ported gap* where the SwiftUI control DOES exist on watchOS — the P0s
> for any interactive watch app are **TextField, ListView, Sheet** (then
> SecureField, TabView), all currently `#if !os(watchOS)`-excluded. Bucket 3 (~11,
> e.g. Popover/Menu/ColorPicker/NavigationSplitView/Toolbar) are correctly excluded
> — no honest watchOS analog; route to the accessible fallback.

## Sequencing for the four phases

1. **B — adaptive layout (do first; narrowed per [Codex]).** **Additive only:**
   resolve `Fluid` values into the *existing* iOS/macOS constraint helpers + the
   `horizontalSizeClass`/`DeviceMetrics` size-class, and migrate the Voyager
   screens off hard-coded `content_width` to `Fluid` intent. Do **not** touch
   host identity, the NSStackView/UIStackView composition, the constraint pins, AX
   grouping, or the focus/reconcile path. Verify: the green web suite stays green,
   the macOS AX behavior suites stay green, and a screen reflows at two window
   widths (macOS) without losing AX frames or focus.
2. **C — designed demo (uses B).** One intentionally-designed, resizable screen
   on iOS + macOS. Forcing function for the last layout gaps; AX + motion-evidence.
3. **D — watchOS (the heaviest; gated on the boundary work).** Implement Principle
   1's `APSKViewBox` + passthrough host + `.watchOS` platform; gate the facade
   audit; prove a one-facade watchOS compile; then the `WatchKit::Renderer`
   (declarative boundary) + complication snapshot + `WCSession`.
   > **STATUS (2026-06-02): D is in progress and now GATED on the Crystal
   > toolchain.** Boundary node done (Principle 1 STATUS); facade audit done +
   > 23/40 facades reachable (TextField/ListView/Sheet/SecureField/TabView ported).
   > **But the Crystal compiler cannot yet target watchOS** — proven: a watchOS
   > cross-compile fails at `require "c/dlfcn"` because `Target#os_name` lacks a
   > `watchos` case, deriving the nonexistent lib_c dir `aarch64-watchos10.0`
   > instead of the (present) `aarch64-watchos`. Exact ~10-line compiler fix +
   > the `swiftkit_bridge` gate prerequisite are in
   > [`handoff/2026-06-02-watchos-crystal-toolchain-blocker.md`](../handoff/2026-06-02-watchos-crystal-toolchain-blocker.md).
   > Writing `WatchKit::Renderer` before that lands would be unprovable, so the
   > renderer waits on the compiler patch + rebuild.
4. **Preview release** once the suite is green (done) + B/C land: scope to web +
   core iOS/macOS, capability guide as the stability matrix, watch/Android marked
   not-yet.

## Phase B implementation findings (2026-06-01)

- **Fluid works on a container whose content NATURALLY fills it** — proven: a
  long `Label` inside a `fluid_width` `VStack(max:340)` wraps at ≤340 (gallery
  cap test, AX-verified). The label fills because wrapping text expands to the
  available width.
- **But facade-hosted LEAF controls do NOT fill a fluid container.** Migrating
  the sign-in form to a `fluid_width` column with `Fill` alignment + pins removed
  rendered the `TextField`/`SecureField`/`Button` as tiny intrinsic-width pills
  (offscreen capture caught it; the AX test passed because the controls still
  exist + function — the classic "passed but unusable" trap). The NSHostingView-
  wrapped SwiftUI controls hug their intrinsic width and `Fill` alignment does
  not stretch them. **Reverted** (sign-in is back on the working size-class
  `content_width` pins).
- **Built (and PARKED — does not work):** `objc_constrain_equal_width(child,
  container)` leaf-fill and `objc_constrain_fluid_width(view, min, max)`
  (bound≤parent 900 > cap≤max 800 > floor≥min 700 > fill==parent 500, per Codex,
  applied post-`push_native`). **CORRECTION (do not trust the earlier "cap works
  5/5"): that was a FALSE PASS.** The gallery cap test asserted the label width
  ≤360, which a COLLAPSED column (~120pt) also satisfies — so it passed while the
  column was actually collapsed. The fluid gallery demo + that test have been
  REMOVED. Native fluid containers do not work *at all* on NSStackView (see below);
  the renderer primitives remain in the tree, unused/parked, as a starting point
  for the wrapper-NSView redo.
- **DEEP BLOCKER — NSStackView fluid containers COLLAPSE to their content minimum.**
  Both the fill-up case (a form of ~120pt controls) AND a content column (a fluid
  VStack of long text — the Welcome v1 attempt) collapse to ~120pt and clip,
  because every direct child is pinned `== container` (leaf-fill) so content can't
  push the container wide, and `fill==parent` is dropped by NSStackView. Verified
  via offscreen capture: the Welcome v1 fluid column was ~120pt and fully clipped
  at a 900pt window. NSStackView
  `floor≥min (700)` and `fill==parent (500)` constraints. So you cannot make a
  vertical NSStackView wider than its content via width constraints on the stack
  itself. Sign-in re-migrated + reverted **twice**; it stays on `content_width`.
- **What actually unblocks fluid forms (future, not churned now):** don't fight
  NSStackView — either (a) wrap the fluid column in a plain `NSView`/`UIView`
  pinned to fill its parent (capped at max) and put the stack inside it pinned to
  the wrapper's edges, or (b) set the stack's `huggingPriority`/distribution so it
  yields width, or (c) use a non-stack container for fluid columns. This needs a
  dedicated investigation, not a drive-by.
- **For NOW:** `fluid_width` is correct for containers with self-filling content
  (text/images — the gallery proof). **Size-class-adaptive `content_width`
  (compact?340:400) remains the correct, good-looking pattern for FORMS** — and
  Phase C (the designed demo) should use it rather than block on continuous-fluid.

## Track 2 — full adaptive layout: Codex-validated plan (2026-06-01)

> **STATUS (2026-06-01): Track 2 core COMPLETE on macOS.** All three prioritized
> steps landed and proven: (1) size-class metric contract + live `windowDidResize`
> → `rebuild` (the whole tree re-runs `build` on drag); (2) `DeviceMetrics#responsive`
> authoring primitive (sign-in + welcome migrated — width, spacing, padding, type all
> reflow); (3) determined the fluid-wrapper is NOT needed for fixed-width columns
> (the "stretch" claim was a measurement misread). **Phase C proof artifact:**
> `docs/initiative-cross-platform-ui/handoff/phase-c-evidence/welcome-reflow-macos.png`
> — the welcome demo at compact (420pt/340 column) vs regular (980pt/600 column).
> Remaining: time-debounce, iOS host trait/bounds-change → rebuild equivalent,
> migrate the other Voyager screens, GUI/AX interactive-drag test.

The owner's north star ("the inputs have to move, the spacing has to change, the
design in its entirety adapts — not just the window"). Codex's verdict, in
priority order. **Key truth:** *constraints alone can resize boxes but cannot
change tree shape or spacing after first render — for the whole design to adapt,
the Crystal tree must be REBUILT with updated environment on resize.* That's why
"the window resizes but nothing moves" today.

**1. Resize → re-render plumbing + a real window-metric contract (THE prerequisite).**
- The macOS host (`host.cr`) rebuilds the tree only on `coord.on_change`
  (nav/state) — **never on window resize** (`host.cr:259`). Auto-Layout
  relayouts existing native views, but Crystal-side responsive decisions stay
  frozen. Wire an `NSWindow` frame-change / resize callback to the same
  `rebuild_for(coord.current)` path (debounced).
- `DeviceMetrics.content_width_pt` derives from **screen** width
  (`appkit_renderer.cr:212 objc_macos_screen_width`), not the window/container —
  so even a resize-rebuild won't adapt correctly. The metrics provider must read
  the actual **window/content** size. (This is also why the earlier
  clamp-against-content_width idea failed.)
- Verifiable by offscreen captures at two window widths showing the rebuilt
  layout differs; the live callback needs an AX resize/integration test.
- **LANDED (2026-06-01) — the metric-contract half.** Codex's read was partly
  stale: `objc_macos_screen_width` *already* reads the active-window content rect
  (a prior P2 fix). The real bug was in `objc_horizontal/vertical_size_class`,
  which still used a bare `[NSApp mainWindow]` — nil during offscreen capture
  (the capture window is visible but never "main") and a *different* window than
  the width helper. So size class returned `Unspecified` → `compact_horizontal?`
  false → every screen always picked its WIDE column even in a narrow window.
  Fix: both size-class helpers now derive from `ap_macos_active_window_content_rect()`
  (keyWindow→mainWindow→any-visible→screen), consistent with width. Proven via new
  `VOYAGER_DEBUG_METRICS=1` host instrumentation: width 460→Compact, 760→Compact,
  900→Regular (threshold 768); pre-fix all three were Unspecified.
- **LANDED (2026-06-01) — the live-resize half.** `window_helper.m`'s
  `APWindowResizeObserver` registers for `NSWindowDidResizeNotification` and
  bridges back into Crystal via the existing `crystal_ui_callback_dispatch(tag)`
  → `CallbackRegistry.call` trampoline; the host registers a Proc →
  `VoyagerHost.on_window_resized` → `rebuild_for(coord.current)` (coalesced: skips
  when content width is unchanged). Wired into the interactive window. PROVEN
  headless via `VOYAGER_RESIZE_PROBE="460,900"` + `objc_window_set_content_size`
  + `objc_window_order_front`: initial 460→Compact, programmatic resize 900→Regular,
  the second build triggered ONLY by the resize (no navigation). A resized window
  now re-runs `build` so the whole composition reflows live. **Follow-ups:** a true
  time-debounce (per-pixel rebuild can be heavy for large trees) and a GUI/AX
  interactive-drag test — the mechanism itself is proven.
- **CORRECTION (2026-06-01) — the "column stretches edge-to-edge" claim was
  WRONG.** It was a misread of two screenshots captured at different pixel scales
  (460pt→920px image vs 900pt→1800px image), which made a 340pt and a 400pt column
  look similarly proportioned. Pixel-measuring the captures shows the column IS
  capped and centered: 460pt window → **342pt** field, 900pt → **402pt** field.
  The `content_width` equality (`objc_constrain_width` @999) IS authoritative on a
  fixed-width column because VStack alignment is Leading/Center (not a fill that
  would stretch). **Implication:** the fluid-wrapper (step 3) is NOT needed for
  fixed-width columns — it only matters for genuinely *fluid* `Fill` containers
  whose leaf controls must stretch. Most "responsive" forms want a capped centered
  column, which already works.

**2. Responsive Crystal authoring primitives + migrate Voyager off hard-coded values.**
- Spacing / padding / axis / repositioning are chosen by Crystal view
  construction + renderer visits — so adaptation is authored, then re-run on
  rebuild. Add a responsive API (e.g. size-class-aware values) and migrate
  Voyager's hard-coded `content_width`/spacing/padding to it.
- Verifiable by offscreen capture at compact + regular widths.
- **LANDED (2026-06-01).** Added `DeviceMetrics#responsive(compact:, regular:)` +
  `#responsive_vertical` (generic `forall T`; Unspecified → regular). Migrated the
  Voyager sign-in screen so the WHOLE composition adapts: content_width 340↔400,
  root spacing 16↔24, fields spacing 10↔14, padding 28/20↔48/32, wordmark 28↔34.
  PROVEN by capture-measurement: 460pt → 35pt top-pad / 342pt column; 900pt → 57pt
  top-pad / 402pt column. Both clean + centered. Suite 2107 ex / 0 fail.
  REMAINING migration: the other Voyager screens (todos, settings, editor, gallery,
  hub) still use the older `compact_horizontal? ? a : b` width-only idiom — migrate
  them to `responsive` for spacing too as they're touched.

**3. Fluid wrapper for VStack/HStack (continuous box sizing — solves the collapse).**
The plain wrapper becomes the logical emitted native view:
- `wrapper = NSView/UIView`; added to parent normally.
- inner stack added as a plain subview of the wrapper; pinned `top/leading/
  trailing/bottom == wrapper`.
- `objc_constrain_fluid_width` applied to the **wrapper** (not the inner stack):
  `width >= min` @700, `width <= max` @800, `width <= parent.width` @900,
  `width == parent.width` @500.
- **Reconciliation safety:** wrapper handle label `"NSView[vstack-wrapper]"` /
  `"UIView[vstack-wrapper]"`, but the wrapper `NativeView.children` MUST equal
  the authored `VStack` children, and `view_kind` must still resolve to
  `UI::VStack` (model after the existing `ZStack` plain-view-owns-logical-children
  pattern). The inner stack is a retained native object that must NOT appear as a
  logical child (internal-owned-child slot / explicit ownership).
- **Caveat:** only fills when an ancestor provides real available width
  (root-fill / pinned parent); a rootless offscreen stack can't infer width.
- Verifiable by offscreen capture at two widths + measuring column/control widths.

**Order matters:** #1 first (nothing adapts without rebuild-on-resize + correct
window metrics), then #2 (the authored responsiveness), then #3 (continuous width).

## Resolved by Codex review (2026-06-01)

1. **watchOS boundary:** NOT a bare box — an explicit `APSKWatchNode` (NSObject +
   ownership + stable `view_kind` + child topology + update channel). See
   Principle 1.
2. **iOS/macOS layout:** do NOT replace Auto-Layout; B feeds `Fluid` *into* the
   existing constraints (additive). See Principle 2.
3. **Facades:** three buckets (portable / child-adapter / watch-specific); core
   stacks are imperative and need a separate watch composition. See Principle 3.
4. **Sequencing:** B→C→D holds **only with B narrowed to additive**; the risk is B
   regressing host identity / constraints / AX / focus, so B is bounded to not
   touch those. See "Sequencing".

**Codex's single biggest risk to watch for:** treating the watchOS node as "just
another `APSKPlatformView`" when its real contract is ownership + identity + child
topology + native sizing + AX behavior. The Principle-1 node contract is the guard.

The 3 pre-implementation changes Codex required are now in this doc: explicit
Apple-output-node contract (P1), additive-only B (P2), facade bucket
classification (P3).
