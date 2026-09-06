# Android renderer tiers — September 6, 2026

Classification of every `UI::View` type against the Android Views renderer,
per the plan's Phase 2 tiers. "A core" means a native instrumentation suite
asserts the control's behavior on API 31, 35 and 36 (the named contract
suites in `samples/cross_platform/android_host/app/src/androidTest`). "B
preview" renders natively in a study fixture but has no behavioral contract.
"unverified" has a renderer handler that no Android fixture or test exercises;
it must not appear in a support claim until it does. "D unsupported" has no
handler and fails with an explicit diagnostic. Promotion to A still requires
the Phase 2 exit gate per control (accessibility roles and traits, theme,
lifecycle, phone/tablet matrix); the contract suites cover the listed aspects.

| View | Handler | Exercised by | Tier | Basis |
| --- | --- | --- | --- | --- |
| `ActionSheet` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `ActionSheetWithWebFallback` | yes | — | unverified | handler exists; no Android fixture or test |
| `ActivityIndicator` | yes | basics | A core | basics (indeterminate, paused visibility) |
| `ActivityRing` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `ActivityRings` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `ActivityView` | yes | material_bridge | B preview | renders in the study fixture; no behavioral contract |
| `ActivityViewPresenter` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `Alert` | yes | dialog, sheet | A core | dialogs |
| `AndroidSwipeActionRow` | yes | — | unverified | handler exists; no Android fixture or test |
| `AsyncImage` | yes | — | unverified | handler exists; no Android fixture or test |
| `Button` | yes | basics, compound_focus, dialog, failure, focus, layout, layout_contract, material_bridge, navigation, semantics, sheet, view_state | A core | layout, semantics, focus, dialogs, sheets |
| `Canvas` | yes | — | unverified | handler exists; no Android fixture or test |
| `Capsule` | yes | structure | A core | structure (intrinsic size, fill, outline clip) |
| `Card` | yes | layout, material_bridge | A core | layout |
| `ChartView` | yes | material_bridge | B preview | renders in the study fixture; no behavioral contract |
| `Checkbox` | yes | material_bridge, semantics | A core | semantics, compound focus |
| `Circle` | yes | structure | A core | structure (intrinsic size, fill, outline clip) |
| `ColorPicker` | yes | material_bridge | B preview | renders in the study fixture; no behavioral contract |
| `ColumnView` | yes | — | unverified | handler exists; no Android fixture or test |
| `Item` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `ComboBox` | yes | material_bridge | A core | compound focus |
| `Complication` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `ComplicationWithWebFallback` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `ConfirmationDialog` | yes | dialog | A core | dialogs |
| `ContextMenu` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `ContextMenuWithWebFallback` | yes | — | unverified | handler exists; no Android fixture or test |
| `DatePicker` | yes | — | unverified | handler exists; no Android fixture or test |
| `DisclosureGroup` | yes | structure | A core | structure (header tap calls back to Crystal, expanded state survives recreation, accessibility text) |
| `Divider` | yes | basics | A core | basics (geometry) |
| `Form` | yes | structure | A core | structure (section header, labeled fields, footer, in order) |
| `FullScreenCover` | yes | — | unverified | handler exists; no Android fixture or test |
| `Gauge` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `GlassBackground` | yes | — | unverified | handler exists; no Android fixture or test |
| `Grid` | yes | structure | A core | structure (one native row per row, cells side by side) |
| `HStack` | yes | failure, focus, layout, layout_contract, material_bridge | A core | layout (equal width, RTL) |
| `IconButton` | yes | basics | A core | basics (drawable, label, callback) |
| `Image` | yes | image | A core | images |
| `ImageWell` | yes | — | unverified | handler exists; no Android fixture or test |
| `InlineActionRow` | yes | — | unverified | handler exists; no Android fixture or test |
| `Inspector` | yes | — | unverified | handler exists; no Android fixture or test |
| `Label` | yes | basics, compound_focus, dialog, failure, focus, layout, layout_contract, material_bridge, navigation, semantics, sheet, text, view_state | A core | layout, text, semantics |
| `LinkButton` | yes | basics | A core | basics (on_tap, browser fallback) |
| `ListView` | yes | — | unverified | handler exists; no Android fixture or test |
| `MapView` | yes | material_bridge | B preview | renders in the study fixture; no behavioral contract |
| `MenuButton` | yes | — | unverified | handler exists; no Android fixture or test |
| `NavigationLink` | yes | navigation, view_state | A core | navigation |
| `NavigationSplitView` | yes | — | unverified | handler exists; no Android fixture or test |
| `NavigationStack` | yes | failure, navigation, view_state | A core | navigation |
| `OutlineView` | yes | — | unverified | handler exists; no Android fixture or test |
| `Node` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `PageControl` | yes | — | unverified | handler exists; no Android fixture or test |
| `Panel` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `PathControl` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `PathControlWithWebFallback` | yes | — | unverified | handler exists; no Android fixture or test |
| `PathView` | yes | — | unverified | handler exists; no Android fixture or test |
| `Picker` | yes | material_bridge, semantics | A core | semantics, compound focus |
| `Popover` | yes | material_bridge | B preview | renders in the study fixture; no behavioral contract |
| `PopoverPresenter` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `ProgressView` | yes | basics | A core | basics (Material indicators, real ratios) |
| `RadioGroup` | yes | compound_focus, material_bridge, semantics | A core | semantics, focus |
| `RatingIndicator` | yes | — | unverified | handler exists; no Android fixture or test |
| `Rectangle` | yes | structure | A core | structure (intrinsic size, fill) |
| `RichText` | yes | — | unverified | handler exists; no Android fixture or test |
| `RoundedRectangle` | yes | structure | A core | structure (intrinsic size, fill, outline clip) |
| `ScrollView` | yes | focus, layout_contract, view_state | A core | layout, view state |
| `SearchField` | yes | material_bridge | A core | text |
| `SecureField` | yes | basics | A core | basics (masking, Crystal-owned restoration) |
| `SegmentedControl` | yes | compound_focus | A core | focus |
| `Sheet` | yes | material_bridge, sheet | A core | sheets, window matrix |
| `SheetPresenter` | no | sheet | D unsupported | raises AndroidRendererNotImplemented |
| `Slider` | yes | material_bridge, semantics | A core | semantics, compound focus |
| `Snackbar` | yes | material_bridge | B preview | renders in the study fixture; no behavioral contract |
| `SnackbarPresenter` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `Spacer` | yes | layout_contract, view_state | A core | layout |
| `Stepper` | yes | material_bridge | A core | compound focus |
| `Surface` | yes | — | unverified | handler exists; no Android fixture or test |
| `SwipeAction` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `SwipeActionRow` | yes | — | unverified | handler exists; no Android fixture or test |
| `TabView` | yes | — | unverified | handler exists; no Android fixture or test |
| `TextArea` | yes | basics | A core | basics (multi-line, callback) |
| `TextEditor` | yes | text | A core | text, view state |
| `TextField` | yes | failure, focus, layout_contract, material_bridge, navigation, semantics, sheet, text, view_state | A core | text, view state, focus, sheets |
| `TimePicker` | yes | — | unverified | handler exists; no Android fixture or test |
| `Toggle` | yes | material_bridge, semantics | A core | semantics, compound focus |
| `ToggleButton` | yes | basics | A core | basics (label in both states, on_toggle) |
| `TokenField` | yes | — | unverified | handler exists; no Android fixture or test |
| `Token` | no | — | D unsupported | raises AndroidRendererNotImplemented |
| `Toolbar` | yes | material_bridge | A core | navigation |
| `ToolbarItemGroup` | yes | — | unverified | handler exists; no Android fixture or test |
| `ToolbarSpacer` | yes | — | unverified | handler exists; no Android fixture or test |
| `Tooltip` | yes | — | unverified | handler exists; no Android fixture or test |
| `VideoPlayer` | yes | material_bridge | B preview | renders in the study fixture; no behavioral contract |
| `VStack` | yes | basics, compound_focus, dialog, failure, focus, image, layout, layout_contract, material_bridge, navigation, semantics, sheet, text, view_state | A core | layout |
| `WebViewComponent` | yes | material_bridge | B preview | renders in the study fixture; no behavioral contract |
| `ZStack` | yes | layout_contract | A core | layout |

## Totals

- A core: 41
- B preview: 8
- D unsupported: 17
- unverified: 29

## Next promotions

The unverified group is the largest. Promote in this order, each through its
own fixture and contract suite: `ListView`, `TabView`, `DatePicker`,
`TimePicker`, `MenuButton`; then the remaining decorative surfaces. The
structure suite (September 6) promoted the four shapes, `Grid`, `Form` and
`DisclosureGroup`; the Android handlers now give shapes their intrinsic size,
lay out a grid as real rows, and let a disclosure header call back to Crystal
through the new optional `DisclosureGroup#on_toggle`. `Popover`, `Snackbar`, `MapView`, `ChartView`,
`VideoPlayer`, `WebViewComponent`, `ColorPicker` and `ActivityView` stay preview
until their platform dependencies are split from the core target (Phase 2).
`ActionSheet`, `ActivityRing(s)`, `Gauge`, `Panel` and the complication views
remain unsupported; Android has no native counterpart for several of them and
they need an explicit design, not a stub.
