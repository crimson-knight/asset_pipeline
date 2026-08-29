# Platform Capability & Usability Guide

**The single source of truth for: what each target can do, what is exclusive to
one platform, what is honestly wired vs. modeled vs. faked — and the bar a
capability must clear before it counts as "usable."**

This guide is written to be read by a person *or an agent* deciding how to use a
capability. If a row says ✅, you can build on it. If it says 🟡 or ⚠️, the
binding may exist but the experience does not yet meet the bar — read the note
before you depend on it.

It supersedes the scattered picture in
[`tier-matrix.md`](tier-matrix.md) (widgets only),
[`architecture/intent-catalog.md`](architecture/intent-catalog.md) (system
actions; deferred a "Class E"), and [`../APPLE_NATIVE_UI_STATUS.md`](../APPLE_NATIVE_UI_STATUS.md).
Those remain authoritative for their own slice; this guide reconciles them.

---

## 0. Organizing principles (the vision this guide serves)

These are the criteria for *how we classify and name things*. They are not all
built yet — they are the contract every row is measured against.

1. **Foundation → abstraction, in that order.** We wire each platform-native
   capability to the metal, *prove it works with a real interaction test*, and
   only then surface a simple, widget-style interface over it. A capability that
   is abstracted before it is proven is a 🟡, never a ✅.

2. **The type system is the safety rail.** Crystal's compile-time `flag?()`
   gating exists so you *cannot* accidentally use a platform-exclusive
   capability where it has no meaning. Naming `UI::PathControl` in a non-macOS
   build is a compile error that names the missing flag and the
   `*WithWebFallback` escape hatch. A future `UI::Complication` must be gated the
   same way: a watch-only complication referenced from a desktop target must
   fail to *compile*, not fail at runtime. **Capability ↔ platform is a typed
   contract, not a convention.**

