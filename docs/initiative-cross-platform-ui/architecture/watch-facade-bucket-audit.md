# watchOS facade-bucket audit (2026-06-02)

Phase D, Track 1. Principle 3 of
[`foundational-output-and-layout-model.md`](./foundational-output-and-layout-model.md)
requires the ~40 SwiftKit facades to be classified into buckets before the
Crystal-side `UI::WatchKit::Renderer` is built, so the renderer's catalog subset
is grounded in what actually compiles + renders on watchOS rather than assumed.

## Method (authoritative, not assumed)

The package compiles clean for `arm64-apple-watchos10.0-simulator` (release), so
"compiles on watch" is not the discriminator. The real discriminator is whether
each facade's primary `@objc static func make*` entry point is *reachable* on
watchOS or compiled out behind `#if !os(watchOS)`. That was determined by a
guard-aware scan of every `*Facade.swift` (walk the `#if/#elseif/#else/#endif`
stack to the `func make` line and report whether a `!os(watchOS)` true-branch —
or an `os(watchOS)` `#else` — encloses it). Spot-verified against
`TextFieldFacade` (excluded: `#if !os(watchOS)` at line 18 wraps `makeTextField`)
and `ImageFacade` (reachable: `UIImage`/`NSImage` probe with a watch-valid
`canImport(UIKit)` branch).

**Result (original scan): 18 of 40 facades reachable on watch; 22 compiled out.**
**Update 2026-06-02:** TextField + ListView + Sheet (P0s) + SecureField + TabView
(P1s) + Toggle + Slider + Stepper ported → **26 reachable / 14 compiled out** (see Bucket 2).

## Bucket 1 — Watch-reachable now (18)

These compile AND expose their `make*` entry point on watchOS. The shared SwiftUI
*content* is the reusable asset; the WatchKit renderer composes them via the
`APSKWatchHostView` boundary node (kind + children + `@Published` content — see
the Principle 1 STATUS note).

| Facade | Notes |
|---|---|
| Label, Button, IconButton, LinkButton, ToggleButton | pure SwiftUI leaves — the portable core |
| Image | `Image(systemName:)` / named via the `UIImage` probe (UIImage exists on watchOS) |
| Spacer, Divider | layout primitives |
| Checkbox, RadioGroup | SwiftUI-composed selection |
| Alert, ConfirmationDialog | `.alert` / `.confirmationDialog` exist on watchOS |
| Card, Surface, Form, Grid | **child-adapter** — embed children through `APSKHostedChild`, which on watch reads each boundary node's `.content` |
| NavigationStack, NavigationLink | `NavigationStack` is the watch-native navigation model |

## Bucket 2 — Not-yet-ported GAP (SwiftUI-native exists on watchOS) (≈11)

Compiled out today, but the SwiftUI control IS available on watchOS — so these are
*porting work*, not honest exclusions. **This is the real finding:** the basic
input vocabulary an interactive watch app needs is currently absent. For the
agent-interaction watch vision (chat + voice + a message list — see the watchOS
vision note) the load-bearing gaps are **TextField, SecureField, ListView, Sheet,
TabView**.

