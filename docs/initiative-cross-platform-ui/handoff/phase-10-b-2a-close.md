# Phase 10B.2a close — Static AX metadata on UI::View base

**Branch:** `phase-10-b-2a` (cut from `phase-10` @ `phase-10-batch-2-merged-2026-05-26`).
**Brief:** `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/brief-10-b-2a.md` (v1).
**Status:** Forward-only commits; ready for content review.

---

## What shipped

`UI::View` gains five new static accessibility-metadata properties and
all four platform renderers thread them through. The widget catalog
declares per-class default accessibility roles so `:button`, `:text`,
`:switch`, `:slider`, … fall out of the type rather than requiring the
caller to set `accessibility_role` on every leaf.

WCAG 2.2 AA gains: web emits `aria-description`, `role`, `aria-valuetext`,
`aria-selected`, `aria-disabled`, `aria-required`, `aria-invalid`,
`aria-busy`, and `aria-live` from the new properties. UIKit gains
`accessibilityHint`, `accessibilityValue`, and a `accessibilityTraits`
bitmask. AppKit gains `setAccessibilityHelp:`, `setAccessibilityValue:`,
`setAccessibilityRole:` (mapped to NSAccessibility role constants), and
partial trait coverage (`Selected`, `Enabled`). Android composes
label + value + hint into the single `contentDescription` channel
(stateDescription bridge deferred — documented limitation).

## New properties (5)

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `accessibility_hint` | `String?` | `nil` | Supplemental explanation read after the label ("Double-tap to open settings"). |
| `accessibility_role` | `Symbol?` | `nil` (falls back to `default_accessibility_role`) | Explicit semantic role override. |
| `accessibility_traits` | `Array(Symbol)` | `[]` | UIKit-style capability flags (`:selected`, `:not_enabled`, `:plays_sound`, …). |
| `accessibility_value` | `String?` | `nil` | Current value as a human string ("On", "75%", "3 of 7"). |
| `accessibility_identifier` | `String?` | `nil` | Explicit XCTest / Espresso identifier; wins over `test_id` on native. |

`effective_accessibility_role` resolves the explicit override-or-default
precedence. Renderers MUST call `effective_accessibility_role`, not
read `@accessibility_role` directly.

## Default `default_accessibility_role` table

51 widget subclasses ship explicit defaults:

| Widget | Role | Widget | Role |
|---|---|---|---|
| `Button` | `:button` | `Label` | `:text` |
| `Toggle` | `:switch` | `Checkbox` | `:checkbox` |
| `Slider` | `:slider` | `ProgressView` | `:progress_bar` |
| `Image` | `:image` | `TextField` | `:text_field` |
| `SecureField` | `:text_field` | `SearchField` | `:search` |
| `TextArea` | `:text_field` | `TextEditor` | `:text_field` |
| `LinkButton` | `:link` | `IconButton` | `:button` |
| `ToggleButton` | `:button` | `MenuButton` | `:button` |
| `RadioGroup` | `:radio_group` | `TabView` | `:tab_list` |
| `NavigationLink` | `:link` | `NavigationStack` | `:navigation` |
| `NavigationSplitView` | `:navigation` | `Toolbar` | `:toolbar` |
| `Alert` | `:alert` | `Sheet` | `:dialog` |
| `Popover` | `:dialog` | `ConfirmationDialog` | `:alert` |
| `ListView` | `:list` | `Card` | `:group` |
| `Divider` | `:separator` | `Stepper` | `:spinbutton` |
| `SegmentedControl` | `:tab_list` | `DatePicker` | `:group` |
| `TimePicker` | `:group` | `ColorPicker` | `:button` |
| `Picker` | `:combobox` | `Tooltip` | `:tooltip` |
| `Snackbar` | `:status` | `Form` | `:form` |
| `Grid` | `:grid` | `RichText` | `:text` |
| `VideoPlayer` | `:group` | `MapView` | `:group` |
| `WebViewComponent` | `:group` | `ChartView` | `:img` |
| `RatingIndicator` | `:slider` | `Gauge` | `:progress_bar` |
| `ActivityIndicator` | `:progress_bar` | `ActivityRing` | `:progress_bar` |
| `PageControl` | `:tab_list` | `DisclosureGroup` | `:group` |
| `SwipeActionRow` | `:list_item` | `InlineActionRow` | `:list_item` |
| `Button` (button.cr) | `:button` |  |  |

