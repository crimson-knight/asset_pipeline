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

| Trait | Web (ARIA) | UIKit | AppKit | Android |
|---|---|---|---|---|
| `:selected` | `aria-selected="true"` | `Selected` (0x4) | `setAccessibilitySelected:YES` | — |
| `:not_enabled` | `aria-disabled="true"` | `NotEnabled` (0x40) | `setAccessibilityEnabled:NO` | `setEnabled(false)` |
| `:plays_sound` | — | `PlaysSound` (0x10) | — | — |
| `:starts_media` | — | `StartsMediaSession` (0x100) | — | — |
| `:causes_page_turn` | — | `CausesPageTurn` (0x20000) | — | — |
| `:updates_frequently` | `aria-live="polite"` | `UpdatesFrequently` (0x80) | — | — |
| `:is_busy` | `aria-busy="true"` | (summary; closest analog) | — | — |
| `:is_required` | `aria-required="true"` | — | — | — |
| `:is_invalid` | `aria-invalid="true"` | — | — | — |
| `:adjustable` | — | `Adjustable` (0x1000) | — | — |
| `:allows_direct_interaction` | — | `AllowsDirectInteraction` (0x8000) | — | — |

Unmapped combinations fall through silently — the trait is advisory on
the platform that lacks the analog.

## Per-platform role-symbol mapping

Web emits a literal `role=` attribute (e.g. `role="button"`,
`role="heading"`, `role="progressbar"`). AppKit maps to
`NSAccessibility*Role` strings (e.g. `AXButton`, `AXSlider`,
`AXProgressIndicator`); roles without an AppKit analog skip the
`setAccessibilityRole:` call so the underlying NSView's intrinsic role
wins. UIKit overloads the traits bitmask with role-flag bits
(`Button=0x1`, `Link=0x2`, `Header=0x10000`, `Image=0x8`,
`SearchField=0x80000`, `StaticText=0x40000`, `TabBar=0x20000000`); roles
without a UIKit trait analog rely on the underlying UIKit class's
intrinsic role. Android exposes no first-class role channel — the
existing widget class hierarchy + `contentDescription` carries the
semantics.

## Renderer status

| Renderer | Hint | Role | Traits | Value | Identifier |
|---|---|---|---|---|---|
| Web | `aria-description` | `role=` (via `ax_role_to_aria`) | ARIA-state mapping | `aria-valuetext` | `data-accessibility-id` |
| AppKit | `setAccessibilityHelp:` | `setAccessibilityRole:` (via `appkit_ax_role_string`) | `setAccessibilitySelected:` / `setAccessibilityEnabled:` | `setAccessibilityValue:` | `setAccessibilityIdentifier:` (wins over `test_id`) |
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
   set is smaller than ARIA's; `:tab_panel`, `:status`, `:navigation`,
   `:form`, `:tooltip` map to the closest analog (`AXGroup`,
   `AXHelpTag`) rather than a dedicated role.
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