| Facade | watchOS SwiftUI status | Priority for agent-watch |
|---|---|---|
| ~~TextField~~ **PORTED 2026-06-02** | available (dictation/Scribble input) — now watch-reachable: dropped the `#if !os(watchOS)` exclusion, gated `.roundedBorder` (unavailable on watch) + `keyboardType` for non-watch; the `PromptOverlayField` body is pure SwiftUI. Compiles clean on watchOS-sim/iOS-sim/macOS. | **P0** — message entry ✅ |
| ~~SecureField~~ **PORTED 2026-06-02** | available — mirrors TextField (reuses `PromptOverlayField`); only `.roundedBorder` gated for non-watch. Compiles clean watchOS/iOS/macOS. | P1 — auth ✅ |
| ~~ListView (`List`)~~ **PORTED 2026-06-02** | core watch control — now watch-reachable: gated `.listRowSeparator(.hidden)` (watch-unavailable) + mapped `.inset`/`.sidebar`/`.grouped`/`.insetGrouped` styles → `.plain`/`.automatic`; `.swipeActions`/`.onMove`/`.listRowInsets` are watch-valid. Compiles clean on watchOS-sim/iOS-sim/macOS. | **P0** — message/feed list ✅ |
| ~~Sheet (`.sheet`)~~ **PORTED 2026-06-02** | available — now watch-reachable: gated `.presentationDetents`/`PresentationDetent` (watch-unavailable; `canImport(UIKit)` is true on watch so needs `!os(watchOS)`) and `.presentationBackground`/`.glassEffect()` (watch presents full-screen with system chrome); `.sheet`/`.interactiveDismissDisabled`/`.task`/reduce-motion are watch-valid. Compiles clean on watchOS-sim/iOS-sim/macOS. | **P0** — modal compose/confirm ✅ |
| ~~TabView~~ **PORTED 2026-06-02** | available (vertical-page idiom) — gated the `.toolbarBackground`/`.glassEffect()` bar chrome (watch-unavailable); `.tabItem`/`.tag`/`.tint` watch-valid. Compiles clean watchOS/iOS/macOS. | P1 — section switch ✅ |
| ~~Toggle~~ **PORTED 2026-06-02** | available — the 'hard UIView-bound' case: iOS wraps UISwitch (XCUITest interop), but watchOS has no UISwitch, so watch/macOS route through SwiftUI `Toggle`; `.switch`/`.checkbox` styles gated (watch-unavailable). Compiles clean watchOS/iOS/macOS. | P1 — settings ✅ |
| ~~Slider~~ **PORTED 2026-06-02** | available (Digital Crown) — pure SwiftUI, straight un-gate. Compiles clean watchOS/iOS/macOS. | P2 ✅ |
| ~~Stepper~~ **PORTED 2026-06-02** | available — pure SwiftUI, straight un-gate. Compiles clean watchOS/iOS/macOS. | P2 ✅ |
| Picker | available (wheel/list style) | P1 |
| DatePicker / TimePicker | available, restricted styles | P2 — *confirm exact style support on a watch compile* |

## Bucket 3 — Correctly excluded (no honest watchOS analog) (≈11)

Compiled out, and that is the right call — the underlying SwiftUI API is
unavailable on watchOS or has no sensible watch idiom. The Crystal `UI::View`
should route these to an accessible fallback (or be out of the watch catalog),
not force a degraded native control.

| Facade | Why excluded |
|---|---|
| ColorPicker | `ColorPicker` unavailable on watchOS |
| MenuButton | `Menu` unavailable on watchOS |
| Popover | no popover presentation on watchOS |
| NavigationSplitView | no split view; collapses to a stack |
| Toolbar | watch `.toolbar` is a different, limited model — *not* a port of the iOS bar |
| SearchField | `.searchable` unavailable on watchOS |
| TextEditor / TextArea | `TextEditor` unavailable on watchOS (use multiline `TextField` if needed) |
| SegmentedControl | `.pickerStyle(.segmented)` unsupported; degrade to a wheel `Picker` |
| SwipeActionRow | `.swipeActions` *does* exist on watch — re-classify to Bucket 2 if the watch catalog wants row actions; excluded for now (UIView-bound `intrinsicContentSize` impl) |
| GlassBackground | no `UIVisualEffectView` on watchOS; could degrade to SwiftUI `.ultraThinMaterial` if the design wants it |

## Implications for the WatchKit renderer

1. The renderer's initial catalog = **Bucket 1 (18)**, which already covers a
   real screen: navigation, cards, forms, labels, buttons, images, alerts.
2. **Before an agent-interaction watch app is buildable**, port the Bucket 2 P0s:
   **TextField, ListView, Sheet** (then SecureField, TabView). Each port is:
   remove the facade's `#if !os(watchOS)` exclusion, provide the SwiftUI-native
   watch body, route through `HostingHelpers.host(_:kind:)`, prove a watch compile.
3. Bucket 3 stays excluded; the Crystal `UI::View` for each already has a
   `*WithWebFallback` / accessible-fallback path (Tier 3 convention) that the
   renderer uses on watch.

> Status flags marked *confirm* are SwiftUI-availability facts to verify against
> an actual watch compile when the port lands — recorded here as candidates, not
> proven, per the "cite evidence, don't rubber-stamp" bar.