Layout primitives (`VStack`, `HStack`, `ZStack`, `ScrollView`, `Spacer`)
deliberately return `nil` so the underlying HTML tag's intrinsic role
(no role) wins on web and the AppKit/UIKit visual container stays a
plain non-AX-element on native — matching the existing container
clamp logic in `apply_common_properties`.

## Per-platform trait-symbol mapping

Corrected in iter 2 (Codex Finding 2) — the iter-1 UIKit bit
positions were wrong. The table below shows the canonical
`UIAccessibilityConstants.h` bit values.

| Trait | Web (ARIA) | UIKit | AppKit | Android |
|---|---|---|---|---|
| `:selected` | `aria-selected="true"` | `Selected` (1 << 4 = 0x10) | `setAccessibilitySelected:YES` | — |
| `:not_enabled` | `aria-disabled="true"` + `disabled` attr | `NotEnabled` (1 << 9 = 0x200) + `setEnabled:NO` | `setEnabled:NO` (via `ap_set_enabled_if_responds`) | `setEnabled(false)` |
| `:plays_sound` | — | `PlaysSound` (1 << 5 = 0x20) | — | — |
| `:starts_media` | — | `StartsMediaSession` (1 << 11 = 0x800) | — | — |
| `:causes_page_turn` | — | `CausesPageTurn` (1 << 14 = 0x4000) | — | — |
| `:updates_frequently` | `aria-live="polite"` | `UpdatesFrequently` (1 << 10 = 0x400) | — | — |
| `:is_busy` | `aria-busy="true"` | — (no UIKit analog; bit 0x100 is `SummaryElement`, semantically different) | — | — |
| `:is_required` | `aria-required="true"` | — | — | — |
| `:is_invalid` | `aria-invalid="true"` | — | — | — |
| `:adjustable` | — | `Adjustable` (1 << 12 = 0x1000) | — | — |
| `:allows_direct_interaction` | — | `AllowsDirectInteraction` (1 << 13 = 0x2000) | — | — |

Unmapped combinations fall through silently — the trait is advisory on
the platform that lacks the analog.

## Per-platform role-symbol mapping

Web emits a literal `role=` attribute (e.g. `role="button"`,
`role="heading"`, `role="progressbar"`). AppKit maps to
`NSAccessibility*Role` strings (e.g. `AXButton`, `AXSlider`,
`AXProgressIndicator`); roles without an AppKit analog skip the
`setAccessibilityRole:` call so the underlying NSView's intrinsic role
wins. UIKit overloads the traits bitmask with role-flag bits
(corrected in iter 2: `Button=1<<0=0x1`, `Link=1<<1=0x2`,
`SearchField=1<<2=0x4`, `Image=1<<3=0x8`, `StaticText=1<<7=0x80`,
`TabBar=1<<15=0x8000`, `Header=1<<16=0x10000`); roles without a UIKit
trait analog rely on the underlying UIKit class's intrinsic role.
Android exposes no first-class role channel — the existing widget
class hierarchy + `contentDescription` carries the semantics.

## Renderer status

| Renderer | Hint | Role | Traits | Value | Identifier |
|---|---|---|---|---|---|
| Web | `aria-description` | `role=` (via `ax_role_to_aria`) | ARIA-state mapping | `aria-valuetext` | `data-accessibility-id` |
| AppKit | `setAccessibilityHelp:` | `setAccessibilityRole:` (via `appkit_ax_role_string`) | `setAccessibilitySelected:` / `setEnabled:` (iter 2; guarded via `ap_set_enabled_if_responds`) | `setAccessibilityValue:` | `setAccessibilityIdentifier:` (wins over `test_id`) |
| UIKit | `setAccessibilityHint:` | trait bitmask (via `uikit_role_trait_bitmask`) | `setAccessibilityTraits:` bitmask OR | `setAccessibilityValue:` | `setAccessibilityIdentifier:` (wins over `test_id`) |
| Android | concatenated into `contentDescription` ("label. value. hint") | — (covered by widget class) | `setEnabled(false)` for `:not_enabled` | concatenated into `contentDescription` | (deferred; planned via stateDescription bridge) |