3. **Cross-platform parity is the long-game organizing axis** (not built now).
   We classify capabilities so that a feature on one platform points at its
   analog everywhere the hardware can honor it: Apple complications ↔ Wear OS
   complications/tiles; iOS Controls ↔ Android Quick Settings tiles; Live
   Activities ↔ Android ongoing notifications. The eventual goal is "if the
   device can do it, the abstraction reaches it" — including Apple **and**
   Android watches. The [parity table](#9-parity-opportunities) records where
   those seams are.

4. **"Available" means "usable," not "present."** A control that exists in the
   tree, or a binding that returns `success`, is *necessary but never
   sufficient*. See [§1, the usability bar](#1-the-usability-bar--what-available-must-mean).
   This is the governing rule: every status mark in this guide is subordinate to
   it.

---

## 1. The usability bar — what "available" must mean

> **Motivating failure.** A `Sheet` that opened and closed nearly instantly was
> marked **passing**. No human could use it. It "passed" because the validation
> bar only ever checked *static screenshots of the open state* — and a 0ms sheet
> and a 350ms sheet produce an identical "open" screenshot. The transition was
> invisible to the check. This is the same class of false-pass as the SecureField
> password-drop bug: appearance/discoverability verified, **behavior and timing
> never exercised.**

### 1.1 Why the too-fast sheet passed (root cause, in code)

* The native Sheet present/dismiss is driven entirely by SwiftUI's
  `.sheet(isPresented:)` (`SheetFacade.swift:223`). `SheetOverrides`
  (`SheetOverrides.swift:12`) carries **no duration, no spring, no
  reduce-motion field** — the library literally cannot slow, spring, floor, or
  soften the transition; whatever SwiftUI does is final. *(Verified by Codex.)*
  **There is no floor anywhere asserting "present takes ≥ N ms,"** so a
  programmatic present can land with no perceptible animation. (The facade tracks
  `tree-removal` vs `binding-dismiss` (`SheetFacade.swift:173`), not motion — the
  exact "true→true reseed" mechanism is plausible but not proven in code.)
* Validation is a **PNG/report freshness audit with no motion or interaction
  assertions**: `audit_evidence.py` validates that the per-slug PNGs exist, are
  >10KB and readable, are newer than the report, plus report links, mtimes,
  hashes, manifests, and worklist state (`:125,276`) — it never inspects motion,
  timing, or interaction. The designer playbook captures the "interesting state"
  (the *open* sheet) as a single still; the design-critic rubric R18
  (`design-critic/agent.md:177`) only confirms "open/expanded state is the state
  shown." None of it can tell a usable transition from an instant one.

### 1.2 The bar (what a capability MUST clear to be marked ✅)

A surface is **usable** — and may be marked ✅ — only when *all* of these hold.
These are requirements, not suggestions; today almost nothing enforces them, so
they are also the gap list.

| # | Criterion | Why / source |
|---|---|---|
| U1 | **Present/dismiss is perceptible and bounded** — lands in ~300–500ms with a spring; a **floor** (≥~200ms, never instant) *and* a **ceiling** (<1s). | HIG `motion.md:31,35` ("aim for brevity"; "don't make people wait"). Today: no floor, no control on native. |
| U2 | **Reduce-motion swaps to a *fade*, not a *kill*.** | HIG `accessibility.md:174` ("replace transitions with fades"). Today `environment.cr:364` returns `0.0` (instant) — wrong; and native Sheet ignores reduce-motion entirely. |
| U3 | **Native motion reads the MotionScale tokens** (`design_tokens.cr:1120` → baked into `AssetPipelineTokens.swift:132`), or the doc explicitly states "native motion is intentionally system-default." Today no facade reads them; web does, native doesn't. | Brand-contract consistency. |
| U4 | **Proven by a *behavior test*, not a still** — drive the real control (XCUITest / `UI::AXTest` / DOM): present it, prove its action is correctly gated on real input, then dismiss and assert it left. **Caveat (live finding, see §1.4): AX cannot observe a SwiftUI present *animation* — assert observable behavior + input-gating, and prove motion via the code-layer floor + the recorded motion-evidence artifact, not AX geometry.** | CLAUDE.md Definition of Done. |
| U5 | **≥44pt hit target** on every interactive control. | HIG; `touch_target_minimum_px` exists in tokens but nothing asserts rendered size. |
| U6 | **Dismiss is never gesture-only** — when interactive-dismiss is disabled (`sheet.cr:99`) a visible Close/Done affordance must exist. | A no-gesture, no-button sheet is a trap. |
| U7 | **No silent `animated:NO` on a user-facing present.** | `objc_bridge.m:2443` (activity view), `:1793` (map) present instantly — fine for those, but flag any surface that does it. |
| U8 | **Real input, real outcome** (the SecureField lesson) — a binding that returns `success` must be proven to actually move the value/perform the effect, especially where the web path is a stand-in or an anchor is null. | See [§7 false-success risks](#7-honest-gaps--false-success-risks). |

### 1.3 The missing evidence class

`audit_evidence.py` + the 4-screenshot bar must gain a **`motion`/`interaction`
evidence class**: a before/during/after triptych or short recording, plus the
timed behavior test from U4 and a reduce-motion variant asserting a fade (not a
snap, not a kill). Until a surface ships that evidence, it stays 🟡 — a still
frame can no longer promote anything to ✅. **This is the concrete fix for the
class of bug that let the too-fast sheet pass.**

### 1.4 Live findings (2026-06-01, macOS GUI session)

Running the timed Sheet test against the live macOS host (screen unlocked)
produced two corrections that are themselves the usability bar working:

1. **AX cannot observe a SwiftUI `.sheet` present animation.** Sampling the
   sheet body's AX frame at t≈0 vs t≈500ms returned `1.0pt` at *both* — the AX
   tree exposes a degenerate container frame, not transient animation geometry.
   So the original geometry-over-time test was the wrong instrument. The Sheet
   behavior spec (`spec/native_macos/voyager/voyager_sheet_motion_spec.cr`) was
   **reframed** to assert what AX reliably proves and what matters to a user:
   the sheet presents, **Save is correctly gated** (disabled until a real typed
   title reaches it — the SecureField value-fidelity lesson), and **Cancel
   dismisses** leaving the sheet gone. *Verified live, green.* Motion
   perceptibility (U1) is guaranteed at the SwiftUI layer
   (`SheetFacade.resolvePresentationAnimation`, swift-build-verified) + the
   recorded motion-evidence artifact — not AX geometry.

2. **Rerender-mounted presents now animate (CLOSED, 2026-06-01).** Previously
   the imperative `is_presented=` binding-flip path animated
   (`apsk_sheet_set_presented` wraps the flip in `withAnimation`) but the common
   pattern — a `Rerender` rebuilding the tree with a `UI::Sheet` already
   `is_presented=true` (Voyager's editor: `todos_screen.cr:346`) — mounted the
   sheet already-presented, which SwiftUI snaps in without a slide. **Fix (Phase
   12.D):** `makeReactiveSheet` now starts `isPresented=false` and arms
   `pendingInitialPresent`; the persistent host's `.onAppear` flips it true on
   the next runloop wrapped in the resolved animation, so SwiftUI plays the
   present transition. The Codex-hardened dismiss discriminator in
   `SheetHost.onDisappear` is untouched (it only sees `state.isPresented` once
   the sheet content has appeared, i.e. after the flip), and the flip is
   one-shot guarded against `onAppear` re-fire. **Verified:** `swift build` green;
   macOS Sheet behavior AX suite 5/5 green; iOS regression — **V1ContractTests
   (the "sheet shouldn't instantly close" contract), ShareActionSheetTests,
   ReconcileTests, FilePickerTests — 6/6 green** on the iOS 26.5 simulator. The
   *animation timing itself* is still a code-layer + recorded-evidence guarantee
   (AX can't observe it, per finding 1); behavior/no-regression is proven.

---

## 2. Status legend

| Mark | Meaning |
|---|---|
| ✅ | **Usable** — natively wired, beautiful default, and meets [the usability bar](#1-the-usability-bar--what-available-must-mean) incl. a timed behavior test. |
| 🟢 | **Wired, validation pending** — renders/fires natively, but motion/interaction evidence (U1–U4) not yet captured. The honest state of most "passing" surfaces today. |
| 🟡 | **Model-only / export-only** — a Crystal model exists and may emit native scaffold, but there is no live host wiring / in-app render. |
| ⚠️ | **Degrades or fakes** — exists in the cross-platform API but stubs, no-ops, or silently returns success on this platform. Read before depending. |
| 📋 | **Planned** — a phase brief exists; not implemented. |
| ⚪ | **Greenfield** — no code. Listed for territory completeness. |
| — | **No honest analog on this platform.** |

Columns throughout: **Web · iOS/iPadOS · macOS · Android · watchOS** (watchOS is
greenfield everywhere — see [§8](#8-watchos--the-greenfield-target)).

---

## 3. Cross-platform core (not exclusive)

Most of the library renders everywhere from one `UI::View` tree. Authoritative
list: [`tier-matrix.md`](tier-matrix.md).

* **Tier 1 — Brand-universal (17):** `VStack`/`HStack`/`ZStack`, `Card`,
  `Surface`, `Panel`, `Divider`, `Grid`, `Image`, `Label`, `Spacer`, shapes
  (`Circle`/`Rectangle`/`RoundedRectangle`/`Capsule`), `PathView`, `ColumnView`.
* **Tier 2 — Platform default (59):** universal API, idiomatic native render —
  `Button`, `TextField`, `Toggle`, `Slider`, `Picker`, `Sheet`, `TabView`,
  `NavigationStack`, `Form`, etc. Most route through SwiftKit facades on Apple
  (`apsk_make_*`); both Apple value channels (numeric + string) are fully wired
  bidirectionally (`CallbackBridge.swift:74,86`).
  * **Caveat — partial facade coverage:** 7 view kinds (`ColumnView`,
    `TokenField`, `ImageWell`, `Panel`, `Gauge`, `ActivityRing`, `ActivityRings`)
    still route through a generic `fallback_view` rather than a dedicated native
    visit (`platform_visitor.cr:46-72`). They render, but not via a bespoke
    facade. `swiftkit_bridge.cr:15-18` confirms incremental migration.
* **Cross-cutting invariants (all platforms):** `UI::Environment`
  (reduce-motion/contrast/dynamic-type/color-scheme), `UI::DesignTokens` (23
  color roles × light/dark, spacing/type/radius/shadow/**motion** scales).
  ⚠️ The motion scale is honored on web but **ignored by native renderers** —
  see [U3](#12-the-bar-what-a-capability-must-clear-to-be-marked-).

If a capability is here, it is **not** exclusive and is not in the tables below.

---

## 4. Platform-exclusive capabilities

The literal "what's available only on platform X" answer — widgets **and**
capability surfaces. Status reflects the audit (file:line evidence inline).

### 4a. Exclusive widgets (Tier 3 + companions)

| Widget | Exclusive to | Native mapping | Cross-platform fallback | Status |
|---|---|---|---|---|
| `PathControl` | **macOS** | `NSPathControl` (`appkit_renderer.cr:2620`) | `PathControlWithWebFallback` → semantic `<nav>` breadcrumb | 🟢 |
| `ContextMenu` | **macOS + iOS** | ⚠️ **custom visual approximation** — renders a `NSVisualEffectView`/`UIVisualEffectView` row stack (`appkit:2281,2348`, `uikit:2576,2658`), **not** `NSMenu`/`UIMenu`/`UIContextMenuInteraction`; no item-action callbacks wired in those paths | `ContextMenuWithWebFallback` → JS dropdown (web), LinearLayout (Android) | ⚠️ static approximation |
| `ActionSheet` | **iOS** | `.confirmationDialog` via `ConfirmationDialogFacade` (UIKit sends **all** action labels/styles/tokens; facade renders them with `ForEach` — `uikit_renderer.cr:4197`, `ConfirmationDialogFacade.swift:69`) | `ActionSheetWithWebFallback` → bottom-sheet / synth ConfirmationDialog | ⚠️ iOS popover-missing-Cancel bug only ([§10](#10-known-platform-bugs)); multi-action is **no longer** degraded |

Gating mechanics are correct: each gated class lives behind `{% if flag?(...) %}`
with a `_gate_stubs/` file so the `{% raise %}` defers to the call site, and the
Android renderer defines *no* visit methods for these Apple-only classes.

### 4b. Exclusive capability surfaces (beyond widgets)

These are app-shell / OS-integration surfaces, **not** `UI::View`s. Most have a
*real* `ap_*` native bridge with an `apply`/`install` that reaches the OS on
Apple. **Status note (per Codex review):** these are *bridge-proven*, not
*timed-usability*-proven — by [the legend](#2-status-legend) that makes them 🟢,
**not** ✅. Nothing here has a behavior/interaction test yet.

| Capability | Source | Web | iOS | macOS | Android | Status & evidence |
|---|---|---|---|---|---|---|
| **App-shell menu bar** + **MenuBarExtra** | `menu_bar.cr` | — | ⚠️ no-op (bridge returns 0) | 🟢 wired | — | `ap_menu_bar_install` real on macOS (`menu_bar.cr:119`); iOS branch returns 0 (`objc_bridge.m:2762`). **macOS-defining.** |
| **Status-bar item** (menu-bar-resident app) | `status_bar.cr` | — | — | 🟢 wired | — | `ap_status_item_install` (`objc_bridge.m:2826`); iOS branch returns 0. **macOS-only.** |
| **Window config / titlebar style** | `windows.cr` | ⚠️ false (browser-owned) | ⚠️ partial — title + `preferredContentSize` only (`objc_bridge.m:3030`) | 🟢 wired | — | `ap_window_apply_configuration` (`windows.cr:159`). Multi-window + `NSWindow.titlebarStyle` is **macOS-only** (`objc_bridge.m:3091`); iOS has no titlebar/multi-window. |
| **Status-bar appearance** (light/dark, hidden) | `status_bar.cr` | — | 🟢 wired | — | — | `ap_status_bar_apply` (`objc_bridge.m:2986`); macOS branch off. **iOS-only.** |
| **Home-screen Quick Actions** | `quick_actions.cr` | — | 🟢 wired | — | 📋 | `ap_home_screen_quick_actions_apply` (`objc_bridge.m:2702`); export plist/manifest is pure Crystal (all platforms). **iOS-only at runtime.** |
| **User notifications** (auth/schedule/remove) | `notifications.cr` | ⚠️ unsupported | 🟢 wired | 🟢 wired | 🟡 | `UNUserNotificationCenter` bridge both Apple (`objc_bridge.m:2455`); `Unsupported` variant marks gaps honestly. Most complete of the system surfaces. |
| **Share / `ActivityView`** (system share sheet) | `activity_view.cr` | ⚠️ approximation | 🟢 `UIActivityViewController` | 🟢 `NSSharingServicePicker` | 🟢 `Intent.createChooser` | `activity_view.cr:43`; `objc_bridge.m:2334,2403`; `android_renderer.cr:2869`. Real OS share on all three native targets. |
| **AX test harness** | `ax_test/` | — | — | 🟢 (tooling) | — | macOS-only tooling, not an app capability. |

> **macOS-only, at a glance:** `PathControl`, MenuBarExtra/status-bar app,
> multi-window + titlebar styling, app-shell menu bar, the AXTest harness.
> *Greenfield macOS exclusives* (named, no code): Services menu, Quick Look,
> Dock tile/menu/badge, `NSToolbar` customization (future Tier 3
> `PlatformToolbar`), AppleScript/Automation.
>
> **iOS-only, at a glance:** `ActionSheet`, status-bar appearance, Home-screen
> Quick Actions, home-screen Widgets (📋), and (greenfield) Live Activities /
> Dynamic Island, Controls, App Clips, Handoff.

---

## 5. Cross-platform-but-degrades (read before depending)

Capabilities exposed with a concrete visit on *every* renderer, but which stub,
no-op, or degrade on specific platforms. **This category is where "looks
cross-platform" misleads.**

| Capability | Degrades on | What actually happens | Evidence |
|---|---|---|---|
| `ComboBox` | iOS | static chrome only — no live picker wiring | `uikit_renderer.cr:3983` |
| `ComboBox` | web | emits Divs, not `<datalist>` — "stub for doc/test purposes only" | `web_renderer.cr:2390` |
| `TextField` string `on_change` | macOS (per comment, iOS too) | action-only stub; richer string-bound dispatch deferred | `appkit_renderer.cr:600` |
| `SwipeActionRow` / `:swipe_actions` | Android | degrades to an inline `LinearLayout` fallback (drops the swipe affordance) — does **not** raise | `android_renderer.cr:3219`, `widget_route/bootstrap.cr:70` |
| `PageControl` | macOS | HIG "not supported"; synthesized fallback chrome | `appkit_renderer.cr:3652` |
| `RatingIndicator` | iOS | HIG "not supported"; SF-Symbol approximation | `uikit_renderer.cr:4097` |
| `GlassBackground` | Android | `RenderEffect` blur on API≥31, else alpha/elevation fallback | `android_renderer.cr:2184` |
| **All** design tokens | Android | renderer **raises `AndroidRendererNotImplemented`** | `android_renderer.cr:3464` |
| Reactive / WebSocket components | iOS, Android | excluded from compilation entirely (link-symbol reasons) | `components.cr:66` |
| `ChartView` | all Apple | **not** Apple Swift Charts — hand-drawn bars/lines in stack views | `appkit:2771`, `uikit:3031` |

---

## 6. System actions (`UI::SystemAction`, Class C — bridged)

Single Crystal API, per-platform native implementation. Full per-intent matrix
from `system_action/bootstrap.cr`. **The honest pattern is: web = `STDERR`
test stand-in, macOS = bridge-wired, iOS = mostly bridge-wired, Android =
stub-raises.** Apple cells are 🟢 (bridge-proven, not timed-usability-proven).

| Intent | Web | iOS | macOS | Android |
|---|---|---|---|---|
| `copy_to_clipboard` | ⚠️ STDERR | 🟢 | 🟢 | ⚠️ raises → `Failed` |
| `paste_from_clipboard` | ⚠️ STDERR | 🟢 | 🟢 | ⚠️ raises → `Failed` |
| `open_url` | ⚠️ STDERR | 🟢 | 🟢 | ⚠️ raises → `Failed` |
| `incoming_deep_link` | ⚠️ callback-bus + test-dispatch only | ⚠️ same | ⚠️ same | ⚠️ same |
| `print` | ⚠️ STDERR | 🟢 | 🟢 | ⚠️ raises → `Failed` |
| `open_file_picker` | ⚠️ STDERR | 🟢 presents via key-window presenter (XCUITest-verified) | 🟢 | ⚠️ raises → `Failed` |
| `export_file` | ⚠️ STDERR | 🟢 presents (honest 0 return if no presenter / nil source) | 🟢 | ⚠️ raises → `Failed` |
| `request_permission` | ⚠️ STDERR | 🟢 notifications / ⚠️ other resources raise | 🟢 notifications / ⚠️ other | ⚠️ raises → `Failed` |
| `hello_world_alert` | ⚠️ STDERR | ⚠️ raises (demo binding never finished) | 🟢 | ⚠️ raises → `Failed` |

> **Correction (Codex):** `incoming_deep_link` ships only as callback
> registration + a test-time `perform(:incoming_deep_link)` — the full OS event
> wire-through (URL scheme / `onOpenURL`) is **not** wired
> (`bootstrap.cr:493,738`). `request_permission` *is* wired for notifications on
> both Apple platforms (`bootstrap.cr:401`, `objc_bridge.m:3470,3779`); only
> non-notification resources raise.

On Android, `platform_built_in?(:android)` returns *true*, so a stubbed intent
**raises and `perform` returns `Failed`** (not `Unsupported`) — `bootstrap.cr:135`,
`system_action.cr:94`. And **a web caller of `copy_to_clipboard` gets `success`
while nothing reaches the clipboard** (`bootstrap.cr:131-134`). See
[§11](#11-honest-gaps--false-success-risks).

---

## 7. System-experiences surface (Widgets / Activities / Shortcuts / …)

The surface `intent-catalog.md` deferred as "Class E." **Correction to my first
draft:** App Shortcuts, Widgets, and Live Activities are *not* greenfield — each
has a real **export-only Crystal model** that emits deterministic Swift scaffold
(this matches `APPLE_NATIVE_UI_STATUS.md`). They model metadata and emit Swift;
they do **not** render in-app or perform live registration.

| Surface | Web | iOS | macOS | Android | watchOS | Modeled? |
|---|---|---|---|---|---|---|
| **Widgets (WidgetKit)** | — | 📋 render path / 🟡 model | 🟡 (shared WidgetKit) | ⚪ | ⚪ | `widgets.cr` (`export_widgetkit_scaffold`); families incl. `accessoryCircular/Rectangular/Inline/Corner` already mapped. Render primitive `UI::HomeScreenWidget` + App-Group bridge = Phase 11. |
| **App Shortcuts (App Intents)** | — | 🟡 | 🟡 | ⚪ | ⚪ | `app_shortcuts.cr` (`export_app_intents_scaffold`) — title/phrases/params; no live registration. |
| **Live Activities / Dynamic Island** | — | 🟡 | — | ⚪ | — | `live_activities.cr` (`export_activitykit_scaffold`); no Dynamic Island layout, no push-update path. |
| **Notifications** | ⚠️ | 🟢 auth wired | 🟢 | 🟡 | ⚪ | `notifications.cr` — the most complete; real Apple auth binding. |
| **Controls (Control Center / Lock Screen, iOS 18)** | — | ⚪ | — | ⚪ | — | Greenfield. Parity peer: Android QS tiles. |
| **Complications** | — | — | — | — | 🟡 model+gate | **watchOS-exclusive.** `UI::Complication` (`views/complication.cr`) ships now: Tier 3, compile-gated to `:watchos` (naming it off-watch is a compile error — *verified*), with `ComplicationWithWebFallback` (card preview, AX-proven in the Voyager gallery). The `UI::WatchKit::Renderer` that draws it natively is 📋 Phase 12. |
| **Handoff / Continuity** | — | ⚪ | ⚪ | — | — | Greenfield (`NSUserActivity`). |
| **Spotlight / CoreSpotlight** | — | ⚪ | ⚪ | ⚪ | — | Greenfield. |
| **System Drag & Drop (cross-app)** | ⚪ | ⚪ | ⚪ | ⚪ | — | Greenfield for *cross-app* DnD. (In-list reorder via `ListView#on_move` **is** wired through SwiftUI `.onMove` — `list_view.cr:49`, `uikit_renderer.cr:1191`, `ListViewFacade.swift:180`.) |

**Planned architecture (Phase 11 roadmap, not yet built):** WidgetKit /
ActivityKit / ClockKit run in a *separate process with no Crystal runtime*.
Today `widgets.cr` is **export-only** (emits scaffold; `widgets.cr:1,312`) — the
in-app render primitive `UI::HomeScreenWidget` and the App-Group JSON-snapshot
bridge are the *plan*. Once built, that same bridge is what a watchOS
complication reuses — which is why Phase 11 de-risks complications. Treat this
paragraph as roadmap, not a current capability.

---

## 8. watchOS — the greenfield target

**Confirmed entirely greenfield:** zero `flag?(:watchos)`, no `WatchKit::Renderer`,
no `UI::Complication`, no `WCSession` symbols anywhere in `src/`. The only
`watchOS` references are HIG comment text in a few renderers (e.g.
`activity_view.cr:55`, `appkit_renderer.cr:3206`, `uikit_renderer.cr:3972`) —
prose, not code.

Forward scaffold (roadmap, not shipped):

1. **`WatchKit::Renderer`** — a `PlatformVisitor` subclass under
   `{% if flag?(:watchos) %}`, SwiftUI-only (closer to the WidgetKit path than
   UIKit). A *subset* of the catalog applies (no `TextEditor`; watch-idiomatic
   list / page `TabView`).
2. **`UI::Complication`** — mirrors `UI::HomeScreenWidget`
   (`kind`/`family`/`content`), with watch families
   (`.accessoryCircular/.accessoryRectangular/.accessoryInline/.accessoryCorner`)
   — **already present as string→Swift mappings in `widgets.cr`** (the seam).
   Gated so a desktop target referencing it **fails to compile** (principle #2).
3. **Watch↔phone sync** — `WatchConnectivity` (`WCSession`) + the App-Group
   snapshot bridge + `WidgetCenter.reloadComplications()`.

**Opinionated-beauty obligations:** SF-Symbols-first compact layouts, smart-stack
tint, `.privacySensitive` redaction, `.containerBackground`, Digital-Crown-aware
scrolling — zero config, HIG-authentic light + dark, and meeting the
[usability bar](#1-the-usability-bar--what-available-must-mean) before any row
leaves 🟡.

**Sequencing:** watchOS follows Phase 11 — complications *are* the WidgetKit /
App-Group snapshot model applied to a new family set.

---

## 9. Parity opportunities

The cross-platform-parity axis (principle #3). Where one platform's exclusive
has an honest analog elsewhere, a single abstraction could drive both.

| Unified concept | Apple | Android | Watch | Seam today |
|---|---|---|---|---|
| **Glanceable timeline surface** (highest leverage) | WidgetKit | App Widgets / Glance | complications / tiles | `widgets.cr` (accessory families present) + Phase 11 App-Group bridge |
| **Quick-toggle control** | Controls (iOS 18) | Quick Settings tiles | — | greenfield both |
| **Voice / automation intent** | App Intents / Siri | App Actions | — | `app_shortcuts.cr` (title/phrases/params abstracted) |
| **Live / ongoing status** | Live Activities / Dynamic Island | ongoing notifications | — | `live_activities.cr` (add Android export target) |
| **Launcher shortcut** | Home-screen Quick Actions | App Shortcuts | Wear tiles | `quick_actions.cr` (has objc apply path) |
| **Notifications** | UserNotifications | NotificationCompat | — | `notifications.cr` (model already parity-aware) |

All "glanceable" surfaces share the property *out-of-process, snapshot-driven, no
app runtime* — the single most reusable abstraction in the framework's future.

---

## 10. Known platform bugs

* **iOS `ActionSheet`/`ConfirmationDialog` renders as a popover missing Cancel**
  on some size classes; size-class env override does *not* fix it — needs a
  trait override or native `UIAlertController`. (Session memory
  `project_voyager_action_sheet_popover`.)
* **The Sheet too-fast transition** — see [§1.1](#11-why-the-too-fast-sheet-passed-root-cause-in-code).
  Native Sheet has no motion control; reduce-motion unhonored.

---

## 11. Honest gaps & false-success risks

The risks an agent/person most needs to know — "reports success, does nothing"
is the recurring shape:

1. **Web SystemActions are `STDERR` stand-ins.** `copy_to_clipboard`,
   `paste`, `open_url`, `print` return `success` on web but only print to STDERR
   — nothing reaches the browser (`bootstrap.cr:131-134`).
2. ~~**iOS file-picker / export report success but no-op**~~ **RESOLVED + PROVEN
   (2026-06-01).** The bridge now resolves the key window's `rootViewController`
   as presenter (a null anchor is fine) and presents a real
   `UIDocumentPickerViewController`; the presenter is resolved **synchronously**
   so the int return is honest (0 → Crystal raises → not-performed, never fake
   success). Runtime-proven by `FilePickerTests` (XCUITest, iOS 26.5 sim): tapping
   the Class-C exerciser's "Open file picker" presents the picker (its `Cancel`
   chrome appears). The earlier "returns success, no-ops" false-success is gone.
3. **Android SystemActions all raise** — "cross-platform system actions" is
   really web(fake) / macOS / iOS today; Android = none.
4. **Live Activities / App Shortcuts / Widgets are export-only** — emit Swift,
   never render in-app, no runtime registration. "Supports Live Activities" =
   "emits ActivityKit scaffold," not "renders one."
5. **Deep links are catalogued `missing`** (`:open_url`/`:on_open_url` =
   `coverage_today: missing`) — **yet Phase 11's interactive-widget deliverable
   D5 assumes a deep-link handler exists.** Real risk; wire before relying.
6. **JNI handles leak by design** (`native_handle.cr:179-187`) — global refs
   can't be released at finalize (no JNIEnv); require explicit `release!`. A real
   Android correctness gap, not a stub.
7. **Native motion ignores the brand MotionScale** (U3) — durations like `0.2`
   (`objc_bridge.m:3004`) and `0.4` (`list_view.cr:81`) are hand-picked literals;
   the 240ms/spring contract is silently unused on Apple platforms.
8. **`ChartView` is not Apple Swift Charts** — hand-drawn; looks native, isn't.

---

## 12. Maintenance

* This guide is **derived**. When `tier-matrix.md`, `intent-catalog.md`, the
  `phases/` briefs, `APPLE_NATIVE_UI_STATUS.md`, the SwiftKit facades, or the
  renderers change, update the relevant table here in the same commit.
* New platform-exclusive surface? Add it to [§4b](#4b-exclusive-capability-surfaces-beyond-widgets)
  with an **honest** status mark — and 🟡 until it meets the usability bar.
* **No still frame promotes a surface to ✅.** Promotion to ✅ requires the
  motion/interaction evidence class from [§1.3](#13-the-missing-evidence-class):
  a timed behavior test (U4) + reduce-motion variant + before/during/after
  evidence.
* watchOS rows move off ⚪/📋 only when a real `WatchKit::Renderer` + validation
  captures exist.

## Change log

* **2026-06-01 (revision 3)** — Applied a Codex (gpt-5.5, xhigh) adversarial
  accuracy review. **P0 corrections:** downgraded all unproven `✅` → `🟢` (the
  app-shell + SystemAction cells are bridge-proven, not timed-usability-proven —
  per the doc's own legend); marked iOS menu-bar/status-item `⚠️ no-op` (bridge
  returns 0 off macOS); iOS window-config `⚠️ partial` (title + preferredContentSize
  only); `ContextMenu` `⚠️ static approximation` (custom `NSVisualEffectView` row
  stack, **not** `NSMenu`/`UIMenu`/`UIContextMenuInteraction`); removed the stale
  "ActionSheet multi-action degrades" claim (UIKit now sends all actions via
  `ForEach`); fixed `request_permission` (notifications **are** wired both Apple
  platforms); `incoming_deep_link` → `⚠️ callback-bus + test-dispatch only`;
  Android `:swipe_actions` degrades to LinearLayout (does not raise). **P1:** added
  the missing `ActivityView`/share-sheet row. **P2:** softened the unproven Sheet
  reseed causality, reworded `audit_evidence.py` (PNG/report freshness audit, no
  motion assertions), fixed Android-returns-`Failed`-not-`Unsupported`, reframed
  the App-Group complication bridge as roadmap, corrected `ListView#on_move` (it
  *is* wired). Codex verdict on rev2: "not safe to build on as-is" — these fixes
  address its top-3.
* **2026-06-01 (revision 2)** — Rebuilt from four parallel code audits
  (Crystal capability gating, Swift/native bridges, unmodeled system-experiences,
  interaction/timing). Added the governing **usability bar** (§1) with the
  Sheet-too-fast root cause and the missing motion/interaction evidence class;
  added the **organizing principles** (§0: foundation→abstraction, type-system
  safety rail, parity vision); added **cross-platform-but-degrades** (§5) and
  the full **SystemAction matrix** (§6); **corrected** App Shortcuts / Widgets /
  Live Activities from greenfield → 🟡 export-only (they emit Swift scaffold) and
  upgraded the app-shell surfaces (menu bar / status bar / windows / quick
  actions / notifications) from model-only → ✅-Apple-wired per their real `ap_*`
  bridges; added **false-success risks** (§11).
* **2026-06-01 (revision 1)** — Created. Consolidated the scattered exclusivity
  picture and scaffolded the watchOS / complications direction.
