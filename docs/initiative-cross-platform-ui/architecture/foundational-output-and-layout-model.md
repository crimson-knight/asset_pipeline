# Foundational output + layout model (cross-platform)

**Status:** Design proposal, 2026-06-01. Written because the Phase 12 watchOS
preflight exposed that the SwiftKit facade layer is UIKit/AppKit-bound, which
forces a foundational decision the remaining phases (B adaptive layout, C
designed demo, D watchOS) all rest on. This doc is the foundation; it is to be
Codex-reviewed before implementation.

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
| **watchOS** | **`APSKViewBox`** (a `final class { let content: AnyView }`) | `APSKViewBox(AnyView(view))` | watchOS is pure SwiftUI — no UIView host. A **class** (reference type), not bare `AnyView` (a value type), so Crystal can hold it as a +1-retained opaque pointer through the existing bridge model. |

The facades' SwiftUI-building logic is then **shared across all three Apple
platforms unchanged** — a parent reads each child (UIView to embed via
`UIViewRepresentable`, or on watchOS `child.content` the `AnyView`) and composes
a SwiftUI container. `Package.swift` gains `.watchOS(.v10)`.

### Principle 2 — Composition stays "children-up", layout becomes SwiftUI-native.

The renderer keeps building children and passing them to parent facades. What
changes for adaptive layout: facades stop receiving fixed pixel widths and
instead receive **`Fluid`/intrinsic sizing intent** that maps to SwiftUI's
layout system:

- `Fluid(min, ideal, max)` → `.frame(minWidth:idealWidth:maxWidth:)` + layout
  priority on Apple; `clamp(min, ideal, max)` on web (already done).
- Container width → SwiftUI intrinsic sizing + `@Environment(\.horizontalSizeClass)`
  instead of `content_width = 340/480`. Screens express *intent* ("readable
  column", "fill"), not pixels.
- This subsumes the Card width-pin gotcha: a SwiftUI-sized card reflows; the
  `preferredMaxLayoutWidth` hack is only needed where we still impose NSStackView
  Auto-Layout.

### Principle 3 — Two Apple composition boundaries, one facade body.

- **iOS / macOS (imperative boundary):** facades return a UIView/NSView pointer;
  the renderer threads `NativeView` handles through ObjC; SwiftUI lives *inside*
  each hosted view.
- **watchOS (declarative boundary):** facades return an `APSKViewBox`; the
  renderer composes boxes' `AnyView`s into SwiftUI containers; the watch `@main`
  App body renders the root box's `.content`. No ObjC pointer threading for
  layout — composition is the SwiftUI tree itself.

The divergence is confined to the *boundary*; the facade SwiftUI bodies and the
Crystal renderer's "children-up" structure are shared.

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

## Sequencing for the four phases

1. **B — adaptive layout (do first; foundation for C and a clean watch story).**
   Land `Fluid`→SwiftUI-frame mapping + size-class environment on the iOS/macOS
   facades; migrate the Voyager screens off fixed `content_width` to intent-based
   sizing; close the Card width-pin via intrinsic sizing. Verify: existing AX
   behavior suites stay green + screens reflow at two window sizes (macOS) / size
   classes (iOS).
2. **C — designed demo (uses B).** One intentionally-designed, resizable screen
   on iOS + macOS. Forcing function for the last layout gaps; AX + motion-evidence.
3. **D — watchOS (the heaviest; gated on the boundary work).** Implement Principle
   1's `APSKViewBox` + passthrough host + `.watchOS` platform; gate the facade
   audit; prove a one-facade watchOS compile; then the `WatchKit::Renderer`
   (declarative boundary) + complication snapshot + `WCSession`.
4. **Preview release** once the suite is green (done) + B/C land: scope to web +
   core iOS/macOS, capability guide as the stability matrix, watch/Android marked
   not-yet.

## Open questions for Codex (architect-antagonist)

1. Is `APSKViewBox` (class wrapping `AnyView`) the right watchOS boundary, or does
   the +1-retained-pointer bridge model break for a Swift value-type-backed box
   (lifetime, identity, reconciliation)?
2. Does moving layout from fixed Auto-Layout widths to SwiftUI intrinsic sizing
   conflict with the existing NSStackView-based AppKit/UIKit composition — i.e. is
   B a clean addition or a destabilizing refactor of the proven iOS/macOS path?
3. Is the "two boundaries, one facade body" split honest, or will the watchOS
   declarative path force enough facade divergence that a separate watch facade
   layer is actually cleaner?
4. Sequencing: is B-before-C-before-D correct, and is anything in B likely to
   regress the now-green suite or the AX-proven iOS/macOS behavior?