All four renderers thread label, hint, role, value, traits, and
identifier through `apply_common_properties` /
`apply_common_non_surface_properties`. The legacy `test_id` channel is
preserved on every renderer — only the explicit
`accessibility_identifier` setter overrides it on native.

## Spec coverage

`spec/web/ui/accessibility_metadata_spec.cr` — 27 examples, all green:

```
crystal spec spec/web/ui/accessibility_metadata_spec.cr
27 examples, 0 failures, 0 errors, 0 pending
```

Coverage:

- 5 property-surface specs (getter / setter round-trip for each new
  property).
- 12 default-role inference specs (one per representative widget
  + explicit-override beats default + layout-primitive returns nil).
- 10 web renderer threading specs (each of `aria-description`,
  `role` from override, `role` from default, `aria-valuetext`,
  `aria-selected`, `aria-disabled`, `aria-required` + `aria-invalid`
  combined, `data-accessibility-id`, legacy `data-testid` preserved,
  label + hint coexistence).

**Full web spec regression:**

```
crystal spec spec/web/
1840 examples, 4 failures, 0 errors, 66 pending
```

The 4 failures match the merge-baseline pre-existing failures
(`UI::Theme inject_theme_css returns empty string with no theme`; three
Phase 2 component-system fixture mismatches in
`phase2_verification_spec.cr`). Confirmed identical to the
`phase-10-batch-2-merged-2026-05-26` baseline.

## Lint + format

```
crystal run scripts/lint_conventions.cr
lint_conventions: OK (453 files, 14 rules, 0 diagnostics)

crystal tool format --check
EXIT: 0
```

## Honest limitations

1. **AppKit role coverage is partial.** AppKit's NSAccessibility role
   set is smaller than ARIA's. As of iter 2 (Codex Finding 4), the
   helper `appkit_ax_role_string` maps `:tab_panel`, `:status`,
   `:navigation`, `:form` to `AXGroup` and `:tooltip` to `AXHelpTag`.
   Iter 1 originally claimed this in the doc but the `:tab_panel`
   case was missing from the helper; iter 2 added the case so the
   claim now matches the code.
2. **Android `accessibility_identifier` slot is deferred.** Android's
   identifier surface is `setTag(int, String)` plus testTag in
   Compose — not yet wired through `LibAndroidBridge`. The legacy
   `test_id` channel still writes `contentDescription` when no AX
   label / hint / value is set, preserving Espresso compatibility.
3. **Android `accessibility_value` shares the `contentDescription`
   channel.** Android API 30+ added `setStateDescription` for exactly
   this use case but the JNI bridge doesn't expose it yet. We fold
   value into `contentDescription` as "label. value. hint" so
   pre-30 devices still get an announcement; the bridge upgrade is
   a follow-up.
4. **UIKit traits are an `Array(Symbol)` not a typed enum** to keep
   the API extensible across iOS versions. Unmapped trait symbols
   return 0 from `uikit_trait_bitmask` and silently no-op — adding a
   new trait is a one-line case-arm addition.

These are documented because `[[plan-what-to-understand-not-just-what-to-build]]`
demands we surface lower-layer assumptions explicitly rather than ship
silent gaps.

## Out of scope (deferred to follow-on briefs)

- **Action + focus + keyboard semantics** — 10B.2b.
- **Environment-driven contracts** (motion preferences, contrast
  preferences) — 10B.2c.
- **VoiceOver / TalkBack live testing** — separate validation phase.
- **Android stateDescription bridge** — JNI follow-up.

— Implementer (Claude Opus 4.7), 10B.2a iter-1

---

## Iter 2 — Codex BLOCK remediation

Codex returned BLOCK on iter 1 with 4 findings. All 4 addressed
forward-only on `phase-10-b-2a`. Spec count rises from 27 to 39
(12 new Populator-forwarding specs). Full web regression: 1852
examples, 4 failures (pre-existing baseline), 0 errors.

### Finding 1 (BLOCKER) — SwiftKit Populator gap closed

The iter-1 Populator (`src/ui/native/swiftkit_overrides.cr`) only
forwarded `test_id` + `accessibility_label` to the SwiftKit
ViewOverrides slots. The five new iter-1 properties
(`accessibility_hint`, `accessibility_role`, `accessibility_traits`,
`accessibility_value`, `accessibility_identifier`) bypassed the
SwiftKit-backed widgets entirely (Button, Label, Image, TextField,
Toggle, Slider, ProgressView, etc. — every widget that flows through
`apsk_make_*`).

**Crystal-side changes:**
- `populate_view_common` now writes the 5 new properties.
  Identifier precedence (explicit `accessibility_identifier` wins
  over `test_id`) matches the native AppKit/UIKit precedence.
- Added `Populator::Sender#set_uint64` for the boxed `UInt64`
  traits-mask field. Default no-op so spec recording senders that
  don't care about the new slot stay compiling.
- Added `Populator.populator_trait_bit` and
  `Populator.populator_role_trait_bit` — canonical bit tables that
  MUST stay in lockstep with `uikit_renderer.cr#uikit_trait_bitmask`
  and `uikit_renderer.cr#uikit_role_trait_bitmask`. The traits-mask
  emitted to the Swift side is the OR of all trait bits AND the
  role-derived trait bit.
- Production `SwiftKitObjCSender#set_uint64` dispatches through the
  new `apsk_overrides_set_uint64_boxed` bridge fun.

**Swift-side changes (`ViewOverrides.swift` + `CommonModifiers.swift`):**
- Five new `@objc(apsk*)` properties on `ViewOverrides`:
  `apskAccessibilityHint: String?`, `apskAccessibilityValue: String?`,
  `apskAccessibilityRole: String?`, `apskAccessibilityTraitsMask: NSNumber?`.
  Each uses the `apsk*` selector prefix to dodge the
  `UIAccessibility.*` selector clash on iOS slices (same root cause
  as `apskAccessibilityLabel` in iter 1).
- `CommonModifiers.apply` reads each new slot and emits the matching
  SwiftUI modifier: `.accessibilityHint(Text(...))`,
  `.accessibilityValue(Text(...))`, and a single
  `.accessibilityAddTraits(...)` call composed from the bitmask.
  Bit 0x200 (`NotEnabled`) is special-cased to emit
  `.disabled(true)` because SwiftUI represents disabled via the
  view-modifier channel rather than as an `AccessibilityTraits` flag.
  Bit positions match the Crystal-side canonical table.

**Native bridge changes:**
- New `ap_set_enabled_if_responds(obj, enabled)` helper in
  `objc_bridge.m`. Guards on `[obj respondsToSelector:@selector(setEnabled:)]`
  so the call is safe to send to plain UIView / NSView objects.
- New `apsk_overrides_set_uint64_boxed(target, setter_name, value)`
  helper in `swiftkit_bridge.m`. Boxes the value as
  `[NSNumber numberWithUnsignedLongLong:]` so the
  `apskAccessibilityTraitsMask: NSNumber?` property receives a
  reference-typed value.

**Swift verification status:** the Crystal-side wiring is exercised
by the new spec
`spec/web/ui/renderers/swiftkit/accessibility_metadata_overrides_spec.cr`
(12 examples). The Swift-side application of those slots
(`CommonModifiers.apply` -> SwiftUI modifiers) requires a macOS /
iOS host build to validate end-to-end and is covered by the existing
`OverridesPropagationTests.swift` snapshot harness — extending those
snapshots to assert the new accessibility cascade is a follow-up
when the Swift build host is available. The Crystal-side guards
ensure no claim is made about behaviour the Crystal half can't
verify in plain `crystal spec`.

### Finding 2 (BLOCKER) — UIKit trait/role constants corrected

The iter-1 `uikit_trait_bitmask` and `uikit_role_trait_bitmask`
helpers in `src/ui/renderers/uikit_renderer.cr` carried wrong bit
positions. Corrected against `UIAccessibilityConstants.h`:

| Symbol | iter-1 value | iter-2 (canonical) value |
|---|---|---|
| `:selected` | `0x4` | `0x10` (1 << 4) |
| `:not_enabled` | `0x40` | `0x200` (1 << 9) |
| `:plays_sound` | `0x10` | `0x20` (1 << 5) |
| `:starts_media` | `0x100` | `0x800` (1 << 11) |
| `:causes_page_turn` | `0x20000` | `0x4000` (1 << 14) |
| `:updates_frequently` | `0x80` | `0x400` (1 << 10) |
| `:is_busy` | `0x20` (SummaryElement — wrong) | `0` (no UIKit analog) |
| `:allows_direct_interaction` | `0x8000` (collided with TabBar) | `0x2000` (1 << 13) |
| `:adjustable` | `0x1000` | `0x1000` (correct — unchanged) |
| Role `:search` | `0x80000` | `0x4` (1 << 2) |
| Role `:text` | `0x40000` | `0x80` (1 << 7) |
| Role `:tab` | `0x20000000` (1 << 29 — invented) | `0x8000` (1 << 15) |
| Roles `:button`, `:link`, `:header`, `:image` | correct | unchanged |

`:is_busy` now returns 0 — UIKit has no "busy" trait analog. The
web renderer still emits `aria-busy="true"` (it owns the only honest
mapping); UIKit silently no-ops as documented.

### Finding 3 (BLOCKER) — `:not_enabled` is now canonical disable

Policy adopted: **`:not_enabled` is the canonical accessibility
trait for disabling, and renderers MUST functionally disable the
control in addition to flipping the AX semantic state.**

Web (`web_renderer.cr`): in addition to `aria-disabled="true"`, now
emits the HTML `disabled` attribute. Form controls (`<button>`,
`<input>`, `<select>`, `<textarea>`, `<fieldset>`) actually become
inert. Non-form elements get `aria-disabled` only.

UIKit (`uikit_renderer.cr`): after writing the
`UIAccessibilityTraitNotEnabled` bit to `accessibilityTraits`, now
also calls `ap_set_enabled_if_responds(ptr, 0)`. UIControl-derived
classes (UIButton, UISwitch, UISlider, UISegmentedControl, …)
respond to `setEnabled:`; plain UIViews silently no-op via the
`respondsToSelector:` guard.

AppKit (`appkit_renderer.cr`): replaced the brittle (and ineffective)
`setAccessibilityEnabled:NO` call with
`ap_set_enabled_if_responds(ptr, 0)`. NSControl-derived classes
(NSButton, NSSlider, NSPopUpButton, …) flip to their disabled state;
plain NSViews silently no-op. AppKit's automatic accessibility
dimming propagates the enabled-state change to the AX tree.

Android (`android_renderer.cr`): unchanged from iter 1 —
`setEnabled(false)` was already correct.

Swift (`CommonModifiers.swift`): the bit 0x200 case in the new
`apskAccessibilityTraitsMask` reader emits `.disabled(true)` rather
than adding a trait flag, mirroring SwiftUI's semantics.

### Finding 4 (MEDIUM) — AppKit `:tab_panel` claim synced

Iter 1 close handoff claimed `:tab_panel`, `:status`, `:navigation`,
`:form`, `:tooltip` mapped to `AXGroup` / `AXHelpTag`. Audit:

- `:status`, `:navigation`, `:form` → `AXGroup` ✓ (matched)
- `:tooltip` → `AXHelpTag` ✓ (matched)
- `:tab_panel` → returned nil (FALSE CLAIM)

Patched the code: added `when :tab_panel then "AXGroup"` to
`appkit_ax_role_string` in `src/ui/renderers/appkit_renderer.cr`.
The handoff "Honest limitations" section now matches the helper.
Chose to patch the code (rather than walk back the handoff claim)
because `AXGroup` is the correct AppKit analog for a tab panel —
the parent AXTabGroup owns selection while the content panel is a
plain group.

### Iter-2 spec + lint result

```
crystal spec spec/web/ui/accessibility_metadata_spec.cr
27 examples, 0 failures, 0 errors, 0 pending

crystal spec spec/web/ui/renderers/swiftkit/accessibility_metadata_overrides_spec.cr
12 examples, 0 failures, 0 errors, 0 pending

crystal spec spec/web/
1852 examples, 4 failures, 0 errors, 66 pending   (baseline-matching)

crystal run scripts/lint_conventions.cr
lint_conventions: OK (454 files, 14 rules, 0 diagnostics)

crystal build src/asset_pipeline.cr
(success)
```

— Implementer (Claude Opus 4.7), 10B.2a iter-2
